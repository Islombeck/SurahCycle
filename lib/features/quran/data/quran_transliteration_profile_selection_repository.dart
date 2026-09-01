import '../../../core/data/repositories/settings_repository.dart';
import '../domain/quran_transliteration_profile.dart';

/// Persists the stable ID of the selected, bundled transliteration profile.
final class QuranTransliterationProfileSelectionRepository {
  const QuranTransliterationProfileSelectionRepository(
    this.settings, {
    this.registry = const QuranTransliterationProfileRegistry(),
  });

  static const String settingKey = 'quran.transliteration.profile.v1';

  final AppSettingsRepository settings;
  final QuranTransliterationProfileRegistry registry;

  Future<QuranTransliterationProfile> loadSelected() async {
    final id = await settings.getString(settingKey);
    return id == null ? registry.defaultProfile : registry.requireById(id);
  }

  Stream<QuranTransliterationProfile> watchSelected() async* {
    yield await loadSelected();
    yield* settings
        .watchString(settingKey)
        .map(
          (id) =>
              id == null ? registry.defaultProfile : registry.requireById(id),
        );
  }

  Future<void> save(
    QuranTransliterationProfile profile, {
    required DateTime updatedAtUtc,
  }) {
    final canonical = registry.requireById(profile.id);
    if (!canonical.isAvailableOffline) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        canonical.unavailabilityExplanation,
      );
    }
    return settings.setString(
      settingKey,
      canonical.id,
      updatedAtUtc: updatedAtUtc,
    );
  }
}
