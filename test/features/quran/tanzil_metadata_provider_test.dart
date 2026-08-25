import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TanzilMetadataProvider', () {
    test(
      'loads exactly 114 validated descriptors from the bundled asset',
      () async {
        final provider = TanzilMetadataProvider();

        final metadata = await provider.loadMetadata();
        final descriptors = await provider.loadSurahs();

        expect(metadata, hasLength(TanzilMetadataProvider.expectedSurahCount));
        expect(
          descriptors,
          hasLength(TanzilMetadataProvider.expectedSurahCount),
        );
        for (var index = 0; index < metadata.length; index += 1) {
          final item = metadata[index];
          expect(item.descriptor.surahNumber, index + 1);
          expect(item.descriptor.ayahCount, greaterThan(0));
          expect(item.descriptor.officialName, item.transliteratedName);
          expect(item.arabicName, isNotEmpty);
          expect(item.transliteratedName, isNotEmpty);
          expect(item.englishName, isNotEmpty);
          expect(descriptors[index], item.descriptor);
        }
        expect(
          () => descriptors.add(descriptors.first),
          throwsUnsupportedError,
        );
      },
    );

    test('source constants match the verified XML header verbatim', () async {
      final xml = await rootBundle.loadString(
        TanzilMetadataProvider.defaultAssetPath,
        cache: false,
      );
      final root = XmlDocument.parse(xml).rootElement;

      expect(root.getAttribute('version'), TanzilMetadataProvider.version);
      expect(root.getAttribute('copyright'), TanzilMetadataProvider.copyright);
      expect(root.getAttribute('license'), TanzilMetadataProvider.license);
      expect(TanzilMetadataProvider.sourceId, 'tanzil.info');
      expect(TanzilMetadataProvider.attribution, 'Tanzil.info');
    });

    test('rejects a catalog with a tampered surah count', () async {
      final provider = TanzilMetadataProvider();
      final original = await rootBundle.loadString(
        TanzilMetadataProvider.defaultAssetPath,
        cache: false,
      );
      final tampered = original.replaceFirst(
        RegExp(r'\s*<sura index="114"[^>]*/>'),
        '',
      );
      expect(tampered, isNot(original));

      expect(
        () => provider.parseMetadataXml(tampered),
        throwsA(
          isA<TanzilMetadataException>().having(
            (error) => error.code,
            'code',
            'tanzil_surah_count_invalid',
          ),
        ),
      );
    });

    test('rejects a non-positive ayah count', () async {
      final provider = TanzilMetadataProvider();
      final original = await rootBundle.loadString(
        TanzilMetadataProvider.defaultAssetPath,
        cache: false,
      );
      final tampered = original.replaceFirst(RegExp(r'ayas="\d+"'), 'ayas="0"');
      expect(tampered, isNot(original));

      expect(
        () => provider.parseMetadataXml(tampered),
        throwsA(
          isA<TanzilMetadataException>().having(
            (error) => error.code,
            'code',
            'tanzil_ayas_invalid',
          ),
        ),
      );
    });

    test('rejects duplicated or reordered surah indexes', () async {
      final provider = TanzilMetadataProvider();
      final original = await rootBundle.loadString(
        TanzilMetadataProvider.defaultAssetPath,
        cache: false,
      );
      final tampered = original.replaceFirst('index="2"', 'index="1"');

      expect(
        () => provider.parseMetadataXml(tampered),
        throwsA(
          isA<TanzilMetadataException>().having(
            (error) => error.code,
            'code',
            'tanzil_surah_index_invalid',
          ),
        ),
      );
    });
  });
}
