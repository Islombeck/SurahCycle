import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TanzilEnglishTransliterationRepository', () {
    test('loads the complete pinned offline corpus', () async {
      final corpus = await TanzilEnglishTransliterationRepository().load();
      final metadata = await TanzilMetadataProvider().loadSurahs();

      expect(
        corpus.sha256,
        TanzilEnglishTransliterationRepository.expectedSha256,
      );
      expect(
        corpus.surahCount,
        TanzilEnglishTransliterationRepository.expectedSurahCount,
      );
      expect(
        corpus.ayahCount,
        TanzilEnglishTransliterationRepository.expectedAyahCount,
      );
      expect(corpus.source.datasetId, 'en.transliteration');
      expect(
        corpus.source.version,
        TanzilEnglishTransliterationRepository.version,
      );
      expect(corpus.source.licenseUsageInformation, contains('Non-commercial'));
      expect(
        TanzilEnglishTransliterationRepository.commercialRedistributionCleared,
        isFalse,
      );
      for (final descriptor in metadata) {
        expect(
          corpus.surahAyahCount(descriptor.surahNumber),
          descriptor.ayahCount,
        );
      }
    });

    test(
      'bundles attribution and the non-commercial release blocker',
      () async {
        final notice = await rootBundle.loadString(
          TanzilEnglishTransliterationRepository.licenseAssetPath,
          cache: false,
        );

        expect(notice, contains('English Transliteration'));
        expect(
          notice,
          contains(TanzilEnglishTransliterationRepository.sourceUrl),
        );
        expect(
          notice,
          contains(TanzilEnglishTransliterationRepository.expectedSha256),
        );
        expect(notice, contains('non-commercial'));
        expect(notice, contains('production release is\nblocked'));
      },
    );

    test('preserves every exact coordinate string and source markup', () async {
      final raw = await rootBundle.loadString(
        TanzilEnglishTransliterationRepository.defaultAssetPath,
        cache: false,
      );
      final separator = raw.indexOf(
        '\n\n\n# --------------------------------------------------------------------',
      );
      expect(separator, greaterThan(0));
      final expectedCoordinates = raw.substring(0, separator);
      final corpus = await TanzilEnglishTransliterationRepository().load();

      final reconstructed = corpus.ayahs
          .map(
            (ayah) =>
                '${ayah.surahNumber}|${ayah.ayahNumber}|${ayah.exactText}',
          )
          .join('\n');

      expect(reconstructed, expectedCoordinates);
      expect(
        corpus.ayah(surahNumber: 1, ayahNumber: 1).exactText,
        contains('<u>'),
      );
      expect(
        corpus.ayah(surahNumber: 114, ayahNumber: 1).exactText,
        contains('</U>'),
      );
    });

    test('accepts only the audited presentation tag vocabulary', () async {
      final corpus = await TanzilEnglishTransliterationRepository().load();
      final anyTag = RegExp(r'<(/?)([^>]+)>');
      final names = <String>{};
      for (final ayah in corpus.ayahs) {
        for (final match in anyTag.allMatches(ayah.exactText)) {
          names.add(match.group(2)!.toLowerCase());
        }
      }

      expect(names, unorderedEquals(<String>['u', 'b', 'i', 'strong']));
    });

    test('rejects a byte-level change before parsing', () async {
      final data = await rootBundle.load(
        TanzilEnglishTransliterationRepository.defaultAssetPath,
      );
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      bytes[100] ^= 1;
      final metadata = await TanzilMetadataProvider().loadSurahs();

      expect(
        () => TanzilEnglishTransliterationParser(
          expectedByteLength:
              TanzilEnglishTransliterationRepository.expectedByteLength,
          expectedSha256: TanzilEnglishTransliterationRepository.expectedSha256,
          source: TanzilEnglishTransliterationRepository.source,
        ).parse(bytes, metadata),
        throwsA(
          isA<TanzilTransliterationException>().having(
            (error) => error.code,
            'code',
            'tanzil_transliteration_sha256_invalid',
          ),
        ),
      );
    });

    test(
      'rejects reordered coordinates even under a matching test pin',
      () async {
        final raw = await rootBundle.loadString(
          TanzilEnglishTransliterationRepository.defaultAssetPath,
          cache: false,
        );
        final tampered = raw.replaceFirst('\n1|2|', '\n1|1|');
        expect(tampered, isNot(raw));
        final bytes = Uint8List.fromList(utf8.encode(tampered));
        final metadata = await TanzilMetadataProvider().loadSurahs();

        expect(
          () => TanzilEnglishTransliterationParser(
            expectedByteLength: bytes.length,
            expectedSha256: sha256.convert(bytes).toString(),
            source: TanzilEnglishTransliterationRepository.source,
          ).parse(bytes, metadata),
          throwsA(
            isA<TanzilTransliterationException>().having(
              (error) => error.code,
              'code',
              'tanzil_transliteration_coordinate_invalid',
            ),
          ),
        );
      },
    );

    test('range lookups are immutable and fail closed', () async {
      final repository = TanzilEnglishTransliterationRepository();
      final range = await repository.getRange(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 3,
      );

      expect(range, hasLength(3));
      expect(range.map((ayah) => ayah.ayahNumber), <int>[1, 2, 3]);
      expect(() => range.add(range.first), throwsUnsupportedError);
      await expectLater(
        repository.getAyah(surahNumber: 1, ayahNumber: 8),
        throwsRangeError,
      );
    });
  });
}
