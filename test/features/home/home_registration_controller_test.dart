import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/home/application/home_registration_controller.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// The mark pipeline, driven without a screen.
///
/// Until 2026-10-09 every one of these questions could only be asked by
/// pumping the whole of Home — which is why the two midnight defects of
/// September were found on a device rather than by a test.
void main() {
  late AppDatabase database;

  final today = LocalDate(2026, 10, 9);
  final yesterday = LocalDate(2026, 10, 8);
  final nowUtc = DateTime.utc(2026, 10, 9, 15);

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> addSurah(String id, int number) async {
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(<SurahDescriptor>[
      SurahDescriptor(
        id: id,
        surahNumber: number,
        officialName: 'Test $id',
        ayahCount: 4,
      ),
    ]);
    await surahs.addMastered(id);
  }

  /// A Fajr Fard the imam can lead — the only kind of part following the
  /// imam may complete.
  Future<void> followableFajrFard() async {
    final routines = PrayerRoutineRepository(database);
    final fajr = await routines.getTemplate(PrayerType.fajr);
    await routines.replaceTemplate(
      prayerType: PrayerType.fajr,
      expectedRevision: fajr.revision,
      displayName: fajr.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: 'fajr-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 2,
          requiredSurahSlots: 2,
          allowsFollowingImam: true,
        ),
      ],
    );
  }

  /// Witr as he keeps it, but with one slot, so a second mark finds it full.
  Future<void> oneSlotWitr() async {
    final routines = PrayerRoutineRepository(database);
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
          kind: PrayerRoutinePartKind.witr,
          customLabel: 'Важиб',
          rakaatCount: 3,
          requiredSurahSlots: 1,
        ),
      ],
    );
  }

  ({ProviderContainer container, HomeRegistrationController controller})
  harness({
    PrayerContextSelectionMode mode = PrayerContextSelectionMode.manual,
    PrayerContextResolution? resolution,
    bool Function()? isActive,
    void Function()? onBusyChanged,
  }) {
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        startupProvider.overrideWith((ref) async {}),
        timeProviderProvider.overrideWithValue(_FixedTimeProvider(nowUtc)),
        localDateProvider.overrideWithValue(_FixedLocalDateProvider(today)),
        prayerTimeSettingsProvider.overrideWith(
          (ref) => Stream<PrayerTimeSettings>.value(
            PrayerTimeSettings(
              location: UzbekistanPrayerLocations.bySlug('toshkent-shahri')!,
              contextSelectionMode: mode,
            ),
          ),
        ),
        prayerTodayScheduleProvider.overrideWith(
          (ref) async => throw StateError('No schedule in this fixture.'),
        ),
        if (resolution != null)
          prayerContextResolutionProvider.overrideWith(
            (ref) => Stream<PrayerContextResolution>.value(resolution),
          ),
      ],
    );
    addTearDown(container.dispose);
    final controller = HomeRegistrationController(
      read: container.read,
      invalidate: container.invalidate,
      isActive: isActive ?? () => true,
      onBusyChanged: onBusyChanged,
    );
    return (container: container, controller: controller);
  }

  Future<void> settle(ProviderContainer container) async {
    final subscriptions = <ProviderSubscription<Object?>>[
      container.listen(prayerTimeSettingsProvider, (_, _) {}),
      container.listen(homePrayerContextResolutionProvider, (_, _) {}),
    ];
    for (var index = 0; index < 80; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });
  }

  group('the registration token', () {
    test('a token is current until something it depends on changes', () async {
      final h = harness();
      await settle(h.container);

      final token = h.controller.captureToken();
      expect(h.controller.isCurrent(token), isTrue);

      h.controller.contextChanged();
      expect(h.controller.isCurrent(token), isFalse);
      expect(
        () => h.controller.requireCurrent(token),
        throwsA(isA<RegistrationContextChanged>()),
      );
    });

    test('a token from a screen that has gone is never current', () async {
      var active = true;
      final h = harness(isActive: () => active);
      await settle(h.container);

      final token = h.controller.captureToken();
      active = false;
      expect(h.controller.isCurrent(token), isFalse);
    });

    test(
      'choosing another day in the calendar makes the token stale',
      () async {
        final h = harness();
        await settle(h.container);

        final token = h.controller.captureToken();
        h.container.read(pendingRegistrationDateProvider.notifier).state =
            LocalDate(2026, 10, 1);

        expect(h.controller.isCurrent(token), isFalse);
      },
    );
  });

  group('which day a mark belongs to', () {
    test('between midnight and Fajr it is the night that is ending', () async {
      final h = harness(
        mode: PrayerContextSelectionMode.automatic,
        resolution: PrayerContextResolution(
          status: PrayerContextResolutionStatus.automatic,
          context: PrayerContext(prayerType: PrayerType.isha),
          contextLocalDate: yesterday,
        ),
      );
      await settle(h.container);

      expect(h.controller.currentPrayerLocalDate(), yesterday);
      expect(h.controller.registrationLocalDate(), yesterday);
      expect(h.controller.captureToken().localDate, yesterday);
    });

    test(
      'choosing that same night in the calendar is still ordinary',
      () async {
        final h = harness(
          mode: PrayerContextSelectionMode.automatic,
          resolution: PrayerContextResolution(
            status: PrayerContextResolutionStatus.automatic,
            context: PrayerContext(prayerType: PrayerType.isha),
            contextLocalDate: yesterday,
          ),
        );
        await settle(h.container);

        h.container.read(pendingRegistrationDateProvider.notifier).state =
            yesterday;
        expect(h.controller.pendingRegistrationDate(), isNull);

        h.container.read(pendingRegistrationDateProvider.notifier).state =
            today;
        expect(
          h.controller.pendingRegistrationDate(),
          today,
          reason: 'choosing the new day is an explicit instruction',
        );
      },
    );
  });

  group('which prayer a mark belongs to', () {
    test('a hand-picked prayer is what was picked', () async {
      await PrayerRepository(database).saveSelectedContext(
        PrayerContext(prayerType: PrayerType.maghrib),
        updatedAtUtc: nowUtc,
      );
      final h = harness();
      await settle(h.container);

      final action = await h.controller.resolvePrayerForAction();

      expect(action?.context, PrayerContext(prayerType: PrayerType.maghrib));
      expect(action?.isAutomatic, isFalse);
    });

    test('a past day in automatic mode asks rather than guesses', () async {
      final h = harness(mode: PrayerContextSelectionMode.automatic);
      await settle(h.container);
      h.container.read(pendingRegistrationDateProvider.notifier).state =
          LocalDate(2026, 10, 1);

      expect(await h.controller.resolvePrayerForAction(), isNull);
    });

    test('an override chosen for today wins in automatic mode', () async {
      final h = harness(mode: PrayerContextSelectionMode.automatic);
      await settle(h.container);
      h.controller.setPrayerContextOverride(
        PrayerContext(prayerType: PrayerType.jumuah),
      );

      final action = await h.controller.resolvePrayerForAction();

      expect(action?.context.prayerType, PrayerType.jumuah);
      expect(action?.isAutomatic, isFalse);
    });
  });

  group('recording into the routine', () {
    final witr = PrayerContext(prayerType: PrayerType.witr);

    test('the mark fills the next free slot, and a full routine refuses '
        'the next one without writing', () async {
      await addSurah('surah-a', 112);
      await addSurah('surah-b', 113);
      await oneSlotWitr();
      var busyChanges = 0;
      final h = harness(onBusyChanged: () => busyChanges++);
      await settle(h.container);

      final first = await h.controller.registerRecitation(
        surahId: 'surah-a',
        prayer: witr,
        token: h.controller.captureToken(),
      );
      expect(first, isA<RecitationRecorded>());
      final recorded = (first as RecitationRecorded).registration.event;
      expect(recorded.slotIndex, 0);
      expect(recorded.localDate, today);
      expect(recorded.prayerSessionId, isNotNull);
      expect(first.contextStillCurrent, isTrue);

      final second = await h.controller.registerRecitation(
        surahId: 'surah-b',
        prayer: witr,
        token: h.controller.captureToken(),
      );
      expect(second, isA<RecitationSlotUnavailable>());
      expect((second as RecitationSlotUnavailable).routineCompleted, isTrue);

      final history = await RecitationRepository(database).getHistory();
      expect(history.map((entry) => entry.event.surahId), <String>['surah-a']);
      expect(h.controller.busySurahIds, isEmpty);
      expect(busyChanges, 4, reason: 'marked busy and released, twice');
    });

    test('a stale token writes nothing', () async {
      await addSurah('surah-a', 112);
      await oneSlotWitr();
      final h = harness();
      await settle(h.container);

      final token = h.controller.captureToken();
      h.controller.contextChanged();
      final outcome = await h.controller.registerRecitation(
        surahId: 'surah-a',
        prayer: witr,
        token: token,
      );

      expect(outcome, isA<RecitationContextChanged>());
      expect(await RecitationRepository(database).getHistory(), isEmpty);
      expect(
        await database.select(database.prayerSessions).get(),
        isEmpty,
        reason:
            'ensuring the session creates it, so a stale mark must stop before '
            'that — an empty session on a day he did not pray is the defect '
            'of 8f1b4e4',
      );
      expect(h.controller.busySurahIds, isEmpty);
    });

    test('a second tap on the same surah while the first is in flight is '
        'ignored', () async {
      await addSurah('surah-a', 112);
      await oneSlotWitr();
      final h = harness();
      await settle(h.container);

      final first = h.controller.registerRecitation(
        surahId: 'surah-a',
        prayer: witr,
        token: h.controller.captureToken(),
      );
      final second = await h.controller.registerRecitation(
        surahId: 'surah-a',
        prayer: witr,
        token: h.controller.captureToken(),
      );

      expect(second, isA<RecitationAlreadyInFlight>());
      expect(await first, isA<RecitationRecorded>());
    });

    test('Undo withdraws what was recorded', () async {
      await addSurah('surah-a', 112);
      await oneSlotWitr();
      final h = harness();
      await settle(h.container);

      final outcome = await h.controller.registerRecitation(
        surahId: 'surah-a',
        prayer: witr,
        token: h.controller.captureToken(),
      );
      await h.controller.undoRecitation(
        (outcome as RecitationRecorded).registration,
      );

      expect(await RecitationRepository(database).getHistory(), isEmpty);
    });

    test(
      'following the imam completes the part and records no recitation',
      () async {
        await followableFajrFard();
        final fajr = PrayerContext(prayerType: PrayerType.fajr);
        final h = harness();
        await settle(h.container);
        final session = await PrayerRoutineRepository(database)
            .ensureCurrentSession(
              context: fajr,
              localDate: today,
              startedAtUtc: nowUtc,
            );
        final partId = session!.parts.single.part.id;

        final completion = await h.controller.completeByFollowingImam(partId);

        expect(completion, isNotNull);
        final after = await PrayerRoutineRepository(database)
            .ensureCurrentSession(
              context: fajr,
              localDate: today,
              startedAtUtc: nowUtc,
            );
        expect(after!.isCompleted, isTrue);
        expect(
          await RecitationRepository(database).getHistory(),
          isEmpty,
          reason: '"followed the imam" creates no recitation — the rule',
        );
        expect(h.controller.busyRoutinePartIds, isEmpty);
      },
    );
  });

  group('applying a picked prayer', () {
    test('manual mode keeps it as the selection', () async {
      final h = harness();
      await settle(h.container);
      final token = h.controller.captureToken();

      final applied = await h.controller.applyPickedPrayer(
        PrayerContext(prayerType: PrayerType.asr),
        token,
      );

      expect(applied, isTrue);
      expect(
        await PrayerRepository(database).getSelectedContext(),
        PrayerContext(prayerType: PrayerType.asr),
      );
    });

    test('automatic mode keeps it as an override for today only', () async {
      final h = harness(mode: PrayerContextSelectionMode.automatic);
      await settle(h.container);
      final token = h.controller.captureToken();

      await h.controller.applyPickedPrayer(
        PrayerContext(prayerType: PrayerType.witr),
        token,
      );

      final override = h.container.read(prayerContextOverrideProvider);
      expect(override?.context, PrayerContext(prayerType: PrayerType.witr));
      expect(override?.localDate, today);
    });

    test('a stale token applies nothing', () async {
      final h = harness(mode: PrayerContextSelectionMode.automatic);
      await settle(h.container);
      final token = h.controller.captureToken();
      h.controller.contextChanged();

      final applied = await h.controller.applyPickedPrayer(
        PrayerContext(prayerType: PrayerType.witr),
        token,
      );

      expect(applied, isFalse);
      expect(h.container.read(prayerContextOverrideProvider), isNull);
    });
  });
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this._value);

  final DateTime _value;

  @override
  DateTime nowUtc() => _value;
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this._value);

  final LocalDate _value;

  @override
  LocalDate today() => _value;
}
