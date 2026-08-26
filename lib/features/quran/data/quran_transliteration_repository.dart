import '../domain/quran_transliteration.dart';

/// Independent boundary for provider-owned Quran transliteration.
///
/// It deliberately does not share the Arabic, translation, or word-by-word
/// repository contracts. Implementations must return exact source strings.
abstract interface class QuranTransliterationRepository {
  Future<QuranTransliterationCorpus> load();

  Future<QuranTransliterationAyah> getAyah({
    required int surahNumber,
    required int ayahNumber,
  });

  Future<List<QuranTransliterationAyah>> getSurah(int surahNumber);

  Future<List<QuranTransliterationAyah>> getRange({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  });
}
