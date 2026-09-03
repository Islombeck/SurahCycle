import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/history/presentation/history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/learning/presentation/learning_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/statistics/presentation/statistics_screen.dart';
import '../features/surahs/presentation/surahs_screen.dart';
import '../features/surahs/presentation/surah_detail_screen.dart';
import '../core/widgets/widgets.dart';
import 'localization_extensions.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root-navigator',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final primaryNavigationIndex = ValueNotifier<int>(0);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => HomeScreen(
                  primaryNavigationIndexListenable: primaryNavigationIndex,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/surahs',
                builder: (context, state) => const SurahsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/learning',
                builder: (context, state) => const LearningScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/statistics',
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(path: '/home', redirect: (context, state) => '/'),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/surah/:id',
        builder: (context, state) =>
            SurahDetailScreen(surahId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/learning/:id',
        builder: (context, state) =>
            LearningScreen(initialSurahId: state.pathParameters['id']),
      ),
    ],
  );
  void syncPrimaryNavigationIndex() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    final index = switch (path) {
      '/' => 0,
      final value when value.startsWith('/surahs') => 1,
      final value when value.startsWith('/learning') => 2,
      final value when value.startsWith('/statistics') => 3,
      final value when value.startsWith('/settings') => 4,
      _ => -1,
    };
    if (primaryNavigationIndex.value != index) {
      primaryNavigationIndex.value = index;
    }
  }

  router.routerDelegate.addListener(syncPrimaryNavigationIndex);
  syncPrimaryNavigationIndex();
  void openWidgetLink(WidgetDeepLink link) {
    final location = switch (link) {
      WidgetHomeDeepLink() => '/',
      WidgetLearningRootDeepLink() => '/learning',
      WidgetSurahDeepLink(:final surahId, :final partId) => Uri(
        path: '/surah/$surahId',
        queryParameters: partId == null
            ? null
            : <String, String>{'part': partId},
      ).toString(),
      WidgetLearningDeepLink(:final surahId) => '/learning/$surahId',
    };
    router.go(location);
  }

  StreamSubscription<WidgetDeepLink>? widgetClickSubscription;
  if (defaultTargetPlatform == TargetPlatform.android) {
    const widgetBridge = HomeWidgetBridge();
    widgetClickSubscription = widgetBridge.clicks.listen(
      openWidgetLink,
      onError: (Object _) {},
    );
    unawaited(
      widgetBridge
          .initiallyLaunchedFromWidget()
          .then((link) {
            if (link != null) openWidgetLink(link);
          })
          .catchError((Object _) {}),
    );
  }
  ref.onDispose(() {
    unawaited(widgetClickSubscription?.cancel());
    router.routerDelegate.removeListener(syncPrimaryNavigationIndex);
    router.dispose();
    primaryNavigationIndex.dispose();
  });
  return router;
});

final class _AppScaffold extends StatelessWidget {
  const _AppScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index != navigationShell.currentIndex) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            key: const ValueKey<String>('primary-tab-home'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTab,
          ),
          NavigationDestination(
            key: const ValueKey<String>('primary-tab-surahs'),
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.surahsTab,
          ),
          NavigationDestination(
            key: const ValueKey<String>('primary-tab-learning'),
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: l10n.learningTab,
          ),
          NavigationDestination(
            key: const ValueKey<String>('primary-tab-statistics'),
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n.statisticsTab,
          ),
          NavigationDestination(
            key: const ValueKey<String>('primary-tab-settings'),
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settingsTab,
          ),
        ],
      ),
    );
  }
}
