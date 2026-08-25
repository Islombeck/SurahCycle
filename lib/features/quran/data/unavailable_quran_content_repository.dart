import '../domain/quran_models.dart';
import 'quran_content_repository.dart';
import 'quran_content_state.dart';

/// Safe default while no provider/license configuration has been approved.
/// It performs no network access and makes unloaded content explicit to UI.
final class UnavailableQuranContentRepository
    implements QuranContentRepository {
  const UnavailableQuranContentRepository({
    this.issue = const QuranContentIssue(
      reason: QuranContentUnavailableReason.notConfigured,
      code: 'quran_content_not_configured',
    ),
  });

  final QuranContentIssue issue;

  @override
  Future<QuranContentState<List<QuranTranslation>>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async => UnavailableQuranContent<List<QuranTranslation>>(issue: issue);

  @override
  Future<QuranContentState<QuranSurahContent>> getSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
    required int expectedAyahCount,
    required bool allowNetwork,
    bool refresh = false,
  }) async => UnavailableQuranContent<QuranSurahContent>(issue: issue);
}
