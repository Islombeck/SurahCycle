import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test('unavailable repository exposes a typed unloaded state', () async {
    const repository = UnavailableQuranContentRepository();

    final catalog = await repository.listTranslations();
    final content = await repository.getSurahTranslation(
      translation: QuranTranslation(
        source: 'test-provider',
        key: 'test-key',
        languageCode: 'xx',
        version: 'test-v1',
        title: 'Synthetic test translation',
      ),
      surahNumber: 9,
    );

    expect(catalog, isA<UnavailableQuranContent<List<QuranTranslation>>>());
    expect(content, isA<UnavailableQuranContent<QuranSurahContent>>());
    expect(
      (content as UnavailableQuranContent<QuranSurahContent>).issue.reason,
      QuranContentUnavailableReason.notConfigured,
    );
  });
}
