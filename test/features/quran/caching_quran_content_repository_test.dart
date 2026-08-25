import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  group('CachingQuranContentRepository', () {
    test(
      'caches and returns exact provider strings without another fetch',
      () async {
        const exactTranslation = '  Synthetic provider value\nunchanged  ';
        final translation = _translation();
        final providerContent = _content(exactTranslation: exactTranslation);
        final provider = _FakeProvider(
          translation: translation,
          content: providerContent,
        );
        final cache = _MemoryCache();
        final repository = CachingQuranContentRepository(
          provider: provider,
          cache: cache,
        );

        final first = await repository.getSurahTranslation(
          translation: translation,
          surahNumber: 9,
          expectedAyahCount: 1,
          allowNetwork: true,
        );
        final second = await repository.getSurahTranslation(
          translation: translation,
          surahNumber: 9,
          expectedAyahCount: 1,
          allowNetwork: false,
        );

        expect(provider.fetchCount, 1);
        expect(provider.catalogCount, 2);
        expect(cache.writeCount, 1);
        expect(first, isA<AvailableQuranContent<QuranSurahContent>>());
        expect(second, isA<AvailableQuranContent<QuranSurahContent>>());
        final cached = second as AvailableQuranContent<QuranSurahContent>;
        expect(cached.fromCache, isTrue);
        expect(cached.value.ayahs.single.fullTranslation, exactTranslation);
        expect(
          cache.values.values.single.ayahs.single.fullTranslation,
          exactTranslation,
        );
      },
    );

    test('cache-only miss never calls the provider', () async {
      final translation = _translation();
      final provider = _FakeProvider(
        translation: translation,
        content: _content(exactTranslation: 'Synthetic network value'),
      );
      final repository = CachingQuranContentRepository(
        provider: provider,
        cache: _MemoryCache(),
      );

      final state = await repository.getSurahTranslation(
        translation: translation,
        surahNumber: 9,
        expectedAyahCount: 1,
        allowNetwork: false,
      );

      expect(provider.fetchCount, 0);
      expect(provider.catalogCount, 0);
      expect(state, isA<UnavailableQuranContent<QuranSurahContent>>());
      expect(
        (state as UnavailableQuranContent<QuranSurahContent>).issue,
        const QuranContentIssue(
          reason: QuranContentUnavailableReason.notDownloaded,
          code: 'quran_translation_not_cached',
        ),
      );
    });

    test('returns valid cache with a warning when refresh fails', () async {
      final translation = _translation();
      final cachedContent = _content(
        exactTranslation: 'Synthetic cached translation',
      );
      final cache = _MemoryCache();
      final key = QuranContentCacheKey(
        providerId: _FakeProvider.id,
        translationKey: translation.key,
        version: translation.version,
        surahNumber: 9,
      );
      await cache.writeSurah(key, cachedContent);
      final repository = CachingQuranContentRepository(
        provider: _FakeProvider(
          translation: translation,
          content: cachedContent,
          fetchError: const QuranProviderException(
            failure: QuranProviderFailure.network,
            code: 'synthetic_network_failure',
          ),
        ),
        cache: cache,
      );

      final state = await repository.getSurahTranslation(
        translation: translation,
        surahNumber: 9,
        expectedAyahCount: 1,
        allowNetwork: true,
        refresh: true,
      );

      final available = state as AvailableQuranContent<QuranSurahContent>;
      expect(available.fromCache, isTrue);
      expect(available.value, cachedContent);
      expect(
        available.issue?.reason,
        QuranContentUnavailableReason.networkFailure,
      );
    });

    test(
      'direct network access is blocked before fetch on catalog mismatch',
      () async {
        final selected = _translation(version: 'test-v1');
        final current = _translation(version: 'test-v2');
        final cache = _MemoryCache();
        final provider = _FakeProvider(
          translation: current,
          content: _content(
            exactTranslation: 'Must never be fetched',
            translation: selected,
          ),
        );
        final repository = CachingQuranContentRepository(
          provider: provider,
          cache: cache,
        );

        final state = await repository.getSurahTranslation(
          translation: selected,
          surahNumber: 9,
          expectedAyahCount: 1,
          allowNetwork: true,
        );

        expect(provider.catalogCount, 1);
        expect(provider.fetchCount, 0);
        expect(cache.writeCount, 0);
        expect(cache.values, isEmpty);
        expect(
          (state as UnavailableQuranContent<QuranSurahContent>).issue,
          const QuranContentIssue(
            reason: QuranContentUnavailableReason.versionMismatch,
            code: 'translation_version_not_current',
          ),
        );
      },
    );

    test('post-fetch catalog mismatch never commits fetched content', () async {
      final selected = _translation(version: 'test-v1');
      final current = _translation(version: 'test-v2');
      final cache = _MemoryCache();
      final provider = _FakeProvider(
        translation: selected,
        content: _content(
          exactTranslation: 'Fetched during a catalog change',
          translation: selected,
        ),
        catalogResponses: <List<QuranTranslation>>[
          <QuranTranslation>[selected],
          <QuranTranslation>[current],
        ],
      );
      final repository = CachingQuranContentRepository(
        provider: provider,
        cache: cache,
      );

      final state = await repository.getSurahTranslation(
        translation: selected,
        surahNumber: 9,
        expectedAyahCount: 1,
        allowNetwork: true,
      );

      expect(provider.catalogCount, 2);
      expect(provider.fetchCount, 1);
      expect(cache.writeCount, 0);
      expect(cache.values, isEmpty);
      expect(
        (state as UnavailableQuranContent<QuranSurahContent>).issue.reason,
        QuranContentUnavailableReason.versionMismatch,
      );
    });

    test('incomplete provider response never writes cache', () async {
      final translation = _translation();
      final cache = _MemoryCache();
      final provider = _FakeProvider(
        translation: translation,
        content: _content(
          exactTranslation: 'Only the first ayah was returned',
          translation: translation,
        ),
      );
      final repository = CachingQuranContentRepository(
        provider: provider,
        cache: cache,
      );

      final state = await repository.getSurahTranslation(
        translation: translation,
        surahNumber: 9,
        expectedAyahCount: 2,
        allowNetwork: true,
      );

      expect(provider.catalogCount, 1);
      expect(provider.fetchCount, 1);
      expect(cache.writeCount, 0);
      expect(cache.values, isEmpty);
      expect(
        (state as UnavailableQuranContent<QuranSurahContent>).issue.reason,
        QuranContentUnavailableReason.invalidProviderResponse,
      );
    });

    test(
      'invalid refresh response returns valid cache with an issue and no write',
      () async {
        final translation = _translation();
        final cachedContent = _content(
          exactTranslation: 'Complete cached translation',
          translation: translation,
          ayahCount: 2,
        );
        final cache = _MemoryCache();
        final key = QuranContentCacheKey(
          providerId: _FakeProvider.id,
          translationKey: translation.key,
          version: translation.version,
          surahNumber: 9,
        );
        cache.values[key] = cachedContent;
        final repository = CachingQuranContentRepository(
          provider: _FakeProvider(
            translation: translation,
            content: _content(
              exactTranslation: 'Incomplete refresh response',
              translation: translation,
            ),
          ),
          cache: cache,
        );

        final state = await repository.getSurahTranslation(
          translation: translation,
          surahNumber: 9,
          expectedAyahCount: 2,
          allowNetwork: true,
          refresh: true,
        );

        final available = state as AvailableQuranContent<QuranSurahContent>;
        expect(available.value, same(cachedContent));
        expect(available.fromCache, isTrue);
        expect(
          available.issue?.reason,
          QuranContentUnavailableReason.invalidProviderResponse,
        );
        expect(cache.writeCount, 0);
      },
    );

    test(
      'refresh catalog mismatch returns valid cache without fetch or write',
      () async {
        final selected = _translation(version: 'test-v1');
        final current = _translation(version: 'test-v2');
        final cachedContent = _content(
          exactTranslation: 'Pinned cached translation',
          translation: selected,
        );
        final cache = _MemoryCache();
        final key = QuranContentCacheKey(
          providerId: _FakeProvider.id,
          translationKey: selected.key,
          version: selected.version,
          surahNumber: 9,
        );
        cache.values[key] = cachedContent;
        final provider = _FakeProvider(
          translation: current,
          content: _content(
            exactTranslation: 'Must never be fetched',
            translation: selected,
          ),
        );
        final repository = CachingQuranContentRepository(
          provider: provider,
          cache: cache,
        );

        final state = await repository.getSurahTranslation(
          translation: selected,
          surahNumber: 9,
          expectedAyahCount: 1,
          allowNetwork: true,
          refresh: true,
        );

        final available = state as AvailableQuranContent<QuranSurahContent>;
        expect(available.value, same(cachedContent));
        expect(available.fromCache, isTrue);
        expect(
          available.issue?.reason,
          QuranContentUnavailableReason.versionMismatch,
        );
        expect(provider.fetchCount, 0);
        expect(cache.writeCount, 0);
      },
    );

    test('rejects a catalog attributed to another provider', () async {
      final wrongTranslation = QuranTranslation(
        source: 'another-test-provider',
        key: 'test-key',
        languageCode: 'xx',
        version: 'test-v1',
        title: 'Synthetic translation title',
      );
      final repository = CachingQuranContentRepository(
        provider: _FakeProvider(
          translation: wrongTranslation,
          content: _content(exactTranslation: 'Synthetic provider translation'),
        ),
        cache: _MemoryCache(),
      );

      final state = await repository.listTranslations();

      expect(state, isA<UnavailableQuranContent<List<QuranTranslation>>>());
    });
  });
}

QuranTranslation _translation({String version = 'test-v1'}) => QuranTranslation(
  source: _FakeProvider.id,
  key: 'test-key',
  languageCode: 'xx',
  version: version,
  title: 'Synthetic translation title',
);

QuranSurahContent _content({
  required String exactTranslation,
  QuranTranslation? translation,
  int ayahCount = 1,
}) {
  final selected = translation ?? _translation();
  return QuranSurahContent(
    surahNumber: 9,
    sourceMetadata: QuranSourceMetadata(
      source: _FakeProvider.id,
      translationKey: selected.key,
      version: selected.version,
      language: selected.languageCode,
      fetchedAtUtc: DateTime.utc(2026),
      attribution: 'Synthetic provider attribution',
    ),
    capabilities: const QuranContentCapabilities(
      hasSurahMetadata: false,
      hasArabicText: false,
      hasFullTranslation: true,
      hasWordTranslation: false,
    ),
    ayahs: <Ayah>[
      for (var ayahNumber = 1; ayahNumber <= ayahCount; ayahNumber += 1)
        Ayah(
          surahNumber: 9,
          ayahNumber: ayahNumber,
          fullTranslation: ayahNumber == 1
              ? exactTranslation
              : 'Synthetic provider value $ayahNumber',
          translationSource: _FakeProvider.id,
          translationVersion: selected.version,
        ),
    ],
  );
}

final class _FakeProvider implements QuranContentProvider {
  _FakeProvider({
    required this.translation,
    required this.content,
    this.fetchError,
    List<List<QuranTranslation>>? catalogResponses,
  }) : _catalogResponses =
           catalogResponses ??
           <List<QuranTranslation>>[
             <QuranTranslation>[translation],
           ];

  static const String id = 'test-provider';

  final QuranTranslation translation;
  final QuranSurahContent content;
  final QuranProviderException? fetchError;
  final List<List<QuranTranslation>> _catalogResponses;
  int fetchCount = 0;
  int catalogCount = 0;

  @override
  QuranContentCapabilities get capabilities => content.capabilities;

  @override
  String get providerId => id;

  @override
  Future<QuranSurahContent> fetchSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
  }) async {
    fetchCount += 1;
    final error = fetchError;
    if (error != null) throw error;
    return content;
  }

  @override
  Future<List<QuranTranslation>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async {
    final index = catalogCount < _catalogResponses.length
        ? catalogCount
        : _catalogResponses.length - 1;
    catalogCount += 1;
    return _catalogResponses[index];
  }
}

final class _MemoryCache implements QuranContentCache {
  final Map<QuranContentCacheKey, QuranSurahContent> values =
      <QuranContentCacheKey, QuranSurahContent>{};
  int writeCount = 0;

  @override
  Future<QuranSurahContent?> readSurah(QuranContentCacheKey key) async =>
      values[key];

  @override
  Future<void> writeSurah(
    QuranContentCacheKey key,
    QuranSurahContent content,
  ) async {
    writeCount += 1;
    values[key] = content;
  }
}
