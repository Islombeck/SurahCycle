import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test(
    'catalog family forwards translation and UI languages independently',
    () async {
      final repository = _RecordingContentRepository();
      final container = ProviderContainer(
        overrides: <Override>[
          quranContentRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(
        quranTranslationsProvider(const (
          languageCode: 'uz',
          localizationLanguageCode: 'ru',
        )).future,
      );

      expect(repository.languageCode, 'uz');
      expect(repository.localizationLanguageCode, 'ru');
    },
  );

  test('catalog family rejects a language that has not been audited', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        quranContentRepositoryProvider.overrideWithValue(
          _RecordingContentRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(
        quranTranslationsProvider(const (
          languageCode: 'en',
          localizationLanguageCode: 'en',
        )).future,
      ),
      throwsArgumentError,
    );
  });

  test('selection controller accepts audited Uzbek QuranEnc entries', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 1, 12);
    final repository = QuranTranslationSelectionRepository(
      AppSettingsRepository(database),
    );
    final controller = QuranTranslationSelectionController(
      repository: repository,
      timeProvider: _FixedTimeProvider(now),
    );
    final translation = QuranTranslation(
      source: QuranEncProvider.sourceId,
      key: 'uzbek_sadiq',
      languageCode: 'uz',
      version: 'test-v1',
      title: 'Muhammad Sadiq Muhammad Yusuf',
    );

    await controller.select(translation);

    final selected = await repository.getSelected();
    expect(selected?.key, 'uzbek_sadiq');
    expect(selected?.languageCode, 'uz');
    expect(selected?.fetchedAtUtc, now);
  });

  test(
    'selection controller still rejects unsupported sources and languages',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final controller = QuranTranslationSelectionController(
        repository: QuranTranslationSelectionRepository(
          AppSettingsRepository(database),
        ),
        timeProvider: _FixedTimeProvider(DateTime.utc(2026, 9, 1)),
      );

      await expectLater(
        controller.select(
          QuranTranslation(
            source: 'unverified.test',
            key: 'uzbek_sadiq',
            languageCode: 'uz',
            version: 'test-v1',
            title: 'Fixture',
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        controller.select(
          QuranTranslation(
            source: QuranEncProvider.sourceId,
            key: 'unsupported',
            languageCode: 'en',
            version: 'test-v1',
            title: 'Fixture',
          ),
        ),
        throwsArgumentError,
      );
    },
  );
}

final class _RecordingContentRepository implements QuranContentRepository {
  String? languageCode;
  String? localizationLanguageCode;

  @override
  Future<QuranContentState<List<QuranTranslation>>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async {
    this.languageCode = languageCode;
    this.localizationLanguageCode = localizationLanguageCode;
    return const AvailableQuranContent<List<QuranTranslation>>(
      value: <QuranTranslation>[],
      fromCache: false,
    );
  }

  @override
  Future<QuranContentState<QuranSurahContent>> getSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
    required int expectedAyahCount,
    required bool allowNetwork,
    bool refresh = false,
  }) => throw UnimplementedError();
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
