import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/application/application.dart';
import '../core/data/data.dart';
import '../core/domain/domain.dart';
import '../core/widgets/widgets.dart';
import '../features/prayer_times/prayer_times.dart';

typedef WidgetDatabaseFactory = AppDatabase Function();
typedef BackgroundPrayerContextResolverFactory =
    FutureOr<RecitationPrayerContextResolver> Function(AppDatabase database);

/// Official home_widget background entry point. It must stay top-level and
/// retained by the AOT compiler because Android can invoke it in a headless
/// Flutter engine after the application process has been removed.
@pragma('vm:entry-point')
Future<void> murajaahWidgetInteractivityCallback(Uri? payload) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await runRotationWidgetBackgroundAction(payload);
  } on Object catch (error, stackTrace) {
    developer.log(
      'Rotation widget background bootstrap failed.',
      name: 'MurajaahWidget',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Lightweight bootstrap exposed for an integration-style unit test. It opens
/// only the user database and local widget bridge; Quran and HTTP services are
/// intentionally absent.
Future<RotationWidgetInteractionOutcome> runRotationWidgetBackgroundAction(
  Uri? payload, {
  WidgetDatabaseFactory openDatabase = AppDatabase.new,
  WidgetSnapshotBridge bridge = const HomeWidgetBridge(),
  TimeProvider timeProvider = const SystemTimeProvider(),
  RecitationLocalDateProvider? localDates,
  String Function()? createEventId,
  BackgroundPrayerContextResolverFactory? createPrayerContextResolver,
  WidgetInteractionErrorHandler? onError,
}) async {
  final database = openDatabase();
  try {
    final eventIdFactory = createEventId ?? const Uuid().v4;
    final surahs = SurahRepository(database);
    final recitations = RecitationRepository(database);
    late final RecitationPrayerContextResolver prayerResolver;
    late final RecitationLocalDateProvider effectiveLocalDates;
    final customPrayerResolver = createPrayerContextResolver;
    if (customPrayerResolver != null) {
      prayerResolver = await customPrayerResolver(database);
      effectiveLocalDates =
          localDates ?? const SystemRecitationLocalDateProvider();
    } else {
      final context = await _createBackgroundPrayerContext(
        database: database,
        timeProvider: timeProvider,
      );
      prayerResolver = context.resolver;
      effectiveLocalDates = localDates ?? context.localDates;
    }
    final applicationService = RecitationApplicationService(
      surahs: surahs,
      recitations: recitations,
      prayerContextResolver: prayerResolver,
      timeProvider: timeProvider,
      localDates: effectiveLocalDates,
      createEventId: eventIdFactory,
    );
    final refresher = InteractiveWidgetSnapshotRefresher(
      surahs: surahs,
      prayerContextResolver: prayerResolver,
      timeProvider: timeProvider,
      createActionToken: eventIdFactory,
      bridge: bridge,
    );
    return await RotationWidgetInteractionHandler(
      recitations: applicationService,
      refresher: refresher,
      onError:
          onError ??
          (Object error, StackTrace stackTrace) {
            developer.log(
              'Rotation widget action failed; restoring current snapshot.',
              name: 'MurajaahWidget',
              error: error,
              stackTrace: stackTrace,
            );
          },
    ).handle(payload);
  } finally {
    await database.close();
  }
}

Future<
  ({
    RecitationPrayerContextResolver resolver,
    RecitationLocalDateProvider localDates,
  })
>
_createBackgroundPrayerContext({
  required AppDatabase database,
  required TimeProvider timeProvider,
}) async {
  final manualContexts = PrayerRepository(database);
  final settings = await PrayerTimeSettingsRepository(
    AppSettingsRepository(database),
  ).load();
  final localDates = PrayerSettingsLocalDateProvider(
    timeProvider: timeProvider,
    utcOffsetMinutes: settings.location.utcOffsetMinutes,
  );
  if (settings.contextSelectionMode == PrayerContextSelectionMode.manual) {
    return (
      resolver: StoredManualRecitationPrayerContextResolver(manualContexts),
      localDates: localDates,
    );
  }
  final support = await getApplicationSupportDirectory();
  final cache = FilePrayerScheduleCacheStore(
    directory: Directory(
      '${support.path}${Platform.pathSeparator}prayer_time_cache_v1',
    ),
  );
  return (
    resolver: CachedRecitationPrayerContextResolver(
      settings: settings,
      manualContexts: manualContexts,
      cache: cache,
      calculator: AdhanPrayerTimeCalculator(timeProvider: timeProvider),
      timeProvider: timeProvider,
    ),
    localDates: localDates,
  );
}
