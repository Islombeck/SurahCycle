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
import 'package:murajaah/features/account/application/account_providers.dart';
import 'package:murajaah/features/account/presentation/account_screen.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Three screens in this project were declared on the root navigator and opened
/// without the bottom navigation — `/learning/:id`, surah details, and the
/// calendar before it was moved. The account screen is nested in the Settings
/// branch for that reason, and this is what keeps it there.
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
            _FixedTimeProvider(DateTime.utc(2026, 9, 17, 9)),
          ),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 9, 17)),
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
          // Signed out, and without building a real Appwrite client: this test
          // is about where the screen lives, not about talking to anyone.
          currentAccountProvider.overrideWith((ref) async => null),
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

  testWidgets('the account screen opens inside the shell and comes back', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/settings/account');
    await _pumpUntil(
      tester,
      () => find.byType(AccountScreen).evaluate().isNotEmpty,
    );

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'a screen above the shell loses its way back into its own tab',
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/settings/account',
    );

    router.go('/settings');
    await _pumpUntil(
      tester,
      () => find.byType(AccountScreen).evaluate().isEmpty,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await _disposeWidgetTree(tester);
  });

  testWidgets('the Settings tab stays selected while the account screen is up', (
    tester,
  ) async {
    // The branch index is derived from the path prefix. A nested route that
    // fell outside `/settings` would deselect the tab the user is standing in.
    final router = await pumpApp(tester);

    router.go('/settings/account');
    await _pumpUntil(
      tester,
      () => find.byType(AccountScreen).evaluate().isNotEmpty,
    );

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);

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
