import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:murajaah/app/localization_extensions.dart';
import 'package:murajaah/app/prayer_widget_projection_assembly.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';
import 'package:murajaah/l10n/app_localizations.dart';

import '../features/prayer_times/prayer_test_fixtures.dart';

// What the widgets say about where and when, in the widget's language.
//
// Found on his phone on 2026-10-09: the strip read "My location" and the
// vertical widget's date line "2026-10-09" — a stored English name for the
// phone's own coordinates and a LocalDate.toString(), on a Russian phone. The
// card on Home said "Local calculation · My location" for the same reason.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
    await initializeDateFormatting('uz');
  });

  final ru = lookupAppLocalizations(const Locale('ru'));
  final uz = lookupAppLocalizations(const Locale('uz'));

  // His own location, as the app stored it when he chose "use my location".
  final ownCoordinates = PrayerLocation(
    providerSlug: 'user-41.3000-69.2000',
    displayName: 'My location',
    timeZoneId: 'Asia/Tashkent',
    utcOffsetMinutes: 300,
    coordinates: PrayerCoordinates(latitude: 41.3, longitude: 69.2),
  );

  PrayerTodaySchedule calculatedDay() {
    final provenance = PrayerTimeProvenance.calculated(
      source: AdhanPrayerTimeCalculator.calculatorSource,
      sourceUri: Uri.https('pub.dev', '/packages/adhan_dart'),
      calculatedAtUtc: DateTime.utc(2026, 10, 9),
      attribution: 'Calculated locally.',
      calculationSettings: const PrayerCalculationSettings.uzbekistanFallback(),
      calculatorVersion: AdhanPrayerTimeCalculator.calculatorVersion,
    );
    PrayerDaySchedule day(int d) => PrayerDaySchedule(
      date: LocalDate(2026, 10, d),
      times: testPrayerTimes(),
      provenance: provenance,
      timeZoneId: 'Asia/Tashkent',
      utcOffsetMinutes: 300,
    );
    return PrayerTodaySchedule(
      day: day(9),
      previousDay: day(8),
      previousDayIsReliable: true,
      nextDay: day(10),
      nextDayIsReliable: true,
      loadResult: PrayerScheduleLoadResult(
        schedule: PrayerMonthSchedule(
          location: ownCoordinates,
          year: 2026,
          month: 10,
          provenance: provenance,
          days: <PrayerDaySchedule>[for (var d = 1; d <= 31; d += 1) day(d)],
        ),
        origin: PrayerScheduleLoadOrigin.freshCache,
        freshness: PrayerScheduleFreshness.fresh,
      ),
    );
  }

  group('the prayer widget projection speaks the widget language', () {
    test('his own coordinates are "Моё местоположение", not "My location"', () {
      final projection = assemblePrayerWidgetProjection(
        l10n: ru,
        localeCode: 'ru',
        todaySchedule: calculatedDay(),
        location: ownCoordinates,
      );

      expect(projection.regionLabel, 'Моё местоположение');
      expect(projection.providerLabel, 'Локальный расчёт');
      expect(projection.dateLabel, '9 октября');
    });

    test('a chosen region keeps its own name', () {
      final projection = assemblePrayerWidgetProjection(
        l10n: ru,
        localeCode: 'ru',
        todaySchedule: calculatedDay(),
        location: testTashkentLocation(),
      );

      expect(projection.regionLabel, testTashkentLocation().displayName);
    });

    test('Uzbek gets Uzbek', () {
      final projection = assemblePrayerWidgetProjection(
        l10n: uz,
        localeCode: 'uz',
        todaySchedule: calculatedDay(),
        location: ownCoordinates,
      );

      expect(projection.regionLabel, 'Mening joylashuvim');
      expect(projection.providerLabel, 'Mahalliy hisoblash');
      expect(projection.dateLabel, isNot(contains('2026')));
    });

    test('no location or no schedule is unavailable, not invented', () {
      expect(
        assemblePrayerWidgetProjection(
          l10n: ru,
          localeCode: 'ru',
          todaySchedule: null,
          location: ownCoordinates,
        ).isAvailable,
        isFalse,
      );
      expect(
        assemblePrayerWidgetProjection(
          l10n: ru,
          localeCode: 'ru',
          todaySchedule: calculatedDay(),
          location: null,
        ).isAvailable,
        isFalse,
      );
    });
  });

  group('the same labels for Home and Settings', () {
    test('a published source keeps its brand name', () {
      expect(
        NamozVaqtiUzPrayerTimeProvider.providerSource.label(ru),
        'Namoz-vaqti.uz',
      );
    });

    test('the device-coordinates location is recognised by its slug', () {
      expect(ownCoordinates.isDeviceCoordinates, isTrue);
      expect(testTashkentLocation().isDeviceCoordinates, isFalse);
      expect(ownCoordinates.label(ru), 'Моё местоположение');
    });
  });
}
