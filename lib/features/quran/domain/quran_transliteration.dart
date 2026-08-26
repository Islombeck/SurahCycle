/// Exact provenance for a Quran transliteration dataset.
final class QuranTransliterationSource {
  factory QuranTransliterationSource({
    required String source,
    required String datasetId,
    required String version,
    required String attribution,
    required String licenseUsageInformation,
    required Uri provenanceUri,
  }) {
    for (final value in <String>[
      source,
      datasetId,
      version,
      attribution,
      licenseUsageInformation,
    ]) {
      if (value.isEmpty) {
        throw ArgumentError('Transliteration provenance must not be empty.');
      }
    }
    if (provenanceUri.scheme != 'https' || !provenanceUri.hasAuthority) {
      throw ArgumentError.value(
        provenanceUri,
        'provenanceUri',
        'Must be an absolute HTTPS URI.',
      );
    }
    return QuranTransliterationSource._(
      source: source,
      datasetId: datasetId,
      version: version,
      attribution: attribution,
      licenseUsageInformation: licenseUsageInformation,
      provenanceUri: provenanceUri,
    );
  }

  const QuranTransliterationSource._({
    required this.source,
    required this.datasetId,
    required this.version,
    required this.attribution,
    required this.licenseUsageInformation,
    required this.provenanceUri,
  });

  final String source;
  final String datasetId;
  final String version;
  final String attribution;
  final String licenseUsageInformation;
  final Uri provenanceUri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranTransliterationSource &&
          source == other.source &&
          datasetId == other.datasetId &&
          version == other.version &&
          attribution == other.attribution &&
          licenseUsageInformation == other.licenseUsageInformation &&
          provenanceUri == other.provenanceUri;

  @override
  int get hashCode => Object.hash(
    source,
    datasetId,
    version,
    attribution,
    licenseUsageInformation,
    provenanceUri,
  );
}

/// One provider-owned transliteration string, preserved verbatim.
final class QuranTransliterationAyah {
  factory QuranTransliterationAyah({
    required int surahNumber,
    required int ayahNumber,
    required String exactText,
    required QuranTransliterationSource source,
  }) {
    if (surahNumber <= 0 || ayahNumber <= 0) {
      throw ArgumentError('Quran coordinates must be positive.');
    }
    if (exactText.isEmpty) {
      throw ArgumentError.value(exactText, 'exactText', 'Must not be empty.');
    }
    return QuranTransliterationAyah._(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      exactText: exactText,
      source: source,
    );
  }

  const QuranTransliterationAyah._({
    required this.surahNumber,
    required this.ayahNumber,
    required this.exactText,
    required this.source,
  });

  final int surahNumber;
  final int ayahNumber;
  final String exactText;
  final QuranTransliterationSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranTransliterationAyah &&
          surahNumber == other.surahNumber &&
          ayahNumber == other.ayahNumber &&
          exactText == other.exactText &&
          source == other.source;

  @override
  int get hashCode => Object.hash(surahNumber, ayahNumber, exactText, source);
}

/// Fully validated and immutable transliteration corpus.
final class QuranTransliterationCorpus {
  QuranTransliterationCorpus({
    required Iterable<Iterable<QuranTransliterationAyah>> surahs,
    required this.source,
    required this.sha256,
  }) : _surahs = List<List<QuranTransliterationAyah>>.unmodifiable(
         surahs.map(List<QuranTransliterationAyah>.unmodifiable),
       ) {
    if (_surahs.isEmpty || sha256.isEmpty) {
      throw ArgumentError('A transliteration corpus must not be empty.');
    }
    for (var surahIndex = 0; surahIndex < _surahs.length; surahIndex += 1) {
      final surah = _surahs[surahIndex];
      if (surah.isEmpty) {
        throw ArgumentError('A transliteration surah must not be empty.');
      }
      for (var ayahIndex = 0; ayahIndex < surah.length; ayahIndex += 1) {
        final ayah = surah[ayahIndex];
        if (ayah.surahNumber != surahIndex + 1 ||
            ayah.ayahNumber != ayahIndex + 1 ||
            ayah.source != source) {
          throw ArgumentError(
            'Transliteration coordinates or provenance are inconsistent.',
          );
        }
      }
    }
  }

  final List<List<QuranTransliterationAyah>> _surahs;
  final QuranTransliterationSource source;
  final String sha256;

  int get surahCount => _surahs.length;

  int get ayahCount =>
      _surahs.fold<int>(0, (total, surah) => total + surah.length);

  Iterable<QuranTransliterationAyah> get ayahs sync* {
    for (final surah in _surahs) {
      yield* surah;
    }
  }

  int surahAyahCount(int surahNumber) => _surah(surahNumber).length;

  QuranTransliterationAyah ayah({
    required int surahNumber,
    required int ayahNumber,
  }) {
    final surah = _surah(surahNumber);
    if (ayahNumber < 1 || ayahNumber > surah.length) {
      throw RangeError.range(ayahNumber, 1, surah.length, 'ayahNumber');
    }
    return surah[ayahNumber - 1];
  }

  List<QuranTransliterationAyah> surah(int surahNumber) =>
      List<QuranTransliterationAyah>.unmodifiable(_surah(surahNumber));

  List<QuranTransliterationAyah> range({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) {
    final surah = _surah(surahNumber);
    if (startAyah < 1 || startAyah > surah.length) {
      throw RangeError.range(startAyah, 1, surah.length, 'startAyah');
    }
    if (endAyah < startAyah || endAyah > surah.length) {
      throw RangeError.range(endAyah, startAyah, surah.length, 'endAyah');
    }
    return List<QuranTransliterationAyah>.unmodifiable(
      surah.sublist(startAyah - 1, endAyah),
    );
  }

  List<QuranTransliterationAyah> _surah(int surahNumber) {
    if (surahNumber < 1 || surahNumber > _surahs.length) {
      throw RangeError.range(surahNumber, 1, _surahs.length, 'surahNumber');
    }
    return _surahs[surahNumber - 1];
  }
}
