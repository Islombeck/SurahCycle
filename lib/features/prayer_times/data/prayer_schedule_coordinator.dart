import '../domain/prayer_time_models.dart';
import 'caching_prayer_schedule_repository.dart';
import 'prayer_schedule_cache.dart';
import 'prayer_schedule_provider.dart';

/// Resolves a published timetable first and uses a clearly-labelled generic
/// calculation only when the user enabled that fallback.
final class PrayerScheduleCoordinator {
  const PrayerScheduleCoordinator({
    required this.publishedRepository,
    required this.calculator,
  });

  final CachingPrayerScheduleRepository publishedRepository;
  final CalculatedPrayerScheduleProvider calculator;

  Future<PrayerScheduleLoadResult> loadMonth({
    required PrayerTimeSettings settings,
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    final request = PrayerScheduleRequest(
      location: settings.location,
      year: year,
      month: month,
      calculationSettings: settings.calculationSettings,
    );
    if (settings.locationSelectionMode ==
        PrayerLocationSelectionMode.userCoordinates) {
      if (!settings.allowCalculatedFallback) {
        throw const PrayerScheduleProviderException(
          code: 'user_coordinates_require_calculation',
          message:
              'User coordinates cannot be sent as a Namoz-vaqti.uz region.',
        );
      }
      final calculated = await calculator.loadMonth(request);
      return PrayerScheduleLoadResult(
        schedule: calculated.withAdjustments(settings.effectiveAdjustments),
        origin: PrayerScheduleLoadOrigin.calculated,
        freshness: PrayerScheduleFreshness.fresh,
      );
    }
    PrayerScheduleLoadResult? published;
    Object? publishedFailure;
    try {
      published = await publishedRepository.loadMonth(
        request,
        forceRefresh: forceRefresh,
      );
      if (published.isReliableForAutomaticContext ||
          !settings.allowCalculatedFallback) {
        return _adjusted(published, settings.effectiveAdjustments);
      }
    } on Object catch (error) {
      publishedFailure = error;
      if (!settings.allowCalculatedFallback) rethrow;
    }

    try {
      final calculated = await calculator.loadMonth(request);
      return PrayerScheduleLoadResult(
        schedule: calculated.withAdjustments(settings.effectiveAdjustments),
        origin: PrayerScheduleLoadOrigin.calculated,
        freshness: PrayerScheduleFreshness.fresh,
        refreshError: publishedFailure ?? published?.refreshError,
      );
    } on Object {
      if (published != null) {
        return _adjusted(published, settings.effectiveAdjustments);
      }
      rethrow;
    }
  }

  PrayerScheduleLoadResult _adjusted(
    PrayerScheduleLoadResult result,
    PrayerTimeAdjustments adjustments,
  ) => PrayerScheduleLoadResult(
    schedule: result.schedule.withAdjustments(adjustments),
    origin: result.origin,
    freshness: result.freshness,
    refreshError: result.refreshError,
  );
}
