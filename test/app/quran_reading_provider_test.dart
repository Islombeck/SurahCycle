import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled Arabic does not wait for a pending translation request',
    () async {
      final pendingNetwork = Completer<QuranContentState<QuranSurahContent>>();
      final translations = _DelayedTranslationRepository(pendingNetwork);
      final selection = _selection();
      final container = ProviderContainer(
        overrides: <Override>[
          quranReadingRepositoryProvider.overrideWithValue(
            QuranReadingRepository(
              arabic: TanzilUthmaniTextRepository(),
              translations: translations,
            ),
          ),
          selectedQuranTranslationProvider.overrideWith(
            (ref) => Stream<QuranTranslationSelection?>.value(selection),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(selectedQuranTranslationProvider.future);

      final reading = await container
          .read(
            quranReadingSurahProvider(const (
              surahNumber: 1,
              ayahCount: 7,
              warmTranslation: true,
            )).future,
          )
          .timeout(const Duration(seconds: 2));

      expect(reading.ayahs, hasLength(7));
      expect(reading.ayah(1).arabicText, isNotEmpty);
      expect(reading.ayah(1).translation, isNull);
      expect(reading.translationSelection, selection);
      await Future<void>.delayed(Duration.zero);
      expect(translations.cacheOnlyRequests, 1);
      expect(translations.networkRequests, 1);

      pendingNetwork.complete(
        const UnavailableQuranContent<QuranSurahContent>(
          issue: QuranContentIssue(
            reason: QuranContentUnavailableReason.networkFailure,
            code: 'fixture_network_pending_completed',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('malformed saved selection never hides bundled Arabic', () async {
    final translations = _DelayedTranslationRepository(
      Completer<QuranContentState<QuranSurahContent>>(),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        quranReadingRepositoryProvider.overrideWithValue(
          QuranReadingRepository(
            arabic: TanzilUthmaniTextRepository(),
            translations: translations,
          ),
        ),
        selectedQuranTranslationProvider.overrideWith(
          (ref) => Stream<QuranTranslationSelection?>.error(
            const FormatException('fixture malformed selection'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(selectedQuranTranslationProvider.future),
      throwsFormatException,
    );

    final reading = await container.read(
      quranReadingSurahProvider(const (
        surahNumber: 1,
        ayahCount: 7,
        warmTranslation: true,
      )).future,
    );

    expect(reading.ayahs, hasLength(7));
    expect(reading.ayah(1).arabicText, isNotEmpty);
    expect(reading.translationSelection, isNull);
    expect(
      reading.translationIssue?.code,
      'quran_translation_selection_invalid',
    );
    expect(translations.cacheOnlyRequests, 0);
    expect(translations.networkRequests, 0);
  });
}

QuranTranslationSelection _selection() {
  final translation = QuranTranslation(
    source: QuranEncProvider.sourceId,
    key: 'fixture-russian',
    languageCode: 'ru',
    version: '1.0.0',
    title: 'Fixture Russian',
  );
  return QuranTranslationSelection.fromCatalog(
    translation: translation,
    fetchedAtUtc: DateTime.utc(2026, 8, 25),
    attribution: QuranEncProvider.attribution,
  );
}

final class _DelayedTranslationRepository implements QuranContentRepository {
  _DelayedTranslationRepository(this.pendingNetwork);

  final Completer<QuranContentState<QuranSurahContent>> pendingNetwork;
  int cacheOnlyRequests = 0;
  int networkRequests = 0;

  @override
  Future<QuranContentState<QuranSurahContent>> getSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
    required int expectedAyahCount,
    required bool allowNetwork,
    bool refresh = false,
  }) async {
    if (allowNetwork) {
      networkRequests += 1;
      return pendingNetwork.future;
    }
    cacheOnlyRequests += 1;
    return const UnavailableQuranContent<QuranSurahContent>(
      issue: QuranContentIssue(
        reason: QuranContentUnavailableReason.notDownloaded,
        code: 'quran_translation_not_cached',
      ),
    );
  }

  @override
  Future<QuranContentState<List<QuranTranslation>>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async => const AvailableQuranContent<List<QuranTranslation>>(
    value: <QuranTranslation>[],
    fromCache: false,
  );
}
