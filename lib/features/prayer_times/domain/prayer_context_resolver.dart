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
    this.currentStartsAt,
    this.currentEndsAt,
    this.nextPrayerType,
    this.nextPrayerAt,
  });

  final PrayerContextResolutionStatus status;
  final PrayerContext? context;
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

    final nowUtc = timeProvider.nowUtc();
    if (!nowUtc.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return a UTC DateTime.');
    }
    final offset = automaticSchedule.utcOffsetMinutes;
    final localNow = nowUtc.add(Duration(minutes: offset));
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
          currentStartsAt: previousDaySchedule!.times.isha.effective,
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
        startsAt: dhuhr,
        endsAt: asr,
        nextType: PrayerType.asr,
        nextAt: asr,
      );
    }
    if (_before(secondOfDay, maghrib)) {
      return _automatic(
        PrayerType.asr,
        startsAt: asr,
        endsAt: maghrib,
        nextType: PrayerType.maghrib,
        nextAt: maghrib,
      );
    }
    if (_before(secondOfDay, isha)) {
      return _automatic(
        PrayerType.maghrib,
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
    required PrayerClockTime startsAt,
    required PrayerClockTime endsAt,
    required PrayerType nextType,
    required PrayerClockTime nextAt,
  }) => PrayerContextResolution(
    status: PrayerContextResolutionStatus.automatic,
    context: PrayerContext(prayerType: type),
    currentStartsAt: startsAt,
    currentEndsAt: endsAt,
    nextPrayerType: nextType,
    nextPrayerAt: nextAt,
  );
}
