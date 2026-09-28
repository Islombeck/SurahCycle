import '../../../core/domain/domain.dart';
import 'prayer_time_models.dart';

enum PrayerContextResolutionStatus {
  manual,
  automatic,
  betweenPrayers,
  missingManualContext,
  missingSchedule,
  unreliableSchedule,
  scheduleDateMismatch,
}

/// Safe result for Home/widget integration. A null [context] always disables
/// direct marking; callers must never substitute a default prayer.
final class PrayerContextResolution {
  const PrayerContextResolution({
    required this.status,
    this.context,
    this.contextLocalDate,
    this.currentStartsAt,
    this.currentEndsAt,
    this.nextPrayerType,
    this.nextPrayerAt,
  });

  final PrayerContextResolutionStatus status;
  final PrayerContext? context;

  /// The prayer day [context] belongs to, which is not always today.
  ///
  /// Between midnight and Fajr the current prayer is the **previous** day's
  /// Isha — this resolver has always said so, by taking the start time from
  /// the previous day's schedule — but it had no way to say *which day*, so
  /// every caller asked the wall clock instead. A prayer marked at 00:32 was
  /// filed on the new calendar day: the night that was ending read as missed,
  /// and the day that had not begun read as already prayed, which is why it
  /// could not be marked that evening.
  ///
  /// Null when there is no context, and deliberately null for a **manual**
  /// one: choosing a prayer by hand says what, not when, and the caller's own
  /// date stands.
  final LocalDate? contextLocalDate;

  final PrayerClockTime? currentStartsAt;
  final PrayerClockTime? currentEndsAt;
  final PrayerType? nextPrayerType;
  final PrayerClockTime? nextPrayerAt;

  bool get canMarkDirectly => context != null;
}

final class PrayerContextResolver {
  const PrayerContextResolver(this.timeProvider);

  final TimeProvider timeProvider;

  PrayerContextResolution resolve({
    required PrayerContextSelectionMode mode,
    PrayerContext? manualContext,
    PrayerDaySchedule? automaticSchedule,
    bool automaticScheduleIsReliable = false,
    PrayerDaySchedule? previousDaySchedule,
    bool previousDayScheduleIsReliable = false,
    PrayerDaySchedule? nextDaySchedule,
    bool nextDayScheduleIsReliable = false,
    DateTime? nowUtc,
  }) {
    if (mode == PrayerContextSelectionMode.manual) {
      return PrayerContextResolution(
        status: manualContext == null
            ? PrayerContextResolutionStatus.missingManualContext
            : PrayerContextResolutionStatus.manual,
        context: manualContext,
      );
    }
    if (automaticSchedule == null) {
      return const PrayerContextResolution(
        status: PrayerContextResolutionStatus.missingSchedule,
      );
    }
    if (!automaticScheduleIsReliable) {
      return const PrayerContextResolution(
        status: PrayerContextResolutionStatus.unreliableSchedule,
      );
    }

    final effectiveNowUtc = nowUtc ?? timeProvider.nowUtc();
    if (!effectiveNowUtc.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return a UTC DateTime.');
    }
    final offset = automaticSchedule.utcOffsetMinutes;
    final localNow = effectiveNowUtc.add(Duration(minutes: offset));
    final localDate = LocalDate.fromLocalDateTime(localNow);
    if (localDate != automaticSchedule.date) {
      return const PrayerContextResolution(
        status: PrayerContextResolutionStatus.scheduleDateMismatch,
      );
    }

    final secondOfDay =
        localNow.hour * 3600 + localNow.minute * 60 + localNow.second;
    final times = automaticSchedule.times;
    final fajr = times.fajr.effective;
    final sunrise = times.sunrise.effective;
    final dhuhr = times.dhuhr.effective;
    final asr = times.asr.effective;
    final maghrib = times.maghrib.effective;
    final isha = times.isha.effective;

    if (_before(secondOfDay, fajr)) {
      if (_isReliablePreviousDay(
        current: automaticSchedule,
        previous: previousDaySchedule,
        declaredReliable: previousDayScheduleIsReliable,
      )) {
        return PrayerContextResolution(
          status: PrayerContextResolutionStatus.automatic,
          context: PrayerContext(prayerType: PrayerType.isha),
          // The night that is ending, not the morning that has started. The
          // start time already comes from that day; the date has to as well,
          // or the prayer is filed a day forward.
          contextLocalDate: previousDaySchedule!.date,
          currentStartsAt: previousDaySchedule.times.isha.effective,
          currentEndsAt: fajr,
          nextPrayerType: PrayerType.fajr,
          nextPrayerAt: fajr,
        );
      }
      return PrayerContextResolution(
        status: PrayerContextResolutionStatus.betweenPrayers,
        nextPrayerType: PrayerType.fajr,
        nextPrayerAt: fajr,
      );
    }
    if (_before(secondOfDay, sunrise)) {
      return _automatic(
        PrayerType.fajr,
        localDate: automaticSchedule.date,
        startsAt: fajr,
        endsAt: sunrise,
        nextType: PrayerType.dhuhr,
        nextAt: dhuhr,
      );
    }
    if (_before(secondOfDay, dhuhr)) {
      return PrayerContextResolution(
        status: PrayerContextResolutionStatus.betweenPrayers,
        nextPrayerType: PrayerType.dhuhr,
        nextPrayerAt: dhuhr,
      );
    }
    if (_before(secondOfDay, asr)) {
      return _automatic(
        PrayerType.dhuhr,
        localDate: automaticSchedule.date,
        startsAt: dhuhr,
        endsAt: asr,
        nextType: PrayerType.asr,
        nextAt: asr,
      );
    }
    if (_before(secondOfDay, maghrib)) {
      return _automatic(
        PrayerType.asr,
        localDate: automaticSchedule.date,
        startsAt: asr,
        endsAt: maghrib,
        nextType: PrayerType.maghrib,
        nextAt: maghrib,
      );
    }
    if (_before(secondOfDay, isha)) {
      return _automatic(
        PrayerType.maghrib,
        localDate: automaticSchedule.date,
        startsAt: maghrib,
        endsAt: isha,
        nextType: PrayerType.isha,
        nextAt: isha,
      );
    }
    final hasReliableNextDay = _isReliableAdjacentDay(
      current: automaticSchedule,
      adjacent: nextDaySchedule,
      dayDelta: 1,
      declaredReliable: nextDayScheduleIsReliable,
    );
    return PrayerContextResolution(
      status: PrayerContextResolutionStatus.automatic,
      context: PrayerContext(prayerType: PrayerType.isha),
      // Isha before midnight is still this day's. The same prayer read after
      // midnight is the branch at the top of `resolve`, which takes the day
      // that is ending.
      contextLocalDate: automaticSchedule.date,
      currentStartsAt: isha,
      currentEndsAt: hasReliableNextDay
          ? nextDaySchedule!.times.fajr.effective
          : null,
      nextPrayerType: hasReliableNextDay ? PrayerType.fajr : null,
      nextPrayerAt: hasReliableNextDay
          ? nextDaySchedule!.times.fajr.effective
          : null,
    );
  }

  bool _before(int secondOfDay, PrayerClockTime time) =>
      secondOfDay < time.minutesSinceMidnight * 60;

  bool _isReliablePreviousDay({
    required PrayerDaySchedule current,
    required PrayerDaySchedule? previous,
    required bool declaredReliable,
  }) {
    if (!declaredReliable || previous == null) return false;
    return _isReliableAdjacentDay(
      current: current,
      adjacent: previous,
      dayDelta: -1,
      declaredReliable: declaredReliable,
    );
  }

  bool _isReliableAdjacentDay({
    required PrayerDaySchedule current,
    required PrayerDaySchedule? adjacent,
    required int dayDelta,
    required bool declaredReliable,
  }) {
    if (!declaredReliable || adjacent == null) return false;
    final expectedDateTime = DateTime.utc(
      current.date.year,
      current.date.month,
      current.date.day,
    ).add(Duration(days: dayDelta));
    return adjacent.date == LocalDate.fromLocalDateTime(expectedDateTime) &&
        adjacent.timeZoneId == current.timeZoneId &&
        adjacent.utcOffsetMinutes == current.utcOffsetMinutes;
  }

  PrayerContextResolution _automatic(
    PrayerType type, {
    required LocalDate localDate,
    required PrayerClockTime startsAt,
    required PrayerClockTime endsAt,
    required PrayerType nextType,
    required PrayerClockTime nextAt,
  }) => PrayerContextResolution(
    status: PrayerContextResolutionStatus.automatic,
    context: PrayerContext(prayerType: type),
    contextLocalDate: localDate,
    currentStartsAt: startsAt,
    currentEndsAt: endsAt,
    nextPrayerType: nextType,
    nextPrayerAt: nextAt,
  );
}
