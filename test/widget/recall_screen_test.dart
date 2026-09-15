import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/learning/application/recall_controller.dart';
import 'package:murajaah/features/learning/presentation/recall_screen.dart';
import 'package:murajaah/features/quran/quran.dart';
import 'package:murajaah/l10n/app_localizations.dart';

/// The screen is where the rule is easiest to break by accident, so the order
/// is pinned here too: no grade button exists until the ayah is revealed.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    quranCacheDatabase = QuranCacheDatabase(NativeDatabase.memory());
    await SurahRepository(database).upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlas',
          ayahCount: 4,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
  });

  tearDown(() async {
    await database.close();
    await quranCacheDatabase.close();
  });

  const request = RecallRequest(
    surahId: 'surah-112',
    surahNumber: 112,
    surahAyahCount: 4,
    ayahStart: 1,
    ayahEnd: 2,
    learningCycle: 1,
    source: RecallSource.learning,
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(
            _FixedTimeProvider(DateTime.utc(2026, 9, 15, 5)),
          ),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 9, 15)),
          ),
          // The reveal gate is what this suite is about. Real Quran content
          // is assembled and verified by its own tests; here it would only
          // add a translation warm-up and its timers.
          quranReadingSurahProvider.overrideWith(
            (ref, request) async => _fixtureSurah(request),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: <LocalizationsDelegate<Object?>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecallScreen(request: request, surahTitle: 'Al-Ikhlas'),
        ),
      ),
    );
    await tester.pump();
  }

  /// Tears the tree down inside the test body so drift's stream cleanup timer
  /// fires before the framework checks for pending timers.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var index = 0; index < 5; index += 1) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('no grade is offered before the ayah is revealed', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey<String>('recall-hidden')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('recall-reveal')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('recall-grade-recalled')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('recall-grade-mistake')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('recall-grade-not-recalled')),
      findsNothing,
    );
    await finish(tester);
  });

  testWidgets('revealing swaps the hidden card for the grades', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('recall-reveal')));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('recall-hidden')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('recall-revealed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('recall-grade-recalled')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('recall-reveal')), findsNothing);
    await finish(tester);
  });

  testWidgets('a grade is stored and the next ayah is hidden again', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('recall-reveal')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('recall-grade-mistake')),
    );
    await tester.pump();
    await tester.pump();

    final stored = await RecallRepository(database).getHistory();
    expect(stored, hasLength(1));
    expect(stored.single.ayahStart, 1);
    expect(stored.single.result, RecallResult.recalledWithMistake);
    expect(find.byKey(const ValueKey<String>('recall-hidden')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('skipping moves on without storing anything', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey<String>('recall-skip')));
    await tester.pump();

    expect(await RecallRepository(database).getHistory(), isEmpty);
    expect(find.byKey(const ValueKey<String>('recall-hidden')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the summary appears only after the last ayah', (tester) async {
    await pumpScreen(tester);

    for (var index = 0; index < 2; index += 1) {
      expect(
        find.byKey(const ValueKey<String>('recall-summary')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey<String>('recall-reveal')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('recall-grade-recalled')),
      );
      await tester.pump();
      await tester.pump();
    }

    expect(
      find.byKey(const ValueKey<String>('recall-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('recall-reveal')), findsNothing);
    expect(await RecallRepository(database).getHistory(), hasLength(2));
    await finish(tester);
  });
}

/// Deliberately not Arabic: a fixture must never stand in for scripture.
QuranReadingSurah _fixtureSurah(QuranReadingRequest request) =>
    QuranReadingSurah(
      surahNumber: request.surahNumber,
      ayahs: <QuranReadingAyah>[
        for (var number = 1; number <= request.ayahCount; number += 1)
          QuranReadingAyah(
            surahNumber: request.surahNumber,
            ayahNumber: number,
            arabicText: 'fixture-ayah-$number',
          ),
      ],
      translationSelection: null,
      translationFromCache: null,
      translationIssue: null,
      transliterationSource: null,
      transliterationIssueCode: null,
    );

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
