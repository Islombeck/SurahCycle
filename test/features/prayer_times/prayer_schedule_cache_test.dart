import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  late PrayerScheduleRequest request;

  setUp(() {
    request = PrayerScheduleRequest(
      location: testTashkentLocation(),
      year: 2026,
      month: 8,
    );
  });

  test('file cache survives recreation and preserves raw/provenance', () async {
    final directory = await Directory.systemTemp.createTemp(
      'murajaah_prayer_cache_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final key = request.cacheKey(NamozVaqtiUzPrayerTimeProvider.sourceId);
    final cachedAt = DateTime.utc(2026, 8, 25, 13);
    final first = FilePrayerScheduleCacheStore(directory: directory);
    await first.write(
      CachedPrayerMonthSchedule(
        cacheKey: key,
        schedule: testPrayerMonth(),
        cachedAtUtc: cachedAt,
      ),
    );

    final reopened = FilePrayerScheduleCacheStore(directory: directory);
    final restored = await reopened.read(key);

    expect(restored, isNotNull);
    expect(restored!.cachedAtUtc, cachedAt);
    expect(restored.schedule.location, testTashkentLocation());
    expect(restored.schedule.provenance.isPublished, isTrue);
    expect(
      restored.schedule.day(LocalDate(2026, 8, 25))!.times.asr.raw,
      PrayerClockTime(17, 9),
    );
  });

  test('corrupt external cache is safely treated as missing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'murajaah_prayer_cache_corrupt_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final key = request.cacheKey(NamozVaqtiUzPrayerTimeProvider.sourceId);
    final cache = FilePrayerScheduleCacheStore(directory: directory);
    await directory.create(recursive: true);
    final safe = key.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    await File(
      '${directory.path}${Platform.pathSeparator}$safe.json',
    ).writeAsString('{not json');

    expect(await cache.read(key), isNull);
  });

  test('fresh cache avoids a network call', () async {
    final now = DateTime.utc(2026, 8, 26);
    final store = _MemoryCacheStore();
    final provider = _FakePublishedProvider(
      schedule: testPrayerMonth(fetchedAtUtc: now),
    );
    final repository = CachingPrayerScheduleRepository(
      provider: provider,
      cache: store,
      timeProvider: FixedPrayerTimeProvider(now),
    );

    final first = await repository.loadMonth(request);
    final second = await repository.loadMonth(request);

    expect(first.origin, PrayerScheduleLoadOrigin.network);
    expect(second.origin, PrayerScheduleLoadOrigin.freshCache);
    expect(provider.calls, 1);
  });

  test('network error returns and preserves the last valid cache', () async {
    final now = DateTime.utc(2026, 8, 26);
    final store = _MemoryCacheStore();
    final provider = _FakePublishedProvider(
      schedule: testPrayerMonth(fetchedAtUtc: now),
    );
    final repository = CachingPrayerScheduleRepository(
      provider: provider,
      cache: store,
      timeProvider: FixedPrayerTimeProvider(now),
    );
    await repository.loadMonth(request);
    final beforeFailure = store.values.single;
    provider.failure = StateError('offline');

    final offline = await repository.loadMonth(request, forceRefresh: true);

    expect(offline.origin, PrayerScheduleLoadOrigin.freshCache);
    expect(offline.refreshError, isA<StateError>());
    expect(store.values.single, same(beforeFailure));
    expect(offline.schedule, same(beforeFailure.schedule));
  });

  test(
    'stale cache remains visible but is unsafe for automatic marking',
    () async {
      final fetched = DateTime.utc(2026, 6, 1);
      final now = DateTime.utc(2026, 8, 26);
      final store = _MemoryCacheStore();
      final provider = _FakePublishedProvider(
        schedule: testPrayerMonth(fetchedAtUtc: fetched),
        failure: StateError('offline'),
      );
      final key = request.cacheKey(provider.source.id);
      await store.write(
        CachedPrayerMonthSchedule(
          cacheKey: key,
          schedule: testPrayerMonth(fetchedAtUtc: fetched),
          cachedAtUtc: fetched,
        ),
      );
      final repository = CachingPrayerScheduleRepository(
        provider: provider,
        cache: store,
        timeProvider: FixedPrayerTimeProvider(now),
      );

      final result = await repository.loadMonth(request);
      final local = await repository.readLocalMonth(request);

      expect(result.origin, PrayerScheduleLoadOrigin.staleCache);
      expect(result.freshness, PrayerScheduleFreshness.stale);
      expect(result.isReliableForAutomaticContext, isFalse);
      expect(local!.origin, PrayerScheduleLoadOrigin.staleCache);
      expect(provider.calls, 1);
    },
  );
}

final class _MemoryCacheStore implements PrayerScheduleCacheStore {
  final Map<String, CachedPrayerMonthSchedule> _values =
      <String, CachedPrayerMonthSchedule>{};

  Iterable<CachedPrayerMonthSchedule> get values => _values.values;

  @override
  Future<CachedPrayerMonthSchedule?> read(String cacheKey) async =>
      _values[cacheKey];

  @override
  Future<void> write(CachedPrayerMonthSchedule value) async {
    _values[value.cacheKey] = value;
  }
}

final class _FakePublishedProvider implements PublishedPrayerScheduleProvider {
  _FakePublishedProvider({required this.schedule, this.failure});

  final PrayerMonthSchedule schedule;
  Object? failure;
  int calls = 0;

  @override
  PrayerTimeSource get source => NamozVaqtiUzPrayerTimeProvider.providerSource;

  @override
  Future<PrayerMonthSchedule> loadMonth(PrayerScheduleRequest request) async {
    calls += 1;
    if (failure case final error?) throw error;
    return schedule;
  }
}
