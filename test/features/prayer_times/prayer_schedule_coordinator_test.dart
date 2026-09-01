import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 8, 26);

  test(
    'prefers a fresh published schedule and applies visible adjustments',
    () async {
      final provider = _FakePublishedProvider(
        createSchedule: (request) => _publishedMonth(request, now),
      );
      final calculator = _FakeCalculator();
      final coordinator = _coordinator(provider, calculator, now);

      final result = await coordinator.loadMonth(
        settings: PrayerTimeSettings(
          location: testTashkentLocation(),
          adjustments: PrayerTimeAdjustments(asrMinutes: 2),
          allowCalculatedFallback: true,
        ),
        year: 2026,
        month: 8,
      );

      expect(result.origin, PrayerScheduleLoadOrigin.network);
      expect(result.schedule.provenance.isPublished, isTrue);
      expect(calculator.calls, 0);
      final asr = result.schedule.day(LocalDate(2026, 8, 25))!.times.asr;
      expect(asr.raw, PrayerClockTime(17, 9));
      expect(asr.effective, PrayerClockTime(17, 11));
      expect(asr.manualAdjustmentMinutes, 2);
    },
  );

  test('uses a labelled calculation only after a published failure', () async {
    final failure = StateError('provider offline');
    final provider = _FakePublishedProvider(failure: failure);
    final calculator = _FakeCalculator();
    final coordinator = _coordinator(provider, calculator, now);

    final result = await coordinator.loadMonth(
      settings: PrayerTimeSettings(
        location: testTashkentLocation(),
        allowCalculatedFallback: true,
      ),
      year: 2026,
      month: 8,
    );

    expect(result.origin, PrayerScheduleLoadOrigin.calculated);
    expect(result.schedule.provenance.isCalculated, isTrue);
    expect(result.refreshError, same(failure));
    expect(provider.calls, 1);
    expect(calculator.calls, 1);
  });

  test(
    'never falls back unless the user explicitly enabled calculation',
    () async {
      final failure = StateError('provider offline');
      final provider = _FakePublishedProvider(failure: failure);
      final calculator = _FakeCalculator();
      final coordinator = _coordinator(provider, calculator, now);

      await expectLater(
        coordinator.loadMonth(
          settings: PrayerTimeSettings(location: testTashkentLocation()),
          year: 2026,
          month: 8,
        ),
        throwsA(same(failure)),
      );
      expect(calculator.calls, 0);
    },
  );

  test(
    'user coordinates are never sent to the published region provider',
    () async {
      final provider = _FakePublishedProvider(
        createSchedule: (request) => _publishedMonth(request, now),
      );
      final calculator = _FakeCalculator();
      final coordinator = _coordinator(provider, calculator, now);
      final location = PrayerLocation(
        providerSlug: 'user-41.3000-69.2000',
        displayName: 'My location',
        timeZoneId: 'Asia/Tashkent',
        utcOffsetMinutes: 300,
        coordinates: PrayerCoordinates(latitude: 41.3, longitude: 69.2),
      );

      final result = await coordinator.loadMonth(
        settings: PrayerTimeSettings(
          location: location,
          locationSelectionMode: PrayerLocationSelectionMode.userCoordinates,
          allowCalculatedFallback: true,
        ),
        year: 2026,
        month: 8,
      );

      expect(result.origin, PrayerScheduleLoadOrigin.calculated);
      expect(provider.calls, 0);
      expect(calculator.calls, 1);
    },
  );

  test(
    'retains stale published data when both refresh and calculator fail',
    () async {
      final fetchedAt = DateTime.utc(2026, 6, 1);
      final providerFailure = StateError('provider offline');
      final provider = _FakePublishedProvider(failure: providerFailure);
      final calculatorFailure = StateError('calculator unavailable');
      final calculator = _FakeCalculator(failure: calculatorFailure);
      final cache = _MemoryCacheStore();
      final request = PrayerScheduleRequest(
        location: testTashkentLocation(),
        year: 2026,
        month: 8,
      );
      await cache.write(
        CachedPrayerMonthSchedule(
          cacheKey: request.cacheKey(provider.source.id),
          schedule: _publishedMonth(request, fetchedAt),
          cachedAtUtc: fetchedAt,
        ),
      );
      final coordinator = PrayerScheduleCoordinator(
        publishedRepository: CachingPrayerScheduleRepository(
          provider: provider,
          cache: cache,
          timeProvider: FixedPrayerTimeProvider(now),
        ),
        calculator: calculator,
      );

      final result = await coordinator.loadMonth(
        settings: PrayerTimeSettings(
          location: testTashkentLocation(),
          allowCalculatedFallback: true,
        ),
        year: 2026,
        month: 8,
      );

      expect(result.origin, PrayerScheduleLoadOrigin.staleCache);
      expect(result.freshness, PrayerScheduleFreshness.stale);
      expect(result.refreshError, same(providerFailure));
      expect(result.isReliableForAutomaticContext, isFalse);
      expect(calculator.calls, 1);
    },
  );

  test(
    'today and next-month refresh use the configured local UTC offset',
    () async {
      final localSeptemberFirst = DateTime.utc(2026, 8, 31, 20, 30);
      final provider = _FakePublishedProvider(
        createSchedule: (request) =>
            _publishedMonth(request, localSeptemberFirst),
      );
      final calculator = _FakeCalculator();
      final coordinator = _coordinator(
        provider,
        calculator,
        localSeptemberFirst,
      );
      final useCases = PrayerScheduleUseCases(
        coordinator: coordinator,
        timeProvider: FixedPrayerTimeProvider(localSeptemberFirst),
      );
      final settings = PrayerTimeSettings(location: testTashkentLocation());

      final today = await useCases.loadToday(settings: settings);
      final refreshed = await useCases.refreshCurrentAndNext(
        settings: settings,
      );

      expect(today.day.date, LocalDate(2026, 9, 1));
      expect(today.previousDay?.date, LocalDate(2026, 8, 31));
      expect(today.previousDayIsReliable, isTrue);
      expect(today.nextDay?.date, LocalDate(2026, 9, 2));
      expect(today.nextDayIsReliable, isTrue);
      expect(refreshed, hasLength(2));
      expect(refreshed[0].schedule.month, 9);
      expect(refreshed[1].schedule.month, 10);
      expect(
        provider.requests
            .map((request) => '${request.year}-${request.month}')
            .toList(),
        <String>['2026-9', '2026-8', '2026-9', '2026-10'],
      );
    },
  );

  test('loads the next month at the end-of-month prayer boundary', () async {
    final localAugustLast = DateTime.utc(2026, 8, 31, 18, 30);
    final provider = _FakePublishedProvider(
      createSchedule: (request) => _publishedMonth(request, localAugustLast),
    );
    final useCases = PrayerScheduleUseCases(
      coordinator: _coordinator(provider, _FakeCalculator(), localAugustLast),
      timeProvider: FixedPrayerTimeProvider(localAugustLast),
    );

    final today = await useCases.loadToday(
      settings: PrayerTimeSettings(location: testTashkentLocation()),
    );

    expect(today.day.date, LocalDate(2026, 8, 31));
    expect(today.nextDay?.date, LocalDate(2026, 9, 1));
    expect(today.nextDayIsReliable, isTrue);
    expect(
      provider.requests
          .map((request) => '${request.year}-${request.month}')
          .toList(),
      <String>['2026-8', '2026-9'],
    );
  });
}

PrayerScheduleCoordinator _coordinator(
  _FakePublishedProvider provider,
  _FakeCalculator calculator,
  DateTime now,
) => PrayerScheduleCoordinator(
  publishedRepository: CachingPrayerScheduleRepository(
    provider: provider,
    cache: _MemoryCacheStore(),
    timeProvider: FixedPrayerTimeProvider(now),
  ),
  calculator: calculator,
);

PrayerMonthSchedule _publishedMonth(
  PrayerScheduleRequest request,
  DateTime fetchedAt,
) => _month(
  request,
  PrayerTimeProvenance.published(
    source: NamozVaqtiUzPrayerTimeProvider.providerSource,
    sourceUri: Uri.https('namoz-vaqti.uz', '/index.php'),
    fetchedAtUtc: fetchedAt,
    attribution: NamozVaqtiUzPrayerTimeProvider.attribution,
    providerRegionSlug: request.location.providerSlug,
  ),
);

PrayerMonthSchedule _calculatedMonth(
  PrayerScheduleRequest request,
  DateTime calculatedAt,
) => _month(
  request,
  PrayerTimeProvenance.calculated(
    source: AdhanPrayerTimeCalculator.calculatorSource,
    sourceUri: Uri.https('pub.dev', '/packages/adhan_dart'),
    calculatedAtUtc: calculatedAt,
    attribution: 'Calculated locally with adhan_dart 2.0.1.',
    calculationSettings:
        request.calculationSettings ??
        const PrayerCalculationSettings.uzbekistanFallback(),
    calculatorVersion: 'adhan_dart 2.0.1',
  ),
);

PrayerMonthSchedule _month(
  PrayerScheduleRequest request,
  PrayerTimeProvenance provenance,
) {
  final count = DateTime.utc(request.year, request.month + 1, 0).day;
  return PrayerMonthSchedule(
    location: request.location,
    year: request.year,
    month: request.month,
    provenance: provenance,
    days: List<PrayerDaySchedule>.generate(
      count,
      (index) => PrayerDaySchedule(
        date: LocalDate(request.year, request.month, index + 1),
        times: testPrayerTimes(),
        provenance: provenance,
        timeZoneId: request.location.timeZoneId,
        utcOffsetMinutes: request.location.utcOffsetMinutes,
      ),
      growable: false,
    ),
  );
}

final class _MemoryCacheStore implements PrayerScheduleCacheStore {
  final Map<String, CachedPrayerMonthSchedule> values =
      <String, CachedPrayerMonthSchedule>{};

  @override
  Future<CachedPrayerMonthSchedule?> read(String cacheKey) async =>
      values[cacheKey];

  @override
  Future<void> write(CachedPrayerMonthSchedule value) async {
    values[value.cacheKey] = value;
  }
}

final class _FakePublishedProvider implements PublishedPrayerScheduleProvider {
  _FakePublishedProvider({this.createSchedule, this.failure});

  final PrayerMonthSchedule Function(PrayerScheduleRequest request)?
  createSchedule;
  final Object? failure;
  final List<PrayerScheduleRequest> requests = <PrayerScheduleRequest>[];

  int get calls => requests.length;

  @override
  PrayerTimeSource get source => NamozVaqtiUzPrayerTimeProvider.providerSource;

  @override
  Future<PrayerMonthSchedule> loadMonth(PrayerScheduleRequest request) async {
    requests.add(request);
    if (failure case final error?) throw error;
    return createSchedule!(request);
  }
}

final class _FakeCalculator implements CalculatedPrayerScheduleProvider {
  _FakeCalculator({this.failure});

  final Object? failure;
  int calls = 0;

  @override
  PrayerTimeSource get source => AdhanPrayerTimeCalculator.calculatorSource;

  @override
  Future<PrayerMonthSchedule> loadMonth(PrayerScheduleRequest request) async {
    calls += 1;
    if (failure case final error?) throw error;
    return _calculatedMonth(request, DateTime.utc(2026, 8, 26));
  }
}
