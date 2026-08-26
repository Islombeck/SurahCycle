import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  testWidgets('Settings persists an explicit QuranEnc catalog choice', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final quranCache = QuranCacheDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    addTearDown(quranCache.close);
    await SurahRepository(database).getRotationSnapshot();
    final translation = QuranTranslation(
      source: QuranEncProvider.sourceId,
      key: 'fixture-russian',
      languageCode: 'ru',
      version: '1.2.3',
      title: 'Fixture Russian',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCache),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(
            _FixedTimeProvider(DateTime.utc(2026, 8, 25, 12)),
          ),
          russianQuranTranslationsProvider.overrideWith(
            (ref) async => AvailableQuranContent<List<QuranTranslation>>(
              value: <QuranTranslation>[translation],
              fromCache: false,
            ),
          ),
          prayerTodayScheduleProvider.overrideWith(
            (ref) async => throw StateError('Fixture schedule unavailable.'),
          ),
        ],
        child: const MurajaahApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('primary-tab-settings')),
    );
    await tester.pumpAndSettle();
    await _scrollToTranslationSettings(tester);

    final selector = find.byKey(
      const ValueKey<String>('quran-translation-selector'),
    );
    expect(selector, findsOneWidget);
    expect(
      await QuranTranslationSelectionRepository(
        AppSettingsRepository(database),
      ).getSelected(),
      isNull,
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture Russian · quranenc.com · v1.2.3').last);
    await tester.pumpAndSettle();

    final stored = await QuranTranslationSelectionRepository(
      AppSettingsRepository(database),
    ).getSelected();
    expect(stored, isNotNull);
    expect(stored!.key, translation.key);
    expect(stored.title, translation.title);
    expect(stored.version, translation.version);
    expect(stored.source, QuranEncProvider.sourceId);
    expect(stored.attribution, QuranEncProvider.attribution);
    expect(stored.fetchedAtUtc, DateTime.utc(2026, 8, 25, 12));

    await _disposeWidgetTree(tester);
  });

  testWidgets('selected translation can be cleared with an empty catalog', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await SurahRepository(database).getRotationSnapshot();
    final settings = AppSettingsRepository(database);
    final selections = QuranTranslationSelectionRepository(settings);
    final selected = QuranTranslationSelection.fromCatalog(
      translation: _translation(version: '1.0.0'),
      fetchedAtUtc: DateTime.utc(2026, 8, 24),
      attribution: QuranEncProvider.attribution,
    );
    await selections.save(selected, updatedAtUtc: DateTime.utc(2026, 8, 24));

    await _pumpSettings(
      tester,
      database,
      const AvailableQuranContent<List<QuranTranslation>>(
        value: <QuranTranslation>[],
        fromCache: false,
      ),
    );

    expect(find.textContaining('Fixture Russian'), findsOneWidget);
    final clear = find.byKey(const ValueKey<String>('quran-translation-clear'));
    expect(clear, findsOneWidget);
    await tester.ensureVisible(clear);
    await tester.pump();
    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(await selections.getSelected(), isNull);
    await _disposeWidgetTree(tester);
  });

  testWidgets('translation version update requires an explicit tap', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await SurahRepository(database).getRotationSnapshot();
    final selections = QuranTranslationSelectionRepository(
      AppSettingsRepository(database),
    );
    await selections.save(
      QuranTranslationSelection.fromCatalog(
        translation: _translation(version: '1.0.0'),
        fetchedAtUtc: DateTime.utc(2026, 8, 24),
        attribution: QuranEncProvider.attribution,
      ),
      updatedAtUtc: DateTime.utc(2026, 8, 24),
    );
    final update = _translation(version: '2.0.0');

    await _pumpSettings(
      tester,
      database,
      AvailableQuranContent<List<QuranTranslation>>(
        value: <QuranTranslation>[update],
        fromCache: false,
      ),
    );

    expect((await selections.getSelected())!.version, '1.0.0');
    final updateButton = find.byKey(
      const ValueKey<String>('quran-translation-update'),
    );
    expect(updateButton, findsOneWidget);
    await tester.ensureVisible(updateButton);
    await tester.pump();
    await tester.tap(updateButton);
    await tester.pumpAndSettle();

    expect((await selections.getSelected())!.version, '2.0.0');
    await _disposeWidgetTree(tester);
  });

  testWidgets('malformed saved selection can be cleared', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await SurahRepository(database).getRotationSnapshot();
    final settings = AppSettingsRepository(database);
    await settings.setString(
      QuranTranslationSelectionRepository.settingKey,
      '{malformed',
      updatedAtUtc: DateTime.utc(2026, 8, 24),
    );

    await _pumpSettings(
      tester,
      database,
      const AvailableQuranContent<List<QuranTranslation>>(
        value: <QuranTranslation>[],
        fromCache: false,
      ),
    );

    final clear = find.byKey(const ValueKey<String>('quran-translation-clear'));
    expect(clear, findsOneWidget);
    await tester.ensureVisible(clear);
    await tester.pump();
    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(
      await settings.getString(QuranTranslationSelectionRepository.settingKey),
      isNull,
    );
    await _disposeWidgetTree(tester);
  });
}

QuranTranslation _translation({required String version}) => QuranTranslation(
  source: QuranEncProvider.sourceId,
  key: 'fixture-russian',
  languageCode: 'ru',
  version: version,
  title: 'Fixture Russian',
);

Future<void> _pumpSettings(
  WidgetTester tester,
  AppDatabase database,
  QuranContentState<List<QuranTranslation>> catalog,
) async {
  final quranCache = QuranCacheDatabase(NativeDatabase.memory());
  addTearDown(quranCache.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        quranCacheDatabaseProvider.overrideWithValue(quranCache),
        startupProvider.overrideWith((ref) async {}),
        timeProviderProvider.overrideWithValue(
          _FixedTimeProvider(DateTime.utc(2026, 8, 25, 12)),
        ),
        russianQuranTranslationsProvider.overrideWith((ref) async => catalog),
        prayerTodayScheduleProvider.overrideWith(
          (ref) async => throw StateError('Fixture schedule unavailable.'),
        ),
      ],
      child: const MurajaahApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('primary-tab-settings')));
  await tester.pumpAndSettle();
  await _scrollToTranslationSettings(tester);
}

Future<void> _scrollToTranslationSettings(WidgetTester tester) async {
  final target = find.byKey(
    const ValueKey<String>('quran-translation-settings-card'),
  );
  for (var attempt = 0; attempt < 12; attempt += 1) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  throw TestFailure('Quran translation settings were not built after scroll.');
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Drift cascades zero-duration cleanup timers while watched queries close.
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
