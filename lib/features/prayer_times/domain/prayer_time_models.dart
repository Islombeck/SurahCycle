import '../../../core/domain/domain.dart';

enum PrayerTimeSourceKind { publishedSchedule, calculated }

/// Identity of a prayer-time source. Published schedules and calculations are
/// deliberately different kinds and must never be relabelled as one another.
final class PrayerTimeSource {
  factory PrayerTimeSource({
    required String id,
    required String displayName,
    required PrayerTimeSourceKind kind,
    required String description,
  }) {
    if (id.trim().isEmpty ||
        displayName.trim().isEmpty ||
        description.trim().isEmpty) {
      throw ArgumentError('Prayer-time source strings must not be empty.');
    }
    return PrayerTimeSource._(
      id: id,
      displayName: displayName,
      kind: kind,
      description: description,
    );
  }

  const PrayerTimeSource._({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.description,
  });

  final String id;
  final String displayName;
  final PrayerTimeSourceKind kind;
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTimeSource &&
          id == other.id &&
          displayName == other.displayName &&
          kind == other.kind &&
          description == other.description;

  @override
  int get hashCode => Object.hash(id, displayName, kind, description);
}

final class PrayerCoordinates {
  factory PrayerCoordinates({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Must be -90..90.');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'Must be -180..180.');
    }
    return PrayerCoordinates._(latitude, longitude);
  }

  const PrayerCoordinates._(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerCoordinates &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

enum PrayerLocationSelectionMode { manualRegion, userCoordinates }

/// Provider-neutral location. [providerSlug] is stable data identity while
/// [displayName] is presentation metadata. Coordinates are optional because
/// Uzbekistan's published schedule works with a manually selected region.
final class PrayerLocation {
  factory PrayerLocation({
    required String providerSlug,
    required String displayName,
    required String timeZoneId,
    required int utcOffsetMinutes,
    String? parentProviderSlug,
    PrayerCoordinates? coordinates,
  }) {
    if (providerSlug.trim().isEmpty ||
        displayName.trim().isEmpty ||
        timeZoneId.trim().isEmpty) {
      throw ArgumentError('Prayer location strings must not be empty.');
    }
    if (utcOffsetMinutes < -14 * 60 || utcOffsetMinutes > 14 * 60) {
      throw ArgumentError.value(
        utcOffsetMinutes,
        'utcOffsetMinutes',
        'Must be a valid UTC offset.',
      );
    }
    if (parentProviderSlug != null && parentProviderSlug.trim().isEmpty) {
      throw ArgumentError.value(
        parentProviderSlug,
        'parentProviderSlug',
        'Must be null or non-empty.',
      );
    }
    return PrayerLocation._(
      providerSlug: providerSlug,
      displayName: displayName,
      timeZoneId: timeZoneId,
      utcOffsetMinutes: utcOffsetMinutes,
      parentProviderSlug: parentProviderSlug,
      coordinates: coordinates,
    );
  }

  const PrayerLocation._({
    required this.providerSlug,
    required this.displayName,
    required this.timeZoneId,
    required this.utcOffsetMinutes,
    required this.parentProviderSlug,
    required this.coordinates,
  });

  final String providerSlug;
  final String displayName;
  final String timeZoneId;
  final int utcOffsetMinutes;
  final String? parentProviderSlug;
  final PrayerCoordinates? coordinates;

  PrayerLocation copyWith({
    String? providerSlug,
    String? displayName,
    String? timeZoneId,
    int? utcOffsetMinutes,
    String? parentProviderSlug,
    PrayerCoordinates? coordinates,
  }) => PrayerLocation(
    providerSlug: providerSlug ?? this.providerSlug,
    displayName: displayName ?? this.displayName,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
    parentProviderSlug: parentProviderSlug ?? this.parentProviderSlug,
    coordinates: coordinates ?? this.coordinates,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerLocation &&
          providerSlug == other.providerSlug &&
          displayName == other.displayName &&
          timeZoneId == other.timeZoneId &&
          utcOffsetMinutes == other.utcOffsetMinutes &&
          parentProviderSlug == other.parentProviderSlug &&
          coordinates == other.coordinates;

  @override
  int get hashCode => Object.hash(
    providerSlug,
    displayName,
    timeZoneId,
    utcOffsetMinutes,
    parentProviderSlug,
    coordinates,
  );
}

/// Platform-neutral geocoding boundary. UI/platform code may obtain
/// coordinates after an explicit user action and pass them here. This layer
/// intentionally owns neither permissions nor GPS access.
abstract interface class PrayerLocationResolver {
  Future<PrayerLocation?> resolve(PrayerCoordinates coordinates);
}

final class PrayerClockTime implements Comparable<PrayerClockTime> {
  factory PrayerClockTime(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError.value('$hour:$minute', 'time', 'Must be HH:mm.');
    }
    return PrayerClockTime._(hour * 60 + minute);
  }

  factory PrayerClockTime.fromMinutesSinceMidnight(int value) {
    if (value < 0 || value >= minutesPerDay) {
      throw ArgumentError.value(
        value,
        'minutesSinceMidnight',
        'Must be within one local calendar day.',
      );
    }
    return PrayerClockTime._(value);
  }

  const PrayerClockTime._(this.minutesSinceMidnight);

  static const int minutesPerDay = 24 * 60;

  final int minutesSinceMidnight;

  int get hour => minutesSinceMidnight ~/ 60;
  int get minute => minutesSinceMidnight % 60;

  PrayerClockTime shifted(int minutes) =>
      PrayerClockTime.fromMinutesSinceMidnight(minutesSinceMidnight + minutes);

  @override
  int compareTo(PrayerClockTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerClockTime &&
          minutesSinceMidnight == other.minutesSinceMidnight;

  @override
  int get hashCode => minutesSinceMidnight.hashCode;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

final class PrayerTimeAdjustments {
  factory PrayerTimeAdjustments({
    int fajrMinutes = 0,
    int dhuhrMinutes = 0,
    int asrMinutes = 0,
    int maghribMinutes = 0,
    int ishaMinutes = 0,
  }) {
    final values = <int>[
      fajrMinutes,
      dhuhrMinutes,
      asrMinutes,
      maghribMinutes,
      ishaMinutes,
    ];
    if (values.any((value) => value.abs() > maxAbsoluteMinutes)) {
      throw ArgumentError(
        'Manual prayer adjustments must be within '
        '±$maxAbsoluteMinutes minutes.',
      );
    }
    return PrayerTimeAdjustments._(
      fajrMinutes: fajrMinutes,
      dhuhrMinutes: dhuhrMinutes,
      asrMinutes: asrMinutes,
      maghribMinutes: maghribMinutes,
      ishaMinutes: ishaMinutes,
    );
  }

  const PrayerTimeAdjustments._({
    required this.fajrMinutes,
    required this.dhuhrMinutes,
    required this.asrMinutes,
    required this.maghribMinutes,
    required this.ishaMinutes,
  });

  static const int maxAbsoluteMinutes = 180;
  static final PrayerTimeAdjustments zero = PrayerTimeAdjustments();

  final int fajrMinutes;
  final int dhuhrMinutes;
  final int asrMinutes;
  final int maghribMinutes;
  final int ishaMinutes;

  bool get isAdjusted =>
      fajrMinutes != 0 ||
      dhuhrMinutes != 0 ||
      asrMinutes != 0 ||
      maghribMinutes != 0 ||
      ishaMinutes != 0;

  int forPrayer(PrayerType prayerType) => switch (prayerType) {
    PrayerType.fajr => fajrMinutes,
    PrayerType.dhuhr => dhuhrMinutes,
    PrayerType.asr => asrMinutes,
    PrayerType.maghrib => maghribMinutes,
    PrayerType.isha => ishaMinutes,
    PrayerType.witr || PrayerType.nafl => 0,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTimeAdjustments &&
          fajrMinutes == other.fajrMinutes &&
          dhuhrMinutes == other.dhuhrMinutes &&
          asrMinutes == other.asrMinutes &&
          maghribMinutes == other.maghribMinutes &&
          ishaMinutes == other.ishaMinutes;

  @override
  int get hashCode => Object.hash(
    fajrMinutes,
    dhuhrMinutes,
    asrMinutes,
    maghribMinutes,
    ishaMinutes,
  );
}

final class PrayerTimeValue {
  const PrayerTimeValue({
    required this.raw,
    required this.effective,
    required this.manualAdjustmentMinutes,
  });

  final PrayerClockTime raw;
  final PrayerClockTime effective;
  final int manualAdjustmentMinutes;

  bool get isManuallyAdjusted => manualAdjustmentMinutes != 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTimeValue &&
          raw == other.raw &&
          effective == other.effective &&
          manualAdjustmentMinutes == other.manualAdjustmentMinutes;

  @override
  int get hashCode => Object.hash(raw, effective, manualAdjustmentMinutes);
}

/// The six daily boundaries. Sunrise is kept as a boundary and is never a
/// [PrayerType]. Manual offsets preserve both provider/calculator raw values
/// and effective user-visible values.
final class PrayerTimes {
  factory PrayerTimes({
    required PrayerClockTime fajr,
    required PrayerClockTime sunrise,
    required PrayerClockTime dhuhr,
    required PrayerClockTime asr,
    required PrayerClockTime maghrib,
    required PrayerClockTime isha,
    PrayerTimeAdjustments? adjustments,
  }) {
    _requireStrictOrder(<PrayerClockTime>[
      fajr,
      sunrise,
      dhuhr,
      asr,
      maghrib,
      isha,
    ], 'raw prayer times');
    final applied = adjustments ?? PrayerTimeAdjustments.zero;
    final effective = <PrayerClockTime>[
      fajr.shifted(applied.fajrMinutes),
      sunrise,
      dhuhr.shifted(applied.dhuhrMinutes),
      asr.shifted(applied.asrMinutes),
      maghrib.shifted(applied.maghribMinutes),
      isha.shifted(applied.ishaMinutes),
    ];
    _requireStrictOrder(effective, 'effective prayer times');
    return PrayerTimes._(
      fajr: PrayerTimeValue(
        raw: fajr,
        effective: effective[0],
        manualAdjustmentMinutes: applied.fajrMinutes,
      ),
      sunrise: PrayerTimeValue(
        raw: sunrise,
        effective: sunrise,
        manualAdjustmentMinutes: 0,
      ),
      dhuhr: PrayerTimeValue(
        raw: dhuhr,
        effective: effective[2],
        manualAdjustmentMinutes: applied.dhuhrMinutes,
      ),
      asr: PrayerTimeValue(
        raw: asr,
        effective: effective[3],
        manualAdjustmentMinutes: applied.asrMinutes,
      ),
      maghrib: PrayerTimeValue(
        raw: maghrib,
        effective: effective[4],
        manualAdjustmentMinutes: applied.maghribMinutes,
      ),
      isha: PrayerTimeValue(
        raw: isha,
        effective: effective[5],
        manualAdjustmentMinutes: applied.ishaMinutes,
      ),
      adjustments: applied,
    );
  }

  const PrayerTimes._({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.adjustments,
  });

  final PrayerTimeValue fajr;
  final PrayerTimeValue sunrise;
  final PrayerTimeValue dhuhr;
  final PrayerTimeValue asr;
  final PrayerTimeValue maghrib;
  final PrayerTimeValue isha;
  final PrayerTimeAdjustments adjustments;

  bool get isManuallyAdjusted => adjustments.isAdjusted;

  PrayerTimes withAdjustments(PrayerTimeAdjustments value) => PrayerTimes(
    fajr: fajr.raw,
    sunrise: sunrise.raw,
    dhuhr: dhuhr.raw,
    asr: asr.raw,
    maghrib: maghrib.raw,
    isha: isha.raw,
    adjustments: value,
  );

  static void _requireStrictOrder(List<PrayerClockTime> values, String label) {
    for (var index = 1; index < values.length; index += 1) {
      if (values[index - 1].compareTo(values[index]) >= 0) {
        throw ArgumentError('$label must be strictly chronological.');
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTimes &&
          fajr == other.fajr &&
          sunrise == other.sunrise &&
          dhuhr == other.dhuhr &&
          asr == other.asr &&
          maghrib == other.maghrib &&
          isha == other.isha &&
          adjustments == other.adjustments;

  @override
  int get hashCode =>
      Object.hash(fajr, sunrise, dhuhr, asr, maghrib, isha, adjustments);
}

enum PrayerCalculationMethod {
  muslimWorldLeague,
  karachi,
  ummAlQura,
  egyptian,
  turkiye,
  dubai,
  qatar,
  kuwait,
  moonsightingCommittee,
  singapore,
  northAmerica,
}

enum PrayerAsrSchool { shafi, hanafi }

enum PrayerHighLatitudeRule {
  recommended,
  middleOfTheNight,
  seventhOfTheNight,
  twilightAngle,
}

final class PrayerCalculationSettings {
  const PrayerCalculationSettings({
    required this.method,
    required this.asrSchool,
    this.highLatitudeRule = PrayerHighLatitudeRule.recommended,
  });

  const PrayerCalculationSettings.uzbekistanFallback()
    : method = PrayerCalculationMethod.karachi,
      asrSchool = PrayerAsrSchool.hanafi,
      highLatitudeRule = PrayerHighLatitudeRule.recommended;

  final PrayerCalculationMethod method;
  final PrayerAsrSchool asrSchool;
  final PrayerHighLatitudeRule highLatitudeRule;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerCalculationSettings &&
          method == other.method &&
          asrSchool == other.asrSchool &&
          highLatitudeRule == other.highLatitudeRule;

  @override
  int get hashCode => Object.hash(method, asrSchool, highLatitudeRule);
}

final class PrayerTimeProvenance {
  factory PrayerTimeProvenance.published({
    required PrayerTimeSource source,
    required Uri sourceUri,
    required DateTime fetchedAtUtc,
    required String attribution,
    required String providerRegionSlug,
    int? providerRegionalOffsetMinutes,
  }) {
    if (source.kind != PrayerTimeSourceKind.publishedSchedule) {
      throw ArgumentError('Published provenance requires a schedule source.');
    }
    return PrayerTimeProvenance._validated(
      source: source,
      sourceUri: sourceUri,
      fetchedAtUtc: fetchedAtUtc,
      attribution: attribution,
      providerRegionSlug: providerRegionSlug,
      providerRegionalOffsetMinutes: providerRegionalOffsetMinutes,
    );
  }

  factory PrayerTimeProvenance.calculated({
    required PrayerTimeSource source,
    required Uri sourceUri,
    required DateTime calculatedAtUtc,
    required String attribution,
    required PrayerCalculationSettings calculationSettings,
    required String calculatorVersion,
  }) {
    if (source.kind != PrayerTimeSourceKind.calculated) {
      throw ArgumentError(
        'Calculated provenance requires a calculated source.',
      );
    }
    if (calculatorVersion.trim().isEmpty) {
      throw ArgumentError.value(
        calculatorVersion,
        'calculatorVersion',
        'Must not be empty.',
      );
    }
    return PrayerTimeProvenance._validated(
      source: source,
      sourceUri: sourceUri,
      fetchedAtUtc: calculatedAtUtc,
      attribution: attribution,
      calculationSettings: calculationSettings,
      calculatorVersion: calculatorVersion,
    );
  }

  factory PrayerTimeProvenance._validated({
    required PrayerTimeSource source,
    required Uri sourceUri,
    required DateTime fetchedAtUtc,
    required String attribution,
    String? providerRegionSlug,
    int? providerRegionalOffsetMinutes,
    PrayerCalculationSettings? calculationSettings,
    String? calculatorVersion,
  }) {
    if (!fetchedAtUtc.isUtc) {
      throw ArgumentError.value(fetchedAtUtc, 'fetchedAtUtc', 'Must be UTC.');
    }
    if (sourceUri.scheme != 'https' || sourceUri.host.isEmpty) {
      throw ArgumentError.value(sourceUri, 'sourceUri', 'Must be HTTPS.');
    }
    if (attribution.trim().isEmpty) {
      throw ArgumentError.value(
        attribution,
        'attribution',
        'Must not be empty.',
      );
    }
    if (providerRegionSlug != null && providerRegionSlug.trim().isEmpty) {
      throw ArgumentError.value(
        providerRegionSlug,
        'providerRegionSlug',
        'Must be null or non-empty.',
      );
    }
    return PrayerTimeProvenance._(
      source: source,
      sourceUri: sourceUri,
      fetchedAtUtc: fetchedAtUtc,
      attribution: attribution,
      providerRegionSlug: providerRegionSlug,
      providerRegionalOffsetMinutes: providerRegionalOffsetMinutes,
      calculationSettings: calculationSettings,
      calculatorVersion: calculatorVersion,
    );
  }

  const PrayerTimeProvenance._({
    required this.source,
    required this.sourceUri,
    required this.fetchedAtUtc,
    required this.attribution,
    required this.providerRegionSlug,
    required this.providerRegionalOffsetMinutes,
    required this.calculationSettings,
    required this.calculatorVersion,
  });

  final PrayerTimeSource source;
  final Uri sourceUri;
  final DateTime fetchedAtUtc;
  final String attribution;
  final String? providerRegionSlug;
  final int? providerRegionalOffsetMinutes;
  final PrayerCalculationSettings? calculationSettings;
  final String? calculatorVersion;

  bool get isPublished => source.kind == PrayerTimeSourceKind.publishedSchedule;
  bool get isCalculated => source.kind == PrayerTimeSourceKind.calculated;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTimeProvenance &&
          source == other.source &&
          sourceUri == other.sourceUri &&
          fetchedAtUtc == other.fetchedAtUtc &&
          attribution == other.attribution &&
          providerRegionSlug == other.providerRegionSlug &&
          providerRegionalOffsetMinutes ==
              other.providerRegionalOffsetMinutes &&
          calculationSettings == other.calculationSettings &&
          calculatorVersion == other.calculatorVersion;

  @override
  int get hashCode => Object.hash(
    source,
    sourceUri,
    fetchedAtUtc,
    attribution,
    providerRegionSlug,
    providerRegionalOffsetMinutes,
    calculationSettings,
    calculatorVersion,
  );
}

final class PrayerDaySchedule {
  factory PrayerDaySchedule({
    required LocalDate date,
    required PrayerTimes times,
    required PrayerTimeProvenance provenance,
    required String timeZoneId,
    required int utcOffsetMinutes,
  }) {
    if (timeZoneId.trim().isEmpty ||
        utcOffsetMinutes < -14 * 60 ||
        utcOffsetMinutes > 14 * 60) {
      throw ArgumentError('Prayer day requires valid timezone metadata.');
    }
    return PrayerDaySchedule._(
      date: date,
      times: times,
      provenance: provenance,
      timeZoneId: timeZoneId,
      utcOffsetMinutes: utcOffsetMinutes,
    );
  }

  const PrayerDaySchedule._({
    required this.date,
    required this.times,
    required this.provenance,
    required this.timeZoneId,
    required this.utcOffsetMinutes,
  });

  final LocalDate date;
  final PrayerTimes times;
  final PrayerTimeProvenance provenance;
  final String timeZoneId;
  final int utcOffsetMinutes;

  PrayerDaySchedule withAdjustments(PrayerTimeAdjustments adjustments) =>
      PrayerDaySchedule(
        date: date,
        times: times.withAdjustments(adjustments),
        provenance: provenance,
        timeZoneId: timeZoneId,
        utcOffsetMinutes: utcOffsetMinutes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerDaySchedule &&
          date == other.date &&
          times == other.times &&
          provenance == other.provenance &&
          timeZoneId == other.timeZoneId &&
          utcOffsetMinutes == other.utcOffsetMinutes;

  @override
  int get hashCode =>
      Object.hash(date, times, provenance, timeZoneId, utcOffsetMinutes);
}

final class PrayerMonthSchedule {
  factory PrayerMonthSchedule({
    required PrayerLocation location,
    required int year,
    required int month,
    required List<PrayerDaySchedule> days,
    required PrayerTimeProvenance provenance,
  }) {
    final dayCount = DateTime.utc(year, month + 1, 0).day;
    if (month < 1 || month > 12 || days.length != dayCount) {
      throw ArgumentError(
        'A month schedule must contain every day exactly once.',
      );
    }
    for (var index = 0; index < days.length; index += 1) {
      final expected = LocalDate(year, month, index + 1);
      if (days[index].date != expected ||
          days[index].provenance != provenance ||
          days[index].timeZoneId != location.timeZoneId ||
          days[index].utcOffsetMinutes != location.utcOffsetMinutes) {
        throw ArgumentError(
          'Month schedule days must be sequential and share provenance.',
        );
      }
    }
    return PrayerMonthSchedule._(
      location: location,
      year: year,
      month: month,
      days: List<PrayerDaySchedule>.unmodifiable(days),
      provenance: provenance,
    );
  }

  const PrayerMonthSchedule._({
    required this.location,
    required this.year,
    required this.month,
    required this.days,
    required this.provenance,
  });

  final PrayerLocation location;
  final int year;
  final int month;
  final List<PrayerDaySchedule> days;
  final PrayerTimeProvenance provenance;

  PrayerDaySchedule? day(LocalDate date) {
    if (date.year != year || date.month != month) return null;
    return days[date.day - 1];
  }

  PrayerMonthSchedule withAdjustments(PrayerTimeAdjustments adjustments) =>
      PrayerMonthSchedule(
        location: location,
        year: year,
        month: month,
        days: days
            .map((day) => day.withAdjustments(adjustments))
            .toList(growable: false),
        provenance: provenance,
      );

  bool get hasManualAdjustments =>
      days.any((day) => day.times.isManuallyAdjusted);
}

enum PrayerContextSelectionMode { manual, automatic }

final class PrayerTimeSettings {
  const PrayerTimeSettings({
    required this.location,
    this.locationSelectionMode = PrayerLocationSelectionMode.manualRegion,
    this.contextSelectionMode = PrayerContextSelectionMode.manual,
    this.adjustments,
    this.calculationSettings =
        const PrayerCalculationSettings.uzbekistanFallback(),
    this.allowCalculatedFallback = false,
  });

  final PrayerLocation location;
  final PrayerLocationSelectionMode locationSelectionMode;
  final PrayerContextSelectionMode contextSelectionMode;
  final PrayerTimeAdjustments? adjustments;
  final PrayerCalculationSettings calculationSettings;
  final bool allowCalculatedFallback;

  PrayerTimeAdjustments get effectiveAdjustments =>
      adjustments ?? PrayerTimeAdjustments.zero;

  PrayerTimeSettings copyWith({
    PrayerLocation? location,
    PrayerLocationSelectionMode? locationSelectionMode,
    PrayerContextSelectionMode? contextSelectionMode,
    PrayerTimeAdjustments? adjustments,
    PrayerCalculationSettings? calculationSettings,
    bool? allowCalculatedFallback,
  }) => PrayerTimeSettings(
    location: location ?? this.location,
    locationSelectionMode: locationSelectionMode ?? this.locationSelectionMode,
    contextSelectionMode: contextSelectionMode ?? this.contextSelectionMode,
    adjustments: adjustments ?? this.adjustments,
    calculationSettings: calculationSettings ?? this.calculationSettings,
    allowCalculatedFallback:
        allowCalculatedFallback ?? this.allowCalculatedFallback,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTimeSettings &&
          location == other.location &&
          locationSelectionMode == other.locationSelectionMode &&
          contextSelectionMode == other.contextSelectionMode &&
          effectiveAdjustments == other.effectiveAdjustments &&
          calculationSettings == other.calculationSettings &&
          allowCalculatedFallback == other.allowCalculatedFallback;

  @override
  int get hashCode => Object.hash(
    location,
    locationSelectionMode,
    contextSelectionMode,
    effectiveAdjustments,
    calculationSettings,
    allowCalculatedFallback,
  );
}

final class PrayerScheduleRequest {
  factory PrayerScheduleRequest({
    required PrayerLocation location,
    required int year,
    required int month,
    PrayerCalculationSettings? calculationSettings,
  }) {
    if (month < 1 || month > 12 || year < 1) {
      throw ArgumentError.value('$year-$month', 'month', 'Must be valid.');
    }
    return PrayerScheduleRequest._(
      location: location,
      year: year,
      month: month,
      calculationSettings: calculationSettings,
    );
  }

  const PrayerScheduleRequest._({
    required this.location,
    required this.year,
    required this.month,
    required this.calculationSettings,
  });

  final PrayerLocation location;
  final int year;
  final int month;
  final PrayerCalculationSettings? calculationSettings;

  String cacheKey(String sourceId) =>
      '$sourceId|${location.providerSlug}|'
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}';

  /// A calculated schedule also depends on the explicit method parameters.
  /// Published provider caches deliberately use [cacheKey] instead.
  String calculationCacheKey(String sourceId) {
    final settings =
        calculationSettings ??
        const PrayerCalculationSettings.uzbekistanFallback();
    final coordinates = location.coordinates;
    return '${cacheKey(sourceId)}|'
        '${settings.method.name}|${settings.asrSchool.name}|'
        '${settings.highLatitudeRule.name}|'
        '${coordinates?.latitude}|${coordinates?.longitude}';
  }
}

/// A schedule producer is either a published timetable provider or a local
/// calculator. Its [source.kind] must truthfully describe which one it is.
abstract interface class PrayerMonthScheduleSource {
  PrayerTimeSource get source;

  Future<PrayerMonthSchedule> loadMonth(PrayerScheduleRequest request);
}
