import '../../../core/data/repositories/settings_repository.dart';
import '../domain/quran_translation_selection.dart';

final class QuranTranslationSelectionRepository {
  const QuranTranslationSelectionRepository(this.settings);

  static const String settingKey = 'quran.translation.selection.v1';

  final AppSettingsRepository settings;

  Future<QuranTranslationSelection?> getSelected() async {
    final encoded = await settings.getString(settingKey);
    return encoded == null
        ? null
        : QuranTranslationSelection.fromJsonString(encoded);
  }

  Stream<QuranTranslationSelection?> watchSelected() => settings
      .watchString(settingKey)
      .map(
        (encoded) => encoded == null
            ? null
            : QuranTranslationSelection.fromJsonString(encoded),
      );

  Future<void> save(
    QuranTranslationSelection selection, {
    required DateTime updatedAtUtc,
  }) => settings.setString(
    settingKey,
    selection.toJsonString(),
    updatedAtUtc: updatedAtUtc,
  );

  Future<bool> clear() => settings.remove(settingKey);
}
