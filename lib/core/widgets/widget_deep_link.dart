sealed class WidgetDeepLink {
  const WidgetDeepLink();

  Uri get uri;

  static WidgetDeepLink? parse(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'murajaah' ||
        uri.host != 'app' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      return null;
    }

    final query = uri.queryParametersAll;
    if (query.values.any((values) => values.length != 1)) return null;

    final segments = uri.pathSegments;
    if (segments.length == 1 && segments.single == 'home') {
      if (uri.path != '/home' || query.isNotEmpty) return null;
      return const WidgetHomeDeepLink();
    }
    if (segments.length == 2 && segments.first == 'surah') {
      if (query.keys.any((key) => key != 'part')) return null;
      final surahId = segments.last;
      final partId = query['part']?.single;
      if (!_isSafeId(surahId) || (partId != null && !_isSafeId(partId))) {
        return null;
      }
      return WidgetSurahDeepLink(surahId: surahId, partId: partId);
    }
    if (segments.length == 2 && segments.first == 'learning') {
      if (query.isNotEmpty) return null;
      final surahId = segments.last;
      if (!_isSafeId(surahId)) return null;
      return WidgetLearningDeepLink(surahId);
    }
    return null;
  }

  static WidgetDeepLink? tryParse(String? source) {
    if (source == null) return null;
    return parse(Uri.tryParse(source));
  }
}

final class WidgetHomeDeepLink extends WidgetDeepLink {
  const WidgetHomeDeepLink();

  @override
  Uri get uri => Uri(
    scheme: 'murajaah',
    host: 'app',
    pathSegments: const <String>['home'],
  );

  @override
  bool operator ==(Object other) => other is WidgetHomeDeepLink;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WidgetSurahDeepLink extends WidgetDeepLink {
  factory WidgetSurahDeepLink({required String surahId, String? partId}) {
    if (!_isSafeId(surahId)) {
      throw ArgumentError.value(surahId, 'surahId', 'Unsafe identifier.');
    }
    if (partId != null && !_isSafeId(partId)) {
      throw ArgumentError.value(partId, 'partId', 'Unsafe identifier.');
    }
    return WidgetSurahDeepLink._(surahId: surahId, partId: partId);
  }

  const WidgetSurahDeepLink._({required this.surahId, required this.partId});

  final String surahId;
  final String? partId;

  @override
  Uri get uri => Uri(
    scheme: 'murajaah',
    host: 'app',
    pathSegments: <String>['surah', surahId],
    queryParameters: partId == null ? null : <String, String>{'part': partId!},
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetSurahDeepLink &&
      surahId == other.surahId &&
      partId == other.partId;

  @override
  int get hashCode => Object.hash(surahId, partId);
}

final class WidgetLearningDeepLink extends WidgetDeepLink {
  factory WidgetLearningDeepLink(String surahId) {
    if (!_isSafeId(surahId)) {
      throw ArgumentError.value(surahId, 'surahId', 'Unsafe identifier.');
    }
    return WidgetLearningDeepLink._(surahId);
  }

  const WidgetLearningDeepLink._(this.surahId);

  final String surahId;

  @override
  Uri get uri => Uri(
    scheme: 'murajaah',
    host: 'app',
    pathSegments: <String>['learning', surahId],
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetLearningDeepLink && surahId == other.surahId;

  @override
  int get hashCode => surahId.hashCode;
}

bool _isSafeId(String value) =>
    value.length <= 128 && RegExp(r'^[A-Za-z0-9._~:-]+$').hasMatch(value);
