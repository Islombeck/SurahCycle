import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'surah picker opens plan editor and persists a custom chunked target',
    (tester) async {
      final fixture = await _LearningWidgetFixture.create();
      addTearDown(fixture.close);
      final surah = SurahDescriptor(
        id: 'surah-78',
        surahNumber: 78,
        officialName: 'An-Naba',
        ayahCount: 40,
      );
      await fixture.surahs.upsertCatalog(<SurahDescriptor>[surah]);

      await fixture.pumpApp(tester);
      await _openLearningTab(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Start learning'));
      await tester.pumpAndSettle();

      expect(find.text('Select a surah'), findsOneWidget);
      await tester.tap(find.text('An-Naba'));
      await tester.pumpAndSettle();

      final planSelector = find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<LearningPlanKind>,
      );
      expect(planSelector, findsOneWidget);
      expect(
        find.text(
          'Chunks are usually easier for a long surah. '
          'You can change this choice.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: planSelector, matching: find.text('In chunks')),
      );
      await tester.pump();

      for (final size in <int>[3, 5, 7, 10]) {
        expect(find.widgetWithText(ChoiceChip, '$size ayahs'), findsOneWidget);
      }
      final preset = find.widgetWithText(ChoiceChip, '7 ayahs');
      await tester.tap(preset);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(preset).selected, isTrue);

      final rangeSelectors = find.byType(DropdownButtonFormField<int>);
      expect(rangeSelectors, findsNWidgets(2));
      tester
          .widget<DropdownButtonFormField<int>>(rangeSelectors.at(0))
          .onChanged!(2);
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>).at(1),
          )
          .onChanged!(12);
      await tester.pump();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Custom size'));
      await tester.pump();
      final customSize = find.widgetWithText(TextField, 'Block size');
      expect(customSize, findsOneWidget);
      await tester.enterText(customSize, '4');
      await tester.pump();

      final confirm = find.widgetWithText(FilledButton, 'Confirm');
      await tester.ensureVisible(confirm);
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await _pumpUntil(
        tester,
        () async => await fixture.learning.getBySurahId(surah.id) != null,
      );

      final saved = await fixture.learning.getBySurahId(surah.id);
      expect(saved, isNotNull);
      expect(saved!.plan.kind, LearningPlanKind.chunked);
      expect(saved.plan.targetStartAyah, 2);
      expect(saved.plan.targetEndAyah, 12);
      expect(saved.plan.blockSize, 4);
      expect(saved.stage, saved.plan.stages.first);
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets(
    'plan change requires confirmation and records preserved-history cycle',
    (tester) async {
      final fixture = await _LearningWidgetFixture.create();
      addTearDown(fixture.close);
      final surah = SurahDescriptor(
        id: 'surah-112',
        surahNumber: 112,
        officialName: 'Al-Ikhlas',
        ayahCount: 4,
      );
      final originalPlan = LearningPlan.classicCumulative(
        targetStartAyah: 1,
        targetEndAyah: surah.ayahCount,
      );
      final original = LearningSurahState(
        id: 'learning-112',
        surahId: surah.id,
        ayahCount: surah.ayahCount,
        plan: originalPlan,
        stage: originalPlan.stages[2],
        lastLearningActivityAtUtc: fixture.now,
      );
      await fixture.surahs.upsertCatalog(<SurahDescriptor>[surah]);
      await fixture.learning.saveState(original);

      await fixture.pumpApp(tester);
      await _openLearningTab(tester);
      await _pumpUntil(
        tester,
        () async => find
            .byKey(const ValueKey<String>('learning-surah-surah-112'))
            .evaluate()
            .isNotEmpty,
      );

      await tester.tap(find.byTooltip('Change plan'));
      await _pumpUntil(
        tester,
        () async => find
            .byWidgetPredicate(
              (widget) => widget is SegmentedButton<LearningPlanKind>,
            )
            .evaluate()
            .isNotEmpty,
      );
      final planSelector = find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<LearningPlanKind>,
      );
      tester
          .widget<SegmentedButton<LearningPlanKind>>(planSelector)
          .onSelectionChanged!(<LearningPlanKind>{LearningPlanKind.chunked});
      await tester.pump();
      final blockSize = find.widgetWithText(ChoiceChip, '3 ayahs');
      tester.widget<ChoiceChip>(blockSize).onSelected!(true);
      await tester.pump();
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
          .onPressed!();
      await _pumpUntil(
        tester,
        () async => find.text('Start a new cycle?').evaluate().isNotEmpty,
      );

      expect(find.text('Start a new cycle?'), findsOneWidget);
      expect(
        find.text(
          'Current progress will restart with the new plan. '
          'Learning history will be preserved.',
        ),
        findsOneWidget,
      );
      expect(await fixture.learning.getById(original.id), original);
      expect(await fixture.learning.getEvents(original.id), isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await _pumpUntil(tester, () async {
        final state = await fixture.learning.getById(original.id);
        return state?.learningCycle == 2;
      });

      final changed = await fixture.learning.getById(original.id);
      expect(changed, isNotNull);
      expect(changed!.plan.kind, LearningPlanKind.chunked);
      expect(changed.plan.blockSize, 3);
      expect(changed.stage, changed.plan.stages.first);
      expect(changed.learningCycle, 2);
      final events = await fixture.learning.getEvents(original.id);
      expect(events, hasLength(1));
      expect(events.single.type, LearningEventType.planChanged);
      expect(events.single.reason, 'user_changed_learning_plan');
      expect(events.single.fromPlan, originalPlan);
      expect(events.single.toPlan, changed.plan);
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets(
    'partial target completion never offers or creates whole-surah mastery',
    (tester) async {
      final fixture = await _LearningWidgetFixture.create();
      addTearDown(fixture.close);
      final surah = SurahDescriptor(
        id: 'surah-107',
        surahNumber: 107,
        officialName: 'Al-Maun',
        ayahCount: 7,
      );
      final partialPlan = LearningPlan.classicCumulative(
        targetStartAyah: 2,
        targetEndAyah: 3,
      );
      final partial = LearningSurahState(
        id: 'learning-107',
        surahId: surah.id,
        ayahCount: surah.ayahCount,
        plan: partialPlan,
        stage: partialPlan.stages.last,
        lastLearningActivityAtUtc: fixture.now,
      );
      await fixture.surahs.upsertCatalog(<SurahDescriptor>[surah]);
      await fixture.learning.saveState(partial);

      await fixture.pumpApp(tester);
      await _openLearningTab(tester);
      await _pumpUntil(
        tester,
        () async => find
            .byKey(const ValueKey<String>('learned-surah-107'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('learned-surah-107')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('learned-surah-107')));
      await _pumpUntil(
        tester,
        () async => find.text('Range completed').evaluate().isNotEmpty,
      );

      expect(find.text('Range completed'), findsOneWidget);
      expect(
        find.text(
          'The learned range was saved. '
          'The whole surah was not marked as mastered.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add to rotation?'), findsNothing);
      expect(find.text('Complete and add'), findsNothing);
      expect(find.text('Complete without adding'), findsNothing);
      expect((await fixture.surahs.getCatalog()).single.isMastered, isFalse);

      await tester.tap(find.widgetWithText(FilledButton, 'Complete learning'));
      await _pumpUntil(tester, () async {
        final state = await fixture.learning.getById(partial.id);
        return state?.status == LearningStatus.completed;
      });

      expect((await fixture.surahs.getCatalog()).single.isMastered, isFalse);
      expect((await fixture.surahs.getRotationSnapshot()).surahs, isEmpty);
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets(
    'remove from mastered confirms history preservation and archives mastery',
    (tester) async {
      final fixture = await _LearningWidgetFixture.create();
      addTearDown(fixture.close);
      final surah = SurahDescriptor(
        id: 'surah-103',
        surahNumber: 103,
        officialName: 'Al-Asr',
        ayahCount: 3,
      );
      await fixture.surahs.upsertCatalog(<SurahDescriptor>[surah]);
      await fixture.surahs.addMastered(surah.id);

      await fixture.pumpApp(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('primary-tab-surahs')),
      );
      await _pumpUntil(
        tester,
        () async => find
            .byKey(const ValueKey<String>('mastered-surah-103'))
            .evaluate()
            .isNotEmpty,
      );

      final tile = find.byKey(const ValueKey<String>('mastered-surah-103'));
      await tester.tap(
        find.descendant(
          of: tile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from mastered').last);
      await tester.pumpAndSettle();

      expect(find.text('Return this surah to learning?'), findsOneWidget);
      expect(
        find.text(
          'The surah will leave rotation. History, statistics, segmentation, '
          'and previous scores will remain.',
        ),
        findsOneWidget,
      );
      final beforeConfirm = (await fixture.surahs.getRotationSnapshot())
          .surahById(surah.id);
      expect(beforeConfirm.isCurrentlyMastered, isTrue);
      expect(beforeConfirm.isActive, isTrue);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Remove from mastered'),
      );
      await _pumpUntil(tester, () async {
        final catalog = await fixture.surahs.getCatalog();
        return catalog.single.isMastered == false;
      });

      final archived = (await fixture.surahs.getRotationSnapshot()).surahById(
        surah.id,
      );
      expect(archived.isCurrentlyMastered, isFalse);
      expect(archived.isActive, isFalse);
      expect(archived.rotationScheme, beforeConfirm.rotationScheme);
      expect(archived.totalRecitations, beforeConfirm.totalRecitations);
      await _disposeWidgetTree(tester);
    },
  );
}

Future<void> _openLearningTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('primary-tab-learning')));
  await _pumpUntil(
    tester,
    () async => find.text('Learning').evaluate().isNotEmpty,
  );
}

final class _LearningWidgetFixture {
  _LearningWidgetFixture._({
    required this.database,
    required this.quranCacheDatabase,
    required this.now,
  }) : surahs = SurahRepository(database),
       learning = LearningRepository(database);

  static Future<_LearningWidgetFixture> create() async {
    final fixture = _LearningWidgetFixture._(
      database: AppDatabase(NativeDatabase.memory()),
      quranCacheDatabase: QuranCacheDatabase(NativeDatabase.memory()),
      now: DateTime.utc(2026, 8, 27, 10),
    );
    await fixture.surahs.getRotationSnapshot();
    return fixture;
  }

  final AppDatabase database;
  final QuranCacheDatabase quranCacheDatabase;
  final DateTime now;
  final SurahRepository surahs;
  final LearningRepository learning;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(_FixedTimeProvider(now)),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 8, 27)),
          ),
          prayerContextResolutionProvider.overrideWith(
            (ref) => Stream<PrayerContextResolution>.value(
              PrayerContextResolution(
                status: PrayerContextResolutionStatus.manual,
                context: PrayerContext(prayerType: PrayerType.fajr),
              ),
            ),
          ),
          prayerTodayScheduleProvider.overrideWith(
            (ref) async => throw StateError('Fixture schedule unavailable.'),
          ),
        ],
        child: const MurajaahApp(),
      ),
    );
    await _pumpUntil(
      tester,
      () async => find
          .byKey(const ValueKey<String>('home-screen'))
          .evaluate()
          .isNotEmpty,
    );
  }

  Future<void> close() async {
    await database.close();
    await quranCacheDatabase.close();
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Future<bool> Function() condition,
) async {
  for (var attempt = 0; attempt < 150; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (await condition()) return;
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .join(' | ');
  throw TestFailure('Timed out. Visible text: $visibleText');
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

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this.value);

  final LocalDate value;

  @override
  LocalDate today() => value;
}
