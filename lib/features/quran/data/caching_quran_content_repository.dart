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
    required int expectedAyahCount,
    required bool allowNetwork,
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
    if (expectedAyahCount <= 0) {
      return const UnavailableQuranContent<QuranSurahContent>(
        issue: QuranContentIssue(
          reason: QuranContentUnavailableReason.providerRejectedRequest,
          code: 'invalid_expected_ayah_count',
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
        _validateBundle(cached, translation, surahNumber, expectedAyahCount);
      }
    } on Object {
      cached = null;
      cacheIssue = const QuranContentIssue(
        reason: QuranContentUnavailableReason.cacheFailure,
        code: 'quran_cache_read_failed',
      );
    }

    if (cached != null && (!refresh || !allowNetwork)) {
      return AvailableQuranContent<QuranSurahContent>(
        value: cached,
        fromCache: true,
      );
    }
    if (!allowNetwork) {
      return UnavailableQuranContent<QuranSurahContent>(
        issue:
            cacheIssue ??
            const QuranContentIssue(
              reason: QuranContentUnavailableReason.notDownloaded,
              code: 'quran_translation_not_cached',
            ),
      );
    }

    final preflightIssue = await _catalogIssueFor(translation);
    if (preflightIssue != null) {
      return _fallbackOrUnavailable(cached, preflightIssue);
    }

    try {
      final fetched = await provider.fetchSurahTranslation(
        translation: translation,
        surahNumber: surahNumber,
      );
      _validateBundle(fetched, translation, surahNumber, expectedAyahCount);

      // QuranEnc's surah endpoint is versionless. Revalidate the catalog after
      // fetching and before committing so a version change during the request
      // cannot be persisted under the previously selected version.
      final postflightIssue = await _catalogIssueFor(translation);
      if (postflightIssue != null) {
        return _fallbackOrUnavailable(cached, postflightIssue);
      }

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
      return _fallbackOrUnavailable(cached, issue);
    } on ArgumentError {
      const issue = QuranContentIssue(
        reason: QuranContentUnavailableReason.invalidProviderResponse,
        code: 'provider_bundle_identity_or_coordinates_invalid',
      );
      return _fallbackOrUnavailable(cached, issue);
    }
  }

  Future<QuranContentIssue?> _catalogIssueFor(
    QuranTranslation translation,
  ) async {
    final state = await listTranslations(
      languageCode: translation.languageCode,
      localizationLanguageCode: translation.languageCode,
    );
    return switch (state) {
      AvailableQuranContent<List<QuranTranslation>>(:final value)
          when value.any(
            (candidate) =>
                candidate.source == translation.source &&
                candidate.key == translation.key &&
                candidate.languageCode == translation.languageCode &&
                candidate.version == translation.version,
          ) =>
        null,
      AvailableQuranContent<List<QuranTranslation>>() =>
        const QuranContentIssue(
          reason: QuranContentUnavailableReason.versionMismatch,
          code: 'translation_version_not_current',
        ),
      UnavailableQuranContent<List<QuranTranslation>>(:final issue) => issue,
    };
  }

  QuranContentState<QuranSurahContent> _fallbackOrUnavailable(
    QuranSurahContent? cached,
    QuranContentIssue issue,
  ) {
    if (cached != null) {
      return AvailableQuranContent<QuranSurahContent>(
        value: cached,
        fromCache: true,
        issue: issue,
      );
    }
    return UnavailableQuranContent<QuranSurahContent>(issue: issue);
  }

  void _validateBundle(
    QuranSurahContent content,
    QuranTranslation translation,
    int surahNumber,
    int expectedAyahCount,
  ) {
    final source = content.sourceMetadata;
    if (content.surahNumber != surahNumber ||
        source.source != provider.providerId ||
        source.translationKey != translation.key ||
        source.version != translation.version ||
        source.language != translation.languageCode ||
        !content.capabilities.hasFullTranslation ||
        content.ayahs.length != expectedAyahCount) {
      throw ArgumentError('Provider bundle identity does not match request.');
    }
    for (var index = 0; index < content.ayahs.length; index += 1) {
      final ayah = content.ayahs[index];
      if (ayah.surahNumber != surahNumber ||
          ayah.ayahNumber != index + 1 ||
          ayah.fullTranslation == null ||
          ayah.translationSource != provider.providerId ||
          ayah.translationVersion != translation.version) {
        throw ArgumentError(
          'Ayah translation coordinates or provenance do not match its bundle.',
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
