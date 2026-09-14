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
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Entering Learning from the widget must land inside the navigation shell.
/// The selected-surah route used to be declared on the root navigator, which
/// opened the screen without the bottom navigation and without a normal back
/// path — the user hit this once from the Learning widget.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;
  late ProviderContainer container;

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
    final scope = ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
        startupProvider.overrideWith((ref) async {}),
        timeProviderProvider.overrideWithValue(
          _FixedTimeProvider(DateTime.utc(2026, 9, 14, 9)),
        ),
        localDateProvider.overrideWithValue(
          _FixedLocalDateProvider(LocalDate(2026, 9, 14)),
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
    );
    await tester.pumpWidget(scope);
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('home-screen'))
          .evaluate()
          .isNotEmpty,
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(MurajaahApp)),
    );
    return container.read(appRouterProvider);
  }

  bool hasBottomNavigation(WidgetTester tester) =>
      find.byType(NavigationBar).evaluate().isNotEmpty;

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> goAndSettle(
    WidgetTester tester,
    GoRouter router,
    String to,
  ) async {
    router.go(to);
    await _pumpUntil(
      tester,
      () => router.routerDelegate.currentConfiguration.uri.path.isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a cold deep link keeps the bottom navigation', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/learning/112');

    expect(location(router), '/learning?surah=112');
    expect(hasBottomNavigation(tester), isTrue);
    await _dispose(tester);
  });

  testWidgets('a warm deep link switches the surah in place', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/learning/112');
    await goAndSettle(tester, router, '/learning/114');

    expect(
      router.routerDelegate.currentConfiguration.uri.queryParameters['surah'],
      '114',
    );
    expect(hasBottomNavigation(tester), isTrue);
    await _dispose(tester);
  });

  testWidgets('the same deep link twice stays stable', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/learning/112');
    final first = location(router);
    await goAndSettle(tester, router, '/learning/112');

    expect(location(router), first);
    expect(hasBottomNavigation(tester), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('an unknown surah id still opens Learning safely', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/learning/no-such-surah');

    expect(location(router), '/learning?surah=no-such-surah');
    expect(hasBottomNavigation(tester), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('an empty id falls back to the Learning root', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/learning/');

    expect(router.routerDelegate.currentConfiguration.uri.path, '/learning');
    expect(hasBottomNavigation(tester), isTrue);
    await _dispose(tester);
  });

  testWidgets('system back from a deep link cannot trap the user', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/learning/112');

    expect(
      router.canPop(),
      isFalse,
      reason: 'a deep link must not leave a stack the user has to unwind',
    );
    expect(hasBottomNavigation(tester), isTrue);
    await _dispose(tester);
  });

  testWidgets('switching tabs after a deep link works normally', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/learning/112');
    await goAndSettle(tester, router, '/settings');

    expect(router.routerDelegate.currentConfiguration.uri.path, '/settings');
    expect(hasBottomNavigation(tester), isTrue);
    await _dispose(tester);
  });
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

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  throw StateError('Condition not met within $timeout.');
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}
