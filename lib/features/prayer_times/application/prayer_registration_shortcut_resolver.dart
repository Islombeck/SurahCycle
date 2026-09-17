import '../../../core/domain/domain.dart';
import '../domain/prayer_context_resolver.dart';
import '../domain/prayer_time_models.dart';

/// Product-level shortcuts offered by full-app historical registration.
///
/// These values contain no presentation strings so they can be reused by any
/// UI. Widgets intentionally do not use this resolver: their action remains a
/// current-context-only operation.
enum PrayerRegistrationShortcut {
  now,
  previousPrayer,
  yesterday,
  customDateAndPrayer,
}

/// A complete, explicit input for [RecitationApplicationService.registerFromApp].
final class PrayerRegistrationSelection {
  const PrayerRegistrationSelection({
    required this.shortcut,
    required this.occurrenceLocalDate,
    required this.prayerContext,
    this.qadaOriginIsUnknown = false,
    this.qadaFulfilledLocalDate,
  });

  final PrayerRegistrationShortcut shortcut;
  final LocalDate occurrenceLocalDate;
  final PrayerContext prayerContext;

  /// The user is making up a prayer whose day he cannot name — very old debts
  /// from before he began praying regularly. [occurrenceLocalDate] is then the
  /// day of the make-up, because it is the only date that exists, and the
  /// record carries this flag so no screen pretends otherwise.
  final bool qadaOriginIsUnknown;

  /// The day the make-up was actually prayed, which is not the day it belongs
  /// to and not the moment it was typed in.
  final LocalDate? qadaFulfilledLocalDate;

  PrayerRegistrationSelection withQadaOriginUnknown(bool value) =>
      PrayerRegistrationSelection(
        shortcut: shortcut,
        occurrenceLocalDate: occurrenceLocalDate,
        prayerContext: prayerContext,
        qadaOriginIsUnknown: value,
        qadaFulfilledLocalDate: qadaFulfilledLocalDate,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerRegistrationSelection &&
          shortcut == other.shortcut &&
          occurrenceLocalDate == other.occurrenceLocalDate &&
          prayerContext == other.prayerContext &&
          qadaOriginIsUnknown == other.qadaOriginIsUnknown &&
          qadaFulfilledLocalDate == other.qadaFulfilledLocalDate;

  @override
  int get hashCode => Object.hash(
    shortcut,
    occurrenceLocalDate,
    prayerContext,
    qadaOriginIsUnknown,
    qadaFulfilledLocalDate,
  );
}

enum PrayerRegistrationShortcutStatus {
  resolved,
  currentPrayerUnavailable,
  missingSchedule,
  unreliableSchedule,
  scheduleDateMismatch,
  previousDayScheduleUnavailable,
  unsupportedAutomaticPrayer,
}

/// Fail-closed shortcut result. An unavailable shortcut never substitutes a
/// guessed prayer or date.
final class PrayerRegistrationShortcutResult {
  const PrayerRegistrationShortcutResult.resolved(this.selection)
    : status = PrayerRegistrationShortcutStatus.resolved;

  const PrayerRegistrationShortcutResult.unavailable(this.status)
    : assert(status != PrayerRegistrationShortcutStatus.resolved),
      selection = null;

  final PrayerRegistrationShortcutStatus status;
  final PrayerRegistrationSelection? selection;

  bool get canRegister => selection != null;
}

/// Resolves registration shortcuts using the same injected clock and schedule
/// primitives as automatic prayer-context resolution.
///
/// Jumuah, Witr, and Nafl have no calculated schedule boundary. They are
/// therefore accepted only through a manual current context,
/// [resolveYesterday], or [resolveCustom]; [resolvePreviousPrayer] can only
/// produce the five daily scheduled prayers.
final class PrayerRegistrationShortcutResolver {
  const PrayerRegistrationShortcutResolver(this.timeProvider);

  final TimeProvider timeProvider;

  PrayerRegistrationShortcutResult resolveNow({
    required PrayerContextResolution currentResolution,
    required int utcOffsetMinutes,
  }) {
    final context = currentResolution.context;
    if (context == null) {
      return const PrayerRegistrationShortcutResult.unavailable(
        PrayerRegistrationShortcutStatus.currentPrayerUnavailable,
      );
    }
    final isManual =
        currentResolution.status == PrayerContextResolutionStatus.manual;
    if (!isManual &&
        (context.prayerType == PrayerType.jumuah ||
            context.prayerType == PrayerType.witr ||
            context.prayerType == PrayerType.nafl)) {
      return const PrayerRegistrationShortcutResult.unavailable(
        PrayerRegistrationShortcutStatus.unsupportedAutomaticPrayer,
      );
    }
    return PrayerRegistrationShortcutResult.resolved(
      PrayerRegistrationSelection(
        shortcut: PrayerRegistrationShortcut.now,
        occurrenceLocalDate: _localToday(utcOffsetMinutes),
        prayerContext: context,
      ),
    );
  }

  PrayerRegistrationShortcutResult resolvePreviousPrayer({
    required PrayerDaySchedule? currentDaySchedule,
    bool currentDayScheduleIsReliable = false,
    PrayerDaySchedule? previousDaySchedule,
    bool previousDayScheduleIsReliable = false,
  }) {
    if (currentDaySchedule == null) {
      return const PrayerRegistrationShortcutResult.unavailable(
        PrayerRegistrationShortcutStatus.missingSchedule,
      );
    }
    if (!currentDayScheduleIsReliable) {
      return const PrayerRegistrationShortcutResult.unavailable(
        PrayerRegistrationShortcutStatus.unreliableSchedule,
      );
    }

    final localNow = _localNow(currentDaySchedule.utcOffsetMinutes);
    final localDate = LocalDate.fromLocalDateTime(localNow);
    if (localDate != currentDaySchedule.date) {
      return const PrayerRegistrationShortcutResult.unavailable(
        PrayerRegistrationShortcutStatus.scheduleDateMismatch,
      );
    }

    final secondOfDay =
        localNow.hour * 3600 + localNow.minute * 60 + localNow.second;
    final times = currentDaySchedule.times;
    final fajr = times.fajr.effective.minutesSinceMidnight * 60;
    final sunrise = times.sunrise.effective.minutesSinceMidnight * 60;
    final dhuhr = times.dhuhr.effective.minutesSinceMidnight * 60;
    final asr = times.asr.effective.minutesSinceMidnight * 60;
    final maghrib = times.maghrib.effective.minutesSinceMidnight * 60;
    final isha = times.isha.effective.minutesSinceMidnight * 60;

    // Before today's Fajr the current automatic context is yesterday's Isha,
    // so the preceding prayer is yesterday's Maghrib. Once Fajr starts, the
    // preceding prayer becomes yesterday's Isha. Both cross-day answers are
    // allowed only when the adjacent schedule is explicitly reliable.
    if (secondOfDay < fajr) {
      if (!_isReliablePreviousDay(
        current: currentDaySchedule,
        previous: previousDaySchedule,
        declaredReliable: previousDayScheduleIsReliable,
      )) {
        return const PrayerRegistrationShortcutResult.unavailable(
          PrayerRegistrationShortcutStatus.previousDayScheduleUnavailable,
        );
      }
      return _resolvedPrevious(
        date: previousDaySchedule!.date,
        prayerType: PrayerType.maghrib,
      );
    }
    if (secondOfDay < sunrise) {
      if (!_isReliablePreviousDay(
        current: currentDaySchedule,
        previous: previousDaySchedule,
        declaredReliable: previousDayScheduleIsReliable,
      )) {
        return const PrayerRegistrationShortcutResult.unavailable(
          PrayerRegistrationShortcutStatus.previousDayScheduleUnavailable,
        );
      }
      return _resolvedPrevious(
        date: previousDaySchedule!.date,
        prayerType: PrayerType.isha,
      );
    }

    // Sunrise is a safe gap for "Now", but the most recent completed prayer
    // is still unambiguous: Fajr. Sunrise itself is never modeled as prayer.
    if (secondOfDay < dhuhr) {
      return _resolvedPrevious(
        date: currentDaySchedule.date,
        prayerType: PrayerType.fajr,
      );
    }
    if (secondOfDay < asr) {
      return _resolvedPrevious(
        date: currentDaySchedule.date,
        prayerType: PrayerType.fajr,
      );
    }
    if (secondOfDay < maghrib) {
      return _resolvedPrevious(
        date: currentDaySchedule.date,
        prayerType: PrayerType.dhuhr,
      );
    }
    if (secondOfDay < isha) {
      return _resolvedPrevious(
        date: currentDaySchedule.date,
        prayerType: PrayerType.asr,
      );
    }
    return _resolvedPrevious(
      date: currentDaySchedule.date,
      prayerType: PrayerType.maghrib,
    );
  }

  /// The prayer is always supplied explicitly. In particular, a past date is
  /// not converted to Qada and yesterday's Witr remains representable.
  PrayerRegistrationShortcutResult resolveYesterday({
    required PrayerContext prayerContext,
    required int utcOffsetMinutes,
  }) => PrayerRegistrationShortcutResult.resolved(
    PrayerRegistrationSelection(
      shortcut: PrayerRegistrationShortcut.yesterday,
      occurrenceLocalDate: _shiftDate(
        _localToday(utcOffsetMinutes),
        const Duration(days: -1),
      ),
      prayerContext: prayerContext,
    ),
  );

  /// Both historical facts are explicit; no schedule lookup or Qada inference
  /// is performed for a custom selection.
  PrayerRegistrationShortcutResult resolveCustom({
    required LocalDate occurrenceLocalDate,
    required PrayerContext prayerContext,
  }) => PrayerRegistrationShortcutResult.resolved(
    PrayerRegistrationSelection(
      shortcut: PrayerRegistrationShortcut.customDateAndPrayer,
      occurrenceLocalDate: occurrenceLocalDate,
      prayerContext: prayerContext,
    ),
  );

  PrayerRegistrationShortcutResult _resolvedPrevious({
    required LocalDate date,
    required PrayerType prayerType,
  }) => PrayerRegistrationShortcutResult.resolved(
    PrayerRegistrationSelection(
      shortcut: PrayerRegistrationShortcut.previousPrayer,
      occurrenceLocalDate: date,
      prayerContext: PrayerContext(prayerType: prayerType),
    ),
  );

  DateTime _localNow(int utcOffsetMinutes) {
    if (utcOffsetMinutes < -14 * 60 || utcOffsetMinutes > 14 * 60) {
      throw ArgumentError.value(
        utcOffsetMinutes,
        'utcOffsetMinutes',
        'Must be a valid UTC offset.',
      );
    }
    final nowUtc = timeProvider.nowUtc();
    if (!nowUtc.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return a UTC DateTime.');
    }
    return nowUtc.add(Duration(minutes: utcOffsetMinutes));
  }

  LocalDate _localToday(int utcOffsetMinutes) =>
      LocalDate.fromLocalDateTime(_localNow(utcOffsetMinutes));

  bool _isReliablePreviousDay({
    required PrayerDaySchedule current,
    required PrayerDaySchedule? previous,
    required bool declaredReliable,
  }) {
    if (!declaredReliable || previous == null) return false;
    final expectedDate = _shiftDate(current.date, const Duration(days: -1));
    return previous.date == expectedDate &&
        previous.timeZoneId == current.timeZoneId &&
        previous.utcOffsetMinutes == current.utcOffsetMinutes;
  }

  LocalDate _shiftDate(LocalDate date, Duration delta) {
    final shifted = DateTime.utc(date.year, date.month, date.day).add(delta);
    return LocalDate.fromLocalDateTime(shifted);
  }
}
