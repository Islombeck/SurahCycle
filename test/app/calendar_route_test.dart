import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/app_router.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/calendar/presentation/prayer_calendar_screen.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Twice now a detail screen was declared on the root navigator and opened
/// without the bottom navigation — Stage D for `/learning/:id`, Stage I for
/// surah details. The calendar is nested in the Home branch for that reason,
/// and this is what keeps it there.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    quranCacheDatabase = QuranCacheDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    await quranCacheDatabase.close();
  });

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(
            _FixedTimeProvider(DateTime.utc(2026, 9, 16, 9)),
          ),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 9, 16)),
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
      () => find
          .byKey(const ValueKey<String>('home-screen'))
          .evaluate()
          .isNotEmpty,
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(MurajaahApp)),
    ).read(appRouterProvider);
  }

  testWidgets('the calendar opens inside the shell and comes back', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/calendar');
    await _pumpUntil(
      tester,
      () => find.byType(PrayerCalendarScreen).evaluate().isNotEmpty,
    );

    expect(find.byType(PrayerCalendarScreen), findsOneWidget);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'a screen above the shell loses its way back into its own tab',
    );
    expect(
      find.byKey(const ValueKey<String>('calendar-legend')),
      findsOneWidget,
    );

    router.go('/');
    // The route pops with an animation, so "gone" is a state to wait for
    // rather than something true on the next frame.
    await _pumpUntil(
      tester,
      () => find.byType(PrayerCalendarScreen).evaluate().isEmpty,
    );
    expect(
      find.byKey(const ValueKey<String>('home-screen')),
      findsOneWidget,
      reason: 'back from the calendar lands on Home, not on a dead end',
    );

    await _disposeWidgetTree(tester);
  });

  testWidgets('an empty month reads as "no mark", never as missed', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    router.go('/calendar');
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('calendar-month-grid'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('calendar-day-2026-09-16')),
    );
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('calendar-day-details'))
          .evaluate()
          .isNotEmpty,
    );

    expect(find.text('No mark'), findsWidgets);
    expect(
      find.textContaining('not that a prayer was missed'),
      findsWidgets,
      reason: 'the app records what was entered; it does not rule on worship',
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
