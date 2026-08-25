import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TanzilUthmaniTextRepository', () {
    test(
      'loads the pinned offline asset and validates every coordinate',
      () async {
        final repository = TanzilUthmaniTextRepository();

        final corpus = await repository.load();

        expect(corpus.sha256, TanzilUthmaniTextRepository.expectedSha256);
        expect(
          corpus.surahCount,
          TanzilUthmaniTextRepository.expectedSurahCount,
        );
        expect(corpus.ayahCount, TanzilUthmaniTextRepository.expectedAyahCount);
        final metadata = await TanzilMetadataProvider().loadSurahs();
        for (final descriptor in metadata) {
          expect(
            corpus
                .range(
                  surahNumber: descriptor.surahNumber,
                  startAyah: 1,
                  endAyah: descriptor.ayahCount,
                )
                .length,
            descriptor.ayahCount,
          );
        }
      },
    );

    test('preserves every downloaded coordinate string exactly', () async {
      final raw = await rootBundle.loadString(
        TanzilUthmaniTextRepository.defaultAssetPath,
        cache: false,
      );
      final separator = raw.indexOf(
        '\n\n\n# PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK',
      );
      expect(separator, greaterThan(0));
      final expectedCoordinateSection = raw.substring(0, separator);
      final corpus = await TanzilUthmaniTextRepository().load();

      final reconstructed = corpus.ayahs
          .map(
            (ayah) =>
                '${ayah.surahNumber}|${ayah.ayahNumber}|${ayah.arabicText}',
          )
          .join('\n');

      expect(reconstructed, expectedCoordinateSection);
    });

    test('rejects a byte-level change before parsing content', () async {
      final data = await rootBundle.load(
        TanzilUthmaniTextRepository.defaultAssetPath,
      );
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      bytes[100] ^= 1;
      final metadata = await TanzilMetadataProvider().loadSurahs();

      expect(
        () => const TanzilUthmaniTextParser(
          expectedByteLength: TanzilUthmaniTextRepository.expectedByteLength,
          expectedSha256: TanzilUthmaniTextRepository.expectedSha256,
        ).parse(bytes, metadata),
        throwsA(
          isA<TanzilTextException>().having(
            (error) => error.code,
            'code',
            'tanzil_text_sha256_invalid',
          ),
        ),
      );
    });

    test(
      'rejects duplicate or reordered coordinates even with a matching pin',
      () async {
        final raw = await rootBundle.loadString(
          TanzilUthmaniTextRepository.defaultAssetPath,
          cache: false,
        );
        final tampered = raw.replaceFirst('\n1|2|', '\n1|1|');
        expect(tampered, isNot(raw));
        final bytes = Uint8List.fromList(utf8.encode(tampered));
        final metadata = await TanzilMetadataProvider().loadSurahs();
        final parser = TanzilUthmaniTextParser(
          expectedByteLength: bytes.length,
          expectedSha256: sha256.convert(bytes).toString(),
        );

        expect(
          () => parser.parse(bytes, metadata),
          throwsA(
            isA<TanzilTextException>().having(
              (error) => error.code,
              'code',
              'tanzil_text_coordinate_invalid',
            ),
          ),
        );
      },
    );

    test('rejects invalid lookup coordinates without a fallback', () async {
      final corpus = await TanzilUthmaniTextRepository().load();

      expect(
        () => corpus.ayah(surahNumber: 0, ayahNumber: 1),
        throwsRangeError,
      );
      expect(
        () => corpus.range(surahNumber: 1, startAyah: 1, endAyah: 8),
        throwsRangeError,
      );
    });
  });
}
