import '../../../core/domain/domain.dart';
import '../domain/prayer_time_models.dart';
import 'prayer_schedule_cache.dart';
import 'prayer_schedule_provider.dart';

enum PrayerScheduleLoadOrigin { network, freshCache, staleCache, calculated }

final class PrayerScheduleLoadResult {
  const PrayerScheduleLoadResult({
    required this.schedule,
    required this.origin,
    required this.freshness,
    this.refreshError,
  });

  final PrayerMonthSchedule schedule;
  final PrayerScheduleLoadOrigin origin;
  final PrayerScheduleFreshness freshness;
  final Object? refreshError;

  bool get isReliableForAutomaticContext =>
      freshness == PrayerScheduleFreshness.fresh;
  bool get isOfflineCache =>
      origin == PrayerScheduleLoadOrigin.freshCache ||
      origin == PrayerScheduleLoadOrigin.staleCache;
}

final class CachingPrayerScheduleRepository {
  const CachingPrayerScheduleRepository({
    required this.provider,
    required this.cache,
    required this.timeProvider,
    this.cachePolicy = const PrayerScheduleCachePolicy(),
  });

  final PublishedPrayerScheduleProvider provider;
  final PrayerScheduleCacheStore cache;
  final TimeProvider timeProvider;
  final PrayerScheduleCachePolicy cachePolicy;

  PrayerTimeSource get source => provider.source;

  Future<PrayerScheduleLoadResult> loadMonth(
    PrayerScheduleRequest request, {
    bool forceRefresh = false,
  }) async {
    final nowUtc = _nowUtc();
    final key = request.cacheKey(provider.source.id);
    final cached = await cache.read(key);
    final cachedFreshness = cached?.freshnessAt(nowUtc, policy: cachePolicy);
    if (!forceRefresh &&
        cached != null &&
        cachedFreshness == PrayerScheduleFreshness.fresh) {
      return PrayerScheduleLoadResult(
        schedule: cached.schedule,
        origin: PrayerScheduleLoadOrigin.freshCache,
        freshness: cachedFreshness!,
      );
    }

    try {
      final schedule = await provider.loadMonth(request);
      final saved = CachedPrayerMonthSchedule(
        cacheKey: key,
        schedule: schedule,
        cachedAtUtc: _nowUtc(),
      );
      await cache.write(saved);
      return PrayerScheduleLoadResult(
        schedule: schedule,
        origin: PrayerScheduleLoadOrigin.network,
        freshness: PrayerScheduleFreshness.fresh,
      );
    } on Object catch (error) {
      if (cached == null) rethrow;
      return PrayerScheduleLoadResult(
        schedule: cached.schedule,
        origin: cachedFreshness == PrayerScheduleFreshness.fresh
            ? PrayerScheduleLoadOrigin.freshCache
            : PrayerScheduleLoadOrigin.staleCache,
        freshness: cachedFreshness!,
        refreshError: error,
      );
    }
  }

  /// Reads only local state. Interactive widgets use this boundary and never
  /// invoke [loadMonth], which can perform HTTP.
  Future<PrayerScheduleLoadResult?> readLocalMonth(
    PrayerScheduleRequest request,
  ) async {
    final key = request.cacheKey(provider.source.id);
    final cached = await cache.read(key);
    if (cached == null) return null;
    final freshness = cached.freshnessAt(_nowUtc(), policy: cachePolicy);
    return PrayerScheduleLoadResult(
      schedule: cached.schedule,
      origin: freshness == PrayerScheduleFreshness.fresh
          ? PrayerScheduleLoadOrigin.freshCache
          : PrayerScheduleLoadOrigin.staleCache,
      freshness: freshness,
    );
  }

  DateTime _nowUtc() {
    final value = timeProvider.nowUtc();
    if (!value.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return UTC.');
    }
    return value;
  }
}
