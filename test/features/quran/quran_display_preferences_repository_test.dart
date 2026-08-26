import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/features/quran/data/quran_display_preferences_repository.dart';
import 'package:murajaah/features/quran/domain/quran_display_preferences.dart';

void main() {
  test('Quran display layers default on and persist atomically', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = QuranDisplayPreferencesRepository(
      AppSettingsRepository(database),
    );

    expect(await repository.load(), QuranDisplayPreferences.defaults);

    const saved = QuranDisplayPreferences(
      showArabic: false,
      showTransliteration: true,
      showTranslation: false,
    );
    await repository.save(saved, updatedAtUtc: DateTime.utc(2026, 8, 25, 12));

    expect(await repository.load(), saved);
    expect(
      await AppSettingsRepository(
        database,
      ).getString(QuranDisplayPreferencesRepository.settingKey),
      '{"schemaVersion":1,"showArabic":false,'
      '"showTransliteration":true,"showTranslation":false}',
    );
  });

  test('malformed or unknown display settings fail closed', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(database);
    final repository = QuranDisplayPreferencesRepository(settings);

    await settings.setString(
      QuranDisplayPreferencesRepository.settingKey,
      '{"schemaVersion":2}',
      updatedAtUtc: DateTime.utc(2026, 8, 25),
    );

    await expectLater(repository.load(), throwsStateError);
  });
}
