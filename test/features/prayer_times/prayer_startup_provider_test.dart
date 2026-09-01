import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'selected prayer starts empty and then restores the stored context',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PrayerRepository(database);
      final stored = PrayerContext(prayerType: PrayerType.dhuhr, isQada: true);
      await repository.saveSelectedContext(
        stored,
        updatedAtUtc: DateTime.utc(2026, 8, 25, 12),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          timeProviderProvider.overrideWithValue(
            FixedPrayerTimeProvider(DateTime.utc(2026, 8, 25, 12)),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedPrayerProvider), isNull);
      final loaded = await container
          .read(selectedPrayerProvider.notifier)
          .stream
          .firstWhere((value) => value != null)
          .timeout(const Duration(seconds: 2));

      expect(loaded, stored);
      expect(loaded?.prayerType, isNot(PrayerType.fajr));
    },
  );

  test(
    'fresh unconfirmed settings fail closed without loading a schedule',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var scheduleUseCaseReads = 0;
      final settings = PrayerTimeSettings(
        location: testTashkentLocation(),
        contextSelectionMode: PrayerContextSelectionMode.automatic,
      );
      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          prayerTimeSettingsProvider.overrideWith(
            (ref) => Stream<PrayerTimeSettings>.value(settings),
          ),
          prayerScheduleUseCasesProvider.overrideWith((ref) async {
            scheduleUseCaseReads += 1;
            throw StateError('Schedule loading must not start.');
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(prayerTimeSettingsProvider.future);
      await _settleSelectedPrayerLoad(container, database);
      final resolution = await container.read(
        prayerContextResolutionProvider.future,
      );

      expect(resolution.status, PrayerContextResolutionStatus.missingSchedule);
      expect(resolution.context, isNull);
      expect(resolution.canMarkDirectly, isFalse);
      expect(scheduleUseCaseReads, 0);

      await expectLater(
        container.read(prayerTodayScheduleProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(scheduleUseCaseReads, 0);
    },
  );

  test(
    'schema v1 manual Tashkent stays manual without schedule loading',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await PrayerRepository(database).saveSelectedContext(
        PrayerContext(prayerType: PrayerType.isha),
        updatedAtUtc: DateTime.utc(2026, 8, 25),
      );
      final legacy = PrayerTimeSettingsRepository.encode(
        PrayerTimeSettings(
          location: testTashkentLocation(),
          contextSelectionMode: PrayerContextSelectionMode.manual,
        ),
      );
      legacy['schemaVersion'] = 1;
      legacy.remove('locationConfirmed');
      legacy.remove('contextModeExplicitlyChosen');
      await AppSettingsRepository(database).setString(
        PrayerTimeSettingsRepository.settingKey,
        jsonEncode(legacy),
        updatedAtUtc: DateTime.utc(2026, 8, 25),
      );
      final settings = await PrayerTimeSettingsRepository(
        AppSettingsRepository(database),
      ).load();
      var scheduleUseCaseReads = 0;
      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          prayerTimeSettingsProvider.overrideWith(
            (ref) => Stream<PrayerTimeSettings>.value(settings),
          ),
          prayerScheduleUseCasesProvider.overrideWith((ref) async {
            scheduleUseCaseReads += 1;
            throw StateError('Schedule loading must not start.');
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(prayerTimeSettingsProvider.future);
      await _waitForSelectedPrayerLoad(container);
      final resolution = await container.read(
        prayerContextResolutionProvider.future,
      );

      expect(settings.locationConfirmed, isFalse);
      expect(settings.contextSelectionMode, PrayerContextSelectionMode.manual);
      expect(settings.contextModeExplicitlyChosen, isTrue);
      expect(resolution.status, PrayerContextResolutionStatus.manual);
      expect(resolution.context?.prayerType, PrayerType.isha);
      await expectLater(
        container.read(prayerTodayScheduleProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(scheduleUseCaseReads, 0);
    },
  );

  test('confirmed reliable schedule resolves the current prayer', () async {
    final harness = _ProviderHarness(
      nowUtc: _utcForTashkent(2026, 8, 25, 17, 30),
    );
    addTearDown(harness.dispose);
    await harness.prime();

    final resolution = await harness.container.read(
      prayerContextResolutionProvider.future,
    );

    expect(resolution.status, PrayerContextResolutionStatus.automatic);
    expect(resolution.context?.prayerType, PrayerType.asr);
    expect(resolution.context?.isQada, isFalse);
    expect(resolution.canMarkDirectly, isTrue);
  });

  test('sunrise gap has no context and disables direct marking', () async {
    final harness = _ProviderHarness(
      nowUtc: _utcForTashkent(2026, 8, 25, 6, 0),
    );
    addTearDown(harness.dispose);
    await harness.prime();

    final resolution = await harness.container.read(
      prayerContextResolutionProvider.future,
    );

    expect(resolution.status, PrayerContextResolutionStatus.betweenPrayers);
    expect(resolution.context, isNull);
    expect(resolution.nextPrayerType, PrayerType.dhuhr);
    expect(resolution.canMarkDirectly, isFalse);
  });

  test('schedule retained from another region fails closed', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = PrayerTimeSettings(
      location: UzbekistanPrayerLocations.bySlug('samarqand-shahri')!,
      locationConfirmed: true,
      contextSelectionMode: PrayerContextSelectionMode.automatic,
    );
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        timeProviderProvider.overrideWithValue(
          FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 25, 17, 30)),
        ),
        prayerTimeSettingsProvider.overrideWith(
          (ref) => Stream<PrayerTimeSettings>.value(settings),
        ),
        // This is the previous region's still-reliable retained value.
        prayerTodayScheduleProvider.overrideWith((ref) async => _today()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(prayerTimeSettingsProvider.future);
    await container.read(prayerTodayScheduleProvider.future);
    await _settleSelectedPrayerLoad(container, database);

    final resolution = await container.read(
      prayerContextResolutionProvider.future,
    );

    expect(resolution.status, PrayerContextResolutionStatus.missingSchedule);
    expect(resolution.context, isNull);
    expect(resolution.canMarkDirectly, isFalse);
  });

  testWidgets('automatic context refreshes at the exact minute boundary', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final timeProvider = _MutablePrayerTimeProvider(
      _utcForTashkent(2026, 8, 25, 5, 41, 59),
    );
    final settings = PrayerTimeSettings(
      location: testTashkentLocation(),
      locationConfirmed: true,
      contextSelectionMode: PrayerContextSelectionMode.automatic,
    );
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        timeProviderProvider.overrideWithValue(timeProvider),
        prayerTimeSettingsProvider.overrideWith(
          (ref) => Stream<PrayerTimeSettings>.value(settings),
        ),
        prayerTodayScheduleProvider.overrideWith((ref) async => _today()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(prayerTimeSettingsProvider.future);
    await container.read(prayerTodayScheduleProvider.future);

    final before = await container.read(prayerContextResolutionProvider.future);
    expect(before.context?.prayerType, PrayerType.fajr);

    timeProvider.value = _utcForTashkent(2026, 8, 25, 5, 42);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final atSunrise = container
        .read(prayerContextResolutionProvider)
        .requireValue;
    expect(atSunrise.status, PrayerContextResolutionStatus.betweenPrayers);
    expect(atSunrise.context, isNull);
    expect(atSunrise.canMarkDirectly, isFalse);
    container.dispose();
    await tester.pump();
  });

  testWidgets('automatic context expires a long-lived schedule at runtime', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final initialNow = _utcForTashkent(2026, 8, 25, 17, 30, 59);
    final timeProvider = _MutablePrayerTimeProvider(initialNow);
    final settings = PrayerTimeSettings(
      location: testTashkentLocation(),
      locationConfirmed: true,
      contextSelectionMode: PrayerContextSelectionMode.automatic,
    );
    final almostExpired = initialNow
        .subtract(const Duration(days: 35))
        .add(const Duration(milliseconds: 500));
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        timeProviderProvider.overrideWithValue(timeProvider),
        prayerTimeSettingsProvider.overrideWith(
          (ref) => Stream<PrayerTimeSettings>.value(settings),
        ),
        prayerTodayScheduleProvider.overrideWith(
          (ref) async => _today(fetchedAtUtc: almostExpired),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(prayerTimeSettingsProvider.future);
    await container.read(prayerTodayScheduleProvider.future);

    final before = await container.read(prayerContextResolutionProvider.future);
    expect(before.context?.prayerType, PrayerType.asr);

    timeProvider.value = initialNow.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final expired = container
        .read(prayerContextResolutionProvider)
        .requireValue;
    expect(expired.status, PrayerContextResolutionStatus.unreliableSchedule);
    expect(expired.context, isNull);
    expect(expired.canMarkDirectly, isFalse);
    container.dispose();
    await tester.pump();
  });

  test(
    'one-event override leaves automatic mode and schedule context intact',
    () async {
      final harness = _ProviderHarness(
        nowUtc: _utcForTashkent(2026, 8, 25, 17, 30),
      );
      addTearDown(harness.dispose);
      await harness.prime();
      final override = PrayerContext(prayerType: PrayerType.witr);

      harness.container.read(prayerContextOverrideProvider.notifier).state =
          override;
      final appResolution = await harness.container.read(
        prayerContextResolutionProvider.future,
      );
      final scheduleResolution = await harness.container.read(
        prayerScheduleContextResolutionProvider.future,
      );

      expect(appResolution.status, PrayerContextResolutionStatus.manual);
      expect(appResolution.context, override);
      expect(
        scheduleResolution.status,
        PrayerContextResolutionStatus.automatic,
      );
      expect(scheduleResolution.context?.prayerType, PrayerType.asr);
      expect(
        harness.container
            .read(prayerTimeSettingsProvider)
            .requireValue
            .contextSelectionMode,
        PrayerContextSelectionMode.automatic,
      );
    },
  );

  test('transient override never replaces persisted manual mode', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await PrayerRepository(database).saveSelectedContext(
      PrayerContext(prayerType: PrayerType.dhuhr),
      updatedAtUtc: DateTime.utc(2026, 8, 25),
    );
    final settings = PrayerTimeSettings(
      location: testTashkentLocation(),
      contextSelectionMode: PrayerContextSelectionMode.manual,
      contextModeExplicitlyChosen: true,
    );
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        prayerTimeSettingsProvider.overrideWith(
          (ref) => Stream<PrayerTimeSettings>.value(settings),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(prayerTimeSettingsProvider.future);
    await _waitForSelectedPrayerLoad(container);

    container.read(prayerContextOverrideProvider.notifier).state =
        PrayerContext(prayerType: PrayerType.witr);
    final resolution = await container.read(
      prayerContextResolutionProvider.future,
    );

    expect(resolution.status, PrayerContextResolutionStatus.manual);
    expect(resolution.context?.prayerType, PrayerType.dhuhr);
  });
}

final class _ProviderHarness {
  _ProviderHarness({required DateTime nowUtc}) {
    database = AppDatabase(NativeDatabase.memory());
    settings = PrayerTimeSettings(
      location: testTashkentLocation(),
      locationConfirmed: true,
      contextSelectionMode: PrayerContextSelectionMode.automatic,
    );
    today = _today();
    container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        timeProviderProvider.overrideWithValue(FixedPrayerTimeProvider(nowUtc)),
        prayerTimeSettingsProvider.overrideWith(
          (ref) => Stream<PrayerTimeSettings>.value(settings),
        ),
        prayerTodayScheduleProvider.overrideWith((ref) async => today),
      ],
    );
  }

  late final AppDatabase database;
  late final PrayerTimeSettings settings;
  late final PrayerTodaySchedule today;
  late final ProviderContainer container;

  Future<void> prime() async {
    await container.read(prayerTimeSettingsProvider.future);
    await container.read(prayerTodayScheduleProvider.future);
    await _settleSelectedPrayerLoad(container, database);
  }

  Future<void> dispose() async {
    container.dispose();
    await database.close();
  }
}

Future<void> _settleSelectedPrayerLoad(
  ProviderContainer container,
  AppDatabase database,
) async {
  await PrayerRepository(database).saveSelectedContext(
    PrayerContext(prayerType: PrayerType.nafl),
    updatedAtUtc: DateTime.utc(2026, 8, 25),
  );
  await _waitForSelectedPrayerLoad(container);
}

Future<void> _waitForSelectedPrayerLoad(ProviderContainer container) async {
  final notifier = container.read(selectedPrayerProvider.notifier);
  if (notifier.state == null) {
    await notifier.stream
        .firstWhere((value) => value != null)
        .timeout(const Duration(seconds: 2));
  }
}

PrayerTodaySchedule _today({DateTime? fetchedAtUtc}) => PrayerTodaySchedule(
  day: testPrayerDay(25, fetchedAtUtc: fetchedAtUtc),
  previousDay: testPrayerDay(24, fetchedAtUtc: fetchedAtUtc),
  previousDayIsReliable: true,
  nextDay: testPrayerDay(26, fetchedAtUtc: fetchedAtUtc),
  nextDayIsReliable: true,
  loadResult: PrayerScheduleLoadResult(
    schedule: testPrayerMonth(fetchedAtUtc: fetchedAtUtc),
    origin: PrayerScheduleLoadOrigin.freshCache,
    freshness: PrayerScheduleFreshness.fresh,
  ),
);

DateTime _utcForTashkent(
  int year,
  int month,
  int day,
  int hour,
  int minute, [
  int second = 0,
]) => DateTime.utc(
  year,
  month,
  day,
  hour,
  minute,
  second,
).subtract(const Duration(hours: 5));

final class _MutablePrayerTimeProvider implements TimeProvider {
  _MutablePrayerTimeProvider(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}
