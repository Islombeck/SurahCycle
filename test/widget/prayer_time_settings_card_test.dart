import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';
import 'package:murajaah/features/settings/presentation/prayer_time_settings_card.dart';
import 'package:murajaah/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'manual selector exposes audited hierarchy and clears unsafe fallback',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PrayerTimeSettingsRepository(
        AppSettingsRepository(database),
      );
      final initial = PrayerTimeSettings(
        location: UzbekistanPrayerLocations.bySlug('toshkent-shahri')!,
        allowCalculatedFallback: true,
      );
      final controller = PrayerTimeSettingsController(
        repository: repository,
        timeProvider: const _FixedTimeProvider(),
        refreshSchedules: (_) async {},
      );
      final location = _DeniedLocationService();

      await _pumpCard(
        tester,
        settings: initial,
        controller: controller,
        location: location,
      );
      expect(location.calls, 0);
      await tester.tap(
        find.byKey(const ValueKey<String>('prayer-time-settings')),
      );
      await tester.pumpAndSettle();

      expect(UzbekistanPrayerLocations.all, hasLength(209));

      await tester.tap(
        find.byKey(const ValueKey<String>('prayer-region-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Olmazor — Toshkent shahri').last);
      await tester.pumpAndSettle();

      final saved = await repository.load();
      expect(saved.location.providerSlug, 'olmazor');
      expect(
        saved.locationSelectionMode,
        PrayerLocationSelectionMode.manualRegion,
      );
      expect(saved.allowCalculatedFallback, isFalse);
      expect(location.calls, 0);
    },
  );

  testWidgets('location is requested only on tap and denial is not retried', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PrayerTimeSettingsRepository(
      AppSettingsRepository(database),
    );
    final settings = PrayerTimeSettings(
      location: UzbekistanPrayerLocations.bySlug('toshkent-shahri')!,
    );
    final location = _DeniedLocationService();

    await _pumpCard(
      tester,
      settings: settings,
      controller: PrayerTimeSettingsController(
        repository: repository,
        timeProvider: const _FixedTimeProvider(),
        refreshSchedules: (_) async {},
      ),
      location: location,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(location.calls, 0);

    await tester.tap(
      find.byKey(const ValueKey<String>('prayer-time-settings')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('use-prayer-location')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('use-prayer-location')));
    await tester.pumpAndSettle();

    expect(location.calls, 1);
    expect(find.textContaining('Choose a region manually'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(location.calls, 1);
    expect((await repository.load()).location, settings.location);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required PrayerTimeSettings settings,
  required PrayerTimeSettingsController controller,
  required DevicePrayerLocationService location,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        prayerTimeSettingsProvider.overrideWith(
          (ref) => Stream<PrayerTimeSettings>.value(settings),
        ),
        prayerTodayScheduleProvider.overrideWith(
          (ref) async => throw StateError('Fixture schedule unavailable.'),
        ),
        prayerTimeSettingsControllerProvider.overrideWithValue(controller),
        devicePrayerLocationServiceProvider.overrideWithValue(location),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: PrayerTimeSettingsCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _DeniedLocationService implements DevicePrayerLocationService {
  int calls = 0;

  @override
  Future<DevicePrayerLocationResult> requestUzbekistanLocation() async {
    calls += 1;
    return const DevicePrayerLocationResult(
      DevicePrayerLocationStatus.permissionDenied,
    );
  }
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 26, 8);
}
