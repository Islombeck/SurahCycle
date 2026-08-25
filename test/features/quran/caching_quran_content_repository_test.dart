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
        );
        final second = await repository.getSurahTranslation(
          translation: translation,
          surahNumber: 9,
        );

        expect(provider.fetchCount, 1);
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

QuranTranslation _translation() => QuranTranslation(
  source: _FakeProvider.id,
  key: 'test-key',
  languageCode: 'xx',
  version: 'test-v1',
  title: 'Synthetic translation title',
);

QuranSurahContent _content({required String exactTranslation}) =>
    QuranSurahContent(
      surahNumber: 9,
      sourceMetadata: QuranSourceMetadata(
        source: _FakeProvider.id,
        translationKey: 'test-key',
        version: 'test-v1',
        language: 'xx',
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
        Ayah(
          surahNumber: 9,
          ayahNumber: 1,
          fullTranslation: exactTranslation,
          translationSource: _FakeProvider.id,
          translationVersion: 'test-v1',
        ),
      ],
    );

final class _FakeProvider implements QuranContentProvider {
  _FakeProvider({
    required this.translation,
    required this.content,
    this.fetchError,
  });

  static const String id = 'test-provider';

  final QuranTranslation translation;
  final QuranSurahContent content;
  final QuranProviderException? fetchError;
  int fetchCount = 0;

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
  }) async => <QuranTranslation>[translation];
}

final class _MemoryCache implements QuranContentCache {
  final Map<QuranContentCacheKey, QuranSurahContent> values =
      <QuranContentCacheKey, QuranSurahContent>{};

  @override
  Future<QuranSurahContent?> readSurah(QuranContentCacheKey key) async =>
      values[key];

  @override
  Future<void> writeSurah(
    QuranContentCacheKey key,
    QuranSurahContent content,
  ) async {
    values[key] = content;
  }
}
