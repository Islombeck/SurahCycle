/// Versioned, untrusted payload dispatched by the Android Rotation Widget.
///
/// The native widget only transports this value. All validation that can
/// affect user data is repeated in Dart at execution time.
final class WidgetRecitationAction {
  factory WidgetRecitationAction({
    required String actionToken,
    required String surahId,
    required String rotationSchemeId,
    String? partId,
    String? prayerSessionId,
    String? prayerSessionPartId,
    int? slotIndex,
  }) {
    _requireUuidV4(actionToken);
    _requireSafeId(surahId, 'surahId');
    _requireSafeId(rotationSchemeId, 'rotationSchemeId');
    if (partId != null) _requireSafeId(partId, 'partId');
    final slotTargetFields = <Object?>[
      prayerSessionId,
      prayerSessionPartId,
      slotIndex,
    ];
    final hasAnySlotTarget = slotTargetFields.any((value) => value != null);
    final hasCompleteSlotTarget = slotTargetFields.every(
      (value) => value != null,
    );
    if (hasAnySlotTarget != hasCompleteSlotTarget) {
      throw ArgumentError(
        'Prayer session, session part, and slot must be provided together.',
      );
    }
    if (prayerSessionId != null) {
      _requireSafeId(prayerSessionId, 'prayerSessionId');
      _requireSafeId(prayerSessionPartId!, 'prayerSessionPartId');
      if (slotIndex! < 0 || slotIndex > maxWidgetPrayerSlotIndex) {
        throw ArgumentError.value(
          slotIndex,
          'slotIndex',
          'Must be in the supported widget range.',
        );
      }
    }
    return WidgetRecitationAction._(
      actionToken: actionToken.toLowerCase(),
      surahId: surahId,
      rotationSchemeId: rotationSchemeId,
      partId: partId,
      prayerSessionId: prayerSessionId,
      prayerSessionPartId: prayerSessionPartId,
      slotIndex: slotIndex,
    );
  }

  const WidgetRecitationAction._({
    required this.actionToken,
    required this.surahId,
    required this.rotationSchemeId,
    required this.partId,
    required this.prayerSessionId,
    required this.prayerSessionPartId,
    required this.slotIndex,
  });

  static const int legacySchemaVersion = 1;
  static const int schemaVersion = 2;
  static const String uriScheme = 'murajaah-widget';
  static const String uriHost = 'recitation';

  final String actionToken;
  final String surahId;
  final String rotationSchemeId;
  final String? partId;
  final String? prayerSessionId;
  final String? prayerSessionPartId;
  final int? slotIndex;

  bool get hasExactPrayerSlot => prayerSessionId != null;

  Uri get uri => Uri(
    scheme: uriScheme,
    host: uriHost,
    queryParameters: <String, String>{
      'schema': '$schemaVersion',
      'token': actionToken,
      'surah': surahId,
      'scheme': rotationSchemeId,
      'part': ?partId,
      'session': ?prayerSessionId,
      'sessionPart': ?prayerSessionPartId,
      if (slotIndex != null) 'slot': '$slotIndex',
    },
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'actionToken': actionToken,
    'surahId': surahId,
    'rotationSchemeId': rotationSchemeId,
    if (partId != null) 'partId': partId,
    if (prayerSessionId != null) 'prayerSessionId': prayerSessionId,
    if (prayerSessionPartId != null) 'prayerSessionPartId': prayerSessionPartId,
    if (slotIndex != null) 'slotIndex': slotIndex,
  };

  static WidgetRecitationAction fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != legacySchemaVersion && version != schemaVersion) {
      throw const FormatException('Unsupported widget action schema.');
    }
    const legacyAllowed = <String>{
      'schemaVersion',
      'actionToken',
      'surahId',
      'rotationSchemeId',
      'partId',
    };
    const currentAllowed = <String>{
      ...legacyAllowed,
      'prayerSessionId',
      'prayerSessionPartId',
      'slotIndex',
    };
    final allowed = version == legacySchemaVersion
        ? legacyAllowed
        : currentAllowed;
    if (json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unknown widget action field.');
    }
    try {
      return WidgetRecitationAction(
        actionToken: _string(json, 'actionToken'),
        surahId: _string(json, 'surahId'),
        rotationSchemeId: _string(json, 'rotationSchemeId'),
        partId: _nullableString(json, 'partId'),
        prayerSessionId: _nullableString(json, 'prayerSessionId'),
        prayerSessionPartId: _nullableString(json, 'prayerSessionPartId'),
        slotIndex: _nullableInteger(json, 'slotIndex'),
      );
    } on ArgumentError {
      throw const FormatException('Invalid widget action value.');
    }
  }

  static WidgetRecitationAction? tryParseUri(Uri? uri) {
    if (uri == null ||
        uri.scheme != uriScheme ||
        uri.host != uriHost ||
        uri.pathSegments.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return null;
    }
    final version = switch (uri.queryParameters['schema']) {
      '$legacySchemaVersion' => legacySchemaVersion,
      '$schemaVersion' => schemaVersion,
      _ => null,
    };
    if (version == null) return null;
    const legacyAllowed = <String>{
      'schema',
      'token',
      'surah',
      'scheme',
      'part',
    };
    const currentAllowed = <String>{
      ...legacyAllowed,
      'session',
      'sessionPart',
      'slot',
    };
    final allowed = version == legacySchemaVersion
        ? legacyAllowed
        : currentAllowed;
    if (uri.queryParametersAll.keys.any((key) => !allowed.contains(key))) {
      return null;
    }
    for (final values in uri.queryParametersAll.values) {
      if (values.length != 1) return null;
    }
    final token = uri.queryParameters['token'];
    final surah = uri.queryParameters['surah'];
    final scheme = uri.queryParameters['scheme'];
    if (token == null || surah == null || scheme == null) return null;
    final slotSource = uri.queryParameters['slot'];
    final slotIndex = slotSource == null ? null : int.tryParse(slotSource);
    if (slotSource != null && slotIndex == null) return null;
    try {
      return WidgetRecitationAction(
        actionToken: token,
        surahId: surah,
        rotationSchemeId: scheme,
        partId: uri.queryParameters['part'],
        prayerSessionId: uri.queryParameters['session'],
        prayerSessionPartId: uri.queryParameters['sessionPart'],
        slotIndex: slotIndex,
      );
    } on Object {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetRecitationAction &&
          actionToken == other.actionToken &&
          surahId == other.surahId &&
          rotationSchemeId == other.rotationSchemeId &&
          partId == other.partId &&
          prayerSessionId == other.prayerSessionId &&
          prayerSessionPartId == other.prayerSessionPartId &&
          slotIndex == other.slotIndex;

  @override
  int get hashCode => Object.hash(
    actionToken,
    surahId,
    rotationSchemeId,
    partId,
    prayerSessionId,
    prayerSessionPartId,
    slotIndex,
  );
}

/// Defensive transport bound mirrored by the Android action decoder.
const int maxWidgetPrayerSlotIndex = 1023;

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-'
  r'[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
final RegExp _safeId = RegExp(r'^[A-Za-z0-9._~:-]+$');

void _requireUuidV4(String value) {
  if (!_uuidV4.hasMatch(value)) {
    throw ArgumentError.value(value, 'actionToken', 'Must be a UUID v4.');
  }
}

void _requireSafeId(String value, String name) {
  if (value.isEmpty || value.length > 128 || !_safeId.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'Must be a safe non-empty ID.');
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key is not a string.');
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value is! String) throw FormatException('$key is not a string.');
  return value;
}

int? _nullableInteger(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value is! int) throw FormatException('$key is not an integer.');
  return value;
}
