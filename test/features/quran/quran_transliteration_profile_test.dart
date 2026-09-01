import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  group('QuranTransliterationProfileRegistry', () {
    const registry = QuranTransliterationProfileRegistry();

    test('registers exact bundled Tanzil Latin metadata', () {
      final profile = registry.defaultProfile;

      expect(profile.id, QuranTransliterationProfileRegistry.tanzilLatinId);
      expect(profile.displayName, 'Latin — Tanzil');
      expect(profile.script, QuranTransliterationScript.latin);
      expect(profile.languageCode, 'en');
      expect(profile.source, TanzilEnglishTransliterationRepository.sourceId);
      expect(profile.version, TanzilEnglishTransliterationRepository.version);
      expect(
        profile.attribution,
        TanzilEnglishTransliterationRepository.attribution,
      );
      expect(
        profile.availability,
        QuranTransliterationProfileAvailability.bundledOffline,
      );
      expect(profile.isAvailableOffline, isTrue);
      expect(profile.unavailabilityExplanation, isNull);
    });

    test('registers Cyrillic as explicitly unavailable', () {
      const profile = QuranTransliterationProfileRegistry.cyrillicUnavailable;

      expect(profile.displayName, isNotEmpty);
      expect(profile.script, QuranTransliterationScript.cyrillic);
      expect(
        profile.availability,
        QuranTransliterationProfileAvailability.unavailable,
      );
      expect(profile.isAvailableOffline, isFalse);
      expect(profile.source, isNull);
      expect(profile.version, isNull);
      expect(profile.attribution, isNull);
      expect(profile.unavailabilityExplanation, contains('No verified'));
      expect(
        profile.unavailabilityExplanation,
        contains('does not automatically'),
      );
    });

    test('has stable unique IDs and rejects unknown profiles', () {
      expect(
        QuranTransliterationProfileRegistry.profiles
            .map((profile) => profile.id)
            .toSet(),
        hasLength(QuranTransliterationProfileRegistry.profiles.length),
      );
      expect(
        registry.byId(QuranTransliterationProfileRegistry.tanzilLatinId),
        QuranTransliterationProfileRegistry.tanzilLatin,
      );
      expect(registry.byId('unknown'), isNull);
      expect(() => registry.requireById('unknown'), throwsStateError);
    });
  });

  group('QuranTransliterationProfileSelectionRepository', () {
    test('defaults to Latin and persists its stable profile ID', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = AppSettingsRepository(database);
      final repository = QuranTransliterationProfileSelectionRepository(
        settings,
      );
      final updatedAt = DateTime.utc(2026, 9, 1, 10);

      expect(
        await repository.loadSelected(),
        QuranTransliterationProfileRegistry.tanzilLatin,
      );
      await repository.save(
        QuranTransliterationProfileRegistry.tanzilLatin,
        updatedAtUtc: updatedAt,
      );

      expect(
        await settings.getString(
          QuranTransliterationProfileSelectionRepository.settingKey,
        ),
        QuranTransliterationProfileRegistry.tanzilLatinId,
      );
      expect(
        await repository.loadSelected(),
        QuranTransliterationProfileRegistry.tanzilLatin,
      );
    });

    test('cannot persist unavailable or unknown profiles', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = AppSettingsRepository(database);
      final repository = QuranTransliterationProfileSelectionRepository(
        settings,
      );

      expect(
        () => repository.save(
          QuranTransliterationProfileRegistry.cyrillicUnavailable,
          updatedAtUtc: DateTime.utc(2026, 9, 1),
        ),
        throwsArgumentError,
      );
      await settings.setString(
        QuranTransliterationProfileSelectionRepository.settingKey,
        'unknown-profile',
        updatedAtUtc: DateTime.utc(2026, 9, 1),
      );
      await expectLater(repository.loadSelected(), throwsStateError);
    });
  });
}
