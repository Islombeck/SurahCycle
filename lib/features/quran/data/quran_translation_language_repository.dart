import '../../../core/data/repositories/settings_repository.dart';

/// Stores the language whose translation catalog the user wants to browse.
///
/// This is deliberately independent from both the application locale and the
/// pinned [QuranTranslationSelection]. Changing it must never select, clear, or
/// replace a theological translation.
final class QuranTranslationLanguageRepository {
  const QuranTranslationLanguageRepository(this.settings);

  static const String settingKey = 'quran.translation.language.v1';
  static const String russian = 'ru';
  static const String uzbek = 'uz';
  static const List<String> supportedLanguageCodes = <String>[russian, uzbek];

  final AppSettingsRepository settings;

  Future<String?> getSelected() async {
    final languageCode = await settings.getString(settingKey);
    _validateStored(languageCode);
    return languageCode;
  }

  Stream<String?> watchSelected() async* {
    yield await getSelected();
    yield* settings.watchString(settingKey).map((languageCode) {
      _validateStored(languageCode);
      return languageCode;
    });
  }

  Future<void> save(String languageCode, {required DateTime updatedAtUtc}) {
    requireSupported(languageCode);
    return settings.setString(
      settingKey,
      languageCode,
      updatedAtUtc: updatedAtUtc,
    );
  }

  static bool isSupported(String? languageCode) =>
      supportedLanguageCodes.contains(languageCode);

  static void requireSupported(String languageCode) {
    if (!isSupported(languageCode)) {
      throw ArgumentError.value(
        languageCode,
        'languageCode',
        'Only audited Quran translation languages are supported.',
      );
    }
  }

  static void _validateStored(String? languageCode) {
    if (languageCode != null && !isSupported(languageCode)) {
      throw StateError(
        'Stored Quran translation language "$languageCode" is unsupported.',
      );
    }
  }
}

/// Resolves which catalog to show without mutating any persisted state.
///
/// An explicit catalog-language setting wins. Existing translation selections
/// then preserve their own language across UI-locale changes. The UI locale is
/// only a suggestion when neither of those choices exists.
String resolveQuranTranslationLanguage({
  required String uiLanguageCode,
  String? explicitlySelectedLanguageCode,
  String? selectedTranslationLanguageCode,
}) {
  if (QuranTranslationLanguageRepository.isSupported(
    explicitlySelectedLanguageCode,
  )) {
    return explicitlySelectedLanguageCode!;
  }
  if (QuranTranslationLanguageRepository.isSupported(
    selectedTranslationLanguageCode,
  )) {
    return selectedTranslationLanguageCode!;
  }
  if (QuranTranslationLanguageRepository.isSupported(uiLanguageCode)) {
    return uiLanguageCode;
  }
  return QuranTranslationLanguageRepository.russian;
}
