import 'package:adhan_dart/adhan_dart.dart' as adhan;

import '../../../core/domain/domain.dart';
import '../domain/prayer_time_models.dart';
import 'prayer_schedule_provider.dart';

/// Generic local astronomical calculation powered by adhan_dart 2.0.1.
///
/// This is intentionally not named after the Uzbekistan Muslim Board: no
/// public audited specification for such an official calculation preset was
/// found. The calculation settings remain visible in provenance.
final class AdhanPrayerTimeCalculator
    implements CalculatedPrayerScheduleProvider {
  const AdhanPrayerTimeCalculator({required this.timeProvider});

  static const String calculatorVersion = 'adhan_dart 2.0.1';
  static final PrayerTimeSource calculatorSource = PrayerTimeSource(
    id: 'adhan_dart_2_0_1',
    displayName: 'Local calculation',
    kind: PrayerTimeSourceKind.calculated,
    description: 'Generic astronomical prayer-time calculation.',
  );

  final TimeProvider timeProvider;

  @override
  PrayerTimeSource get source => calculatorSource;

  @override
  Future<PrayerMonthSchedule> loadMonth(PrayerScheduleRequest request) async {
    final coordinates = request.location.coordinates;
    if (coordinates == null) {
      throw const PrayerScheduleProviderException(
        code: 'calculation_coordinates_missing',
        message: 'A local calculation requires explicit coordinates.',
      );
    }
    final settings =
        request.calculationSettings ??
        const PrayerCalculationSettings.uzbekistanFallback();
    final calculatedAtUtc = timeProvider.nowUtc();
    if (!calculatedAtUtc.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return UTC.');
    }
    final adhanCoordinates = adhan.Coordinates(
      coordinates.latitude,
      coordinates.longitude,
    );
    final parameters = _parameters(settings, adhanCoordinates);
    final provenance = PrayerTimeProvenance.calculated(
      source: calculatorSource,
      sourceUri: Uri.https('pub.dev', '/packages/adhan_dart'),
      calculatedAtUtc: calculatedAtUtc,
      attribution: 'Calculated locally with $calculatorVersion.',
      calculationSettings: settings,
      calculatorVersion: calculatorVersion,
    );
    final dayCount = DateTime.utc(request.year, request.month + 1, 0).day;
    final days = <PrayerDaySchedule>[];
    for (var day = 1; day <= dayCount; day += 1) {
      final calculated = adhan.PrayerTimes(
        coordinates: adhanCoordinates,
        date: DateTime.utc(request.year, request.month, day),
        calculationParameters: parameters,
      );
      days.add(
        PrayerDaySchedule(
          date: LocalDate(request.year, request.month, day),
          times: PrayerTimes(
            fajr: _localClock(calculated.fajr, request.location),
            sunrise: _localClock(calculated.sunrise, request.location),
            dhuhr: _localClock(calculated.dhuhr, request.location),
            asr: _localClock(calculated.asr, request.location),
            maghrib: _localClock(calculated.maghrib, request.location),
            isha: _localClock(calculated.isha, request.location),
          ),
          provenance: provenance,
          timeZoneId: request.location.timeZoneId,
          utcOffsetMinutes: request.location.utcOffsetMinutes,
        ),
      );
    }
    return PrayerMonthSchedule(
      location: request.location,
      year: request.year,
      month: request.month,
      days: days,
      provenance: provenance,
    );
  }

  adhan.CalculationParameters _parameters(
    PrayerCalculationSettings settings,
    adhan.Coordinates coordinates,
  ) {
    final parameters = switch (settings.method) {
      PrayerCalculationMethod.muslimWorldLeague =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      PrayerCalculationMethod.karachi =>
        adhan.CalculationMethodParameters.karachi(),
      PrayerCalculationMethod.ummAlQura =>
        adhan.CalculationMethodParameters.ummAlQura(),
      PrayerCalculationMethod.egyptian =>
        adhan.CalculationMethodParameters.egyptian(),
      PrayerCalculationMethod.turkiye =>
        adhan.CalculationMethodParameters.turkiye(),
      PrayerCalculationMethod.dubai =>
        adhan.CalculationMethodParameters.dubai(),
      PrayerCalculationMethod.qatar =>
        adhan.CalculationMethodParameters.qatar(),
      PrayerCalculationMethod.kuwait =>
        adhan.CalculationMethodParameters.kuwait(),
      PrayerCalculationMethod.moonsightingCommittee =>
        adhan.CalculationMethodParameters.moonsightingCommittee(),
      PrayerCalculationMethod.singapore =>
        adhan.CalculationMethodParameters.singapore(),
      PrayerCalculationMethod.northAmerica =>
        adhan.CalculationMethodParameters.northAmerica(),
    };
    parameters.madhab = switch (settings.asrSchool) {
      PrayerAsrSchool.shafi => adhan.Madhab.shafi,
      PrayerAsrSchool.hanafi => adhan.Madhab.hanafi,
    };
    parameters.highLatitudeRule = switch (settings.highLatitudeRule) {
      PrayerHighLatitudeRule.recommended => adhan.HighLatitudeRule.recommended(
        coordinates,
      ),
      PrayerHighLatitudeRule.middleOfTheNight =>
        adhan.HighLatitudeRule.middleOfTheNight,
      PrayerHighLatitudeRule.seventhOfTheNight =>
        adhan.HighLatitudeRule.seventhOfTheNight,
      PrayerHighLatitudeRule.twilightAngle =>
        adhan.HighLatitudeRule.twilightAngle,
    };
    return parameters;
  }

  PrayerClockTime _localClock(DateTime utc, PrayerLocation location) {
    if (!utc.isUtc) {
      throw StateError('adhan_dart returned a non-UTC boundary.');
    }
    final local = utc.add(Duration(minutes: location.utcOffsetMinutes));
    return PrayerClockTime(local.hour, local.minute);
  }
}
