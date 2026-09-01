import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test(
    'persists translation language separately from translation choice',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = AppSettingsRepository(database);
      final languages = QuranTranslationLanguageRepository(settings);
      final selections = QuranTranslationSelectionRepository(settings);

      expect(await languages.getSelected(), isNull);
      expect(await selections.getSelected(), isNull);

      await languages.save('uz', updatedAtUtc: DateTime.utc(2026, 9, 1));

      expect(await languages.getSelected(), 'uz');
      expect(await selections.getSelected(), isNull);
      expect(
        await settings.getString(QuranTranslationLanguageRepository.settingKey),
        'uz',
      );
      expect(
        await settings.getString(
          QuranTranslationSelectionRepository.settingKey,
        ),
        isNull,
      );
    },
  );

  test('rejects unsupported explicit and stored catalog languages', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(database);
    final languages = QuranTranslationLanguageRepository(settings);

    expect(
      () => languages.save('en', updatedAtUtc: DateTime.utc(2026, 9, 1)),
      throwsArgumentError,
    );

    await settings.setString(
      QuranTranslationLanguageRepository.settingKey,
      'en',
      updatedAtUtc: DateTime.utc(2026, 9, 1),
    );
    await expectLater(languages.getSelected(), throwsStateError);
  });

  group('translation-language suggestion', () {
    test('explicit language wins without changing a pinned selection', () {
      expect(
        resolveQuranTranslationLanguage(
          uiLanguageCode: 'ru',
          explicitlySelectedLanguageCode: 'uz',
          selectedTranslationLanguageCode: 'ru',
        ),
        'uz',
      );
    });

    test('pinned translation survives a UI-locale change', () {
      expect(
        resolveQuranTranslationLanguage(
          uiLanguageCode: 'uz',
          selectedTranslationLanguageCode: 'ru',
        ),
        'ru',
      );
      expect(
        resolveQuranTranslationLanguage(
          uiLanguageCode: 'ru',
          selectedTranslationLanguageCode: 'uz',
        ),
        'uz',
      );
    });

    test('UI locale only suggests a language when there is no user choice', () {
      expect(resolveQuranTranslationLanguage(uiLanguageCode: 'uz'), 'uz');
      expect(resolveQuranTranslationLanguage(uiLanguageCode: 'en'), 'ru');
    });
  });
}
