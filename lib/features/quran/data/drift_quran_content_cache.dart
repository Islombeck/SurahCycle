import 'dart:convert';

import '../../../core/data/repositories/quran_cache_repository.dart';
import '../domain/quran_models.dart';
import 'quran_content_cache.dart';

/// Persistent implementation of [QuranContentCache] backed by the dedicated
/// Quran cache database. User history remains in the separate app database.
final class DriftQuranContentCache implements QuranContentCache {
  const DriftQuranContentCache(this.repository);

  static const String translationDatasetType = 'full_translation';

  final QuranCacheRepository repository;

  static String sourceIdFor(QuranContentCacheKey key) {
    final identity = jsonEncode(<String>[
      key.providerId,
      key.translationKey,
      key.version,
      key.surahNumber.toString(),
    ]);
    return 'quran-content:${base64Url.encode(utf8.encode(identity)).replaceAll('=', '')}';
  }

  @override
  Future<QuranSurahContent?> readSurah(QuranContentCacheKey key) async {
    final sourceId = sourceIdFor(key);
    final source = await repository.getSource(sourceId);
    if (source == null) return null;
    _validateSourceIdentity(source, key);

    final cached = await repository.getAyahs(
      sourceId: sourceId,
      surahNumber: key.surahNumber,
    );
    if (cached.isEmpty) return null;

    final hasArabic = cached.first.arabicText != null;
    final hasTranslation = cached.first.translation != null;
    for (var index = 0; index < cached.length; index += 1) {
      final ayah = cached[index];
      if (ayah.ayahNumber != index + 1 ||
          (ayah.arabicText != null) != hasArabic ||
          (ayah.translation != null) != hasTranslation ||
          (ayah.translationFootnotes != null && !hasTranslation)) {
        throw StateError('Cached Quran surah structure is invalid.');
      }
    }

    final sourceUri = source.sourceUri == null
        ? null
        : Uri.tryParse(source.sourceUri!);
    if (source.sourceUri != null && sourceUri == null) {
      throw StateError('Cached Quran source URI is invalid.');
    }
    return QuranSurahContent(
      surahNumber: key.surahNumber,
      sourceMetadata: QuranSourceMetadata(
        source: source.provider,
        translationKey: source.translationKey,
        version: source.version,
        language: source.languageCode,
        fetchedAtUtc: source.fetchedAtUtc,
        attribution: source.attribution,
        licenseUsageInformation: source.license,
        sourceUri: sourceUri,
      ),
      capabilities: QuranContentCapabilities(
        hasSurahMetadata: false,
        hasArabicText: hasArabic,
        hasFullTranslation: hasTranslation,
        hasWordTranslation: false,
      ),
      ayahs: <Ayah>[
        for (final ayah in cached)
          Ayah(
            surahNumber: ayah.surahNumber,
            ayahNumber: ayah.ayahNumber,
            arabicText: ayah.arabicText,
            fullTranslation: ayah.translation,
            translationSource: hasTranslation ? source.provider : null,
            translationVersion: hasTranslation ? source.version : null,
            translationFootnotes: ayah.translationFootnotes,
          ),
      ],
    );
  }

  @override
  Future<void> writeSurah(
    QuranContentCacheKey key,
    QuranSurahContent content,
  ) async {
    _validateBundle(key, content);
    final sourceId = sourceIdFor(key);
    final metadata = content.sourceMetadata;
    await repository.replaceSurah(
      source: QuranSourceRecord(
        id: sourceId,
        provider: metadata.source,
        datasetType: translationDatasetType,
        version: metadata.version,
        languageCode: metadata.language,
        translationKey: metadata.translationKey,
        sourceUri: metadata.sourceUri?.toString(),
        attribution: metadata.attribution,
        license: metadata.licenseUsageInformation,
        fetchedAtUtc: metadata.fetchedAtUtc,
      ),
      surahNumber: key.surahNumber,
      ayahs: <CachedQuranAyah>[
        for (final ayah in content.ayahs)
          CachedQuranAyah(
            sourceId: sourceId,
            surahNumber: ayah.surahNumber,
            ayahNumber: ayah.ayahNumber,
            arabicText: ayah.arabicText,
            translation: ayah.fullTranslation,
            translationFootnotes: ayah.translationFootnotes,
          ),
      ],
    );
  }

  void _validateSourceIdentity(
    QuranSourceRecord source,
    QuranContentCacheKey key,
  ) {
    if (source.provider != key.providerId ||
        source.datasetType != translationDatasetType ||
        source.translationKey != key.translationKey ||
        source.version != key.version) {
      throw StateError('Cached Quran source identity is invalid.');
    }
  }

  void _validateBundle(QuranContentCacheKey key, QuranSurahContent content) {
    final metadata = content.sourceMetadata;
    if (content.surahNumber != key.surahNumber ||
        metadata.source != key.providerId ||
        metadata.translationKey != key.translationKey ||
        metadata.version != key.version) {
      throw ArgumentError(
        'Quran cache bundle identity does not match its key.',
      );
    }
    for (var index = 0; index < content.ayahs.length; index += 1) {
      final ayah = content.ayahs[index];
      if (ayah.surahNumber != key.surahNumber ||
          ayah.ayahNumber != index + 1 ||
          (ayah.translationFootnotes != null && ayah.fullTranslation == null)) {
        throw ArgumentError('Quran cache bundle coordinates are invalid.');
      }
    }
  }
}
