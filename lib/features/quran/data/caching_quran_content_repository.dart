import '../domain/quran_models.dart';
import 'quran_content_cache.dart';
import 'quran_content_provider.dart';
import 'quran_content_repository.dart';
import 'quran_content_state.dart';

/// Cache-first repository. Network/provider failures never discard a valid
/// cached bundle, and provider strings are passed through unchanged.
final class CachingQuranContentRepository implements QuranContentRepository {
  const CachingQuranContentRepository({
    required this.provider,
    required this.cache,
  });

  final QuranContentProvider provider;
  final QuranContentCache cache;

  @override
  Future<QuranContentState<List<QuranTranslation>>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async {
    try {
      final translations = await provider.listTranslations(
        languageCode: languageCode,
        localizationLanguageCode: localizationLanguageCode,
      );
      for (final translation in translations) {
        if (translation.source != provider.providerId) {
          return const UnavailableQuranContent<List<QuranTranslation>>(
            issue: QuranContentIssue(
              reason: QuranContentUnavailableReason.invalidProviderResponse,
              code: 'translation_source_mismatch',
            ),
          );
        }
      }
      return AvailableQuranContent<List<QuranTranslation>>(
        value: List<QuranTranslation>.unmodifiable(translations),
        fromCache: false,
      );
    } on QuranProviderException catch (error) {
      return UnavailableQuranContent<List<QuranTranslation>>(
        issue: _issueForProvider(error),
      );
    }
  }

  @override
  Future<QuranContentState<QuranSurahContent>> getSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
    bool refresh = false,
  }) async {
    if (translation.source != provider.providerId) {
      return const UnavailableQuranContent<QuranSurahContent>(
        issue: QuranContentIssue(
          reason: QuranContentUnavailableReason.providerRejectedRequest,
          code: 'translation_belongs_to_another_provider',
        ),
      );
    }
    if (surahNumber <= 0) {
      return const UnavailableQuranContent<QuranSurahContent>(
        issue: QuranContentIssue(
          reason: QuranContentUnavailableReason.providerRejectedRequest,
          code: 'invalid_surah_number',
        ),
      );
    }

    final key = QuranContentCacheKey(
      providerId: provider.providerId,
      translationKey: translation.key,
      version: translation.version,
      surahNumber: surahNumber,
    );

    QuranSurahContent? cached;
    QuranContentIssue? cacheIssue;
    try {
      cached = await cache.readSurah(key);
      if (cached != null) {
        _validateBundle(cached, translation, surahNumber);
      }
    } on Object {
      cached = null;
      cacheIssue = const QuranContentIssue(
        reason: QuranContentUnavailableReason.cacheFailure,
        code: 'quran_cache_read_failed',
      );
    }

    if (cached != null && !refresh) {
      return AvailableQuranContent<QuranSurahContent>(
        value: cached,
        fromCache: true,
      );
    }

    try {
      final fetched = await provider.fetchSurahTranslation(
        translation: translation,
        surahNumber: surahNumber,
      );
      _validateBundle(fetched, translation, surahNumber);
      try {
        await cache.writeSurah(key, fetched);
      } on Object {
        return AvailableQuranContent<QuranSurahContent>(
          value: fetched,
          fromCache: false,
          issue: const QuranContentIssue(
            reason: QuranContentUnavailableReason.cacheFailure,
            code: 'quran_cache_write_failed',
          ),
        );
      }
      return AvailableQuranContent<QuranSurahContent>(
        value: fetched,
        fromCache: false,
        issue: cacheIssue,
      );
    } on QuranProviderException catch (error) {
      final issue = _issueForProvider(error);
      if (cached != null) {
        return AvailableQuranContent<QuranSurahContent>(
          value: cached,
          fromCache: true,
          issue: issue,
        );
      }
      return UnavailableQuranContent<QuranSurahContent>(issue: issue);
    } on ArgumentError {
      const issue = QuranContentIssue(
        reason: QuranContentUnavailableReason.invalidProviderResponse,
        code: 'provider_bundle_identity_mismatch',
      );
      if (cached != null) {
        return AvailableQuranContent<QuranSurahContent>(
          value: cached,
          fromCache: true,
          issue: issue,
        );
      }
      return const UnavailableQuranContent<QuranSurahContent>(issue: issue);
    }
  }

  void _validateBundle(
    QuranSurahContent content,
    QuranTranslation translation,
    int surahNumber,
  ) {
    final source = content.sourceMetadata;
    if (content.surahNumber != surahNumber ||
        source.source != provider.providerId ||
        source.translationKey != translation.key ||
        source.version != translation.version ||
        source.language != translation.languageCode) {
      throw ArgumentError('Provider bundle identity does not match request.');
    }
    for (final ayah in content.ayahs) {
      if (ayah.fullTranslation != null &&
          (ayah.translationSource != provider.providerId ||
              ayah.translationVersion != translation.version)) {
        throw ArgumentError(
          'Ayah translation provenance does not match its bundle.',
        );
      }
    }
  }

  QuranContentIssue _issueForProvider(QuranProviderException error) =>
      switch (error.failure) {
        QuranProviderFailure.network => QuranContentIssue(
          reason: QuranContentUnavailableReason.networkFailure,
          code: error.code,
        ),
        QuranProviderFailure.invalidResponse => QuranContentIssue(
          reason: QuranContentUnavailableReason.invalidProviderResponse,
          code: error.code,
        ),
        QuranProviderFailure.rejectedRequest => QuranContentIssue(
          reason: QuranContentUnavailableReason.providerRejectedRequest,
          code: error.code,
        ),
        QuranProviderFailure.credentialsRequireBackend => QuranContentIssue(
          reason: QuranContentUnavailableReason.credentialsRequireBackend,
          code: error.code,
        ),
      };
}
