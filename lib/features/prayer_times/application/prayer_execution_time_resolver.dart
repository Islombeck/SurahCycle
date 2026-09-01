import '../../../core/domain/domain.dart';
import '../data/prayer_schedule_cache.dart';
import '../domain/prayer_context_resolver.dart';
import '../domain/prayer_time_models.dart';

/// Pure execution-time resolver for an interactive widget tap.
///
/// The caller supplies already-read cache entries. This object has no HTTP
/// dependency and cannot refresh data during a direct mark action.
final class PrayerExecutionTimeResolver {
  const PrayerExecutionTimeResolver({
    required this.timeProvider,
    this.cachePolicy = const PrayerScheduleCachePolicy(),
  });

  final TimeProvider timeProvider;
  final PrayerScheduleCachePolicy cachePolicy;

  PrayerContextResolution resolve({
    required PrayerTimeSettings settings,
    PrayerContext? manualContext,
    CachedPrayerMonthSchedule? currentMonth,
    CachedPrayerMonthSchedule? previousMonth,
    CachedPrayerMonthSchedule? nextMonth,
  }) {
    final contextResolver = PrayerContextResolver(timeProvider);
    if (settings.contextSelectionMode == PrayerContextSelectionMode.manual) {
      return contextResolver.resolve(
        mode: PrayerContextSelectionMode.manual,
        manualContext: manualContext,
      );
    }
    if (!settings.locationConfirmed) {
      return contextResolver.resolve(
        mode: PrayerContextSelectionMode.automatic,
      );
    }

    final nowUtc = timeProvider.nowUtc();
    if (!nowUtc.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return UTC.');
    }
    final localNow = nowUtc.add(
      Duration(minutes: settings.location.utcOffsetMinutes),
    );
    final date = LocalDate.fromLocalDateTime(localNow);
    final currentReliable =
        currentMonth?.isReliableAt(nowUtc, policy: cachePolicy) ?? false;
    if (currentMonth == null) {
      return contextResolver.resolve(
        mode: PrayerContextSelectionMode.automatic,
      );
    }
    final currentDay = currentMonth.schedule
        .day(date)
        ?.withAdjustments(settings.effectiveAdjustments);
    if (currentDay == null) {
      return const PrayerContextResolution(
        status: PrayerContextResolutionStatus.scheduleDateMismatch,
      );
    }
    if (!currentReliable) {
      return const PrayerContextResolution(
        status: PrayerContextResolutionStatus.unreliableSchedule,
      );
    }

    final previousDateTime = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(const Duration(days: 1));
    final previousDate = LocalDate.fromLocalDateTime(previousDateTime);
    PrayerDaySchedule? previousDay = currentMonth.schedule.day(previousDate);
    var previousReliable = currentReliable && previousDay != null;
    if (previousDay == null && previousMonth != null) {
      previousDay = previousMonth.schedule.day(previousDate);
      previousReliable =
          previousDay != null &&
          previousMonth.isReliableAt(nowUtc, policy: cachePolicy);
    }
    previousDay = previousDay?.withAdjustments(settings.effectiveAdjustments);

    final nextDateTime = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(const Duration(days: 1));
    final nextDate = LocalDate.fromLocalDateTime(nextDateTime);
    PrayerDaySchedule? nextDay = currentMonth.schedule.day(nextDate);
    var nextReliable = currentReliable && nextDay != null;
    if (nextDay == null && nextMonth != null) {
      nextDay = nextMonth.schedule.day(nextDate);
      nextReliable =
          nextDay != null &&
          nextMonth.isReliableAt(nowUtc, policy: cachePolicy);
    }
    nextDay = nextDay?.withAdjustments(settings.effectiveAdjustments);

    return contextResolver.resolve(
      mode: PrayerContextSelectionMode.automatic,
      automaticSchedule: currentDay,
      automaticScheduleIsReliable: true,
      previousDaySchedule: previousDay,
      previousDayScheduleIsReliable: previousReliable,
      nextDaySchedule: nextDay,
      nextDayScheduleIsReliable: nextReliable,
    );
  }
}
