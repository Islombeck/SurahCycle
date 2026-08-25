bool _sameList<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _requireNonEmpty(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _requirePositive(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Must be positive.');
  }
}

void _requireNonEmptyOrNull(String? value, String name) {
  if (value != null) _requireNonEmpty(value, name);
}

/// Provider-owned surah metadata.
///
/// Every string is stored verbatim. User aliases may be supplied through
/// [customDisplayName], but must not overwrite provider-owned names in storage.
final class Surah {
  factory Surah({
    required String id,
    required int number,
    required int ayahCount,
    String? arabicName,
    String? transliteratedName,
    String? localizedName,
    String? customDisplayName,
  }) {
    _requireNonEmpty(id, 'id');
    _requirePositive(number, 'number');
    _requirePositive(ayahCount, 'ayahCount');
    _requireNonEmptyOrNull(arabicName, 'arabicName');
    _requireNonEmptyOrNull(transliteratedName, 'transliteratedName');
    _requireNonEmptyOrNull(localizedName, 'localizedName');
    _requireNonEmptyOrNull(customDisplayName, 'customDisplayName');
    return Surah._(
      id: id,
      number: number,
      ayahCount: ayahCount,
      arabicName: arabicName,
      transliteratedName: transliteratedName,
      localizedName: localizedName,
      customDisplayName: customDisplayName,
    );
  }

  const Surah._({
    required this.id,
    required this.number,
    required this.ayahCount,
    required this.arabicName,
    required this.transliteratedName,
    required this.localizedName,
    required this.customDisplayName,
  });

  final String id;
  final int number;
  final String? arabicName;
  final String? transliteratedName;
  final String? localizedName;
  final String? customDisplayName;
  final int ayahCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Surah &&
          id == other.id &&
          number == other.number &&
          arabicName == other.arabicName &&
          transliteratedName == other.transliteratedName &&
          localizedName == other.localizedName &&
          customDisplayName == other.customDisplayName &&
          ayahCount == other.ayahCount;

  @override
  int get hashCode => Object.hash(
    id,
    number,
    arabicName,
    transliteratedName,
    localizedName,
    customDisplayName,
    ayahCount,
  );
}

/// One ayah as supplied by a verified source.
///
/// A translation-only provider leaves [arabicText] null explicitly. A
/// translation always carries its exact source and version.
final class Ayah {
  factory Ayah({
    required int surahNumber,
    required int ayahNumber,
    String? arabicText,
    String? fullTranslation,
    String? translationSource,
    String? translationVersion,
    String? translationFootnotes,
  }) {
    _requirePositive(surahNumber, 'surahNumber');
    _requirePositive(ayahNumber, 'ayahNumber');
    _requireNonEmptyOrNull(arabicText, 'arabicText');
    _requireNonEmptyOrNull(fullTranslation, 'fullTranslation');
    _requireNonEmptyOrNull(translationSource, 'translationSource');
    _requireNonEmptyOrNull(translationVersion, 'translationVersion');
    if (arabicText == null && fullTranslation == null) {
      throw ArgumentError(
        'An ayah must contain provider-supplied Arabic text or translation.',
      );
    }
    if (fullTranslation != null &&
        (translationSource == null || translationVersion == null)) {
      throw ArgumentError('A translation must include its source and version.');
    }
    return Ayah._(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      arabicText: arabicText,
      fullTranslation: fullTranslation,
      translationSource: translationSource,
      translationVersion: translationVersion,
      translationFootnotes: translationFootnotes,
    );
  }

  const Ayah._({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
    required this.fullTranslation,
    required this.translationSource,
    required this.translationVersion,
    required this.translationFootnotes,
  });

  final int surahNumber;
  final int ayahNumber;
  final String? arabicText;
  final String? fullTranslation;
  final String? translationSource;
  final String? translationVersion;
  final String? translationFootnotes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ayah &&
          surahNumber == other.surahNumber &&
          ayahNumber == other.ayahNumber &&
          arabicText == other.arabicText &&
          fullTranslation == other.fullTranslation &&
          translationSource == other.translationSource &&
          translationVersion == other.translationVersion &&
          translationFootnotes == other.translationFootnotes;

  @override
  int get hashCode => Object.hash(
    surahNumber,
    ayahNumber,
    arabicText,
    fullTranslation,
    translationSource,
    translationVersion,
    translationFootnotes,
  );
}

/// One provider-supplied word. Missing Arabic or translation stays null.
final class QuranWord {
  factory QuranWord({
    required int surahNumber,
    required int ayahNumber,
    required int position,
    String? arabicText,
    String? translation,
  }) {
    _requirePositive(surahNumber, 'surahNumber');
    _requirePositive(ayahNumber, 'ayahNumber');
    _requirePositive(position, 'position');
    _requireNonEmptyOrNull(arabicText, 'arabicText');
    _requireNonEmptyOrNull(translation, 'translation');
    if (arabicText == null && translation == null) {
      throw ArgumentError(
        'A Quran word must contain provider-supplied text or translation.',
      );
    }
    return QuranWord._(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      position: position,
      arabicText: arabicText,
      translation: translation,
    );
  }

  const QuranWord._({
    required this.surahNumber,
    required this.ayahNumber,
    required this.position,
    required this.arabicText,
    required this.translation,
  });

  final int surahNumber;
  final int ayahNumber;
  final int position;
  final String? arabicText;
  final String? translation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranWord &&
          surahNumber == other.surahNumber &&
          ayahNumber == other.ayahNumber &&
          position == other.position &&
          arabicText == other.arabicText &&
          translation == other.translation;

  @override
  int get hashCode =>
      Object.hash(surahNumber, ayahNumber, position, arabicText, translation);
}

/// Provenance attached to every cached content bundle.
final class QuranSourceMetadata {
  factory QuranSourceMetadata({
    required String source,
    required String version,
    required DateTime fetchedAtUtc,
    String? translationKey,
    String? language,
    String? attribution,
    String? licenseUsageInformation,
    Uri? sourceUri,
  }) {
    _requireNonEmpty(source, 'source');
    _requireNonEmpty(version, 'version');
    _requireNonEmptyOrNull(translationKey, 'translationKey');
    _requireNonEmptyOrNull(language, 'language');
    _requireNonEmptyOrNull(attribution, 'attribution');
    _requireNonEmptyOrNull(licenseUsageInformation, 'licenseUsageInformation');
    if (!fetchedAtUtc.isUtc) {
      throw ArgumentError.value(fetchedAtUtc, 'fetchedAtUtc', 'Must be UTC.');
    }
    return QuranSourceMetadata._(
      source: source,
      translationKey: translationKey,
      version: version,
      language: language,
      fetchedAtUtc: fetchedAtUtc,
      attribution: attribution,
      licenseUsageInformation: licenseUsageInformation,
      sourceUri: sourceUri,
    );
  }

  const QuranSourceMetadata._({
    required this.source,
    required this.translationKey,
    required this.version,
    required this.language,
    required this.fetchedAtUtc,
    required this.attribution,
    required this.licenseUsageInformation,
    required this.sourceUri,
  });

  final String source;
  final String? translationKey;
  final String version;
  final String? language;
  final DateTime fetchedAtUtc;
  final String? attribution;
  final String? licenseUsageInformation;
  final Uri? sourceUri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranSourceMetadata &&
          source == other.source &&
          translationKey == other.translationKey &&
          version == other.version &&
          language == other.language &&
          fetchedAtUtc == other.fetchedAtUtc &&
          attribution == other.attribution &&
          licenseUsageInformation == other.licenseUsageInformation &&
          sourceUri == other.sourceUri;

  @override
  int get hashCode => Object.hash(
    source,
    translationKey,
    version,
    language,
    fetchedAtUtc,
    attribution,
    licenseUsageInformation,
    sourceUri,
  );
}

/// A selectable provider translation. No translation key is hardcoded by the
/// application; the caller selects one returned by the provider catalog.
final class QuranTranslation {
  factory QuranTranslation({
    required String source,
    required String key,
    required String languageCode,
    required String version,
    required String title,
    String? description,
    String? direction,
    int? lastUpdateEpochSeconds,
  }) {
    _requireNonEmpty(source, 'source');
    _requireNonEmpty(key, 'key');
    _requireNonEmpty(languageCode, 'languageCode');
    _requireNonEmpty(version, 'version');
    _requireNonEmpty(title, 'title');
    _requireNonEmptyOrNull(description, 'description');
    _requireNonEmptyOrNull(direction, 'direction');
    if (lastUpdateEpochSeconds != null && lastUpdateEpochSeconds < 0) {
      throw ArgumentError.value(
        lastUpdateEpochSeconds,
        'lastUpdateEpochSeconds',
        'Must not be negative.',
      );
    }
    return QuranTranslation._(
      source: source,
      key: key,
      languageCode: languageCode,
      version: version,
      title: title,
      description: description,
      direction: direction,
      lastUpdateEpochSeconds: lastUpdateEpochSeconds,
    );
  }

  const QuranTranslation._({
    required this.source,
    required this.key,
    required this.languageCode,
    required this.version,
    required this.title,
    required this.description,
    required this.direction,
    required this.lastUpdateEpochSeconds,
  });

  final String source;
  final String key;
  final String languageCode;
  final String version;
  final String title;
  final String? description;
  final String? direction;
  final int? lastUpdateEpochSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranTranslation &&
          source == other.source &&
          key == other.key &&
          languageCode == other.languageCode &&
          version == other.version &&
          title == other.title &&
          description == other.description &&
          direction == other.direction &&
          lastUpdateEpochSeconds == other.lastUpdateEpochSeconds;

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
  );
}

/// Declares which kinds of data a returned bundle actually contains.
final class QuranContentCapabilities {
  const QuranContentCapabilities({
    required this.hasSurahMetadata,
    required this.hasArabicText,
    required this.hasFullTranslation,
    required this.hasWordTranslation,
  });

  final bool hasSurahMetadata;
  final bool hasArabicText;
  final bool hasFullTranslation;
  final bool hasWordTranslation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranContentCapabilities &&
          hasSurahMetadata == other.hasSurahMetadata &&
          hasArabicText == other.hasArabicText &&
          hasFullTranslation == other.hasFullTranslation &&
          hasWordTranslation == other.hasWordTranslation;

  @override
  int get hashCode => Object.hash(
    hasSurahMetadata,
    hasArabicText,
    hasFullTranslation,
    hasWordTranslation,
  );
}

/// Immutable, source-versioned content for one surah.
final class QuranSurahContent {
  factory QuranSurahContent({
    required int surahNumber,
    required QuranSourceMetadata sourceMetadata,
    required QuranContentCapabilities capabilities,
    required Iterable<Ayah> ayahs,
    Surah? surah,
    Iterable<QuranWord> words = const <QuranWord>[],
  }) {
    _requirePositive(surahNumber, 'surahNumber');
    if (surah != null && surah.number != surahNumber) {
      throw ArgumentError('Surah metadata does not match the content number.');
    }
    if (capabilities.hasSurahMetadata != (surah != null)) {
      throw ArgumentError(
        'Surah metadata availability must match declared capabilities.',
      );
    }

    final immutableAyahs = List<Ayah>.unmodifiable(ayahs);
    if (immutableAyahs.isEmpty) {
      throw ArgumentError.value(ayahs, 'ayahs', 'Must not be empty.');
    }
    final ayahNumbers = <int>{};
    for (final ayah in immutableAyahs) {
      if (ayah.surahNumber != surahNumber) {
        throw ArgumentError('Every ayah must belong to the requested surah.');
      }
      if (!ayahNumbers.add(ayah.ayahNumber)) {
        throw ArgumentError('Ayah numbers must be unique within a bundle.');
      }
      if (capabilities.hasArabicText != (ayah.arabicText != null)) {
        throw ArgumentError(
          'Arabic availability must match declared capabilities.',
        );
      }
      if (capabilities.hasFullTranslation != (ayah.fullTranslation != null)) {
        throw ArgumentError(
          'Translation availability must match declared capabilities.',
        );
      }
    }

    final immutableWords = List<QuranWord>.unmodifiable(words);
    if (!capabilities.hasWordTranslation && immutableWords.isNotEmpty) {
      throw ArgumentError(
        'Words cannot be supplied when word content is unavailable.',
      );
    }
    final wordCoordinates = <(int, int)>{};
    for (final word in immutableWords) {
      if (word.surahNumber != surahNumber) {
        throw ArgumentError('Every word must belong to the requested surah.');
      }
      if (!wordCoordinates.add((word.ayahNumber, word.position))) {
        throw ArgumentError('Word coordinates must be unique within a bundle.');
      }
    }

    return QuranSurahContent._(
      surahNumber: surahNumber,
      sourceMetadata: sourceMetadata,
      capabilities: capabilities,
      surah: surah,
      ayahs: immutableAyahs,
      words: immutableWords,
    );
  }

  const QuranSurahContent._({
    required this.surahNumber,
    required this.sourceMetadata,
    required this.capabilities,
    required this.surah,
    required this.ayahs,
    required this.words,
  });

  final int surahNumber;
  final QuranSourceMetadata sourceMetadata;
  final QuranContentCapabilities capabilities;
  final Surah? surah;
  final List<Ayah> ayahs;
  final List<QuranWord> words;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranSurahContent &&
          surahNumber == other.surahNumber &&
          sourceMetadata == other.sourceMetadata &&
          capabilities == other.capabilities &&
          surah == other.surah &&
          _sameList(ayahs, other.ayahs) &&
          _sameList(words, other.words);

  @override
  int get hashCode => Object.hash(
    surahNumber,
    sourceMetadata,
    capabilities,
    surah,
    Object.hashAll(ayahs),
    Object.hashAll(words),
  );
}
