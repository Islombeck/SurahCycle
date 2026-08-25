import 'dart:convert';

import 'quran_models.dart';

/// User-selected, version-pinned translation metadata.
///
/// No translation is selected by default. A newer provider catalog entry does
/// not mutate this value; the application can present an explicit update action
/// and replace it only after user confirmation.
final class QuranTranslationSelection {
  factory QuranTranslationSelection({
    required String source,
    required String key,
    required String languageCode,
    required String version,
    required String title,
    required DateTime fetchedAtUtc,
    required String attribution,
    String? description,
    String? direction,
    int? lastUpdateEpochSeconds,
    Uri? sourceUri,
  }) {
    for (final entry in <String, String>{
      'source': source,
      'key': key,
      'languageCode': languageCode,
      'version': version,
      'title': title,
      'attribution': attribution,
    }.entries) {
      if (entry.value.isEmpty) {
        throw ArgumentError.value(entry.value, entry.key, 'Must not be empty.');
      }
    }
    if (!fetchedAtUtc.isUtc) {
      throw ArgumentError.value(fetchedAtUtc, 'fetchedAtUtc', 'Must be UTC.');
    }
    if (description != null && description.isEmpty) {
      throw ArgumentError.value(
        description,
        'description',
        'Must not be empty.',
      );
    }
    if (direction != null && direction.isEmpty) {
      throw ArgumentError.value(direction, 'direction', 'Must not be empty.');
    }
    if (lastUpdateEpochSeconds != null && lastUpdateEpochSeconds < 0) {
      throw ArgumentError.value(
        lastUpdateEpochSeconds,
        'lastUpdateEpochSeconds',
        'Must not be negative.',
      );
    }
    return QuranTranslationSelection._(
      source: source,
      key: key,
      languageCode: languageCode,
      version: version,
      title: title,
      description: description,
      direction: direction,
      lastUpdateEpochSeconds: lastUpdateEpochSeconds,
      fetchedAtUtc: fetchedAtUtc,
      attribution: attribution,
      sourceUri: sourceUri,
    );
  }

  factory QuranTranslationSelection.fromCatalog({
    required QuranTranslation translation,
    required DateTime fetchedAtUtc,
    required String attribution,
    Uri? sourceUri,
  }) => QuranTranslationSelection(
    source: translation.source,
    key: translation.key,
    languageCode: translation.languageCode,
    version: translation.version,
    title: translation.title,
    description: translation.description,
    direction: translation.direction,
    lastUpdateEpochSeconds: translation.lastUpdateEpochSeconds,
    fetchedAtUtc: fetchedAtUtc,
    attribution: attribution,
    sourceUri: sourceUri,
  );

  const QuranTranslationSelection._({
    required this.source,
    required this.key,
    required this.languageCode,
    required this.version,
    required this.title,
    required this.description,
    required this.direction,
    required this.lastUpdateEpochSeconds,
    required this.fetchedAtUtc,
    required this.attribution,
    required this.sourceUri,
  });

  static const int schemaVersion = 1;

  final String source;
  final String key;
  final String languageCode;
  final String version;
  final String title;
  final String? description;
  final String? direction;
  final int? lastUpdateEpochSeconds;
  final DateTime fetchedAtUtc;
  final String attribution;
  final Uri? sourceUri;

  QuranTranslation get translation => QuranTranslation(
    source: source,
    key: key,
    languageCode: languageCode,
    version: version,
    title: title,
    description: description,
    direction: direction,
    lastUpdateEpochSeconds: lastUpdateEpochSeconds,
  );

  bool matchesCatalogEntry(QuranTranslation candidate) =>
      candidate.source == source &&
      candidate.key == key &&
      candidate.languageCode == languageCode &&
      candidate.version == version;

  bool hasUpdateIn(Iterable<QuranTranslation> catalog) => catalog.any(
    (candidate) =>
        candidate.source == source &&
        candidate.key == key &&
        candidate.languageCode == languageCode &&
        candidate.version != version,
  );

  String toJsonString() => jsonEncode(<String, Object?>{
    'schemaVersion': schemaVersion,
    'source': source,
    'key': key,
    'languageCode': languageCode,
    'version': version,
    'title': title,
    'description': description,
    'direction': direction,
    'lastUpdateEpochSeconds': lastUpdateEpochSeconds,
    'fetchedAtUtc': fetchedAtUtc.toIso8601String(),
    'attribution': attribution,
    'sourceUri': sourceUri?.toString(),
  });

  static QuranTranslationSelection fromJsonString(String encoded) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const FormatException('Translation selection JSON is invalid.');
    }
    if (decoded is! Map<Object?, Object?> ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException(
        'Translation selection schema is unsupported.',
      );
    }

    final fetchedAtRaw = _requiredString(decoded, 'fetchedAtUtc');
    final fetchedAt = DateTime.tryParse(fetchedAtRaw);
    if (fetchedAt == null || !fetchedAt.isUtc) {
      throw const FormatException('Translation fetchedAtUtc is invalid.');
    }
    final sourceUriRaw = _optionalString(decoded, 'sourceUri');
    final sourceUri = sourceUriRaw == null ? null : Uri.tryParse(sourceUriRaw);
    if (sourceUriRaw != null &&
        (sourceUri == null || !sourceUri.hasScheme || sourceUri.host.isEmpty)) {
      throw const FormatException('Translation sourceUri is invalid.');
    }

    try {
      return QuranTranslationSelection(
        source: _requiredString(decoded, 'source'),
        key: _requiredString(decoded, 'key'),
        languageCode: _requiredString(decoded, 'languageCode'),
        version: _requiredString(decoded, 'version'),
        title: _requiredString(decoded, 'title'),
        description: _optionalString(decoded, 'description'),
        direction: _optionalString(decoded, 'direction'),
        lastUpdateEpochSeconds: _optionalInteger(
          decoded,
          'lastUpdateEpochSeconds',
        ),
        fetchedAtUtc: fetchedAt,
        attribution: _requiredString(decoded, 'attribution'),
        sourceUri: sourceUri,
      );
    } on ArgumentError {
      throw const FormatException('Translation selection values are invalid.');
    }
  }

  static String _requiredString(Map<Object?, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key is not a non-empty string.');
    }
    return value;
  }

  static String? _optionalString(Map<Object?, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('$key is not null or a non-empty string.');
    }
    return value;
  }

  static int? _optionalInteger(Map<Object?, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int || value < 0) {
      throw FormatException('$key is not null or a non-negative integer.');
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranTranslationSelection &&
          source == other.source &&
          key == other.key &&
          languageCode == other.languageCode &&
          version == other.version &&
          title == other.title &&
          description == other.description &&
          direction == other.direction &&
          lastUpdateEpochSeconds == other.lastUpdateEpochSeconds &&
          fetchedAtUtc == other.fetchedAtUtc &&
          attribution == other.attribution &&
          sourceUri == other.sourceUri;

  @override
  int get hashCode => Object.hash(
    source,
    key,
    languageCode,
    version,
    title,
    description,
    direction,
    lastUpdateEpochSeconds,
    fetchedAtUtc,
    attribution,
    sourceUri,
  );
}
