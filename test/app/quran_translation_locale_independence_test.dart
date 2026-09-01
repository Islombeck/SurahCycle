import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/quran/quran.dart';
import 'package:murajaah/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Russian selection survives controller and provider recreation',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 9, 1, 9);
      final overrides = <Override>[
        appDatabaseProvider.overrideWithValue(database),
        timeProviderProvider.overrideWithValue(_FixedTimeProvider(now)),
      ];
      final firstContainer = ProviderContainer(overrides: overrides);

      await firstContainer
          .read(quranTranslationSelectionControllerProvider)
          .select(_translation('ru'));

      final stored = await QuranTranslationSelectionRepository(
        AppSettingsRepository(database),
      ).getSelected();
      expect(stored, isNotNull);
      expect(stored!.languageCode, 'ru');
      expect(stored.key, 'fixture-ru');
      expect(stored.fetchedAtUtc, now);

      firstContainer.dispose();
      final recreatedContainer = ProviderContainer(overrides: overrides);
      addTearDown(recreatedContainer.dispose);
      final restored = await recreatedContainer.read(
        selectedQuranTranslationProvider.future,
      );

      expect(restored, stored);
    },
  );

  const crossLocaleCases = <({String ui, String translation})>[
    (ui: 'ru', translation: 'uz'),
    (ui: 'uz', translation: 'ru'),
  ];
  for (final testCase in crossLocaleCases) {
    testWidgets('${testCase.ui.toUpperCase()} UI keeps '
        '${testCase.translation.toUpperCase()} Quran translation', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _saveSelection(database, testCase.translation);

      await _pumpProbe(tester, database: database, locale: Locale(testCase.ui));

      _expectProbe(
        tester,
        uiLanguageCode: testCase.ui,
        translationLanguageCode: testCase.translation,
      );
      expect(
        (await QuranTranslationSelectionRepository(
          AppSettingsRepository(database),
        ).getSelected())!.languageCode,
        testCase.translation,
      );
      await _disposeWidgetTree(tester);
    });
  }

  testWidgets('changing UI locale does not rewrite translation selection', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = AppSettingsRepository(database);
    await _saveSelection(database, 'ru');
    final encodedBefore = await settings.getString(
      QuranTranslationSelectionRepository.settingKey,
    );
    final locale = ValueNotifier<Locale>(const Locale('ru'));
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(database)],
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, child) => _ProbeApp(locale: value),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _expectProbe(tester, uiLanguageCode: 'ru', translationLanguageCode: 'ru');

    locale.value = const Locale('uz');
    await tester.pumpAndSettle();

    _expectProbe(tester, uiLanguageCode: 'uz', translationLanguageCode: 'ru');
    expect(
      await settings.getString(QuranTranslationSelectionRepository.settingKey),
      encodedBefore,
    );
    await _disposeWidgetTree(tester);
  });
}

Future<void> _saveSelection(AppDatabase database, String languageCode) {
  final selected = QuranTranslationSelection.fromCatalog(
    translation: _translation(languageCode),
    fetchedAtUtc: DateTime.utc(2026, 9, 1, 9),
    attribution: QuranEncProvider.attribution,
    sourceUri: Uri.parse('https://quranenc.com/'),
  );
  return QuranTranslationSelectionRepository(
    AppSettingsRepository(database),
  ).save(selected, updatedAtUtc: selected.fetchedAtUtc);
}

QuranTranslation _translation(String languageCode) => QuranTranslation(
  source: QuranEncProvider.sourceId,
  key: 'fixture-$languageCode',
  languageCode: languageCode,
  version: 'test-v1',
  title: 'Fixture ${languageCode.toUpperCase()}',
);

Future<void> _pumpProbe(
  WidgetTester tester, {
  required AppDatabase database,
  required Locale locale,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(database)],
      child: _ProbeApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectProbe(
  WidgetTester tester, {
  required String uiLanguageCode,
  required String translationLanguageCode,
}) {
  final text = tester.widget<Text>(
    find.byKey(const ValueKey<String>('translation-locale-probe')),
  );
  final expectedLabel = lookupAppLocalizations(
    Locale(uiLanguageCode),
  ).quranTranslation;
  expect(
    text.data,
    'ui=$uiLanguageCode;translation=$translationLanguageCode;'
    'label=$expectedLabel',
  );
}

final class _ProbeApp extends StatelessWidget {
  const _ProbeApp({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const Scaffold(body: _TranslationLocaleProbe()),
  );
}

final class _TranslationLocaleProbe extends ConsumerWidget {
  const _TranslationLocaleProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedQuranTranslationProvider);
    return selected.when(
      data: (value) => Text(
        'ui=${Localizations.localeOf(context).languageCode};'
        'translation=${value?.languageCode};'
        'label=${AppLocalizations.of(context).quranTranslation}',
        key: const ValueKey<String>('translation-locale-probe'),
      ),
      error: (error, stackTrace) => Text(
        'error=$error',
        key: const ValueKey<String>('translation-locale-probe'),
      ),
      loading: () => const CircularProgressIndicator(),
    );
  }
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
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
