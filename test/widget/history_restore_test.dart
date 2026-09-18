import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/history/presentation/history_screen.dart';
import 'package:murajaah/l10n/app_localizations.dart';

/// Against a real database rather than a stubbed stream, because the claim
/// worth testing is that the button actually puts the recitation back — and
/// because the rule this session earned is to prove a screen that writes with a
/// test rather than by tapping through the owner's own history.
///
/// Pumped with `_pumpUntil` and torn down with `_disposeWidgetTree`, the shape
/// `account_route_test.dart` already proved. Neither is decoration:
/// `pumpAndSettle` never settles against a stream that re-queries on every read,
/// and a tree left for the framework to dispose fails with "a Timer is still
/// pending" because cancelling a Drift stream schedules one.
void main() {
  late AppDatabase database;
  late RecitationRepository recitations;
  late SurahRecitationEvent event;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    await surahs.upsertCatalog(
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
    await surahs.addMastered('surah-112');
    event = SurahRecitationEvent(
      id: 'restorable',
      surahId: 'surah-112',
      prayerContext: PrayerContext(prayerType: PrayerType.asr),
      createdAtUtc: DateTime.utc(2026, 9, 17, 11, 58),
      localDate: LocalDate(2026, 9, 17),
      rakaatSpanCount: 1,
    );
    await recitations.register(event);
  });

  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HistoryScreen(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(HistoryScreen).evaluate().isNotEmpty,
    );
  }

  Finder toggle() =>
      find.byKey(const ValueKey<String>('history-toggle-deleted'));
  Finder restore() =>
      find.byKey(const ValueKey<String>('history-restore-restorable'));
  Finder entry() =>
      find.byKey(const ValueKey<String>('history-entry-restorable'));
  Finder deleteButton() =>
      find.byKey(const ValueKey<String>('history-delete-restorable'));

  testWidgets('a deleted entry is hidden until it is asked for', (
    tester,
  ) async {
    await recitations.deleteRecitation(
      event.id,
      deletedAtUtc: DateTime.utc(2026, 9, 17, 12),
    );

    await pump(tester);
    await _pumpFrames(tester, 10);
    expect(
      entry(),
      findsNothing,
      reason: 'the default history is what counts, and this no longer counts',
    );

    await tester.tap(toggle());
    await _pumpUntil(tester, () => entry().evaluate().isNotEmpty);

    expect(
      find.byKey(const ValueKey<String>('history-deleted-restorable')),
      findsOneWidget,
      reason: 'it has to say when it was withdrawn, not merely look faded',
    );
    await _disposeWidgetTree(tester);
  });

  testWidgets('a live entry offers deletion, a deleted one offers restore', (
    tester,
  ) async {
    await pump(tester);
    await _pumpUntil(tester, () => deleteButton().evaluate().isNotEmpty);
    expect(restore(), findsNothing);

    await recitations.deleteRecitation(
      event.id,
      deletedAtUtc: DateTime.utc(2026, 9, 17, 12),
    );
    await tester.tap(toggle());
    await _pumpUntil(tester, () => restore().evaluate().isNotEmpty);

    expect(
      deleteButton(),
      findsNothing,
      reason: 'deleting something already deleted has no meaning',
    );
    await _disposeWidgetTree(tester);
  });

  testWidgets('tapping restore puts the recitation back', (tester) async {
    await recitations.deleteRecitation(
      event.id,
      deletedAtUtc: DateTime.utc(2026, 9, 17, 12),
    );

    await pump(tester);
    await tester.tap(toggle());
    await _pumpUntil(tester, () => restore().evaluate().isNotEmpty);
    await tester.tap(restore());
    await _pumpUntil(tester, () => deleteButton().evaluate().isNotEmpty);

    final live = await recitations.getHistory();
    expect(live, hasLength(1));
    expect(live.single.event.id, 'restorable');
    expect(
      live.single.event.localDate,
      LocalDate(2026, 9, 17),
      reason: 'it returns to the day it was prayed, not to today',
    );
    expect(live.single.isDeleted, isFalse);
    expect(
      (await recitations.getStats()).total,
      1,
      reason: 'a restored recitation counts again, everywhere',
    );
    await _disposeWidgetTree(tester);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  throw TestFailure('Condition was not met after 120 pumped frames.');
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}
