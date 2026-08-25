import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  group('Quran content models', () {
    test('preserve provider strings verbatim', () {
      const exactTranslation = '  Synthetic translation\nline  ';
      const exactFootnotes = '';

      final ayah = Ayah(
        surahNumber: 9,
        ayahNumber: 1,
        fullTranslation: exactTranslation,
        translationSource: 'test-provider',
        translationVersion: 'test-v1',
        translationFootnotes: exactFootnotes,
      );

      expect(ayah.fullTranslation, exactTranslation);
      expect(ayah.translationFootnotes, exactFootnotes);
      expect(ayah.arabicText, isNull);
    });

    test('require translation source and version', () {
      expect(
        () => Ayah(
          surahNumber: 9,
          ayahNumber: 1,
          fullTranslation: 'Synthetic translation',
        ),
        throwsArgumentError,
      );
    });

    test('make bundle collections immutable', () {
      final content = _testContent();

      expect(
        () => content.ayahs.add(
          Ayah(
            surahNumber: 9,
            ayahNumber: 2,
            fullTranslation: 'Synthetic translation B',
            translationSource: 'test-provider',
            translationVersion: 'test-v1',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => content.words.add(
          QuranWord(
            surahNumber: 9,
            ayahNumber: 1,
            position: 1,
            translation: 'Synthetic word translation',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('reject content that contradicts declared capabilities', () {
      expect(
        () => QuranSurahContent(
          surahNumber: 9,
          sourceMetadata: _testSource(),
          capabilities: const QuranContentCapabilities(
            hasSurahMetadata: false,
            hasArabicText: true,
            hasFullTranslation: true,
            hasWordTranslation: false,
          ),
          ayahs: <Ayah>[
            Ayah(
              surahNumber: 9,
              ayahNumber: 1,
              fullTranslation: 'Synthetic translation',
              translationSource: 'test-provider',
              translationVersion: 'test-v1',
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

QuranSurahContent _testContent() => QuranSurahContent(
  surahNumber: 9,
  sourceMetadata: _testSource(),
  capabilities: const QuranContentCapabilities(
    hasSurahMetadata: false,
    hasArabicText: false,
    hasFullTranslation: true,
    hasWordTranslation: false,
  ),
  ayahs: <Ayah>[
    Ayah(
      surahNumber: 9,
      ayahNumber: 1,
      fullTranslation: 'Synthetic translation A',
      translationSource: 'test-provider',
      translationVersion: 'test-v1',
    ),
  ],
);

QuranSourceMetadata _testSource() => QuranSourceMetadata(
  source: 'test-provider',
  translationKey: 'test-key',
  version: 'test-v1',
  language: 'xx',
  fetchedAtUtc: DateTime.utc(2026),
  attribution: 'Synthetic test attribution',
);
