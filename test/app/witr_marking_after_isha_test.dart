import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Reported by the owner: after marking Isha he cannot mark Witr while the
/// prayer is chosen automatically, and only selecting Witr by hand works.
///
/// Built from the routine his device actually holds, read off it rather than
/// imagined: Isha is Fard + Sunnah, and Witr is a single part he named
/// «Важиб». The two things Home needs after the transition are a Witr context
/// and a Witr routine with a free slot — `routineMarkingEnabled` is exactly
/// `routine == null || routine.currentPart?.nextSlotIndex != null`.
void main() {
  late AppDatabase database;

  final localDate = LocalDate(2026, 9, 21);
  final startedAt = DateTime.utc(2026, 9, 21, 16);

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> seedOwnersRoutines() async {
    final routines = PrayerRoutineRepository(database);
    final isha = await routines.getTemplate(PrayerType.isha);
    await routines.replaceTemplate(
      prayerType: PrayerType.isha,
      expectedRevision: isha.revision,
      displayName: isha.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: 'isha-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 4,
          requiredSurahSlots: 2,
          allowsFollowingImam: true,
        ),
        PrayerRoutinePartTemplate(
          id: 'isha-sunnah',
          stableKey: 'sunnah',
          orderIndex: 1,
          kind: PrayerRoutinePartKind.sunnah,
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
      ],
    );
    final witr = await routines.getTemplate(PrayerType.witr);
    await routines.replaceTemplate(
      prayerType: PrayerType.witr,
      expectedRevision: witr.revision,
      displayName: witr.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: 'witr-wajib',
          stableKey: 'witr-wajib',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.custom,
          customLabel: 'Важиб',
          rakaatCount: 3,
          requiredSurahSlots: 3,
        ),
      ],
    );
  }

  Future<void> completeIsha({required bool includingSunnah}) async {
    final session = await PrayerRoutineRepository(database)
        .ensureCurrentSession(
          context: PrayerContext(prayerType: PrayerType.isha),
          localDate: localDate,
          startedAtUtc: startedAt,
        );
    for (final progress in session!.parts) {
      if (!includingSunnah &&
          progress.part.kind == PrayerRoutinePartKind.sunnah) {
        continue;
      }
      await (database.update(
        database.prayerSessionParts,
      )..where((row) => row.id.equals(progress.part.id))).write(
        PrayerSessionPartsCompanion(
          completedAtUtc: Value<DateTime>(DateTime.utc(2026, 9, 21, 17)),
        ),
      );
    }
  }

  ProviderContainer containerWith(PrayerContextResolutionStatus status) {
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        startupProvider.overrideWith((ref) async {}),
        localDateProvider.overrideWithValue(_FixedLocalDateProvider(localDate)),
        prayerContextResolutionProvider.overrideWith(
          (ref) => Stream<PrayerContextResolution>.value(
            PrayerContextResolution(
              status: status,
              context: PrayerContext(prayerType: PrayerType.isha),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle(ProviderContainer container) async {
    for (var index = 0; index < 80; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<({PrayerType? type, bool markingEnabled})> homeStateFor(
    PrayerContextResolutionStatus status,
  ) async {
    final container = containerWith(status);
    final resolution = container.listen(
      homePrayerContextResolutionProvider,
      (previous, next) {},
    );
    addTearDown(resolution.close);
    await settle(container);

    final context = container
        .read(homePrayerContextResolutionProvider)
        .valueOrNull
        ?.context;
    if (context == null) return (type: null, markingEnabled: false);

    final key = (context: context, localDate: localDate);
    final routineSubscription = container.listen(
      currentPrayerRoutineProvider(key),
      (previous, next) {},
    );
    addTearDown(routineSubscription.close);
    await settle(container);

    final routine = container
        .read(currentPrayerRoutineProvider(key))
        .valueOrNull;
    return (
      type: context.prayerType,
      // The exact expression Home uses.
      markingEnabled:
          routine == null || routine.currentPart?.nextSlotIndex != null,
    );
  }

  test('a finished Isha hands the automatic context to Witr, markable', () async {
    await seedOwnersRoutines();
    await completeIsha(includingSunnah: true);

    final state = await homeStateFor(PrayerContextResolutionStatus.automatic);

    expect(state.type, PrayerType.witr);
    expect(
      state.markingEnabled,
      isTrue,
      reason:
          'the Witr session is created on demand with its three free slots, so '
          'there is something to mark the moment the context arrives',
    );
  });

  test('an Isha whose Sunnah is unfinished keeps the context', () async {
    // The likelier shape of the report: Home advances only when the *whole*
    // Isha is done, and his Isha has a Sunnah part after the Fard. Marking the
    // Fard alone leaves the context on Isha with its Sunnah still open — so a
    // surah marked then belongs to Isha, not to Witr.
    await seedOwnersRoutines();
    await completeIsha(includingSunnah: false);

    final state = await homeStateFor(PrayerContextResolutionStatus.automatic);

    expect(state.type, PrayerType.isha);
    expect(
      state.markingEnabled,
      isTrue,
      reason: 'the Sunnah still has free slots, so marking stays possible',
    );
  });

  test('a hand-picked Isha never advances, finished or not', () async {
    await seedOwnersRoutines();
    await completeIsha(includingSunnah: true);

    final state = await homeStateFor(PrayerContextResolutionStatus.manual);

    expect(
      state.type,
      PrayerType.isha,
      reason: 'an explicit choice is an instruction, not a guess to improve on',
    );
    expect(
      state.markingEnabled,
      isFalse,
      reason:
          'and this is what the owner would see: a finished Isha he chose '
          'himself has no free slot, so nothing can be marked until he picks '
          'another prayer',
    );
  });
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this._value);

  final LocalDate _value;

  @override
  LocalDate today() => _value;
}
