import '../domain/quran_models.dart';
import 'quran_content_state.dart';

abstract interface class QuranContentRepository {
  Future<QuranContentState<List<QuranTranslation>>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  });

  Future<QuranContentState<QuranSurahContent>> getSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
    bool refresh = false,
  });
}
