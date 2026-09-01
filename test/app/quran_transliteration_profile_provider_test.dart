import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default profile wires exact Tanzil text into Quran readings', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        quranContentRepositoryProvider.overrideWithValue(
          const UnavailableQuranContentRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(selectedQuranTransliterationProfileProvider.future),
      QuranTransliterationProfileRegistry.tanzilLatin,
    );
    final tanzil = container.read(
      tanzilEnglishTransliterationRepositoryProvider,
    );
    final effective = container.read(quranTransliterationRepositoryProvider);
    final readings = container.read(quranReadingRepositoryProvider);

    expect(effective, same(tanzil));
    expect(readings.transliterations, same(tanzil));
    final exact = await tanzil.getAyah(surahNumber: 1, ayahNumber: 1);
    final reading = await readings.getSurah(surahNumber: 1, ayahCount: 7);
    expect(reading.ayah(1).transliteration, exact.exactText);
    expect(reading.transliterationSource, exact.source);
  });

  test('controller persists only an available profile', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(database);
    final now = DateTime.utc(2026, 9, 1, 9, 30);
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        timeProviderProvider.overrideWithValue(_FixedTimeProvider(now)),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      quranTransliterationProfileControllerProvider,
    );

    expect(
      () => controller.select(
        QuranTransliterationProfileRegistry.cyrillicUnavailable,
      ),
      throwsArgumentError,
    );
    await controller.select(QuranTransliterationProfileRegistry.tanzilLatin);

    expect(
      await settings.getString(
        QuranTransliterationProfileSelectionRepository.settingKey,
      ),
      QuranTransliterationProfileRegistry.tanzilLatinId,
    );
    final row =
        await (database.select(database.appSettings)..where(
              (entry) => entry.key.equals(
                QuranTransliterationProfileSelectionRepository.settingKey,
              ),
            ))
            .getSingle();
    expect(row.updatedAtUtc.toUtc(), now);
  });

  test('unavailable profile cannot leak a synthetic repository', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        selectedQuranTransliterationProfileProvider.overrideWith(
          (ref) => Stream<QuranTransliterationProfile>.value(
            QuranTransliterationProfileRegistry.cyrillicUnavailable,
          ),
        ),
        quranContentRepositoryProvider.overrideWithValue(
          const UnavailableQuranContentRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedQuranTransliterationProfileProvider.future);

    expect(container.read(quranTransliterationRepositoryProvider), isNull);
    expect(
      container.read(quranReadingRepositoryProvider).transliterations,
      isNull,
    );
  });
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
