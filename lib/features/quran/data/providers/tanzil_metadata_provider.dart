import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../../../../core/domain/surah.dart';

/// Safe structural failure while reading the verified Tanzil metadata asset.
final class TanzilMetadataException implements Exception {
  const TanzilMetadataException(this.code);

  final String code;

  @override
  String toString() => 'TanzilMetadataException($code)';
}

/// Verbatim names from one `<sura>` entry plus its domain descriptor.
final class TanzilSurahMetadata {
  const TanzilSurahMetadata({
    required this.descriptor,
    required this.arabicName,
    required this.transliteratedName,
    required this.englishName,
  });

  final SurahDescriptor descriptor;
  final String arabicName;
  final String transliteratedName;
  final String englishName;
}

/// Loads the verified, bundled Tanzil metadata catalog.
///
/// Attribute strings are accepted verbatim. The provider does not trim,
/// normalize, transliterate, translate, or infer any Quran metadata.
final class TanzilMetadataProvider {
  TanzilMetadataProvider({
    AssetBundle? assetBundle,
    this.assetPath = defaultAssetPath,
  }) : _assetBundle = assetBundle ?? rootBundle;

  static const String defaultAssetPath = 'assets/quran/quran-data.xml';
  static const String sourceId = 'tanzil.info';
  static const String version = '1.0';
  static const String attribution = 'Tanzil.info';
  static const String license = 'cc-by';
  static const String copyright = '(C) 2008-2009 Tanzil.info';
  static const String expectedSha256 =
      '8867C1D88191472ADEC9DB694B3CD9F135B1A2EF580574D32CF888DCB22C5C7A';
  static const int expectedSurahCount = 114;

  final AssetBundle _assetBundle;
  final String assetPath;

  Future<List<SurahDescriptor>> loadSurahs() async {
    final metadata = await loadMetadata();
    return List<SurahDescriptor>.unmodifiable(
      metadata.map((item) => item.descriptor),
    );
  }

  Future<List<TanzilSurahMetadata>> loadMetadata() async {
    final xml = await _assetBundle.loadString(assetPath, cache: false);
    return parseMetadataXml(xml);
  }

  List<SurahDescriptor> parseSurahsXml(String xml) =>
      List<SurahDescriptor>.unmodifiable(
        parseMetadataXml(xml).map((item) => item.descriptor),
      );

  List<TanzilSurahMetadata> parseMetadataXml(String xml) {
    late final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlParserException {
      throw const TanzilMetadataException('tanzil_xml_invalid');
    }

    final root = document.rootElement;
    if (root.name.local != 'quran' ||
        root.getAttribute('type') != 'metadata' ||
        root.getAttribute('version') != version ||
        root.getAttribute('copyright') != copyright ||
        root.getAttribute('license') != license) {
      throw const TanzilMetadataException('tanzil_header_invalid');
    }

    final surasContainers = root.findElements('suras').toList(growable: false);
    if (surasContainers.length != 1) {
      throw const TanzilMetadataException('tanzil_suras_container_invalid');
    }
    final elements = surasContainers.single
        .findElements('sura')
        .toList(growable: false);
    if (elements.length != expectedSurahCount) {
      throw const TanzilMetadataException('tanzil_surah_count_invalid');
    }

    final result = <TanzilSurahMetadata>[];
    final seenIndexes = <int>{};
    for (var position = 0; position < elements.length; position += 1) {
      final element = elements[position];
      final index = _positiveIntegerAttribute(element, 'index');
      final ayahCount = _positiveIntegerAttribute(element, 'ayas');
      final expectedIndex = position + 1;
      if (index != expectedIndex || !seenIndexes.add(index)) {
        throw const TanzilMetadataException('tanzil_surah_index_invalid');
      }

      final arabicName = _requiredAttribute(element, 'name');
      final transliteratedName = _requiredAttribute(element, 'tname');
      final englishName = _requiredAttribute(element, 'ename');
      result.add(
        TanzilSurahMetadata(
          descriptor: SurahDescriptor(
            id: 'surah-$index',
            surahNumber: index,
            officialName: transliteratedName,
            ayahCount: ayahCount,
          ),
          arabicName: arabicName,
          transliteratedName: transliteratedName,
          englishName: englishName,
        ),
      );
    }
    return List<TanzilSurahMetadata>.unmodifiable(result);
  }

  int _positiveIntegerAttribute(XmlElement element, String name) {
    final raw = _requiredAttribute(element, name);
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0 || parsed.toString() != raw) {
      throw TanzilMetadataException('tanzil_${name}_invalid');
    }
    return parsed;
  }

  String _requiredAttribute(XmlElement element, String name) {
    final value = element.getAttribute(name);
    if (value == null || value.isEmpty) {
      throw TanzilMetadataException('tanzil_${name}_missing');
    }
    return value;
  }
}
