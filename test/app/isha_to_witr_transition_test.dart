import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Reported by the owner: he chose Иша by hand and was taken straight to Витр,
/// because an earlier Иша of the same day was already complete. That left the
/// Иша he had asked for impossible to look at or correct.
///
/// The agreed automatic behaviour is kept. What changes is that an explicit
/// choice is treated as an instruction rather than a guess to improve on.
void main() {
  late AppDatabase database;

  final localDate = LocalDate(2026, 9, 16);
  final startedAt = DateTime.utc(2026, 9, 16, 16);

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> seedTemplate(PrayerType prayerType) async {
    final routines = PrayerRoutineRepository(database);
    final current = await routines.getTemplate(prayerType);
    await routines.replaceTemplate(
      prayerType: prayerType,
      expectedRevision: current.revision,
      displayName: current.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: '${prayerType.name}-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: prayerType == PrayerType.witr
              ? PrayerRoutinePartKind.witr
              : PrayerRoutinePartKind.fard,
          rakaatCount: 3,
          requiredSurahSlots: 2,
        ),
      ],
    );
  }

  /// An Isha that is finished — the precondition the transition looks for.
  Future<void> completeIsha() async {
    final routines = PrayerRoutineRepository(database);
    final session = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.isha),
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    for (final progress in session!.parts) {
      await (database.update(
        database.prayerSessionParts,
      )..where((row) => row.id.equals(progress.part.id))).write(
        PrayerSessionPartsCompanion(
          completedAtUtc: Value<DateTime>(DateTime.utc(2026, 9, 16, 17)),
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

  Future<PrayerType?> resolvedTypeFor(
    PrayerContextResolutionStatus status,
  ) async {
    final container = containerWith(status);
    final subscription = container.listen(
      homePrayerContextResolutionProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    for (var index = 0; index < 60; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
    return container
        .read(homePrayerContextResolutionProvider)
        .valueOrNull
        ?.context
        ?.prayerType;
  }

  test(
    'a manually chosen Isha stays Isha, even once Isha is complete',
    () async {
      await seedTemplate(PrayerType.isha);
      await seedTemplate(PrayerType.witr);
      await completeIsha();

      expect(
        await resolvedTypeFor(PrayerContextResolutionStatus.manual),
        PrayerType.isha,
        reason: 'the prayer he asked for must stay available to correct',
      );
    },
  );

  test(
    'an automatic Isha still advances to Witr once Isha is complete',
    () async {
      await seedTemplate(PrayerType.isha);
      await seedTemplate(PrayerType.witr);
      await completeIsha();

      expect(
        await resolvedTypeFor(PrayerContextResolutionStatus.automatic),
        PrayerType.witr,
        reason: 'the agreed automatic behaviour is deliberately unchanged',
      );
    },
  );

  test('an unfinished Isha never advances, automatic or not', () async {
    await seedTemplate(PrayerType.isha);
    await seedTemplate(PrayerType.witr);

    expect(
      await resolvedTypeFor(PrayerContextResolutionStatus.automatic),
      PrayerType.isha,
    );
    expect(
      await resolvedTypeFor(PrayerContextResolutionStatus.manual),
      PrayerType.isha,
    );
  });
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this.value);

  final LocalDate value;

  @override
  LocalDate today() => value;
}
