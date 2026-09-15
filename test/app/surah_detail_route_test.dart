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
import 'package:murajaah/features/surahs/presentation/surah_detail_screen.dart';

/// Surah details used to be declared on the root navigator, so opening them
/// dropped the bottom navigation — the same defect Stage D fixed for
/// `/learning/:id`. Reproduced on the device on 2026-09-15: the screen *was*
/// reachable by tapping a mastered row, but it opened outside the shell.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    quranCacheDatabase = QuranCacheDatabase(NativeDatabase.memory());
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlaas',
          ayahCount: 4,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-112');
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
            _FixedTimeProvider(DateTime.utc(2026, 9, 15, 9)),
          ),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 9, 15)),
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

  testWidgets('the detail screen keeps the bottom navigation', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/surahs/detail/surah-112');

    expect(find.byType(SurahDetailScreen), findsOneWidget);
    expect(
      hasBottomNavigation(tester),
      isTrue,
      reason: 'a detail of the Surahs tab must stay inside the shell',
    );
    await _dispose(tester);
  });

  testWidgets('it stays on the Surahs tab', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/surahs/detail/surah-112');

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      startsWith('/surahs'),
    );
    await _dispose(tester);
  });

  testWidgets('back returns to the surah list rather than trapping', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/surahs');
    await goAndSettle(tester, router, '/surahs/detail/surah-112');
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routerDelegate.currentConfiguration.uri.path, '/surahs');
    expect(hasBottomNavigation(tester), isTrue);
    await _dispose(tester);
  });

  group('legacy widget deep link', () {
    testWidgets('the old path redirects into the shell', (tester) async {
      final router = await pumpApp(tester);

      await goAndSettle(tester, router, '/surah/surah-112');

      expect(location(router), '/surahs/detail/surah-112');
      expect(
        hasBottomNavigation(tester),
        isTrue,
        reason: 'a widget already on the launcher still holds the old path',
      );
      await _dispose(tester);
    });

    testWidgets('the part query parameter survives the redirect', (
      tester,
    ) async {
      final router = await pumpApp(tester);

      await goAndSettle(tester, router, '/surah/surah-112?part=part-2');

      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['part'],
        'part-2',
      );
      await _dispose(tester);
    });

    testWidgets('an empty id falls back to the surah list', (tester) async {
      final router = await pumpApp(tester);

      await goAndSettle(tester, router, '/surah/');

      expect(router.routerDelegate.currentConfiguration.uri.path, '/surahs');
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });
  });

  testWidgets('an unknown surah id does not crash', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/surahs/detail/no-such-surah');

    expect(tester.takeException(), isNull);
    expect(hasBottomNavigation(tester), isTrue);
    await _dispose(tester);
  });

  testWidgets('switching tabs afterwards works normally', (tester) async {
    final router = await pumpApp(tester);

    await goAndSettle(tester, router, '/surahs/detail/surah-112');
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
