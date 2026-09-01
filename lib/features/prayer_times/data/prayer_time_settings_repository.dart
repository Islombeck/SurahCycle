import 'dart:async';
import 'dart:convert';

import '../../../core/data/repositories/settings_repository.dart';
import '../domain/prayer_time_models.dart';
import 'uzbekistan_prayer_locations.dart';

/// Versioned settings stored in the existing generic settings table. This does
/// not change the main database schema and is separate from downloaded cache.
final class PrayerTimeSettingsRepository {
  const PrayerTimeSettingsRepository(this._settings);

  // Keep the original key so existing installations can read and migrate the
  // schema-v1 payload in place.
  static const String settingKey = 'prayer_time_settings_v1';
  static const int schemaVersion = 2;

  final AppSettingsRepository _settings;

  PrayerTimeSettings get defaultValue => PrayerTimeSettings(
    location: UzbekistanPrayerLocations.bySlug('toshkent-shahri')!,
    locationConfirmed: false,
    contextSelectionMode: PrayerContextSelectionMode.automatic,
    contextModeExplicitlyChosen: false,
  );

  Future<PrayerTimeSettings> load({
    FutureOr<bool> Function()? legacyManualContextExists,
  }) async {
    final value = await _settings.getString(settingKey);
    return _resolveMissingLegacyManual(
      value,
      legacyManualContextExists: legacyManualContextExists,
    );
  }

  Stream<PrayerTimeSettings> watch({
    FutureOr<bool> Function()? legacyManualContextExists,
  }) async* {
    yield await load(legacyManualContextExists: legacyManualContextExists);
    yield* _settings
        .watchString(settingKey)
        .asyncMap(
          (value) => _resolveMissingLegacyManual(
            value,
            legacyManualContextExists: legacyManualContextExists,
          ),
        );
  }

  Future<PrayerTimeSettings> _resolveMissingLegacyManual(
    String? encoded, {
    required FutureOr<bool> Function()? legacyManualContextExists,
  }) async {
    if (encoded != null) return decode(encoded);
    if (legacyManualContextExists != null &&
        await legacyManualContextExists()) {
      // Sprint 4 persisted the selected prayer independently and did not
      // necessarily persist the then-default manual settings. That explicit
      // prayer selection is a durable legacy marker: preserve manual mode,
      // while keeping the old placeholder region unconfirmed.
      return defaultValue.copyWith(
        contextSelectionMode: PrayerContextSelectionMode.manual,
        contextModeExplicitlyChosen: true,
      );
    }
    return defaultValue;
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
        'locationConfirmed': value.locationConfirmed,
        'contextSelectionMode': value.contextSelectionMode.name,
        'contextModeExplicitlyChosen': value.contextModeExplicitlyChosen,
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
      final storedSchemaVersion = _int(root['schemaVersion']);
      if (storedSchemaVersion != 1 && storedSchemaVersion != schemaVersion) {
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
      final locationSelectionMode = PrayerLocationSelectionMode.values.byName(
        _string(root['locationSelectionMode']),
      );
      return PrayerTimeSettings(
        location: location,
        // Schema v1 could be persisted by an unrelated adjustment while its
        // old Tashkent default was still only a placeholder. A non-default
        // region or coordinates are durable evidence of location choice; the
        // placeholder must remain unconfirmed and must not trigger network or
        // automatic attribution after migration.
        locationConfirmed: storedSchemaVersion == 1
            ? _legacyLocationWasExplicit(location, locationSelectionMode)
            : _bool(root['locationConfirmed']),
        locationSelectionMode: locationSelectionMode,
        contextSelectionMode: PrayerContextSelectionMode.values.byName(
          _string(root['contextSelectionMode']),
        ),
        contextModeExplicitlyChosen: storedSchemaVersion == 1
            ? true
            : _bool(root['contextModeExplicitlyChosen']),
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

  static bool _bool(Object? value) {
    if (value is! bool) {
      throw const FormatException('Expected boolean.');
    }
    return value;
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      throw const FormatException('Expected finite coordinate.');
    }
    return value.toDouble();
  }

  static bool _legacyLocationWasExplicit(
    PrayerLocation location,
    PrayerLocationSelectionMode selectionMode,
  ) {
    if (selectionMode == PrayerLocationSelectionMode.userCoordinates) {
      return location.coordinates != null;
    }
    return location.providerSlug != 'toshkent-shahri';
  }
}
