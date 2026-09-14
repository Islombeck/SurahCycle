import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/settings/presentation/prayer_routine_settings_card.dart';
import 'package:murajaah/l10n/app_localizations.dart';

void main() {
  testWidgets('adds a custom zero-slot part and edits every persisted field', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PrayerRoutineRepository(database);

    await _pumpCard(tester, database);
    await _expandCard(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('add-prayer-routine-part')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('prayer-part-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('prayer-part-custom-label')),
      'Before Fard',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('prayer-part-rakaat-count')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('prayer-part-slot-count')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-prayer-part')));
    await tester.pumpAndSettle();

    var template = await repository.getTemplate(PrayerType.fajr);
    expect(template.revision, 2);
    expect(template.parts, hasLength(1));
    final added = template.parts.single;
    expect(added.kind, PrayerRoutinePartKind.custom);
    expect(added.customLabel, 'Before Fard');
    expect(added.rakaatCount, 4);
    expect(added.requiredSurahSlots, 0);
    expect(added.allowsFollowingImam, isFalse);
    expect(find.text('Before Fard'), findsOneWidget);
    expect(find.text('4 rakaats · 0 surah slots'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey<String>('prayer-routine-part-${added.id}')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('prayer-part-custom-label')),
      'After Fard',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('prayer-part-rakaat-count')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('prayer-part-slot-count')),
      '1',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-prayer-part')));
    await tester.pumpAndSettle();

    template = await repository.getTemplate(PrayerType.fajr);
    expect(template.revision, 3);
    expect(template.parts.single.id, added.id);
    expect(template.parts.single.stableKey, added.stableKey);
    expect(template.parts.single.customLabel, 'After Fard');
    expect(template.parts.single.rakaatCount, 3);
    expect(template.parts.single.requiredSurahSlots, 1);
    expect(find.text('After Fard'), findsOneWidget);
    expect(find.text('3 rakaats · 1 surah slots'), findsOneWidget);

    await _disposeWidgetTree(tester);
  });

  testWidgets(
    'reorders parts, confirms deletion, and can disable and re-enable a template',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PrayerRoutineRepository(database);
      final initial = await repository.getTemplate(PrayerType.fajr);
      await repository.replaceTemplate(
        prayerType: PrayerType.fajr,
        expectedRevision: initial.revision,
        displayName: initial.displayName,
        enabled: true,
        parts: <PrayerRoutinePartTemplate>[
          PrayerRoutinePartTemplate(
            id: 'fajr-sunnah',
            stableKey: 'sunnah-before',
            orderIndex: 0,
            kind: PrayerRoutinePartKind.sunnah,
            rakaatCount: 2,
            requiredSurahSlots: 2,
          ),
          PrayerRoutinePartTemplate(
            id: 'fajr-fard',
            stableKey: 'fard',
            orderIndex: 1,
            kind: PrayerRoutinePartKind.fard,
            rakaatCount: 2,
            requiredSurahSlots: 2,
          ),
        ],
      );

      await _pumpCard(tester, database);
      await _expandCard(tester);

      var enabledTile = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey<String>('prayer-routine-enabled')),
      );
      expect(enabledTile.value, isTrue);
      await tester.tap(
        find.byKey(const ValueKey<String>('prayer-routine-enabled')),
      );
      await tester.pumpAndSettle();
      expect((await repository.getTemplate(PrayerType.fajr)).enabled, isFalse);

      enabledTile = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey<String>('prayer-routine-enabled')),
      );
      expect(enabledTile.value, isFalse);
      await tester.tap(
        find.byKey(const ValueKey<String>('prayer-routine-enabled')),
      );
      await tester.pumpAndSettle();
      expect((await repository.getTemplate(PrayerType.fajr)).enabled, isTrue);

      final list = tester.widget<ReorderableListView>(
        find.byKey(const ValueKey<String>('prayer-routine-parts-fajr')),
      );
      list.onReorderItem!(0, 2);
      await tester.pumpAndSettle();
      var template = await repository.getTemplate(PrayerType.fajr);
      expect(template.parts.map((part) => part.id), <String>[
        'fajr-fard',
        'fajr-sunnah',
      ]);
      expect(template.parts.map((part) => part.orderIndex), <int>[0, 1]);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('delete-prayer-routine-part-fajr-fard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete prayer part?'), findsOneWidget);
      expect(
        find.text('Delete “Fard”? Existing prayer sessions will not change.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('cancel-delete-prayer-part')),
      );
      await tester.pumpAndSettle();
      expect(
        (await repository.getTemplate(PrayerType.fajr)).parts,
        hasLength(2),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('delete-prayer-routine-part-fajr-fard'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('confirm-delete-prayer-part')),
      );
      await tester.pumpAndSettle();
      template = await repository.getTemplate(PrayerType.fajr);
      expect(template.parts, hasLength(1));
      expect(template.parts.single.id, 'fajr-sunnah');
      expect(template.parts.single.orderIndex, 0);

      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('an edit still applies when the shown revision is stale', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PrayerRoutineRepository(database);

    await _pumpCard(tester, database);
    await _expandCard(tester);

    // The card is now showing a template snapshot. Something else commits a
    // change before the user's own action reaches the repository, which is
    // exactly what happens while the watch stream has not caught up yet.
    final shown = await repository.getTemplate(PrayerType.fajr);
    await repository.addPart(
      prayerType: PrayerType.fajr,
      expectedRevision: shown.revision,
      part: PrayerRoutinePartTemplate(
        id: 'external',
        stableKey: 'part:external',
        orderIndex: 0,
        kind: PrayerRoutinePartKind.fard,
        rakaatCount: 2,
        requiredSurahSlots: 2,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('add-prayer-routine-part')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('save-prayer-part')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    final stored = await repository.getTemplate(PrayerType.fajr);
    expect(
      stored.parts,
      hasLength(2),
      reason: 'the stale revision must not discard the user action',
    );
    expect(stored.parts.first.id, 'external');

    await _disposeWidgetTree(tester);
  });

  testWidgets('a user-created Jumuah Fard part allows following the imam', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PrayerRoutineRepository(database);

    await _pumpCard(tester, database);
    await _expandCard(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('prayer-routine-prayer-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jumuah').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('add-prayer-routine-part')),
    );
    await tester.pumpAndSettle();

    final followImam = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey<String>('prayer-part-follow-imam')),
    );
    expect(followImam.value, isTrue);
    await tester.tap(find.byKey(const ValueKey<String>('save-prayer-part')));
    await tester.pumpAndSettle();

    final template = await repository.getTemplate(PrayerType.jumuah);
    expect(template.parts, hasLength(1));
    expect(template.parts.single.kind, PrayerRoutinePartKind.fard);
    expect(template.parts.single.rakaatCount, 2);
    expect(template.parts.single.requiredSurahSlots, 2);
    expect(template.parts.single.allowsFollowingImam, isTrue);
    expect(
      template.parts.single.defaultCompletionMode,
      PrayerPartCompletionMode.recitations,
    );

    await _disposeWidgetTree(tester);
  });
}

Future<void> _pumpCard(WidgetTester tester, AppDatabase database) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: PrayerRoutineSettingsCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expandCard(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('prayer-routine-settings')),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey<String>('prayer-routine-prayer-selector')),
    findsOneWidget,
  );
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}
