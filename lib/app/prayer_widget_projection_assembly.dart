import 'package:intl/intl.dart';

import '../core/domain/domain.dart';
import '../core/widgets/widgets.dart';
import '../features/prayer_times/prayer_times.dart';
import '../l10n/app_localizations.dart';
import 'localization_extensions.dart';

/// The prayer part of the widget snapshot, from today's schedule.
///
/// Public and free of providers so it can be tested on its own; it used to
/// be a private method of the widget sync driver in `app_providers.dart`.
///
/// Everything here is said in the widget's language — [l10n] and
/// [localeCode] — including the two things that used to arrive as stored
/// English: the phone's own coordinates ("My location") and the calculated
/// source ("Local calculation"). The caller must have loaded the date symbols
/// for [localeCode] (`initializeDateFormatting`).
PrayerWidgetProjection assemblePrayerWidgetProjection({
  required AppLocalizations l10n,
  required String localeCode,
  required PrayerTodaySchedule? todaySchedule,
  required PrayerLocation? location,
}) {
  const factory = PrayerWidgetProjectionFactory();
  if (todaySchedule == null || location == null) {
    return factory.unavailable(l10n.prayerScheduleUnavailable);
  }
  final times = todaySchedule.day.times;
  final boundaries = <PrayerWidgetBoundary>[
    PrayerWidgetBoundary(
      label: PrayerType.fajr.label(l10n),
      hour: times.fajr.effective.hour,
      minute: times.fajr.effective.minute,
      prayerType: PrayerType.fajr,
    ),
    PrayerWidgetBoundary(
      label: l10n.sunrise,
      hour: times.sunrise.effective.hour,
      minute: times.sunrise.effective.minute,
    ),
    PrayerWidgetBoundary(
      label: PrayerType.dhuhr.label(l10n),
      hour: times.dhuhr.effective.hour,
      minute: times.dhuhr.effective.minute,
      prayerType: PrayerType.dhuhr,
    ),
    PrayerWidgetBoundary(
      label: PrayerType.asr.label(l10n),
      hour: times.asr.effective.hour,
      minute: times.asr.effective.minute,
      prayerType: PrayerType.asr,
    ),
    PrayerWidgetBoundary(
      label: PrayerType.maghrib.label(l10n),
      hour: times.maghrib.effective.hour,
      minute: times.maghrib.effective.minute,
      prayerType: PrayerType.maghrib,
    ),
    PrayerWidgetBoundary(
      label: PrayerType.isha.label(l10n),
      hour: times.isha.effective.hour,
      minute: times.isha.effective.minute,
      prayerType: PrayerType.isha,
    ),
  ];
  final isStale = !todaySchedule.loadResult.isReliableForAutomaticContext;
  final day = todaySchedule.day;
  return factory.available(
    // The day the times are for, the way a person writes it: "9 октября",
    // not "2026-10-09". The year is never in doubt on a widget for today.
    dateLabel: DateFormat.MMMMd(
      localeCode,
    ).format(DateTime(day.date.year, day.date.month, day.date.day)),
    regionLabel: location.label(l10n),
    providerLabel: day.provenance.source.label(l10n),
    boundaries: boundaries,
    // Midnight where he is, as a real instant. Everything the widget needs
    // to answer "which prayer is this, now" is derived from it, which is
    // what lets the launcher stay right between two runs of the app.
    localMidnightUtc: DateTime.utc(
      day.date.year,
      day.date.month,
      day.date.day,
    ).subtract(Duration(minutes: day.utcOffsetMinutes)),
    isStale: isStale,
    staleLabel: isStale ? l10n.prayerScheduleStale : null,
  );
}
