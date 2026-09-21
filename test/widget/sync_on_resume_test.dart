import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import '../features/prayer_times/prayer_test_fixtures.dart';

/// A sync that only runs when someone opens the account screen is a sync
/// nobody has. Coming back to the app is when a network is most likely to
/// exist and when the user is about to look at their data, so that is when an
/// exchange is worth attempting.
///
/// The hook is null by default on purpose: `app_providers.dart` must not name
/// the account feature, which reaches `package:appwrite`, or the SDK lands in
/// the graph of every widget test. These tests therefore check the *shape* —
/// that the app calls whatever it was given, and copes with being given
/// nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late QuranCacheDatabase quranCache;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    quranCache = QuranCacheDatabase(NativeDatabase.memory());
    await SurahRepository(database).getRotationSnapshot();
  });

  tearDown(() async {
    await database.close();
    await quranCache.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? onResume,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCache),
          startupProvider.overrideWith((ref) async {}),
          // Without these the app goes looking for a prayer schedule, and a
          // network request in a widget test never comes back.
          prayerTimeSettingsProvider.overrideWith(
            (ref) => Stream<PrayerTimeSettings>.value(
              PrayerTimeSettings(
                location: testTashkentLocation(),
                contextSelectionMode: PrayerContextSelectionMode.manual,
                contextModeExplicitlyChosen: true,
              ),
            ),
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
          syncOnResumeProvider.overrideWithValue(onResume),
        ],
        child: const MurajaahApp(),
      ),
    );
    for (var frame = 0; frame < 40; frame += 1) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    // Let whatever the last lifecycle change started finish before the tree
    // goes: cancelling a Drift stream schedules a timer of its own, and a tree
    // torn down mid-cancel fails with "a Timer is still pending".
    for (var frame = 0; frame < 20; frame += 1) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 5));
    }
  }

  testWidgets('opening the app attempts one exchange', (tester) async {
    var runs = 0;
    await pump(tester, onResume: () async => runs++);

    expect(
      runs,
      1,
      reason:
          'a cold start is the other moment worth trying, and waiting for the '
          'first backgrounding would mean a device that never syncs at all',
    );

    await dispose(tester);
  });

  testWidgets('returning to the foreground attempts another', (tester) async {
    var runs = 0;
    await pump(tester, onResume: () async => runs++);
    runs = 0;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(runs, 1);

    await dispose(tester);
  });

  testWidgets('leaving the app attempts nothing', (tester) async {
    var runs = 0;
    await pump(tester, onResume: () async => runs++);
    runs = 0;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final whileAway = runs;

    // Back to the foreground before the tree is torn down. Nothing about the
    // assertion needs it — it is already captured above — but a tree disposed
    // while the app is paused leaves the revision monitor's work half-done and
    // the binding fails the whole test with "a Timer is still pending", which
    // says nothing about sync.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      whileAway,
      0,
      reason: 'a cycle started on the way out would be killed on the way out',
    );

    await dispose(tester);
  });

  testWidgets('a build with no account hook runs perfectly well', (
    tester,
  ) async {
    await pump(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('home-screen')),
      findsOneWidget,
      reason: 'a null hook is the app exactly as it was before sync existed',
    );

    await dispose(tester);
  });

  testWidgets('a failing exchange never reaches the user', (tester) async {
    await pump(tester, onResume: () async => throw StateError('no network'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason:
          'being offline is a phone\'s ordinary state; the queue is durable '
          'and there is nothing for the user to do about it',
    );
    expect(find.byKey(const ValueKey<String>('home-screen')), findsOneWidget);

    await dispose(tester);
  });
}
