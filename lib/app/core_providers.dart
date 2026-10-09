/// The providers every feature may depend on, and nothing else.
///
/// The database, the HTTP client, the clock, identifiers, and the two
/// repositories that are pure storage with no feature logic of their own.
/// This file imports no feature: a feature's providers reach the core here,
/// never the whole registry in `app_providers.dart`, which re-exports this
/// file so that no existing import had to change.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/application/application.dart';
import '../core/data/data.dart';
import '../core/domain/domain.dart';

abstract interface class LocalDateProvider
    implements RecitationLocalDateProvider {}

final class SystemLocalDateProvider implements LocalDateProvider {
  const SystemLocalDateProvider([
    this.timeProvider = const SystemTimeProvider(),
  ]);

  final TimeProvider timeProvider;

  @override
  LocalDate today() =>
      LocalDate.fromLocalDateTime(timeProvider.nowUtc().toLocal());
}

final class PrayerRegionLocalDateProvider implements LocalDateProvider {
  const PrayerRegionLocalDateProvider({
    required this.timeProvider,
    required this.utcOffsetMinutes,
  });

  final TimeProvider timeProvider;
  final int utcOffsetMinutes;

  @override
  LocalDate today() => LocalDate.fromLocalDateTime(
    timeProvider.nowUtc().add(Duration(minutes: utcOffsetMinutes)),
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final timeProviderProvider = Provider<TimeProvider>(
  (ref) => const SystemTimeProvider(),
);

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final settingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(ref.watch(appDatabaseProvider)),
);

/// The stored choice of prayer. Here rather than with the prayer context
/// because the prayer-time settings read it too — to migrate a device that
/// chose a prayer by hand before automatic mode existed.
final prayerRepositoryProvider = Provider<PrayerRepository>(
  (ref) => PrayerRepository(ref.watch(appDatabaseProvider)),
);
