import 'dart:convert';

import '../../../core/data/repositories/settings_repository.dart';
import '../domain/prayer_time_models.dart';
import 'uzbekistan_prayer_locations.dart';

/// Versioned settings stored in the existing generic settings table. This does
/// not change the main database schema and is separate from downloaded cache.
final class PrayerTimeSettingsRepository {
  const PrayerTimeSettingsRepository(this._settings);

  static const String settingKey = 'prayer_time_settings_v1';
  static const int schemaVersion = 1;

  final AppSettingsRepository _settings;

  PrayerTimeSettings get defaultValue => PrayerTimeSettings(
    location: UzbekistanPrayerLocations.bySlug('toshkent-shahri')!,
  );

  Future<PrayerTimeSettings> load() async {
    final value = await _settings.getString(settingKey);
    return value == null ? defaultValue : decode(value);
  }

  Stream<PrayerTimeSettings> watch() async* {
    yield await load();
    yield* _settings
        .watchString(settingKey)
        .map((value) => value == null ? defaultValue : decode(value));
  }

  Future<void> save(
    PrayerTimeSettings value, {
    required DateTime updatedAtUtc,
  }) => _settings.setString(
    settingKey,
    jsonEncode(encode(value)),
    updatedAtUtc: updatedAtUtc,
  );

  static Map<String, Object?> encode(PrayerTimeSettings value) =>
      <String, Object?>{
        'schemaVersion': schemaVersion,
        'location': <String, Object?>{
          'providerSlug': value.location.providerSlug,
          'displayName': value.location.displayName,
          'timeZoneId': value.location.timeZoneId,
          'utcOffsetMinutes': value.location.utcOffsetMinutes,
          'parentProviderSlug': value.location.parentProviderSlug,
          'latitude': value.location.coordinates?.latitude,
          'longitude': value.location.coordinates?.longitude,
        },
        'locationSelectionMode': value.locationSelectionMode.name,
        'contextSelectionMode': value.contextSelectionMode.name,
        'adjustments': <String, Object?>{
          'fajr': value.effectiveAdjustments.fajrMinutes,
          'dhuhr': value.effectiveAdjustments.dhuhrMinutes,
          'asr': value.effectiveAdjustments.asrMinutes,
          'maghrib': value.effectiveAdjustments.maghribMinutes,
          'isha': value.effectiveAdjustments.ishaMinutes,
        },
        'calculation': <String, Object?>{
          'method': value.calculationSettings.method.name,
          'asrSchool': value.calculationSettings.asrSchool.name,
          'highLatitudeRule': value.calculationSettings.highLatitudeRule.name,
        },
        'allowCalculatedFallback': value.allowCalculatedFallback,
      };

  static PrayerTimeSettings decode(String encoded) {
    try {
      final root = _map(jsonDecode(encoded));
      if (_int(root['schemaVersion']) != schemaVersion) {
        throw const FormatException('Unsupported settings schema.');
      }
      final locationMap = _map(root['location']);
      final latitude = _nullableDouble(locationMap['latitude']);
      final longitude = _nullableDouble(locationMap['longitude']);
      if ((latitude == null) != (longitude == null)) {
        throw const FormatException('Incomplete coordinates.');
      }
      final location = PrayerLocation(
        providerSlug: _string(locationMap['providerSlug']),
        displayName: _string(locationMap['displayName']),
        timeZoneId: _string(locationMap['timeZoneId']),
        utcOffsetMinutes: _int(locationMap['utcOffsetMinutes']),
        parentProviderSlug: _nullableString(locationMap['parentProviderSlug']),
        coordinates: latitude == null
            ? null
            : PrayerCoordinates(latitude: latitude, longitude: longitude!),
      );
      final adjustments = _map(root['adjustments']);
      final calculation = _map(root['calculation']);
      final allowFallback = root['allowCalculatedFallback'];
      if (allowFallback is! bool) {
        throw const FormatException('Invalid fallback flag.');
      }
      return PrayerTimeSettings(
        location: location,
        locationSelectionMode: PrayerLocationSelectionMode.values.byName(
          _string(root['locationSelectionMode']),
        ),
        contextSelectionMode: PrayerContextSelectionMode.values.byName(
          _string(root['contextSelectionMode']),
        ),
        adjustments: PrayerTimeAdjustments(
          fajrMinutes: _int(adjustments['fajr']),
          dhuhrMinutes: _int(adjustments['dhuhr']),
          asrMinutes: _int(adjustments['asr']),
          maghribMinutes: _int(adjustments['maghrib']),
          ishaMinutes: _int(adjustments['isha']),
        ),
        calculationSettings: PrayerCalculationSettings(
          method: PrayerCalculationMethod.values.byName(
            _string(calculation['method']),
          ),
          asrSchool: PrayerAsrSchool.values.byName(
            _string(calculation['asrSchool']),
          ),
          highLatitudeRule: PrayerHighLatitudeRule.values.byName(
            _string(calculation['highLatitudeRule']),
          ),
        ),
        allowCalculatedFallback: allowFallback,
      );
    } on Object catch (error) {
      throw StateError('Invalid prayer-time settings: $error');
    }
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Expected JSON object.');
    }
    return value;
  }

  static String _string(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Expected non-empty string.');
    }
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    return _string(value);
  }

  static int _int(Object? value) {
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw const FormatException('Expected integer.');
    }
    return value.toInt();
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      throw const FormatException('Expected finite coordinate.');
    }
    return value.toDouble();
  }
}
