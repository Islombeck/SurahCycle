import 'dart:convert';

import 'widget_deep_link.dart';

/// Shared storage key used by Flutter and the native widget implementations.
const String widgetSnapshotStorageKey = 'murajaah_widget_snapshot';

/// A fully denormalized, display-ready projection for home-screen widgets.
///
/// Native widgets must not derive domain state from this object. Dart owns
/// ordering, debt calculation, labels, ranges, aliases, and deep links.
final class WidgetSnapshot {
  factory WidgetSnapshot({
    required DateTime generatedAtUtc,
    required String locale,
    required RotationWidgetProjection rotation,
    required LearningWidgetProjection learning,
  }) {
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError.value(
        generatedAtUtc,
        'generatedAtUtc',
        'Must be UTC.',
      );
    }
    _requireText(locale, 'locale', maxLength: 32);
    return WidgetSnapshot._(
      generatedAtUtc: generatedAtUtc,
      locale: locale,
      rotation: rotation,
      learning: learning,
    );
  }

  const WidgetSnapshot._({
    required this.generatedAtUtc,
    required this.locale,
    required this.rotation,
    required this.learning,
  });

  static const int schemaVersion = 1;

  final DateTime generatedAtUtc;
  final String locale;
  final RotationWidgetProjection rotation;
  final LearningWidgetProjection learning;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'generatedAtUtc': generatedAtUtc.toIso8601String(),
    'locale': locale,
    'rotation': rotation.toJson(),
    'learning': learning.toJson(),
  };

  /// Ignores generation time so stream recomputation does not wake launchers
  /// when the actual projection has not changed.
  bool sameProjectionAs(WidgetSnapshot other) =>
      locale == other.locale &&
      rotation == other.rotation &&
      learning == other.learning;

  static WidgetSnapshot _fromJson(Map<String, Object?> json) {
    final generatedAtUtc = DateTime.parse(_string(json, 'generatedAtUtc'));
    if (!generatedAtUtc.isUtc) {
      throw const FormatException('generatedAtUtc must include a UTC offset.');
    }
    return WidgetSnapshot(
      generatedAtUtc: generatedAtUtc,
      locale: _string(json, 'locale'),
      rotation: RotationWidgetProjection._fromJson(_map(json, 'rotation')),
      learning: LearningWidgetProjection._fromJson(_map(json, 'learning')),
    );
  }
}

final class RotationWidgetProjection {
  factory RotationWidgetProjection({
    required Iterable<RotationWidgetItem> items,
  }) {
    final result = List<RotationWidgetItem>.unmodifiable(items);
    final ids = <String>{};
    for (final item in result) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'items', 'IDs must be unique.');
      }
    }
    return RotationWidgetProjection._(result);
  }

  const RotationWidgetProjection._(this.items);

  final List<RotationWidgetItem> items;

  Map<String, Object?> toJson() => <String, Object?>{
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  static RotationWidgetProjection _fromJson(Map<String, Object?> json) =>
      RotationWidgetProjection(
        items: _list(
          json,
          'items',
        ).map((item) => RotationWidgetItem._fromJson(_asMap(item, 'item'))),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationWidgetProjection && _listEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(items);
}

final class RotationWidgetItem {
  factory RotationWidgetItem({
    required String id,
    required String surahId,
    String? partId,
    required String title,
    String? subtitle,
    required int remaining,
    required bool isRecommended,
    required Uri deepLink,
  }) {
    _requireText(id, 'id', maxLength: 256);
    _requireText(surahId, 'surahId', maxLength: 128);
    if (partId != null) _requireText(partId, 'partId', maxLength: 128);
    _requireText(title, 'title', maxLength: 512);
    if (subtitle != null) _requireText(subtitle, 'subtitle', maxLength: 512);
    if (remaining <= 0) {
      throw ArgumentError.value(remaining, 'remaining', 'Must be positive.');
    }
    final parsedLink = WidgetDeepLink.parse(deepLink);
    if (parsedLink is! WidgetSurahDeepLink ||
        parsedLink.surahId != surahId ||
        parsedLink.partId != partId) {
      throw ArgumentError.value(
        deepLink,
        'deepLink',
        'Must target the projected surah and part.',
      );
    }
    return RotationWidgetItem._(
      id: id,
      surahId: surahId,
      partId: partId,
      title: title,
      subtitle: subtitle,
      remaining: remaining,
      isRecommended: isRecommended,
      deepLink: deepLink,
    );
  }

  const RotationWidgetItem._({
    required this.id,
    required this.surahId,
    required this.partId,
    required this.title,
    required this.subtitle,
    required this.remaining,
    required this.isRecommended,
    required this.deepLink,
  });

  final String id;
  final String surahId;
  final String? partId;
  final String title;
  final String? subtitle;
  final int remaining;
  final bool isRecommended;
  final Uri deepLink;

  /// Debt text is deliberately derived in Dart, never in Kotlin.
  String get debtLabel => remaining > 1 ? '$remaining×' : '';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'surahId': surahId,
    if (partId != null) 'partId': partId,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'remaining': remaining,
    'debtLabel': debtLabel,
    'isRecommended': isRecommended,
    'deepLink': deepLink.toString(),
  };

  static RotationWidgetItem _fromJson(Map<String, Object?> json) {
    final item = RotationWidgetItem(
      id: _string(json, 'id'),
      surahId: _string(json, 'surahId'),
      partId: _nullableString(json, 'partId'),
      title: _string(json, 'title'),
      subtitle: _nullableString(json, 'subtitle'),
      remaining: _integer(json, 'remaining'),
      isRecommended: _boolean(json, 'isRecommended'),
      deepLink: Uri.parse(_string(json, 'deepLink')),
    );
    if (_string(json, 'debtLabel') != item.debtLabel) {
      throw const FormatException('debtLabel does not match remaining.');
    }
    return item;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationWidgetItem &&
          id == other.id &&
          surahId == other.surahId &&
          partId == other.partId &&
          title == other.title &&
          subtitle == other.subtitle &&
          remaining == other.remaining &&
          isRecommended == other.isRecommended &&
          deepLink == other.deepLink;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    partId,
    title,
    subtitle,
    remaining,
    isRecommended,
    deepLink,
  );
}

final class LearningWidgetProjection {
  const LearningWidgetProjection.empty() : item = null;

  const LearningWidgetProjection.selected(LearningWidgetItem selected)
    : item = selected;

  final LearningWidgetItem? item;

  Map<String, Object?> toJson() => <String, Object?>{
    if (item != null) 'item': item!.toJson(),
  };

  static LearningWidgetProjection _fromJson(Map<String, Object?> json) {
    if (!json.containsKey('item')) {
      return const LearningWidgetProjection.empty();
    }
    return LearningWidgetProjection.selected(
      LearningWidgetItem._fromJson(_map(json, 'item')),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningWidgetProjection && item == other.item;

  @override
  int get hashCode => item.hashCode;
}

final class LearningWidgetItem {
  factory LearningWidgetItem({
    required String surahId,
    required String title,
    required String stageLabel,
    required String rangeLabel,
    required String unavailableTextLabel,
    Iterable<String> verifiedTextLines = const <String>[],
    required Uri deepLink,
  }) {
    _requireText(surahId, 'surahId', maxLength: 128);
    _requireText(title, 'title', maxLength: 512);
    _requireText(stageLabel, 'stageLabel', maxLength: 256);
    _requireText(rangeLabel, 'rangeLabel', maxLength: 256);
    _requireText(unavailableTextLabel, 'unavailableTextLabel', maxLength: 512);
    final textLines = List<String>.unmodifiable(verifiedTextLines);
    for (final line in textLines) {
      // Validate without trimming or otherwise changing verified Quran text.
      _requireText(line, 'verifiedTextLines', maxLength: 8192);
    }
    final parsedLink = WidgetDeepLink.parse(deepLink);
    if (parsedLink is! WidgetLearningDeepLink ||
        parsedLink.surahId != surahId) {
      throw ArgumentError.value(
        deepLink,
        'deepLink',
        'Must target the projected learning surah.',
      );
    }
    return LearningWidgetItem._(
      surahId: surahId,
      title: title,
      stageLabel: stageLabel,
      rangeLabel: rangeLabel,
      unavailableTextLabel: unavailableTextLabel,
      verifiedTextLines: textLines,
      deepLink: deepLink,
    );
  }

  const LearningWidgetItem._({
    required this.surahId,
    required this.title,
    required this.stageLabel,
    required this.rangeLabel,
    required this.unavailableTextLabel,
    required this.verifiedTextLines,
    required this.deepLink,
  });

  final String surahId;
  final String title;
  final String stageLabel;
  final String rangeLabel;
  final String unavailableTextLabel;

  /// Exact verified cached content supplied by the Quran repository boundary.
  /// This model never fabricates, transliterates, trims, or normalizes it.
  final List<String> verifiedTextLines;
  final Uri deepLink;

  Map<String, Object?> toJson() => <String, Object?>{
    'surahId': surahId,
    'title': title,
    'stageLabel': stageLabel,
    'rangeLabel': rangeLabel,
    'unavailableTextLabel': unavailableTextLabel,
    'verifiedTextLines': verifiedTextLines,
    'deepLink': deepLink.toString(),
  };

  static LearningWidgetItem _fromJson(Map<String, Object?> json) =>
      LearningWidgetItem(
        surahId: _string(json, 'surahId'),
        title: _string(json, 'title'),
        stageLabel: _string(json, 'stageLabel'),
        rangeLabel: _string(json, 'rangeLabel'),
        unavailableTextLabel: _string(json, 'unavailableTextLabel'),
        verifiedTextLines: _list(json, 'verifiedTextLines').map((line) {
          if (line is! String) {
            throw const FormatException('Verified text line is not a string.');
          }
          return line;
        }),
        deepLink: Uri.parse(_string(json, 'deepLink')),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningWidgetItem &&
          surahId == other.surahId &&
          title == other.title &&
          stageLabel == other.stageLabel &&
          rangeLabel == other.rangeLabel &&
          unavailableTextLabel == other.unavailableTextLabel &&
          _listEquals(verifiedTextLines, other.verifiedTextLines) &&
          deepLink == other.deepLink;

  @override
  int get hashCode => Object.hash(
    surahId,
    title,
    stageLabel,
    rangeLabel,
    unavailableTextLabel,
    Object.hashAll(verifiedTextLines),
    deepLink,
  );
}

enum WidgetSnapshotDecodeError { missing, malformed, unsupportedVersion }

sealed class WidgetSnapshotDecodeResult {
  const WidgetSnapshotDecodeResult();
}

final class WidgetSnapshotDecoded extends WidgetSnapshotDecodeResult {
  const WidgetSnapshotDecoded(this.snapshot);

  final WidgetSnapshot snapshot;
}

final class WidgetSnapshotRejected extends WidgetSnapshotDecodeResult {
  const WidgetSnapshotRejected(this.error, {this.actualVersion});

  final WidgetSnapshotDecodeError error;
  final int? actualVersion;
}

final class WidgetSnapshotCodec {
  const WidgetSnapshotCodec();

  String encode(WidgetSnapshot snapshot) => jsonEncode(snapshot.toJson());

  /// Converts all absent, corrupt, or incompatible data into an explicit safe
  /// result. Callers can render a fallback without allowing parsing failures to
  /// escape a widget receiver.
  WidgetSnapshotDecodeResult decode(String? source) {
    if (source == null || source.isEmpty) {
      return const WidgetSnapshotRejected(WidgetSnapshotDecodeError.missing);
    }
    try {
      final decoded = jsonDecode(source);
      final json = _asMap(decoded, 'snapshot');
      final version = json['schemaVersion'];
      if (version is! int) {
        return const WidgetSnapshotRejected(
          WidgetSnapshotDecodeError.malformed,
        );
      }
      if (version != WidgetSnapshot.schemaVersion) {
        return WidgetSnapshotRejected(
          WidgetSnapshotDecodeError.unsupportedVersion,
          actualVersion: version,
        );
      }
      return WidgetSnapshotDecoded(WidgetSnapshot._fromJson(json));
    } on Object {
      return const WidgetSnapshotRejected(WidgetSnapshotDecodeError.malformed);
    }
  }
}

void _requireText(String value, String name, {required int maxLength}) {
  if (value.isEmpty || value.length > maxLength) {
    throw ArgumentError.value(
      value,
      name,
      'Must contain 1–$maxLength characters.',
    );
  }
}

Map<String, Object?> _asMap(Object? value, String name) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$name is not an object.');
  }
  return value;
}

Map<String, Object?> _map(Map<String, Object?> json, String key) =>
    _asMap(json[key], key);

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key is not a list.');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key is not a string.');
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key is not a string.');
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key is not an integer.');
  return value;
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is not a boolean.');
  return value;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
