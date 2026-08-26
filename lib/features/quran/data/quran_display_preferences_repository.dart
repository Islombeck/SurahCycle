import 'dart:convert';

import '../../../core/data/repositories/settings_repository.dart';
import '../domain/quran_display_preferences.dart';

/// Persists all Quran presentation switches atomically in one versioned value.
final class QuranDisplayPreferencesRepository {
  const QuranDisplayPreferencesRepository(this.settings);

  static const String settingKey = 'quran_display_preferences_v1';
  static const int schemaVersion = 1;

  final AppSettingsRepository settings;

  Future<QuranDisplayPreferences> load() async {
    final encoded = await settings.getString(settingKey);
    return encoded == null ? QuranDisplayPreferences.defaults : decode(encoded);
  }

  Stream<QuranDisplayPreferences> watch() async* {
    yield await load();
    yield* settings
        .watchString(settingKey)
        .map(
          (encoded) => encoded == null
              ? QuranDisplayPreferences.defaults
              : decode(encoded),
        );
  }

  Future<void> save(
    QuranDisplayPreferences value, {
    required DateTime updatedAtUtc,
  }) => settings.setString(
    settingKey,
    jsonEncode(<String, Object>{
      'schemaVersion': schemaVersion,
      'showArabic': value.showArabic,
      'showTransliteration': value.showTransliteration,
      'showTranslation': value.showTranslation,
    }),
    updatedAtUtc: updatedAtUtc,
  );

  static QuranDisplayPreferences decode(String encoded) {
    final Object? value;
    try {
      value = jsonDecode(encoded);
    } on FormatException catch (error) {
      throw StateError('Malformed Quran display preferences: $error');
    }
    if (value is! Map<String, Object?> ||
        value.length != 4 ||
        value['schemaVersion'] != schemaVersion ||
        value['showArabic'] is! bool ||
        value['showTransliteration'] is! bool ||
        value['showTranslation'] is! bool) {
      throw StateError('Invalid Quran display preferences schema.');
    }
    return QuranDisplayPreferences(
      showArabic: value['showArabic']! as bool,
      showTransliteration: value['showTransliteration']! as bool,
      showTranslation: value['showTranslation']! as bool,
    );
  }
}
