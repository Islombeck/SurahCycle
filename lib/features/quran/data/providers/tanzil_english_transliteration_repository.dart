import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/surah.dart';
import '../../domain/quran_transliteration.dart';
import '../quran_transliteration_repository.dart';
import 'tanzil_metadata_provider.dart';

final class TanzilTransliterationException implements Exception {
  const TanzilTransliterationException(this.code);

  final String code;

  @override
  String toString() => 'TanzilTransliterationException($code)';
}

/// Strict parser for Tanzil's exact `en.transliteration` txt-2 download.
final class TanzilEnglishTransliterationParser {
  const TanzilEnglishTransliterationParser({
    required this.expectedByteLength,
    required this.expectedSha256,
    required this.source,
  });

  static const String _footerMarker =
      '# --------------------------------------------------------------------';
  static const String _nameMarker = '#  Name: Transliteration';
  static const String _translatorMarker =
      '#  Translator: English Transliteration';
  static const String _languageMarker = '#  Language: English';
  static const String _idMarker = '#  ID: en.transliteration';
  static const String _lastUpdateMarker = '#  Last Update: September 6, 2010';
  static const String _sourceMarker = '#  Source: Tanzil.net';

  final int expectedByteLength;
  final String expectedSha256;
  final QuranTransliterationSource source;

  QuranTransliterationCorpus parse(
    Uint8List bytes,
    List<SurahDescriptor> metadata,
  ) {
    if (bytes.length != expectedByteLength) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_byte_length_invalid',
      );
    }
    final actualSha256 = sha256.convert(bytes).toString();
    if (actualSha256.toLowerCase() != expectedSha256.toLowerCase()) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_sha256_invalid',
      );
    }
    if (metadata.length !=
        TanzilEnglishTransliterationRepository.expectedSurahCount) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_metadata_count_invalid',
      );
    }

    late final String decoded;
    try {
      decoded = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_utf8_invalid',
      );
    }
    if (decoded.contains('\r')) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_line_endings_invalid',
      );
    }

    // The official txt-2 file has two blank lines between its 6,236 exact
    // coordinate rows and the embedded source metadata. Never trim the file.
    final separator = decoded.indexOf('\n\n\n$_footerMarker');
    if (separator <= 0) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_footer_missing',
      );
    }
    final footer = decoded.substring(separator + 3);
    if (!footer.startsWith(_footerMarker) ||
        !footer.contains(_nameMarker) ||
        !footer.contains(_translatorMarker) ||
        !footer.contains(_languageMarker) ||
        !footer.contains(_idMarker) ||
        !footer.contains(_lastUpdateMarker) ||
        !footer.contains(_sourceMarker) ||
        !footer.endsWith('\n')) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_footer_invalid',
      );
    }

    final coordinateLines = decoded.substring(0, separator).split('\n');
    final result = <List<QuranTransliterationAyah>>[];
    var lineIndex = 0;
    var totalAyahCount = 0;
    for (var position = 0; position < metadata.length; position += 1) {
      final descriptor = metadata[position];
      final expectedSurahNumber = position + 1;
      if (descriptor.surahNumber != expectedSurahNumber ||
          descriptor.ayahCount <= 0) {
        throw const TanzilTransliterationException(
          'tanzil_transliteration_metadata_invalid',
        );
      }
      final surah = <QuranTransliterationAyah>[];
      for (
        var expectedAyahNumber = 1;
        expectedAyahNumber <= descriptor.ayahCount;
        expectedAyahNumber += 1
      ) {
        if (lineIndex >= coordinateLines.length) {
          throw const TanzilTransliterationException(
            'tanzil_transliteration_ayah_missing',
          );
        }
        final parsed = _parseLine(coordinateLines[lineIndex]);
        if (parsed.surahNumber != expectedSurahNumber ||
            parsed.ayahNumber != expectedAyahNumber) {
          throw const TanzilTransliterationException(
            'tanzil_transliteration_coordinate_invalid',
          );
        }
        surah.add(parsed);
        lineIndex += 1;
        totalAyahCount += 1;
      }
      result.add(List<QuranTransliterationAyah>.unmodifiable(surah));
    }

    if (lineIndex != coordinateLines.length) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_extra_ayah',
      );
    }
    if (totalAyahCount !=
        TanzilEnglishTransliterationRepository.expectedAyahCount) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_ayah_count_invalid',
      );
    }
    return QuranTransliterationCorpus(
      surahs: result,
      source: source,
      sha256: actualSha256,
    );
  }

  QuranTransliterationAyah _parseLine(String line) {
    final firstSeparator = line.indexOf('|');
    final secondSeparator = firstSeparator < 0
        ? -1
        : line.indexOf('|', firstSeparator + 1);
    if (firstSeparator <= 0 || secondSeparator <= firstSeparator + 1) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_line_invalid',
      );
    }
    final rawSurahNumber = line.substring(0, firstSeparator);
    final rawAyahNumber = line.substring(firstSeparator + 1, secondSeparator);
    final surahNumber = int.tryParse(rawSurahNumber);
    final ayahNumber = int.tryParse(rawAyahNumber);
    final exactText = line.substring(secondSeparator + 1);
    if (surahNumber == null ||
        ayahNumber == null ||
        surahNumber.toString() != rawSurahNumber ||
        ayahNumber.toString() != rawAyahNumber ||
        surahNumber <= 0 ||
        ayahNumber <= 0 ||
        exactText.isEmpty) {
      throw const TanzilTransliterationException(
        'tanzil_transliteration_line_invalid',
      );
    }
    return QuranTransliterationAyah(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      exactText: exactText,
      source: source,
    );
  }
}

/// Offline-only adapter for the pinned Tanzil English Transliteration file.
///
/// Tanzil permits this translations dataset only for non-commercial use.
/// Commercial/production redistribution is a release blocker until permission
/// is obtained from the relevant rights holder.
final class TanzilEnglishTransliterationRepository
    implements QuranTransliterationRepository {
  TanzilEnglishTransliterationRepository({
    AssetBundle? assetBundle,
    TanzilMetadataProvider? metadataProvider,
    this.assetPath = defaultAssetPath,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _metadataProvider =
           metadataProvider ?? TanzilMetadataProvider(assetBundle: assetBundle);

  static const String defaultAssetPath =
      'assets/quran/quran-transliteration-en.txt';
  static const String licenseAssetPath =
      'assets/quran/TANZIL_TRANSLITERATION_LICENSE.txt';
  static const String sourceId = 'tanzil.net';
  static const String datasetId = 'en.transliteration';
  static const String footerLastUpdate = '2010-09-06';
  static const String changeLogLastChange = '2010-09-14';
  static const String sourceUrl =
      'https://tanzil.net/trans/en.transliteration?type=txt-2';
  static const String termsUrl = 'https://tanzil.net/trans/';
  static const String changeLogUrl =
      'https://tanzil.net/trans/log/en.transliteration';
  static const String expectedSha256 =
      '8c20d95e484534e921cd2e0d2546aab7f5300090c0bd76697095b3ca1db1e01d';
  static const int expectedByteLength = 1044894;
  static const int expectedSurahCount = 114;
  static const int expectedAyahCount = 6236;
  static const bool commercialRedistributionCleared = false;
  static const String version =
      'tanzil-en.transliteration-2010-09-06-sha256-$expectedSha256';
  static const String attribution =
      'English Transliteration — source: Tanzil.net';
  static const String licenseUsageInformation =
      'Non-commercial use only. Commercial or other use requires permission '
      'from the translator or publisher. The separate Tanzil Quran Text '
      'CC BY 3.0 license does not cover this translations dataset. Terms: '
      '$termsUrl';

  static final QuranTransliterationSource source = QuranTransliterationSource(
    source: sourceId,
    datasetId: datasetId,
    version: version,
    attribution: attribution,
    licenseUsageInformation: licenseUsageInformation,
    provenanceUri: Uri.parse(sourceUrl),
  );

  static final TanzilEnglishTransliterationParser _parser =
      TanzilEnglishTransliterationParser(
        expectedByteLength: expectedByteLength,
        expectedSha256: expectedSha256,
        source: source,
      );

  final AssetBundle _assetBundle;
  final TanzilMetadataProvider _metadataProvider;
  final String assetPath;
  Future<QuranTransliterationCorpus>? _loaded;

  @override
  Future<QuranTransliterationCorpus> load() {
    final cached = _loaded;
    if (cached != null) return cached;
    final pending = _load();
    _loaded = pending;
    return pending.then(
      (corpus) => corpus,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_loaded, pending)) _loaded = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  @override
  Future<QuranTransliterationAyah> getAyah({
    required int surahNumber,
    required int ayahNumber,
  }) async =>
      (await load()).ayah(surahNumber: surahNumber, ayahNumber: ayahNumber);

  @override
  Future<List<QuranTransliterationAyah>> getSurah(int surahNumber) async =>
      (await load()).surah(surahNumber);

  @override
  Future<List<QuranTransliterationAyah>> getRange({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async => (await load()).range(
    surahNumber: surahNumber,
    startAyah: startAyah,
    endAyah: endAyah,
  );

  Future<QuranTransliterationCorpus> _load() async {
    final byteData = await _assetBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final metadata = await _metadataProvider.loadSurahs();
    return _parser.parse(bytes, metadata);
  }
}
