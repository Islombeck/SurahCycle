import '../data/providers/tanzil_uthmani_text_repository.dart';
import '../data/quran_content_repository.dart';
import '../data/quran_content_state.dart';
import '../data/quran_transliteration_repository.dart';
import '../domain/quran_models.dart';
import '../domain/quran_translation_selection.dart';
import '../domain/quran_transliteration.dart';

/// Display-ready ayah content assembled without changing either source string.
final class QuranReadingAyah {
  const QuranReadingAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
    this.transliteration,
    this.translation,
  });

  final int surahNumber;
  final int ayahNumber;
  final String arabicText;
  final String? transliteration;
  final String? translation;
}

/// Arabic is always present because it comes from the bundled Tanzil corpus.
/// Transliteration and translation are independent layers and may be absent.
final class QuranReadingSurah {
  QuranReadingSurah({
    required this.surahNumber,
    required Iterable<QuranReadingAyah> ayahs,
    required this.translationSelection,
    required this.translationFromCache,
    required this.translationIssue,
    required this.transliterationSource,
    required this.transliterationIssueCode,
  }) : ayahs = List<QuranReadingAyah>.unmodifiable(ayahs);

  final int surahNumber;
  final List<QuranReadingAyah> ayahs;
  final QuranTranslationSelection? translationSelection;
  final bool? translationFromCache;
  final QuranContentIssue? translationIssue;
  final QuranTransliterationSource? transliterationSource;

  /// Stable, content-free diagnostics. Null means either a verified source
  /// was assembled successfully or no transliteration repository is installed.
  final String? transliterationIssueCode;

  QuranReadingSurah withTranslationIssue(QuranContentIssue? issue) =>
      QuranReadingSurah(
        surahNumber: surahNumber,
        ayahs: ayahs,
        translationSelection: translationSelection,
        translationFromCache: translationFromCache,
        translationIssue: issue,
        transliterationSource: transliterationSource,
        transliterationIssueCode: transliterationIssueCode,
      );

  QuranReadingAyah ayah(int ayahNumber) {
    if (ayahNumber < 1 || ayahNumber > ayahs.length) {
      throw RangeError.range(ayahNumber, 1, ayahs.length, 'ayahNumber');
    }
    return ayahs[ayahNumber - 1];
  }

  List<QuranReadingAyah> range({required int startAyah, required int endAyah}) {
    if (startAyah < 1 || startAyah > ayahs.length) {
      throw RangeError.range(startAyah, 1, ayahs.length, 'startAyah');
    }
    if (endAyah < startAyah || endAyah > ayahs.length) {
      throw RangeError.range(endAyah, startAyah, ayahs.length, 'endAyah');
    }
    return List<QuranReadingAyah>.unmodifiable(
      ayahs.sublist(startAyah - 1, endAyah),
    );
  }
}

/// Joins pinned offline Arabic with optional provider-owned transliteration
/// and a version-pinned translation. Source text is never trimmed or normalized.
final class QuranReadingRepository {
  const QuranReadingRepository({
    required this.arabic,
    required this.translations,
    this.transliterations,
  });

  final TanzilUthmaniTextRepository arabic;
  final QuranContentRepository translations;
  final QuranTransliterationRepository? transliterations;

  Future<QuranReadingSurah> getSurah({
    required int surahNumber,
    required int ayahCount,
    QuranTranslationSelection? translationSelection,
    bool allowTranslationNetwork = false,
  }) async {
    if (surahNumber <= 0 || ayahCount <= 0) {
      throw ArgumentError('Quran coordinates must be positive.');
    }
    final corpus = await arabic.load();
    final verifiedAyahCount = corpus.surahAyahCount(surahNumber);
    if (ayahCount != verifiedAyahCount) {
      throw ArgumentError.value(
        ayahCount,
        'ayahCount',
        'Must exactly match the validated Tanzil corpus.',
      );
    }
    final arabicAyahs = corpus.range(
      surahNumber: surahNumber,
      startAyah: 1,
      endAyah: ayahCount,
    );

    final translationsByAyah = <int, String>{};
    final transliterationsByAyah = <int, String>{};
    QuranTransliterationSource? transliterationSource;
    String? transliterationIssueCode;
    final transliterationRepository = transliterations;
    if (transliterationRepository != null) {
      try {
        final sourceAyahs = await transliterationRepository.getRange(
          surahNumber: surahNumber,
          startAyah: 1,
          endAyah: ayahCount,
        );
        final complete =
            sourceAyahs.length == ayahCount &&
            sourceAyahs.indexed.every(
              (entry) =>
                  entry.$2.surahNumber == surahNumber &&
                  entry.$2.ayahNumber == entry.$1 + 1 &&
                  entry.$2.exactText.isNotEmpty &&
                  entry.$2.source == sourceAyahs.first.source,
            );
        if (!complete) {
          transliterationIssueCode =
              'transliteration_surah_coordinates_incomplete';
        } else {
          transliterationSource = sourceAyahs.first.source;
          for (final ayah in sourceAyahs) {
            transliterationsByAyah[ayah.ayahNumber] = ayah.exactText;
          }
        }
      } on Object {
        // Arabic and any cached translation remain useful even if the
        // independent transliteration source cannot be loaded or validated.
        transliterationIssueCode = 'quran_transliteration_unavailable';
      }
    }

    bool? fromCache;
    QuranContentIssue? issue;
    if (translationSelection != null) {
      bool acceptIfComplete(
        AvailableQuranContent<QuranSurahContent> available,
      ) {
        final content = available.value;
        final complete =
            content.ayahs.length == ayahCount &&
            content.ayahs.indexed.every(
              (entry) =>
                  entry.$2.surahNumber == surahNumber &&
                  entry.$2.ayahNumber == entry.$1 + 1 &&
                  entry.$2.fullTranslation != null,
            );
        if (!complete) {
          issue = const QuranContentIssue(
            reason: QuranContentUnavailableReason.invalidProviderResponse,
            code: 'translation_surah_coordinates_incomplete',
          );
          return false;
        }
        fromCache = available.fromCache;
        issue = available.issue;
        for (final ayah in content.ayahs) {
          final exact = ayah.fullTranslation;
          if (exact != null) translationsByAyah[ayah.ayahNumber] = exact;
        }
        return true;
      }

      final state = await translations.getSurahTranslation(
        translation: translationSelection.translation,
        surahNumber: surahNumber,
        expectedAyahCount: ayahCount,
        allowNetwork: allowTranslationNetwork,
      );
      switch (state) {
        case AvailableQuranContent<QuranSurahContent>():
          acceptIfComplete(state);
        case UnavailableQuranContent<QuranSurahContent>(
          issue: final stateIssue,
        ):
          issue = stateIssue;
      }
    }

    return QuranReadingSurah(
      surahNumber: surahNumber,
      ayahs: <QuranReadingAyah>[
        for (final ayah in arabicAyahs)
          QuranReadingAyah(
            surahNumber: ayah.surahNumber,
            ayahNumber: ayah.ayahNumber,
            arabicText: ayah.arabicText,
            transliteration: transliterationsByAyah[ayah.ayahNumber],
            translation: translationsByAyah[ayah.ayahNumber],
          ),
      ],
      translationSelection: translationSelection,
      translationFromCache: fromCache,
      translationIssue: issue,
      transliterationSource: transliterationSource,
      transliterationIssueCode: transliterationIssueCode,
    );
  }
}
