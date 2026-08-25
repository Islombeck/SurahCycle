import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test(
    'Quran Academy adapter delegates only through the backend boundary',
    () async {
      final translation = QuranTranslation(
        source: QuranAcademyProvider.sourceId,
        key: 'proxy-test-key',
        languageCode: 'xx',
        version: 'proxy-test-v1',
        title: 'Synthetic proxy translation',
      );
      final expected = _proxyContent();
      final proxy = _FakeQuranAcademyProxy(
        translation: translation,
        content: expected,
      );
      final provider = QuranAcademyProvider(backendProxy: proxy);

      final catalog = await provider.listTranslations(languageCode: 'xx');
      final content = await provider.fetchSurahTranslation(
        translation: translation,
        surahNumber: 9,
      );

      expect(QuranAcademyProvider.allowsDirectMobileCredentials, isFalse);
      expect(proxy.catalogCalls, 1);
      expect(proxy.fetchCalls, 1);
      expect(catalog.single, translation);
      expect(content, expected);
      expect(
        content.ayahs.single.fullTranslation,
        'Synthetic backend proxy translation',
      );
    },
  );
}

QuranSurahContent _proxyContent() => QuranSurahContent(
  surahNumber: 9,
  sourceMetadata: QuranSourceMetadata(
    source: QuranAcademyProvider.sourceId,
    translationKey: 'proxy-test-key',
    version: 'proxy-test-v1',
    language: 'xx',
    fetchedAtUtc: DateTime.utc(2026),
    attribution: 'Synthetic backend attribution',
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
      fullTranslation: 'Synthetic backend proxy translation',
      translationSource: QuranAcademyProvider.sourceId,
      translationVersion: 'proxy-test-v1',
    ),
  ],
);

final class _FakeQuranAcademyProxy implements QuranAcademyBackendProxy {
  _FakeQuranAcademyProxy({required this.translation, required this.content});

  final QuranTranslation translation;
  final QuranSurahContent content;
  int catalogCalls = 0;
  int fetchCalls = 0;

  @override
  Future<QuranSurahContent> fetchSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
  }) async {
    fetchCalls += 1;
    return content;
  }

  @override
  Future<List<QuranTranslation>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async {
    catalogCalls += 1;
    return <QuranTranslation>[translation];
  }
}
