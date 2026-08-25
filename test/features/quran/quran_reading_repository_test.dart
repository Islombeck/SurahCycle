import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Arabic is available without a selected translation', () async {
    final arabic = TanzilUthmaniTextRepository();
    final translations = _FakeTranslationRepository();
    final repository = QuranReadingRepository(
      arabic: arabic,
      translations: translations,
    );

    final reading = await repository.getSurah(surahNumber: 1, ayahCount: 7);
    final verified = (await arabic.load()).ayah(surahNumber: 1, ayahNumber: 1);

    expect(reading.ayahs, hasLength(7));
    expect(reading.ayah(1).arabicText, verified.arabicText);
    expect(reading.ayah(1).translation, isNull);
    expect(translations.requests, 0);
  });

  test('new and cumulative lookups retain exact source strings', () async {
    const exactTranslation = '  exact provider translation  ';
    final arabic = TanzilUthmaniTextRepository();
    final translation = QuranTranslation(
      source: QuranEncProvider.sourceId,
      key: 'fixture',
      languageCode: 'ru',
      version: '1.0.0',
      title: 'Fixture',
    );
    final selection = QuranTranslationSelection.fromCatalog(
      translation: translation,
      fetchedAtUtc: DateTime.utc(2026, 8, 25),
      attribution: QuranEncProvider.attribution,
    );
    final translations = _FakeTranslationRepository(
      available: QuranSurahContent(
        surahNumber: 1,
        sourceMetadata: QuranSourceMetadata(
          source: QuranEncProvider.sourceId,
          translationKey: translation.key,
          version: translation.version,
          language: translation.languageCode,
          fetchedAtUtc: DateTime.utc(2026, 8, 25),
        ),
        capabilities: const QuranContentCapabilities(
          hasSurahMetadata: false,
          hasArabicText: false,
          hasFullTranslation: true,
          hasWordTranslation: false,
        ),
        ayahs: <Ayah>[
          for (var ayahNumber = 1; ayahNumber <= 7; ayahNumber += 1)
            Ayah(
              surahNumber: 1,
              ayahNumber: ayahNumber,
              fullTranslation: ayahNumber == 1
                  ? exactTranslation
                  : 'fixture translation $ayahNumber',
              translationSource: QuranEncProvider.sourceId,
              translationVersion: translation.version,
            ),
        ],
      ),
    );
    final repository = QuranReadingRepository(
      arabic: arabic,
      translations: translations,
    );

    final reading = await repository.getSurah(
      surahNumber: 1,
      ayahCount: 7,
      translationSelection: selection,
    );
    final verified = (await arabic.load()).ayah(surahNumber: 1, ayahNumber: 2);

    expect(reading.ayah(1).translation, exactTranslation);
    expect(reading.ayah(2).arabicText, verified.arabicText);
    expect(reading.range(startAyah: 1, endAyah: 3), hasLength(3));
    expect(() => reading.range(startAyah: 0, endAyah: 1), throwsRangeError);
    expect(translations.cacheOnlyRequests, 1);
    expect(translations.catalogRequests, 0);
    expect(translations.networkRequests, 0);
  });

  test('explicit warmup merges a complete repository response', () async {
    final translation = _translation(version: '1.0.0');
    final translations = _FakeTranslationRepository(
      networkAvailable: _translationContent(
        translation,
        firstTranslation: 'exact fetched translation',
      ),
    );
    final repository = QuranReadingRepository(
      arabic: TanzilUthmaniTextRepository(),
      translations: translations,
    );

    final reading = await repository.getSurah(
      surahNumber: 1,
      ayahCount: 7,
      translationSelection: _selection(translation),
      allowTranslationNetwork: true,
    );

    expect(reading.ayah(1).translation, 'exact fetched translation');
    expect(reading.translationFromCache, isFalse);
    expect(reading.translationIssue, isNull);
    expect(translations.cacheOnlyRequests, 0);
    expect(translations.catalogRequests, 0);
    expect(translations.networkRequests, 1);
  });

  test('version mismatch leaves exact Arabic available', () async {
    final selected = _translation(version: '1.0.0');
    final translations = _FakeTranslationRepository(
      networkIssue: const QuranContentIssue(
        reason: QuranContentUnavailableReason.versionMismatch,
        code: 'translation_version_not_current',
      ),
    );
    final repository = QuranReadingRepository(
      arabic: TanzilUthmaniTextRepository(),
      translations: translations,
    );

    final reading = await repository.getSurah(
      surahNumber: 1,
      ayahCount: 7,
      translationSelection: _selection(selected),
      allowTranslationNetwork: true,
    );

    expect(reading.ayahs.every((ayah) => ayah.translation == null), isTrue);
    expect(
      reading.translationIssue,
      const QuranContentIssue(
        reason: QuranContentUnavailableReason.versionMismatch,
        code: 'translation_version_not_current',
      ),
    );
    expect(translations.cacheOnlyRequests, 0);
    expect(translations.catalogRequests, 0);
    expect(translations.networkRequests, 1);
  });

  test('caller ayah count must match the validated Tanzil corpus', () async {
    final translations = _FakeTranslationRepository();
    final repository = QuranReadingRepository(
      arabic: TanzilUthmaniTextRepository(),
      translations: translations,
    );

    await expectLater(
      repository.getSurah(surahNumber: 1, ayahCount: 6),
      throwsArgumentError,
    );
    expect(translations.requests, 0);
  });
}

QuranTranslation _translation({required String version}) => QuranTranslation(
  source: QuranEncProvider.sourceId,
  key: 'fixture',
  languageCode: 'ru',
  version: version,
  title: 'Fixture',
);

QuranTranslationSelection _selection(QuranTranslation translation) =>
    QuranTranslationSelection.fromCatalog(
      translation: translation,
      fetchedAtUtc: DateTime.utc(2026, 8, 25),
      attribution: QuranEncProvider.attribution,
    );

QuranSurahContent _translationContent(
  QuranTranslation translation, {
  required String firstTranslation,
}) => QuranSurahContent(
  surahNumber: 1,
  sourceMetadata: QuranSourceMetadata(
    source: QuranEncProvider.sourceId,
    translationKey: translation.key,
    version: translation.version,
    language: translation.languageCode,
    fetchedAtUtc: DateTime.utc(2026, 8, 25),
  ),
  capabilities: const QuranContentCapabilities(
    hasSurahMetadata: false,
    hasArabicText: false,
    hasFullTranslation: true,
    hasWordTranslation: false,
  ),
  ayahs: <Ayah>[
    for (var ayahNumber = 1; ayahNumber <= 7; ayahNumber += 1)
      Ayah(
        surahNumber: 1,
        ayahNumber: ayahNumber,
        fullTranslation: ayahNumber == 1
            ? firstTranslation
            : 'fixture translation $ayahNumber',
        translationSource: QuranEncProvider.sourceId,
        translationVersion: translation.version,
      ),
  ],
);

final class _FakeTranslationRepository implements QuranContentRepository {
  _FakeTranslationRepository({
    this.available,
    this.networkAvailable,
    this.networkIssue = const QuranContentIssue(
      reason: QuranContentUnavailableReason.networkFailure,
      code: 'offline',
    ),
  });

  final QuranSurahContent? available;
  final QuranSurahContent? networkAvailable;
  final QuranContentIssue networkIssue;
  int requests = 0;
  int cacheOnlyRequests = 0;
  int networkRequests = 0;
  int catalogRequests = 0;

  @override
  Future<QuranContentState<QuranSurahContent>> getSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
    required int expectedAyahCount,
    required bool allowNetwork,
    bool refresh = false,
  }) async {
    requests += 1;
    if (allowNetwork) {
      networkRequests += 1;
    } else {
      cacheOnlyRequests += 1;
    }
    final value = allowNetwork ? networkAvailable : available;
    if (value == null) {
      return UnavailableQuranContent<QuranSurahContent>(
        issue: allowNetwork
            ? networkIssue
            : const QuranContentIssue(
                reason: QuranContentUnavailableReason.notDownloaded,
                code: 'quran_translation_not_cached',
              ),
      );
    }
    return AvailableQuranContent<QuranSurahContent>(
      value: value,
      fromCache: !allowNetwork,
    );
  }

  @override
  Future<QuranContentState<List<QuranTranslation>>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async {
    catalogRequests += 1;
    return const AvailableQuranContent<List<QuranTranslation>>(
      value: <QuranTranslation>[],
      fromCache: false,
    );
  }
}
