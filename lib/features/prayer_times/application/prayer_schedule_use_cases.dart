import '../../../core/domain/domain.dart';
import '../data/caching_prayer_schedule_repository.dart';
import '../data/prayer_schedule_coordinator.dart';
import '../domain/prayer_time_models.dart';

final class PrayerTodaySchedule {
  const PrayerTodaySchedule({required this.day, required this.loadResult});

  final PrayerDaySchedule day;
  final PrayerScheduleLoadResult loadResult;
}

/// App-facing monthly refresh and today's schedule use cases.
final class PrayerScheduleUseCases {
  const PrayerScheduleUseCases({
    required this.coordinator,
    required this.timeProvider,
  });

  final PrayerScheduleCoordinator coordinator;
  final TimeProvider timeProvider;

  Future<PrayerTodaySchedule> loadToday({
    required PrayerTimeSettings settings,
    bool forceRefresh = false,
  }) async {
    final nowUtc = _utcNow();
    final local = nowUtc.add(
      Duration(minutes: settings.location.utcOffsetMinutes),
    );
    final result = await coordinator.loadMonth(
      settings: settings,
      year: local.year,
      month: local.month,
      forceRefresh: forceRefresh,
    );
    final date = LocalDate.fromLocalDateTime(local);
    final day = result.schedule.day(date);
    if (day == null) {
      throw StateError('Resolved monthly schedule does not contain today.');
    }
    return PrayerTodaySchedule(day: day, loadResult: result);
  }

  /// Refreshes the current and next month. A caller may show current data even
  /// if prefetching the next month fails.
  Future<List<PrayerScheduleLoadResult>> refreshCurrentAndNext({
    required PrayerTimeSettings settings,
  }) async {
    final nowUtc = _utcNow();
    final local = nowUtc.add(
      Duration(minutes: settings.location.utcOffsetMinutes),
    );
    final next = DateTime.utc(local.year, local.month + 1);
    final currentResult = await coordinator.loadMonth(
      settings: settings,
      year: local.year,
      month: local.month,
      forceRefresh: true,
    );
    final nextResult = await coordinator.loadMonth(
      settings: settings,
      year: next.year,
      month: next.month,
      forceRefresh: true,
    );
    return List<PrayerScheduleLoadResult>.unmodifiable(
      <PrayerScheduleLoadResult>[currentResult, nextResult],
    );
  }

  DateTime _utcNow() {
    final value = timeProvider.nowUtc();
    if (!value.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return UTC.');
    }
    return value;
  }
}
