import '../../../core/domain/domain.dart';
import '../data/caching_prayer_schedule_repository.dart';
import '../data/prayer_schedule_cache.dart';
import '../data/prayer_schedule_coordinator.dart';
import '../domain/prayer_context_resolver.dart';
import '../domain/prayer_time_models.dart';

final class PrayerTodaySchedule {
  const PrayerTodaySchedule({
    required this.day,
    required this.loadResult,
    this.previousDay,
    this.previousDayIsReliable = false,
    this.nextDay,
    this.nextDayIsReliable = false,
  });

  final PrayerDaySchedule day;
  final PrayerScheduleLoadResult loadResult;
  final PrayerDaySchedule? previousDay;
  final bool previousDayIsReliable;
  final PrayerDaySchedule? nextDay;
  final bool nextDayIsReliable;

  bool currentDayIsReliableAt(
    DateTime nowUtc, {
    PrayerScheduleCachePolicy policy = const PrayerScheduleCachePolicy(),
  }) => loadResult.isReliableAt(nowUtc, policy: policy);

  bool previousDayIsReliableAt(
    DateTime nowUtc, {
    PrayerScheduleCachePolicy policy = const PrayerScheduleCachePolicy(),
  }) => _dayIsReliableAt(
    previousDay,
    declaredReliable: previousDayIsReliable,
    nowUtc: nowUtc,
    policy: policy,
  );

  bool nextDayIsReliableAt(
    DateTime nowUtc, {
    PrayerScheduleCachePolicy policy = const PrayerScheduleCachePolicy(),
  }) => _dayIsReliableAt(
    nextDay,
    declaredReliable: nextDayIsReliable,
    nowUtc: nowUtc,
    policy: policy,
  );

  /// Resolves the automatic context from the execution-time clock and
  /// revalidates every schedule involved in a cross-day boundary.
  PrayerContextResolution resolveAutomaticContext(
    TimeProvider timeProvider, {
    PrayerScheduleCachePolicy policy = const PrayerScheduleCachePolicy(),
  }) {
    final nowUtc = timeProvider.nowUtc();
    return PrayerContextResolver(timeProvider).resolve(
      mode: PrayerContextSelectionMode.automatic,
      automaticSchedule: day,
      automaticScheduleIsReliable: currentDayIsReliableAt(
        nowUtc,
        policy: policy,
      ),
      previousDaySchedule: previousDay,
      previousDayScheduleIsReliable: previousDayIsReliableAt(
        nowUtc,
        policy: policy,
      ),
      nextDaySchedule: nextDay,
      nextDayScheduleIsReliable: nextDayIsReliableAt(nowUtc, policy: policy),
      nowUtc: nowUtc,
    );
  }

  bool matchesSettings(PrayerTimeSettings settings) =>
      loadResult.schedule.location == settings.location &&
      day.timeZoneId == settings.location.timeZoneId &&
      day.utcOffsetMinutes == settings.location.utcOffsetMinutes;
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
    final previousDate = _shiftDate(date, -1);
    final nextDate = _shiftDate(date, 1);
    var previousDay = result.schedule.day(previousDate);
    var previousDayIsReliable =
        previousDay != null && result.isReliableForAutomaticContext;
    var nextDay = result.schedule.day(nextDate);
    var nextDayIsReliable =
        nextDay != null && result.isReliableForAutomaticContext;

    if (previousDay == null) {
      final adjacent = await _tryLoadAdjacentMonth(
        settings: settings,
        date: previousDate,
        forceRefresh: forceRefresh,
      );
      previousDay = adjacent?.schedule.day(previousDate);
      previousDayIsReliable =
          previousDay != null &&
          (adjacent?.isReliableForAutomaticContext ?? false);
    }
    if (nextDay == null) {
      final adjacent = await _tryLoadAdjacentMonth(
        settings: settings,
        date: nextDate,
        forceRefresh: forceRefresh,
      );
      nextDay = adjacent?.schedule.day(nextDate);
      nextDayIsReliable =
          nextDay != null && (adjacent?.isReliableForAutomaticContext ?? false);
    }
    return PrayerTodaySchedule(
      day: day,
      loadResult: result,
      previousDay: previousDay,
      previousDayIsReliable: previousDayIsReliable,
      nextDay: nextDay,
      nextDayIsReliable: nextDayIsReliable,
    );
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

  Future<PrayerScheduleLoadResult?> _tryLoadAdjacentMonth({
    required PrayerTimeSettings settings,
    required LocalDate date,
    required bool forceRefresh,
  }) async {
    try {
      return await coordinator.loadMonth(
        settings: settings,
        year: date.year,
        month: date.month,
        forceRefresh: forceRefresh,
      );
    } on Object {
      // An adjacent month improves the before-Fajr/after-Isha boundary, but
      // failure must not hide an otherwise usable current-day timetable.
      return null;
    }
  }
}

LocalDate _shiftDate(LocalDate date, int days) {
  final shifted = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(Duration(days: days));
  return LocalDate.fromLocalDateTime(shifted);
}

bool _dayIsReliableAt(
  PrayerDaySchedule? day, {
  required bool declaredReliable,
  required DateTime nowUtc,
  required PrayerScheduleCachePolicy policy,
}) {
  if (!nowUtc.isUtc) {
    throw ArgumentError.value(nowUtc, 'nowUtc', 'Must be UTC.');
  }
  return declaredReliable &&
      day != null &&
      policy.freshness(
            fetchedAtUtc: day.provenance.fetchedAtUtc,
            nowUtc: nowUtc,
          ) ==
          PrayerScheduleFreshness.fresh;
}
