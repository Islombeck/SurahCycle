/// Providers for prayer times: the settings, where the schedule comes from,
/// today's schedule, and the local date it implies.
///
/// Kept with the feature rather than in `lib/app/app_providers.dart`, for the
/// reason `features/account/application/account_providers.dart` gives for
/// itself: the composition root should not know every feature's internals,
/// and adding a prayer-time provider should not mean editing a file every
/// other feature imports. This file reaches the core through
/// `core_providers.dart` and never imports the whole registry; the registry
/// re-exports it, so no import anywhere had to change.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../prayer_times.dart';

final prayerTimeSettingsRepositoryProvider =
    Provider<PrayerTimeSettingsRepository>((ref) {
      return PrayerTimeSettingsRepository(
        ref.watch(settingsRepositoryProvider),
      );
    });

final prayerTimeSettingsProvider = StreamProvider<PrayerTimeSettings>((ref) {
  final prayerRepository = ref.watch(prayerRepositoryProvider);
  return ref
      .watch(prayerTimeSettingsRepositoryProvider)
      .watch(
        legacyManualContextExists: () async =>
            await prayerRepository.getSelectedContext() != null,
      );
});

final devicePrayerLocationServiceProvider =
    Provider<DevicePrayerLocationService>(
      (ref) => const GeolocatorDevicePrayerLocationService(),
    );

final prayerScheduleCacheStoreProvider =
    FutureProvider<PrayerScheduleCacheStore>((ref) async {
      final support = await getApplicationSupportDirectory();
      return FilePrayerScheduleCacheStore(
        directory: Directory(
          '${support.path}${Platform.pathSeparator}prayer_time_cache_v1',
        ),
      );
    });

final namozVaqtiUzPrayerTimeProvider = Provider<NamozVaqtiUzPrayerTimeProvider>(
  (ref) {
    return NamozVaqtiUzPrayerTimeProvider(
      client: ref.watch(httpClientProvider),
      timeProvider: ref.watch(timeProviderProvider),
    );
  },
);

final adhanPrayerTimeCalculatorProvider = Provider<AdhanPrayerTimeCalculator>(
  (ref) =>
      AdhanPrayerTimeCalculator(timeProvider: ref.watch(timeProviderProvider)),
);

final cachingPrayerScheduleRepositoryProvider =
    FutureProvider<CachingPrayerScheduleRepository>((ref) async {
      return CachingPrayerScheduleRepository(
        provider: ref.watch(namozVaqtiUzPrayerTimeProvider),
        cache: await ref.watch(prayerScheduleCacheStoreProvider.future),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final prayerScheduleCoordinatorProvider =
    FutureProvider<PrayerScheduleCoordinator>((ref) async {
      return PrayerScheduleCoordinator(
        publishedRepository: await ref.watch(
          cachingPrayerScheduleRepositoryProvider.future,
        ),
        calculator: ref.watch(adhanPrayerTimeCalculatorProvider),
      );
    });

final prayerScheduleUseCasesProvider = FutureProvider<PrayerScheduleUseCases>((
  ref,
) async {
  return PrayerScheduleUseCases(
    coordinator: await ref.watch(prayerScheduleCoordinatorProvider.future),
    timeProvider: ref.watch(timeProviderProvider),
  );
});

final prayerTodayScheduleProvider = FutureProvider<PrayerTodaySchedule>((
  ref,
) async {
  final settings = await ref.watch(prayerTimeSettingsProvider.future);
  if (!settings.locationConfirmed) {
    throw StateError('Prayer location has not been confirmed.');
  }
  final timeProvider = ref.watch(timeProviderProvider);
  final nextLocalDayRefresh = Timer(
    _durationUntilNextLocalDay(
      nowUtc: timeProvider.nowUtc(),
      utcOffsetMinutes: settings.location.utcOffsetMinutes,
    ),
    ref.invalidateSelf,
  );
  ref.onDispose(nextLocalDayRefresh.cancel);
  final useCases = await ref.watch(prayerScheduleUseCasesProvider.future);
  return useCases.loadToday(settings: settings);
});

final prayerTimeSettingsControllerProvider =
    Provider<PrayerTimeSettingsController>((ref) {
      return PrayerTimeSettingsController(
        repository: ref.watch(prayerTimeSettingsRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
        refreshSchedules: (settings) async {
          if (!settings.locationConfirmed) return;
          final useCases = await ref.read(
            prayerScheduleUseCasesProvider.future,
          );
          await useCases.refreshCurrentAndNext(settings: settings);
          ref.invalidate(prayerTodayScheduleProvider);
        },
      );
    });

/// The app's "today": the prayer region's date once a region is confirmed,
/// the phone's own until then.
///
/// Here rather than with the clock in `core_providers.dart`, because it
/// depends on the prayer-time settings — a day here is the day where he
/// prays, which is why it belongs to this feature.
final localDateProvider = Provider<LocalDateProvider>((ref) {
  final timeProvider = ref.watch(timeProviderProvider);
  final settings = _settledValue(ref.watch(prayerTimeSettingsProvider));
  if (settings?.locationConfirmed ?? false) {
    return PrayerRegionLocalDateProvider(
      timeProvider: timeProvider,
      utcOffsetMinutes: settings!.location.utcOffsetMinutes,
    );
  }
  return SystemLocalDateProvider(timeProvider);
});

typedef PrayerScheduleRefresh =
    Future<void> Function(PrayerTimeSettings settings);

final class PrayerTimeSettingsController {
  const PrayerTimeSettingsController({
    required this.repository,
    required this.timeProvider,
    required this.refreshSchedules,
  });

  final PrayerTimeSettingsRepository repository;
  final TimeProvider timeProvider;
  final PrayerScheduleRefresh refreshSchedules;

  Future<void> save(PrayerTimeSettings value, {bool refresh = true}) async {
    await repository.save(value, updatedAtUtc: timeProvider.nowUtc());
    if (refresh && value.locationConfirmed) await refreshSchedules(value);
  }

  Future<void> refresh(PrayerTimeSettings value) =>
      value.locationConfirmed ? refreshSchedules(value) : Future<void>.value();
}

Duration _durationUntilNextLocalDay({
  required DateTime nowUtc,
  required int utcOffsetMinutes,
}) {
  if (!nowUtc.isUtc) {
    throw StateError('TimeProvider.nowUtc() must return UTC.');
  }
  final offset = Duration(minutes: utcOffsetMinutes);
  final local = nowUtc.add(offset);
  final nextLocalMidnight = DateTime.utc(
    local.year,
    local.month,
    local.day + 1,
  );
  final delay = nextLocalMidnight.subtract(offset).difference(nowUtc);
  return delay.isNegative || delay == Duration.zero
      ? const Duration(minutes: 1)
      : delay + const Duration(seconds: 1);
}

/// A value only while the provider is idle: a reload or an error reads as
/// null. The local date drives writes, and acting on a value that is about to
/// change is worse than doing nothing for a frame. (The same rule as
/// `_settledValue` in `app_providers.dart`, which keeps its own copy for the
/// widget snapshot.)
T? _settledValue<T>(AsyncValue<T> state) =>
    state.isLoading || state.hasError ? null : state.valueOrNull;
