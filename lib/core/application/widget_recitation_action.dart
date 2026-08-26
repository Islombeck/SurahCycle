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
  }) {
    _requireUuidV4(actionToken);
    _requireSafeId(surahId, 'surahId');
    _requireSafeId(rotationSchemeId, 'rotationSchemeId');
    if (partId != null) _requireSafeId(partId, 'partId');
    return WidgetRecitationAction._(
      actionToken: actionToken.toLowerCase(),
      surahId: surahId,
      rotationSchemeId: rotationSchemeId,
      partId: partId,
    );
  }

  const WidgetRecitationAction._({
    required this.actionToken,
    required this.surahId,
    required this.rotationSchemeId,
    required this.partId,
  });

  static const int schemaVersion = 1;
  static const String uriScheme = 'murajaah-widget';
  static const String uriHost = 'recitation';

  final String actionToken;
  final String surahId;
  final String rotationSchemeId;
  final String? partId;

  Uri get uri => Uri(
    scheme: uriScheme,
    host: uriHost,
    queryParameters: <String, String>{
      'schema': '$schemaVersion',
      'token': actionToken,
      'surah': surahId,
      'scheme': rotationSchemeId,
      'part': ?partId,
    },
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'actionToken': actionToken,
    'surahId': surahId,
    'rotationSchemeId': rotationSchemeId,
    if (partId != null) 'partId': partId,
  };

  static WidgetRecitationAction fromJson(Map<String, Object?> json) {
    const allowed = <String>{
      'schemaVersion',
      'actionToken',
      'surahId',
      'rotationSchemeId',
      'partId',
    };
    if (json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unknown widget action field.');
    }
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported widget action schema.');
    }
    return WidgetRecitationAction(
      actionToken: _string(json, 'actionToken'),
      surahId: _string(json, 'surahId'),
      rotationSchemeId: _string(json, 'rotationSchemeId'),
      partId: _nullableString(json, 'partId'),
    );
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
    const allowed = <String>{'schema', 'token', 'surah', 'scheme', 'part'};
    if (uri.queryParametersAll.keys.any((key) => !allowed.contains(key))) {
      return null;
    }
    for (final values in uri.queryParametersAll.values) {
      if (values.length != 1) return null;
    }
    if (uri.queryParameters['schema'] != '$schemaVersion') return null;
    final token = uri.queryParameters['token'];
    final surah = uri.queryParameters['surah'];
    final scheme = uri.queryParameters['scheme'];
    if (token == null || surah == null || scheme == null) return null;
    try {
      return WidgetRecitationAction(
        actionToken: token,
        surahId: surah,
        rotationSchemeId: scheme,
        partId: uri.queryParameters['part'],
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
          partId == other.partId;

  @override
  int get hashCode =>
      Object.hash(actionToken, surahId, rotationSchemeId, partId);
}

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
