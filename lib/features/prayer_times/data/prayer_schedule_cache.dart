import 'dart:convert';
import 'dart:io';

import '../../../core/domain/domain.dart';
import '../domain/prayer_time_models.dart';

enum PrayerScheduleFreshness { fresh, stale, futureTimestamp }

final class PrayerScheduleCachePolicy {
  const PrayerScheduleCachePolicy({
    this.freshFor = const Duration(days: 35),
    this.allowedClockSkew = const Duration(minutes: 5),
  });

  final Duration freshFor;
  final Duration allowedClockSkew;

  PrayerScheduleFreshness freshness({
    required DateTime fetchedAtUtc,
    required DateTime nowUtc,
  }) {
    if (!fetchedAtUtc.isUtc || !nowUtc.isUtc) {
      throw ArgumentError('Cache freshness timestamps must be UTC.');
    }
    final age = nowUtc.difference(fetchedAtUtc);
    if (age < -allowedClockSkew) {
      return PrayerScheduleFreshness.futureTimestamp;
    }
    return age <= freshFor
        ? PrayerScheduleFreshness.fresh
        : PrayerScheduleFreshness.stale;
  }
}

final class CachedPrayerMonthSchedule {
  CachedPrayerMonthSchedule({
    required this.cacheKey,
    required this.schedule,
    required this.cachedAtUtc,
  }) {
    if (cacheKey.trim().isEmpty || !cachedAtUtc.isUtc) {
      throw ArgumentError('Cached schedule metadata is invalid.');
    }
  }

  final String cacheKey;
  final PrayerMonthSchedule schedule;
  final DateTime cachedAtUtc;

  PrayerScheduleFreshness freshnessAt(
    DateTime nowUtc, {
    PrayerScheduleCachePolicy policy = const PrayerScheduleCachePolicy(),
  }) => policy.freshness(
    fetchedAtUtc: schedule.provenance.fetchedAtUtc,
    nowUtc: nowUtc,
  );

  bool isReliableAt(
    DateTime nowUtc, {
    PrayerScheduleCachePolicy policy = const PrayerScheduleCachePolicy(),
  }) => freshnessAt(nowUtc, policy: policy) == PrayerScheduleFreshness.fresh;
}

abstract interface class PrayerScheduleCacheStore {
  Future<CachedPrayerMonthSchedule?> read(String cacheKey);

  Future<void> write(CachedPrayerMonthSchedule value);
}

/// Persistent prayer cache kept outside the user database.
///
/// The application supplies a cache directory (normally from path_provider).
/// Each monthly schedule is an independent versioned JSON file, so this does
/// not require a migration of the main Drift schema.
final class FilePrayerScheduleCacheStore implements PrayerScheduleCacheStore {
  FilePrayerScheduleCacheStore({required this.directory});

  static const int schemaVersion = 1;

  final Directory directory;

  @override
  Future<CachedPrayerMonthSchedule?> read(String cacheKey) async {
    try {
      // Read and let a missing file fall into the same answer as a corrupt
      // one. Asking `exists()` first was a second syscall whose answer could
      // already be stale by the time the read ran, and the catch below has
      // always had to handle the file disappearing anyway.
      final decoded = jsonDecode(await _fileFor(cacheKey).readAsString());
      return PrayerScheduleCacheCodec.decode(decoded, expectedKey: cacheKey);
    } on Object {
      // An external cache is disposable. Corruption must not affect user data
      // or cause the caller to guess a prayer context.
      return null;
    }
  }

  @override
  Future<void> write(CachedPrayerMonthSchedule value) async {
    await directory.create(recursive: true);
    final destination = _fileFor(value.cacheKey);
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(PrayerScheduleCacheCodec.encode(value)),
      flush: true,
    );
    // Straight over the top. `rename` replaces an existing file on every
    // platform Dart supports, so deleting first bought nothing and opened a
    // window — between the delete and the rename — where the cache did not
    // exist at all and a concurrent read would answer "no schedule".
    await temporary.rename(destination.path);
  }

  File _fileFor(String cacheKey) {
    final safe = cacheKey.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe.length > 180) {
      throw ArgumentError.value(cacheKey, 'cacheKey', 'Unsafe cache key.');
    }
    return File('${directory.path}${Platform.pathSeparator}$safe.json');
  }
}

abstract final class PrayerScheduleCacheCodec {
  static Map<String, Object?> encode(CachedPrayerMonthSchedule value) =>
      <String, Object?>{
        'schemaVersion': FilePrayerScheduleCacheStore.schemaVersion,
        'cacheKey': value.cacheKey,
        'cachedAtUtc': value.cachedAtUtc.toIso8601String(),
        'schedule': _encodeSchedule(value.schedule),
      };

  static CachedPrayerMonthSchedule decode(
    Object? encoded, {
    required String expectedKey,
  }) {
    final root = _map(encoded);
    if (_int(root['schemaVersion']) !=
            FilePrayerScheduleCacheStore.schemaVersion ||
        _string(root['cacheKey']) != expectedKey) {
      throw const FormatException('Unsupported prayer cache envelope.');
    }
    final cachedAtUtc = _utc(root['cachedAtUtc']);
    return CachedPrayerMonthSchedule(
      cacheKey: expectedKey,
      schedule: _decodeSchedule(_map(root['schedule'])),
      cachedAtUtc: cachedAtUtc,
    );
  }

  static Map<String, Object?> _encodeSchedule(PrayerMonthSchedule schedule) =>
      <String, Object?>{
        'location': _encodeLocation(schedule.location),
        'year': schedule.year,
        'month': schedule.month,
        'provenance': _encodeProvenance(schedule.provenance),
        'days': schedule.days.map(_encodeDay).toList(growable: false),
      };

  static PrayerMonthSchedule _decodeSchedule(Map<String, Object?> value) {
    final location = _decodeLocation(_map(value['location']));
    final year = _int(value['year']);
    final month = _int(value['month']);
    final provenance = _decodeProvenance(_map(value['provenance']));
    final days = _list(value['days'])
        .map(
          (day) =>
              _decodeDay(_map(day), provenance: provenance, location: location),
        )
        .toList(growable: false);
    return PrayerMonthSchedule(
      location: location,
      year: year,
      month: month,
      days: days,
      provenance: provenance,
    );
  }

  static Map<String, Object?> _encodeLocation(PrayerLocation value) =>
      <String, Object?>{
        'providerSlug': value.providerSlug,
        'displayName': value.displayName,
        'timeZoneId': value.timeZoneId,
        'utcOffsetMinutes': value.utcOffsetMinutes,
        'parentProviderSlug': value.parentProviderSlug,
        'coordinates': value.coordinates == null
            ? null
            : <String, Object?>{
                'latitude': value.coordinates!.latitude,
                'longitude': value.coordinates!.longitude,
              },
      };

  static PrayerLocation _decodeLocation(Map<String, Object?> value) {
    final coordinatesValue = value['coordinates'];
    PrayerCoordinates? coordinates;
    if (coordinatesValue != null) {
      final map = _map(coordinatesValue);
      coordinates = PrayerCoordinates(
        latitude: _double(map['latitude']),
        longitude: _double(map['longitude']),
      );
    }
    return PrayerLocation(
      providerSlug: _string(value['providerSlug']),
      displayName: _string(value['displayName']),
      timeZoneId: _string(value['timeZoneId']),
      utcOffsetMinutes: _int(value['utcOffsetMinutes']),
      parentProviderSlug: _nullableString(value['parentProviderSlug']),
      coordinates: coordinates,
    );
  }

  static Map<String, Object?> _encodeProvenance(PrayerTimeProvenance value) =>
      <String, Object?>{
        'source': <String, Object?>{
          'id': value.source.id,
          'displayName': value.source.displayName,
          'kind': value.source.kind.name,
          'description': value.source.description,
        },
        'sourceUri': value.sourceUri.toString(),
        'fetchedAtUtc': value.fetchedAtUtc.toIso8601String(),
        'attribution': value.attribution,
        'providerRegionSlug': value.providerRegionSlug,
        'providerRegionalOffsetMinutes': value.providerRegionalOffsetMinutes,
        'calculationSettings': value.calculationSettings == null
            ? null
            : <String, Object?>{
                'method': value.calculationSettings!.method.name,
                'asrSchool': value.calculationSettings!.asrSchool.name,
                'highLatitudeRule':
                    value.calculationSettings!.highLatitudeRule.name,
              },
        'calculatorVersion': value.calculatorVersion,
      };

  static PrayerTimeProvenance _decodeProvenance(Map<String, Object?> value) {
    final sourceMap = _map(value['source']);
    final kind = PrayerTimeSourceKind.values.byName(_string(sourceMap['kind']));
    final source = PrayerTimeSource(
      id: _string(sourceMap['id']),
      displayName: _string(sourceMap['displayName']),
      kind: kind,
      description: _string(sourceMap['description']),
    );
    final uri = Uri.parse(_string(value['sourceUri']));
    final fetchedAt = _utc(value['fetchedAtUtc']);
    final attribution = _string(value['attribution']);
    if (kind == PrayerTimeSourceKind.publishedSchedule) {
      return PrayerTimeProvenance.published(
        source: source,
        sourceUri: uri,
        fetchedAtUtc: fetchedAt,
        attribution: attribution,
        providerRegionSlug: _nullableString(value['providerRegionSlug'])!,
        providerRegionalOffsetMinutes:
            value['providerRegionalOffsetMinutes'] == null
            ? null
            : _int(value['providerRegionalOffsetMinutes']),
      );
    }
    final settingsMap = _map(value['calculationSettings']);
    return PrayerTimeProvenance.calculated(
      source: source,
      sourceUri: uri,
      calculatedAtUtc: fetchedAt,
      attribution: attribution,
      calculationSettings: PrayerCalculationSettings(
        method: PrayerCalculationMethod.values.byName(
          _string(settingsMap['method']),
        ),
        asrSchool: PrayerAsrSchool.values.byName(
          _string(settingsMap['asrSchool']),
        ),
        highLatitudeRule: PrayerHighLatitudeRule.values.byName(
          _string(settingsMap['highLatitudeRule']),
        ),
      ),
      calculatorVersion: _string(value['calculatorVersion']),
    );
  }

  static Map<String, Object?> _encodeDay(PrayerDaySchedule day) =>
      <String, Object?>{
        'date': day.date.toString(),
        'times': <String, Object?>{
          'fajr': day.times.fajr.raw.minutesSinceMidnight,
          'sunrise': day.times.sunrise.raw.minutesSinceMidnight,
          'dhuhr': day.times.dhuhr.raw.minutesSinceMidnight,
          'asr': day.times.asr.raw.minutesSinceMidnight,
          'maghrib': day.times.maghrib.raw.minutesSinceMidnight,
          'isha': day.times.isha.raw.minutesSinceMidnight,
        },
        'adjustments': <String, Object?>{
          'fajr': day.times.adjustments.fajrMinutes,
          'dhuhr': day.times.adjustments.dhuhrMinutes,
          'asr': day.times.adjustments.asrMinutes,
          'maghrib': day.times.adjustments.maghribMinutes,
          'isha': day.times.adjustments.ishaMinutes,
        },
      };

  static PrayerDaySchedule _decodeDay(
    Map<String, Object?> value, {
    required PrayerTimeProvenance provenance,
    required PrayerLocation location,
  }) {
    final dateParts = _string(value['date']).split('-');
    if (dateParts.length != 3) throw const FormatException('Bad cache date.');
    final times = _map(value['times']);
    final adjustments = _map(value['adjustments']);
    return PrayerDaySchedule(
      date: LocalDate(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      ),
      times: PrayerTimes(
        fajr: PrayerClockTime.fromMinutesSinceMidnight(_int(times['fajr'])),
        sunrise: PrayerClockTime.fromMinutesSinceMidnight(
          _int(times['sunrise']),
        ),
        dhuhr: PrayerClockTime.fromMinutesSinceMidnight(_int(times['dhuhr'])),
        asr: PrayerClockTime.fromMinutesSinceMidnight(_int(times['asr'])),
        maghrib: PrayerClockTime.fromMinutesSinceMidnight(
          _int(times['maghrib']),
        ),
        isha: PrayerClockTime.fromMinutesSinceMidnight(_int(times['isha'])),
        adjustments: PrayerTimeAdjustments(
          fajrMinutes: _int(adjustments['fajr']),
          dhuhrMinutes: _int(adjustments['dhuhr']),
          asrMinutes: _int(adjustments['asr']),
          maghribMinutes: _int(adjustments['maghrib']),
          ishaMinutes: _int(adjustments['isha']),
        ),
      ),
      provenance: provenance,
      timeZoneId: location.timeZoneId,
      utcOffsetMinutes: location.utcOffsetMinutes,
    );
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Expected JSON object.');
    }
    return value;
  }

  static List<Object?> _list(Object? value) {
    if (value is! List<Object?>) {
      throw const FormatException('Expected JSON list.');
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

  static double _double(Object? value) {
    if (value is! num || !value.isFinite) {
      throw const FormatException('Expected finite number.');
    }
    return value.toDouble();
  }

  static DateTime _utc(Object? value) {
    final parsed = DateTime.parse(_string(value));
    if (!parsed.isUtc) throw const FormatException('Expected UTC timestamp.');
    return parsed;
  }
}
