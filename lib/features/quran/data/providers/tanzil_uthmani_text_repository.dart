import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/surah.dart';
import 'tanzil_metadata_provider.dart';

final class TanzilTextException implements Exception {
  const TanzilTextException(this.code);

  final String code;

  @override
  String toString() => 'TanzilTextException($code)';
}

/// One coordinate from the pinned Tanzil download.
///
/// [arabicText] is the exact value after the second `|` delimiter. It is never
/// trimmed, normalized, concatenated, or otherwise rewritten.
final class TanzilUthmaniAyah {
  const TanzilUthmaniAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
  });

  final int surahNumber;
  final int ayahNumber;
  final String arabicText;
}

/// Fully validated, immutable in-memory index of the bundled Uthmani text.
final class TanzilUthmaniCorpus {
  TanzilUthmaniCorpus._(this._surahs, this.sha256);

  final List<List<TanzilUthmaniAyah>> _surahs;
  final String sha256;

  int get surahCount => _surahs.length;

  int get ayahCount =>
      _surahs.fold<int>(0, (total, surah) => total + surah.length);

  int surahAyahCount(int surahNumber) {
    if (surahNumber < 1 || surahNumber > _surahs.length) {
      throw RangeError.range(surahNumber, 1, _surahs.length, 'surahNumber');
    }
    return _surahs[surahNumber - 1].length;
  }

  Iterable<TanzilUthmaniAyah> get ayahs sync* {
    for (final surah in _surahs) {
      yield* surah;
    }
  }

  TanzilUthmaniAyah ayah({required int surahNumber, required int ayahNumber}) {
    if (surahNumber < 1 || surahNumber > _surahs.length) {
      throw RangeError.range(surahNumber, 1, _surahs.length, 'surahNumber');
    }
    final surah = _surahs[surahNumber - 1];
    if (ayahNumber < 1 || ayahNumber > surah.length) {
      throw RangeError.range(ayahNumber, 1, surah.length, 'ayahNumber');
    }
    return surah[ayahNumber - 1];
  }

  List<TanzilUthmaniAyah> range({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) {
    if (surahNumber < 1 || surahNumber > _surahs.length) {
      throw RangeError.range(surahNumber, 1, _surahs.length, 'surahNumber');
    }
    final surah = _surahs[surahNumber - 1];
    if (startAyah < 1 || startAyah > surah.length) {
      throw RangeError.range(startAyah, 1, surah.length, 'startAyah');
    }
    if (endAyah < startAyah || endAyah > surah.length) {
      throw RangeError.range(endAyah, startAyah, surah.length, 'endAyah');
    }
    return List<TanzilUthmaniAyah>.unmodifiable(
      surah.sublist(startAyah - 1, endAyah),
    );
  }
}

/// Strict parser used by the asset repository and by the import validation
/// tests. A caller must provide a pinned byte length and SHA-256 digest.
final class TanzilUthmaniTextParser {
  const TanzilUthmaniTextParser({
    required this.expectedByteLength,
    required this.expectedSha256,
  });

  static const String _footerMarker =
      '# PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK';
  static const String _versionMarker =
      'Tanzil Quran Text (Uthmani, Version 1.1)';
  static const String _licenseMarker =
      'License: Creative Commons Attribution 3.0';

  final int expectedByteLength;
  final String expectedSha256;

  TanzilUthmaniCorpus parse(Uint8List bytes, List<SurahDescriptor> metadata) {
    if (bytes.length != expectedByteLength) {
      throw const TanzilTextException('tanzil_text_byte_length_invalid');
    }
    final actualSha256 = sha256.convert(bytes).toString();
    if (actualSha256.toLowerCase() != expectedSha256.toLowerCase()) {
      throw const TanzilTextException('tanzil_text_sha256_invalid');
    }
    if (metadata.length != TanzilUthmaniTextRepository.expectedSurahCount) {
      throw const TanzilTextException('tanzil_text_metadata_count_invalid');
    }

    late final String decoded;
    try {
      decoded = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const TanzilTextException('tanzil_text_utf8_invalid');
    }

    // The official txt-2 export separates the 6,236 coordinate lines from
    // its mandatory copyright block with exactly two blank lines. Do not use
    // trim here: it could alter the final ayah or accidentally accept a
    // rewritten export.
    final separator = decoded.indexOf('\n\n\n$_footerMarker');
    if (separator <= 0) {
      throw const TanzilTextException('tanzil_text_footer_missing');
    }
    final footer = decoded.substring(separator + 3);
    if (!footer.startsWith(_footerMarker) ||
        !footer.contains(_versionMarker) ||
        !footer.contains(_licenseMarker)) {
      throw const TanzilTextException('tanzil_text_footer_invalid');
    }

    final coordinateLines = decoded.substring(0, separator).split('\n');
    final result = <List<TanzilUthmaniAyah>>[];
    var lineIndex = 0;
    var totalAyahCount = 0;

    for (var position = 0; position < metadata.length; position += 1) {
      final descriptor = metadata[position];
      final expectedSurahNumber = position + 1;
      if (descriptor.surahNumber != expectedSurahNumber ||
          descriptor.ayahCount <= 0) {
        throw const TanzilTextException('tanzil_text_metadata_invalid');
      }

      final surah = <TanzilUthmaniAyah>[];
      for (
        var expectedAyahNumber = 1;
        expectedAyahNumber <= descriptor.ayahCount;
        expectedAyahNumber += 1
      ) {
        if (lineIndex >= coordinateLines.length) {
          throw const TanzilTextException('tanzil_text_ayah_missing');
        }
        final parsed = _parseLine(coordinateLines[lineIndex]);
        if (parsed.surahNumber != expectedSurahNumber ||
            parsed.ayahNumber != expectedAyahNumber) {
          throw const TanzilTextException('tanzil_text_coordinate_invalid');
        }
        surah.add(parsed);
        lineIndex += 1;
        totalAyahCount += 1;
      }
      result.add(List<TanzilUthmaniAyah>.unmodifiable(surah));
    }

    if (lineIndex != coordinateLines.length) {
      throw const TanzilTextException('tanzil_text_extra_ayah');
    }
    if (totalAyahCount != TanzilUthmaniTextRepository.expectedAyahCount) {
      throw const TanzilTextException('tanzil_text_ayah_count_invalid');
    }

    return TanzilUthmaniCorpus._(
      List<List<TanzilUthmaniAyah>>.unmodifiable(result),
      actualSha256,
    );
  }

  TanzilUthmaniAyah _parseLine(String line) {
    final firstSeparator = line.indexOf('|');
    final secondSeparator = firstSeparator < 0
        ? -1
        : line.indexOf('|', firstSeparator + 1);
    if (firstSeparator <= 0 || secondSeparator <= firstSeparator + 1) {
      throw const TanzilTextException('tanzil_text_line_invalid');
    }

    final rawSurahNumber = line.substring(0, firstSeparator);
    final rawAyahNumber = line.substring(firstSeparator + 1, secondSeparator);
    final surahNumber = int.tryParse(rawSurahNumber);
    final ayahNumber = int.tryParse(rawAyahNumber);
    final arabicText = line.substring(secondSeparator + 1);
    if (surahNumber == null ||
        ayahNumber == null ||
        surahNumber.toString() != rawSurahNumber ||
        ayahNumber.toString() != rawAyahNumber ||
        surahNumber <= 0 ||
        ayahNumber <= 0 ||
        arabicText.isEmpty) {
      throw const TanzilTextException('tanzil_text_line_invalid');
    }

    return TanzilUthmaniAyah(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      arabicText: arabicText,
    );
  }
}

/// Offline-only repository for the exact Tanzil Uthmani 1.1 download bundled
/// with the application. It performs no network access.
final class TanzilUthmaniTextRepository {
  TanzilUthmaniTextRepository({
    AssetBundle? assetBundle,
    TanzilMetadataProvider? metadataProvider,
    this.assetPath = defaultAssetPath,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _metadataProvider =
           metadataProvider ?? TanzilMetadataProvider(assetBundle: assetBundle);

  static const String defaultAssetPath = 'assets/quran/quran-uthmani.txt';
  static const String licenseAssetPath = 'assets/quran/TANZIL_TEXT_LICENSE.txt';
  static const String sourceId = 'tanzil.net';
  static const String textType = 'uthmani';
  static const String version = '1.1';
  static const String attribution = 'Tanzil Project';
  static const String license = 'Creative Commons Attribution 3.0';
  static const String sourceUrl =
      'https://tanzil.net/pub/download/index.php?'
      'quranType=uthmani&outType=txt-2&marks=true&'
      'sajdah=true&tatweel=true&agree=true';
  static const String expectedSha256 =
      '6933e133dd56db778c801bf738848454e43648105a151e8d84d86a7cae39ec5f';
  static const int expectedByteLength = 1396087;
  static const int expectedSurahCount = 114;
  static const int expectedAyahCount = 6236;

  static const TanzilUthmaniTextParser _parser = TanzilUthmaniTextParser(
    expectedByteLength: expectedByteLength,
    expectedSha256: expectedSha256,
  );

  final AssetBundle _assetBundle;
  final TanzilMetadataProvider _metadataProvider;
  final String assetPath;
  Future<TanzilUthmaniCorpus>? _loaded;

  Future<TanzilUthmaniCorpus> load() {
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

  Future<TanzilUthmaniAyah> getAyah({
    required int surahNumber,
    required int ayahNumber,
  }) async =>
      (await load()).ayah(surahNumber: surahNumber, ayahNumber: ayahNumber);

  Future<int> getSurahAyahCount(int surahNumber) async =>
      (await load()).surahAyahCount(surahNumber);

  Future<List<TanzilUthmaniAyah>> getRange({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async => (await load()).range(
    surahNumber: surahNumber,
    startAyah: startAyah,
    endAyah: endAyah,
  );

  Future<TanzilUthmaniCorpus> _load() async {
    final byteData = await _assetBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final metadata = await _metadataProvider.loadSurahs();
    return _parser.parse(bytes, metadata);
  }
}
