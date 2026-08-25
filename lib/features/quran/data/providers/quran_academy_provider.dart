import '../../domain/quran_models.dart';
import '../quran_content_provider.dart';

/// Contract implemented by a future application backend.
///
/// Provider credentials terminate at the backend. No client secret, provider
/// token, or direct Quran Academy HTTP configuration is accepted here.
abstract interface class QuranAcademyBackendProxy {
  Future<List<QuranTranslation>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  });

  Future<QuranSurahContent> fetchSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
  });
}

/// Future Quran Academy adapter that can operate only through the app backend.
///
/// Until a licensed backend proxy exists, composition should use
/// `UnavailableQuranContentRepository` instead of constructing this class.
final class QuranAcademyProvider implements QuranContentProvider {
  const QuranAcademyProvider({required QuranAcademyBackendProxy backendProxy})
    : _backendProxy = backendProxy; // ignore: prefer_initializing_formals

  static const String sourceId = 'quran_academy';
  static const bool allowsDirectMobileCredentials = false;

  final QuranAcademyBackendProxy _backendProxy;

  @override
  String get providerId => sourceId;

  @override
  QuranContentCapabilities get capabilities => const QuranContentCapabilities(
    hasSurahMetadata: true,
    hasArabicText: true,
    hasFullTranslation: true,
    hasWordTranslation: true,
  );

  @override
  Future<List<QuranTranslation>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async {
    final translations = await _backendProxy.listTranslations(
      languageCode: languageCode,
      localizationLanguageCode: localizationLanguageCode,
    );
    if (translations.any((item) => item.source != sourceId)) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quran_academy_proxy_source_mismatch',
      );
    }
    return List<QuranTranslation>.unmodifiable(translations);
  }

  @override
  Future<QuranSurahContent> fetchSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
  }) async {
    if (translation.source != sourceId || surahNumber <= 0) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.rejectedRequest,
        code: 'quran_academy_request_invalid',
      );
    }
    final content = await _backendProxy.fetchSurahTranslation(
      translation: translation,
      surahNumber: surahNumber,
    );
    if (content.surahNumber != surahNumber ||
        content.sourceMetadata.source != sourceId ||
        content.sourceMetadata.translationKey != translation.key ||
        content.sourceMetadata.version != translation.version ||
        content.sourceMetadata.language != translation.languageCode) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quran_academy_proxy_content_mismatch',
      );
    }
    return content;
  }
}
