import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'app_providers.dart';
import 'app_router.dart';
import 'app_theme.dart';

final class MurajaahApp extends ConsumerWidget {
  const MurajaahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    final themeMode = switch (preference) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: buildMurajaahTheme(Brightness.light),
      darkTheme: buildMurajaahTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, supportedLocales) {
        if (locales == null || locales.isEmpty) return const Locale('ru');
        for (final locale in locales) {
          for (final supported in supportedLocales) {
            if (locale.languageCode == supported.languageCode) return supported;
          }
        }
        return const Locale('ru');
      },
      builder: (context, child) => _StartupGate(child: child),
    );
  }
}

final class _StartupGate extends ConsumerStatefulWidget {
  const _StartupGate({required this.child});

  final Widget? child;

  @override
  ConsumerState<_StartupGate> createState() => _StartupGateState();
}

final class _StartupGateState extends ConsumerState<_StartupGate>
    with WidgetsBindingObserver {
  Timer? _revisionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (defaultTargetPlatform == TargetPlatform.android) {
      _startRevisionMonitor();
    }
  }

  @override
  void dispose() {
    _revisionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (state == AppLifecycleState.resumed) {
      _startRevisionMonitor();
      unawaited(_reconcile());
    } else {
      _revisionTimer?.cancel();
      _revisionTimer = null;
    }
  }

  void _startRevisionMonitor() {
    _revisionTimer?.cancel();
    _revisionTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_reconcile()),
    );
  }

  Future<void> _reconcile() async {
    try {
      await ref.read(widgetResumeReconcilerProvider).reconcile();
    } on Object {
      // Best-effort lifecycle reconciliation must never block app rendering.
    }
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(startupProvider);
    return startup.when(
      data: (_) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          ref.watch(
            widgetSyncLifecycleProvider(
              Localizations.localeOf(context).languageCode,
            ),
          );
        }
        return widget.child ?? const SizedBox.shrink();
      },
      loading: () => const ColoredBox(
        color: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Material(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).errorGeneric,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(catalogBootstrapProvider);
                      ref.invalidate(startupProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
