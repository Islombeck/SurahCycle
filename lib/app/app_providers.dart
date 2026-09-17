import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/application/application.dart';
import '../core/data/data.dart';
import '../core/domain/domain.dart';
import '../core/widgets/widgets.dart';
import '../features/learning/application/recall_controller.dart';
import '../features/quran/quran.dart';
import '../features/prayer_times/prayer_times.dart';
import '../features/settings/application/prayer_routine_editor.dart';
import '../l10n/app_localizations.dart';
import 'localization_extensions.dart';
import 'widget_localization.dart';

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

enum AppThemePreference { system, light, dark }

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final quranCacheDatabaseProvider = Provider<QuranCacheDatabase>((ref) {
  final database = QuranCacheDatabase();
  ref.onDispose(database.close);
  return database;
});

final quranCacheRepositoryProvider = Provider<QuranCacheRepository>(
  (ref) => QuranCacheRepository(ref.watch(quranCacheDatabaseProvider)),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final quranAudioProvider = Provider<QuranAudioProvider>((ref) {
  return Mp3QuranAudioProvider(client: ref.watch(httpClientProvider));
});

final quranAudioCatalogProvider = FutureProvider<List<QuranReciter>>((ref) {
  return ref.watch(quranAudioProvider).listHafsReciters();
});

final learningAudioControllerProvider = Provider<LearningAudioController>((
  ref,
) {
  final controller = LearningAudioController(
    ref.watch(quranAudioProvider),
    JustAudioQuranPlayback(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final quranEncProvider = Provider<QuranEncProvider>(
  (ref) => QuranEncProvider(
    client: ref.watch(httpClientProvider),
    nowUtc: ref.watch(timeProviderProvider).nowUtc,
  ),
);

final quranContentCacheProvider = Provider<QuranContentCache>(
  (ref) => DriftQuranContentCache(ref.watch(quranCacheRepositoryProvider)),
);

final quranContentRepositoryProvider = Provider<QuranContentRepository>(
  (ref) => CachingQuranContentRepository(
    provider: ref.watch(quranEncProvider),
    cache: ref.watch(quranContentCacheProvider),
  ),
);

final tanzilUthmaniTextRepositoryProvider =
    Provider<TanzilUthmaniTextRepository>((ref) {
      return TanzilUthmaniTextRepository(
        metadataProvider: ref.watch(tanzilCatalogProvider),
      );
    });

final tanzilEnglishTransliterationRepositoryProvider =
    Provider<TanzilEnglishTransliterationRepository>((ref) {
      return TanzilEnglishTransliterationRepository(
        metadataProvider: ref.watch(tanzilCatalogProvider),
      );
    });

final quranTransliterationProfileRegistryProvider =
    Provider<QuranTransliterationProfileRegistry>((ref) {
      return const QuranTransliterationProfileRegistry();
    });

final quranTransliterationProfileSelectionRepositoryProvider =
    Provider<QuranTransliterationProfileSelectionRepository>((ref) {
      return QuranTransliterationProfileSelectionRepository(
        ref.watch(settingsRepositoryProvider),
        registry: ref.watch(quranTransliterationProfileRegistryProvider),
      );
    });

final selectedQuranTransliterationProfileProvider =
    StreamProvider<QuranTransliterationProfile>((ref) {
      return ref
          .watch(quranTransliterationProfileSelectionRepositoryProvider)
          .watchSelected();
    });

final quranTransliterationProfileControllerProvider =
    Provider<QuranTransliterationProfileController>((ref) {
      return QuranTransliterationProfileController(
        repository: ref.watch(
          quranTransliterationProfileSelectionRepositoryProvider,
        ),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final quranTransliterationRepositoryProvider =
    Provider<QuranTransliterationRepository?>((ref) {
      final selection = ref.watch(selectedQuranTransliterationProfileProvider);
      if (selection.hasError) return null;
      final registry = ref.watch(quranTransliterationProfileRegistryProvider);
      final profile = selection.valueOrNull ?? registry.defaultProfile;
      if (!profile.isAvailableOffline) return null;
      if (profile.id == QuranTransliterationProfileRegistry.tanzilLatinId) {
        return ref.watch(tanzilEnglishTransliterationRepositoryProvider);
      }
      return null;
    });

final quranTranslationSelectionRepositoryProvider =
    Provider<QuranTranslationSelectionRepository>((ref) {
      return QuranTranslationSelectionRepository(
        ref.watch(settingsRepositoryProvider),
      );
    });

final quranTranslationLanguageRepositoryProvider =
    Provider<QuranTranslationLanguageRepository>((ref) {
      return QuranTranslationLanguageRepository(
        ref.watch(settingsRepositoryProvider),
      );
    });

final quranDisplayPreferencesRepositoryProvider =
    Provider<QuranDisplayPreferencesRepository>((ref) {
      return QuranDisplayPreferencesRepository(
        ref.watch(settingsRepositoryProvider),
      );
    });

final quranDisplayPreferencesProvider = StreamProvider<QuranDisplayPreferences>(
  (ref) {
    return ref.watch(quranDisplayPreferencesRepositoryProvider).watch();
  },
);

final quranDisplayPreferencesControllerProvider =
    Provider<QuranDisplayPreferencesController>((ref) {
      return QuranDisplayPreferencesController(
        repository: ref.watch(quranDisplayPreferencesRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final selectedQuranTranslationProvider =
    StreamProvider<QuranTranslationSelection?>((ref) {
      return ref
          .watch(quranTranslationSelectionRepositoryProvider)
          .watchSelected();
    });

final quranTranslationLanguageProvider = StreamProvider<String?>((ref) {
  return ref.watch(quranTranslationLanguageRepositoryProvider).watchSelected();
});

typedef QuranTranslationsRequest = ({
  String languageCode,
  String localizationLanguageCode,
});

final quranTranslationsProvider =
    FutureProvider.family<
      QuranContentState<List<QuranTranslation>>,
      QuranTranslationsRequest
    >((ref, request) {
      QuranTranslationLanguageRepository.requireSupported(request.languageCode);
      final localizationLanguageCode =
          const <String>{
            'en',
            'ru',
            'uz',
          }.contains(request.localizationLanguageCode)
          ? request.localizationLanguageCode
          : 'en';
      return ref
          .watch(quranContentRepositoryProvider)
          .listTranslations(
            languageCode: request.languageCode,
            localizationLanguageCode: localizationLanguageCode,
          );
    });

final quranTranslationLanguageControllerProvider =
    Provider<QuranTranslationLanguageController>((ref) {
      return QuranTranslationLanguageController(
        repository: ref.watch(quranTranslationLanguageRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final quranTranslationSelectionControllerProvider =
    Provider<QuranTranslationSelectionController>((ref) {
      return QuranTranslationSelectionController(
        repository: ref.watch(quranTranslationSelectionRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final quranReadingRepositoryProvider = Provider<QuranReadingRepository>((ref) {
  return QuranReadingRepository(
    arabic: ref.watch(tanzilUthmaniTextRepositoryProvider),
    translations: ref.watch(quranContentRepositoryProvider),
    transliterations: ref.watch(quranTransliterationRepositoryProvider),
  );
});

typedef QuranReadingRequest = ({
  int surahNumber,
  int ayahCount,
  bool warmTranslation,
});

typedef QuranTranslationWarmupRequest = ({
  int surahNumber,
  int ayahCount,
  QuranTranslationSelection selection,
});

final quranTranslationWarmupProvider = FutureProvider.autoDispose
    .family<QuranReadingSurah, QuranTranslationWarmupRequest>((ref, request) {
      return ref
          .watch(quranReadingRepositoryProvider)
          .getSurah(
            surahNumber: request.surahNumber,
            ayahCount: request.ayahCount,
            translationSelection: request.selection,
            allowTranslationNetwork: true,
          );
    });

final quranReadingSurahProvider = FutureProvider.autoDispose
    .family<QuranReadingSurah, QuranReadingRequest>((ref, request) async {
      final selectionState = ref.watch(selectedQuranTranslationProvider);
      final selected = selectionState.valueOrNull;
      AsyncValue<QuranReadingSurah>? warmup;
      if (selected != null && request.warmTranslation) {
        warmup = ref.watch(
          quranTranslationWarmupProvider((
            surahNumber: request.surahNumber,
            ayahCount: request.ayahCount,
            selection: selected,
          )),
        );
      }
      final warmed = warmup?.valueOrNull;
      if (warmed != null) return warmed;

      final reading = await ref
          .watch(quranReadingRepositoryProvider)
          .getSurah(
            surahNumber: request.surahNumber,
            ayahCount: request.ayahCount,
            translationSelection: selected,
            allowTranslationNetwork: false,
          );
      if (selectionState.hasError) {
        return reading.withTranslationIssue(
          const QuranContentIssue(
            reason: QuranContentUnavailableReason.invalidProviderResponse,
            code: 'quran_translation_selection_invalid',
          ),
        );
      }
      return reading;
    });

final quranSourcesProvider = StreamProvider<List<QuranSourceRecord>>(
  (ref) => ref.watch(quranCacheRepositoryProvider).watchSources(),
);

final surahRepositoryProvider = Provider<SurahRepository>(
  (ref) => SurahRepository(ref.watch(appDatabaseProvider)),
);

final recitationRepositoryProvider = Provider<RecitationRepository>(
  (ref) => RecitationRepository(ref.watch(appDatabaseProvider)),
);

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LearningRepository(ref.watch(appDatabaseProvider)),
);

final recallRepositoryProvider = Provider<RecallRepository>(
  (ref) => RecallRepository(ref.watch(appDatabaseProvider)),
);

/// Per-surah recall counts, used only to explain review priority to the user.
final recallSummariesProvider = StreamProvider<Map<String, RecallSurahSummary>>(
  (ref) => ref.watch(recallRepositoryProvider).watchSummaries(),
);

/// One running memory check. Disposed with its screen: an abandoned check
/// leaves only the attempts that were actually graded.
final recallControllerProvider = StateNotifierProvider.autoDispose
    .family<RecallController, RecallRunState, RecallRequest>(
      (ref, request) => RecallController(
        session: RecallSession(
          surahId: request.surahId,
          surahNumber: request.surahNumber,
          ayahStart: request.ayahStart,
          ayahEnd: request.ayahEnd,
        ),
        repository: ref.watch(recallRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
        localDateProvider: ref.watch(localDateProvider),
        uuid: ref.watch(uuidProvider),
        learningCycle: request.learningCycle,
        source: request.source,
      ),
    );

final prayerRepositoryProvider = Provider<PrayerRepository>(
  (ref) => PrayerRepository(ref.watch(appDatabaseProvider)),
);

final prayerRoutineRepositoryProvider = Provider<PrayerRoutineRepository>(
  (ref) => PrayerRoutineRepository(ref.watch(appDatabaseProvider)),
);

final prayerRoutineTemplateProvider =
    StreamProvider.family<PrayerRoutineTemplate, PrayerType>((ref, type) {
      return ref.watch(prayerRoutineRepositoryProvider).watchTemplate(type);
    });

/// Single instance: it serializes every routine edit through one queue.
final prayerRoutineEditorProvider = Provider<PrayerRoutineEditor>(
  (ref) => PrayerRoutineEditor(
    repository: ref.watch(prayerRoutineRepositoryProvider),
  ),
);

typedef PrayerRoutineSessionKey = ({
  PrayerContext context,
  LocalDate localDate,
});

final currentPrayerRoutineProvider = StreamProvider.autoDispose
    .family<PrayerRoutineSessionSnapshot?, PrayerRoutineSessionKey>((ref, key) {
      return ref
          .watch(prayerRoutineRepositoryProvider)
          .watchCurrentSession(
            context: key.context,
            localDate: key.localDate,
            startedAtUtc: ref.watch(timeProviderProvider).nowUtc,
          );
    });

final prayerContextResolverProvider = Provider<RecitationPrayerContextResolver>(
  (ref) => StoredManualRecitationPrayerContextResolver(
    ref.watch(prayerRepositoryProvider),
  ),
);

final storedPrayerContextProvider = StreamProvider<PrayerContext?>((ref) {
  return ref.watch(prayerRepositoryProvider).watchSelectedContext();
});

final settingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(ref.watch(appDatabaseProvider)),
);

const _learningNotificationEnabledKey = 'learningNotificationEnabled';

final learningNotificationChannelProvider =
    Provider<LearningNotificationChannel>(
      (ref) => const MethodChannelLearningNotifications(),
    );

/// Off by default: absent setting resolves to `false`.
final learningNotificationEnabledProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watchBool(_learningNotificationEnabledKey)
      .map((bool? value) => value ?? false);
});

final learningNotificationControllerProvider =
    Provider<LearningNotificationController>((ref) {
      return LearningNotificationController(
        repository: ref.watch(settingsRepositoryProvider),
        channel: ref.watch(learningNotificationChannelProvider),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

/// Persists the opt-in state and requests `POST_NOTIFICATIONS` only at the
/// moment the user turns the feature on. A denial (or any non-Android
/// platform) leaves the feature safely off rather than retrying silently.
final class LearningNotificationController {
  const LearningNotificationController({
    required this.repository,
    required this.channel,
    required this.timeProvider,
  });

  final AppSettingsRepository repository;
  final LearningNotificationChannel channel;
  final TimeProvider timeProvider;

  Future<bool> setEnabled(bool value) async {
    if (!value) {
      await repository.setBool(
        _learningNotificationEnabledKey,
        false,
        updatedAtUtc: timeProvider.nowUtc(),
      );
      await channel.cancel();
      return false;
    }
    final granted = await channel.requestPermission();
    await repository.setBool(
      _learningNotificationEnabledKey,
      granted,
      updatedAtUtc: timeProvider.nowUtc(),
    );
    if (!granted) await channel.cancel();
    return granted;
  }
}

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

final timeProviderProvider = Provider<TimeProvider>(
  (ref) => const SystemTimeProvider(),
);

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

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final recitationApplicationServiceProvider =
    Provider<RecitationApplicationService>((ref) {
      return RecitationApplicationService(
        surahs: ref.watch(surahRepositoryProvider),
        recitations: ref.watch(recitationRepositoryProvider),
        prayerContextResolver: ref.watch(prayerContextResolverProvider),
        timeProvider: ref.watch(timeProviderProvider),
        localDates: ref.watch(localDateProvider),
        createEventId: ref.watch(uuidProvider).v4,
      );
    });

final rotationSnapshotProvider = StreamProvider<RotationSnapshot>(
  (ref) => ref.watch(surahRepositoryProvider).watchRotationSnapshot(),
);

final catalogSearchProvider = StateProvider<String>((ref) => '');

final catalogProvider = StreamProvider<List<CatalogSurah>>((ref) {
  final query = ref.watch(catalogSearchProvider);
  return ref.watch(surahRepositoryProvider).watchCatalog(query: query);
});

final fullCatalogProvider = StreamProvider<List<CatalogSurah>>(
  (ref) => ref.watch(surahRepositoryProvider).watchCatalog(),
);

final activeLearningProvider = StreamProvider<List<LearningSurahState>>(
  (ref) => ref.watch(learningRepositoryProvider).watchActive(),
);

final allLearningProvider = StreamProvider<List<LearningSurahState>>(
  (ref) => ref.watch(learningRepositoryProvider).watchAll(),
);

final recitationHistoryProvider = StreamProvider<List<RecitationHistoryEntry>>(
  (ref) => ref.watch(recitationRepositoryProvider).watchHistory(),
);

final recitationStatsProvider = StreamProvider<RecitationStats>(
  (ref) => ref.watch(recitationRepositoryProvider).watchStats(),
);

final recitationStatsForPrayerProvider =
    StreamProvider.family<RecitationStats, PrayerContext>((ref, context) {
      return ref
          .watch(recitationRepositoryProvider)
          .watchStats(prayerType: context.prayerType, isQada: context.isQada);
    });

typedef RoutinePartLastUsedKey = ({
  PrayerType prayerType,
  bool isQada,
  String stableKey,
});

final recitationLastUsedByRoutinePartProvider =
    StreamProvider.family<Map<String, DateTime>, RoutinePartLastUsedKey>((
      ref,
      key,
    ) {
      return ref
          .watch(recitationRepositoryProvider)
          .watchLastUsedByRoutinePart(
            prayerType: key.prayerType,
            isQada: key.isQada,
            stableKey: key.stableKey,
          );
    });

/// Resolves to [ContextualRecommendationInputs.empty] while any dependency
/// is still loading or there is no current routine part, which is exactly
/// the state [ContextualSurahSuggestionService] treats as "no context yet"
/// and answers with the plain global order.
final contextualRecommendationInputsProvider =
    Provider.family<ContextualRecommendationInputs, PrayerRoutineSessionKey>((
      ref,
      key,
    ) {
      // Read before the early return: what a memory check said is true no
      // matter which prayer part happens to be active.
      final recallNeedsReview = <String>{
        for (final summary
            in ref.watch(recallSummariesProvider).valueOrNull?.values ??
                const <RecallSurahSummary>[])
          if (summary.needsReview) summary.surahId,
      };

      final routine = ref.watch(currentPrayerRoutineProvider(key)).valueOrNull;
      final currentPart = routine?.currentPart?.part;
      if (currentPart == null) {
        return ContextualRecommendationInputs(
          recallNeedsReviewSurahIds: recallNeedsReview,
        );
      }

      final lastUsedInExactPart = ref
          .watch(
            recitationLastUsedByRoutinePartProvider((
              prayerType: key.context.prayerType,
              isQada: key.context.isQada,
              stableKey: currentPart.stableKey,
            )),
          )
          .valueOrNull;
      final prayerTypeStats = ref
          .watch(recitationStatsForPrayerProvider(key.context))
          .valueOrNull;
      final lastUsedInPrayerType = <String, DateTime>{
        for (final stat
            in prayerTypeStats?.bySurah ?? const <SurahRecitationStat>[])
          if (stat.lastUsedAtUtc != null) stat.surah.id: stat.lastUsedAtUtc!,
      };
      final history = ref.watch(recitationHistoryProvider).valueOrNull;
      final alreadyFilled = <String>{
        for (final entry in history ?? const <RecitationHistoryEntry>[])
          if (entry.event.localDate == key.localDate &&
              entry.event.prayerContext == key.context &&
              entry.event.prayerSessionPartId == currentPart.id)
            entry.event.surahId,
      };

      return ContextualRecommendationInputs(
        alreadyFilledInCurrentPartSurahIds: alreadyFilled,
        lastUsedInExactPart: lastUsedInExactPart ?? const <String, DateTime>{},
        lastUsedInPrayerType: lastUsedInPrayerType,
        recallNeedsReviewSurahIds: recallNeedsReview,
      );
    });

/// Surahs already recited in this exact occurrence today.
///
/// A batch position uses this to render as completed instead of being
/// removed, which is what keeps the block a stable size. Scoped to the
/// current routine part when there is one, and to the whole prayer otherwise,
/// so the slotless flow behaves the same way.
final recitedInCurrentOccurrenceProvider =
    Provider.family<Set<String>, PrayerRoutineSessionKey>((ref, key) {
      final history = ref.watch(recitationHistoryProvider).valueOrNull;
      if (history == null) return const <String>{};
      final routine = ref.watch(currentPrayerRoutineProvider(key)).valueOrNull;
      final currentPartId = routine?.currentPart?.part.id;
      return <String>{
        for (final entry in history)
          if (entry.event.localDate == key.localDate &&
              entry.event.prayerContext == key.context &&
              (currentPartId == null ||
                  entry.event.prayerSessionPartId == currentPartId))
            entry.event.surahId,
      };
    });

final recommendationBatchRepositoryProvider =
    Provider<RecommendationBatchRepository>(
      (ref) =>
          RecommendationBatchRepository(ref.watch(settingsRepositoryProvider)),
    );

/// Read-only view of the stored batch.
///
/// Consumers that must never *start* a batch read this one. Only Home plans
/// and persists: two planners writing to one stored slot would overwrite each
/// other in a loop whenever their resolved prayer contexts differed, which is
/// exactly what the widget driver would have done.
final storedRecommendationBatchProvider = StreamProvider<RecommendationBatch?>(
  (ref) => ref
      .watch(recommendationBatchRepositoryProvider)
      .watch()
      .map((state) => state.batch),
);

/// The one stable batch Home plans; the Rotation widget reads the same stored
/// value through [storedRecommendationBatchProvider].
///
/// Sharing a single provider is what keeps their ranks and completed marks
/// from ever disagreeing, and the stored batch is what stops the block from
/// shrinking as surahs are marked: a batch is only rebuilt when its key
/// changes, never because a surah in it stopped being due.
final currentRecommendationBatchProvider = StreamProvider.autoDispose
    .family<RecommendationBatch?, PrayerRoutineSessionKey>((ref, key) {
      final snapshot = ref.watch(rotationSnapshotProvider).valueOrNull;
      if (snapshot == null) return Stream<RecommendationBatch?>.value(null);

      final repository = ref.watch(recommendationBatchRepositoryProvider);
      final inputs = ref.watch(contextualRecommendationInputsProvider(key));
      final routine = ref.watch(currentPrayerRoutineProvider(key)).valueOrNull;
      final timeProvider = ref.watch(timeProviderProvider);
      final batchKey = RecommendationBatchKey(
        localDate: key.localDate,
        prayerType: key.context.prayerType,
        isQada: key.context.isQada,
        partStableKey: routine?.currentPart?.part.stableKey,
      );
      final pool = const ContextualSurahSuggestionService()
          .rankedCandidateIdsWith(snapshot, inputs);

      // Read once, plan, persist — deliberately **not** `repository.watch()`.
      //
      // Planning saves into `app_settings` and that watch listens to
      // `app_settings`, so a save fed its own subscription. With a single live
      // key that was harmless: the stored batch matched, the plan came back
      // untouched and nothing was written again. With two live keys against
      // the one stored slot it was an unbounded loop — each planner saw the
      // other's batch, re-planned, saved, and woke the other. Every lap could
      // advance the cycle counter, which is how the owner's device reached
      // `cycleNumber = 5392` against 638 recitations.
      //
      // Nothing is lost by reading once. This provider is the only writer, the
      // widget reads `storedRecommendationBatchProvider`, and anything that
      // would change the plan — the rotation snapshot, the contextual inputs,
      // the current routine part — is already watched above and rebuilds this
      // body. A batch still lives until its own key changes.
      return Stream<RecommendationBatch?>.fromFuture(() async {
        final stored = await repository.load();
        final plan = const RecommendationBatchService().plan(
          key: batchKey,
          rankedEligibleSurahIds: pool,
          cycle: stored.cycle,
          existing: stored.batch,
        );
        if (stored.batch != plan.batch || stored.cycle != plan.cycle) {
          await repository.save(
            StoredRecommendationState(batch: plan.batch, cycle: plan.cycle),
            updatedAtUtc: timeProvider.nowUtc(),
          );
        }
        return plan.batch;
      }());
    });

final widgetSyncCoordinatorProvider = Provider<WidgetSyncCoordinator>((ref) {
  final coordinator = WidgetSyncCoordinator(
    bridge: const HomeWidgetBridge(),
    onError: (Object _, StackTrace _) {},
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final widgetResumeReconcilerProvider = Provider<WidgetResumeReconciler>((ref) {
  return WidgetResumeReconciler(
    bridge: const HomeWidgetBridge(),
    loadDatabaseRevision: ref
        .watch(surahRepositoryProvider)
        .getRotationRevision,
    currentProjectionRevision: () =>
        ref.read(rotationSnapshotProvider).valueOrNull?.revision,
    invalidateProviders: () {
      ref.invalidate(rotationSnapshotProvider);
      ref.invalidate(recitationHistoryProvider);
      ref.invalidate(recitationStatsProvider);
    },
  );
});

final widgetSyncDriverProvider = Provider<_AppWidgetSyncDriver>((ref) {
  return _AppWidgetSyncDriver(
    coordinator: ref.watch(widgetSyncCoordinatorProvider),
    quranReading: ref.watch(quranReadingRepositoryProvider),
    timeProvider: ref.watch(timeProviderProvider),
    uuid: ref.watch(uuidProvider),
    learningNotificationChannel: ref.watch(learningNotificationChannelProvider),
  );
});

/// Keeps the native widgets in sync with every relevant reactive projection.
final widgetSyncLifecycleProvider = Provider.family<void, String>((
  ref,
  languageCode,
) {
  final rotation = ref.watch(rotationSnapshotProvider).valueOrNull;
  final learning = ref.watch(allLearningProvider).valueOrNull;
  final catalog = ref.watch(fullCatalogProvider).valueOrNull;
  final history = ref.watch(recitationHistoryProvider).valueOrNull;
  final storedPrayer = ref.watch(storedPrayerContextProvider);
  final prayerTimeSettings = ref.watch(prayerTimeSettingsProvider);
  final automaticPrayerResolution = ref.watch(
    prayerScheduleContextResolutionProvider,
  );
  final displayPreferences =
      ref.watch(quranDisplayPreferencesProvider).valueOrNull ??
      QuranDisplayPreferences.defaults;
  final translationSelection = ref
      .watch(selectedQuranTranslationProvider)
      .valueOrNull;
  final selectedLearningSurahId = ref.watch(selectedLearningSurahProvider);
  if (rotation == null ||
      learning == null ||
      catalog == null ||
      history == null) {
    return;
  }
  final settings = _settledValue(prayerTimeSettings);
  final storedContext = _settledValue(storedPrayer);
  final prayerTodaySchedule = ref
      .watch(prayerTodayScheduleProvider)
      .valueOrNull;
  final settledScheduleResolution = _settledValue(automaticPrayerResolution);
  final rawWidgetPrayerResolution = settings == null
      ? null
      : settings.contextSelectionMode == PrayerContextSelectionMode.manual
      ? PrayerContextResolution(
          status: storedContext == null
              ? PrayerContextResolutionStatus.missingManualContext
              : PrayerContextResolutionStatus.manual,
          context: storedContext,
        )
      : _settledValue(automaticPrayerResolution);
  final localDate = ref.watch(localDateProvider).today();
  final rawContext = rawWidgetPrayerResolution?.context;
  final witrTemplateForTransition = rawContext?.prayerType == PrayerType.isha
      ? ref.watch(prayerRoutineTemplateProvider(PrayerType.witr)).valueOrNull
      : null;
  final ishaRoutineForTransition = rawContext?.prayerType == PrayerType.isha
      ? ref
            .watch(
              currentPrayerRoutineProvider((
                context: rawContext!,
                localDate: localDate,
              )),
            )
            .valueOrNull
      : null;
  final widgetPrayerResolution = rawWidgetPrayerResolution == null
      ? null
      : _applyIshaToWitrTransition(
          rawWidgetPrayerResolution,
          ishaRoutine: ishaRoutineForTransition,
          witrTemplate: witrTemplateForTransition,
        );
  final widgetPrayerContext = widgetPrayerResolution?.context;
  final routineState = widgetPrayerContext == null
      ? null
      : ref.watch(
          currentPrayerRoutineProvider((
            context: widgetPrayerContext,
            localDate: localDate,
          )),
        );
  if (routineState?.isLoading ?? false) return;
  final contextualInputs = widgetPrayerContext == null
      ? ContextualRecommendationInputs.empty
      : ref.watch(
          contextualRecommendationInputsProvider((
            context: widgetPrayerContext,
            localDate: localDate,
          )),
        );
  // The same stored batch Home renders, read only: the widget never starts a
  // batch of its own, so the two can never overwrite each other.
  final recommendationBatch = ref
      .watch(storedRecommendationBatchProvider)
      .valueOrNull;
  final learningNotificationEnabled =
      ref.watch(learningNotificationEnabledProvider).valueOrNull ?? false;
  ref
      .watch(widgetSyncDriverProvider)
      .update(
        languageCode: languageCode,
        rotation: rotation,
        learning: learning,
        catalog: catalog,
        history: history,
        localDate: localDate,
        prayerResolution: widgetPrayerResolution,
        prayerRoutine: routineState?.valueOrNull,
        prayerRoutineReliable: !(routineState?.hasError ?? false),
        displayPreferences: displayPreferences,
        translationSelection: translationSelection,
        selectedLearningSurahId: selectedLearningSurahId,
        contextualInputs: contextualInputs,
        recommendationBatch: recommendationBatch,
        prayerTodaySchedule: prayerTodaySchedule,
        prayerScheduleResolution: settledScheduleResolution,
        prayerLocationDisplayName: settings?.location.displayName,
        learningNotificationEnabled: learningNotificationEnabled,
      );
});

/// A past day the user chose in the calendar to enter records for.
///
/// It exists because entering a forgotten prayer takes several marks, and
/// having to re-pick the day for each one was the shape of the defect the
/// sticky prayer context already fixed. It is in-memory only: a historical
/// date is a deliberate, temporary mode, and one that silently survived a
/// restart would be a trap — every mark would land on a day the user has long
/// stopped thinking about. Home shows it as a banner the whole time it is set,
/// so it is never in force invisibly.
final pendingRegistrationDateProvider = StateProvider<LocalDate?>(
  (ref) => null,
);

final prayerCalendarRepositoryProvider = Provider<PrayerCalendarRepository>(
  (ref) => PrayerCalendarRepository(ref.watch(appDatabaseProvider)),
);

/// One month of the user's own records, keyed by year and month.
final prayerCalendarMonthProvider =
    StreamProvider.family<List<PrayerCalendarDay>, ({int year, int month})>(
      (ref, key) => ref
          .watch(prayerCalendarRepositoryProvider)
          .watchMonth(year: key.year, month: key.month),
    );

final selectedPrayerProvider =
    StateNotifierProvider<SelectedPrayerController, PrayerContext?>((ref) {
      return SelectedPrayerController(
        repository: ref.watch(prayerRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

/// A manual context chosen while persisted settings remain in automatic mode.
///
/// It deliberately survives a whole series of marks: having to re-pick Witr or
/// Nafl after every single surah was the reported defect. It is scoped to the
/// local date it was chosen for, so a sticky override can never silently
/// produce events for the next day — past midnight it stops applying and the
/// app falls back to automatic resolution. Native widgets ignore it entirely.
final class PrayerContextOverride {
  const PrayerContextOverride({required this.context, required this.localDate});

  final PrayerContext context;
  final LocalDate localDate;

  bool appliesOn(LocalDate today) => localDate == today;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerContextOverride &&
          context == other.context &&
          localDate == other.localDate;

  @override
  int get hashCode => Object.hash(context, localDate);

  @override
  String toString() =>
      'PrayerContextOverride(context: $context, localDate: $localDate)';
}

final prayerContextOverrideProvider = StateProvider<PrayerContextOverride?>((
  ref,
) {
  return null;
});

/// The override that still applies right now, or null once its date has passed.
final activePrayerContextOverrideProvider = Provider<PrayerContext?>((ref) {
  final override = ref.watch(prayerContextOverrideProvider);
  if (override == null) return null;
  return override.appliesOn(ref.watch(localDateProvider).today())
      ? override.context
      : null;
});

final prayerContextResolutionProvider = StreamProvider<PrayerContextResolution>(
  (ref) {
    // Reloading settings must not read as "no settings": that is what turned
    // a chosen Магриб into «Выбрать намаз · Автоматически» mid-session.
    final settings = _lastKnownValue(ref.watch(prayerTimeSettingsProvider));
    if (settings == null) {
      return Stream<PrayerContextResolution>.value(
        const PrayerContextResolution(
          status: PrayerContextResolutionStatus.missingSchedule,
        ),
      );
    }
    final override = ref.watch(activePrayerContextOverrideProvider);
    if (settings.contextSelectionMode == PrayerContextSelectionMode.automatic &&
        override != null) {
      return Stream<PrayerContextResolution>.value(
        PrayerContextResolution(
          status: PrayerContextResolutionStatus.manual,
          context: override,
        ),
      );
    }
    final manualContext = ref.watch(selectedPrayerProvider);
    if (settings.contextSelectionMode == PrayerContextSelectionMode.manual) {
      return Stream<PrayerContextResolution>.value(
        PrayerContextResolution(
          status: manualContext == null
              ? PrayerContextResolutionStatus.missingManualContext
              : PrayerContextResolutionStatus.manual,
          context: manualContext,
        ),
      );
    }
    if (!settings.locationConfirmed) {
      return Stream<PrayerContextResolution>.value(
        const PrayerContextResolution(
          status: PrayerContextResolutionStatus.missingSchedule,
        ),
      );
    }
    final todayState = ref.watch(prayerTodayScheduleProvider);
    final today = todayState.valueOrNull;
    if (todayState.isLoading ||
        todayState.hasError ||
        today == null ||
        !today.matchesSettings(settings)) {
      return Stream<PrayerContextResolution>.value(
        const PrayerContextResolution(
          status: PrayerContextResolutionStatus.missingSchedule,
        ),
      );
    }
    return _watchPrayerContextResolution(
      today: today,
      timeProvider: ref.watch(timeProviderProvider),
    );
  },
);

/// Applies the Isha-to-Witr auto-transition on top of whatever
/// override/manual/automatic resolution [base] already is.
///
/// This deliberately never touches [prayerScheduleContextResolutionProvider]
/// or [PrayerContextResolver]/[PrayerDaySchedule.resolveAutomaticContext]:
/// prayer-time presentation keeps showing Isha for its whole real window.
/// Only which prayer recitations/routine actions attribute to changes, and
/// only after today's Isha routine is actually complete and the user has
/// configured Witr — never for Qada Isha, never by inventing a Witr time or
/// event. It is a pure function of already-resolved data (not a mutation),
/// which is what keeps re-opening the screen from repeating any transition.
PrayerContextResolution _applyIshaToWitrTransition(
  PrayerContextResolution base, {
  required PrayerRoutineSessionSnapshot? ishaRoutine,
  required PrayerRoutineTemplate? witrTemplate,
}) {
  final context = base.context;
  if (context == null ||
      context.prayerType != PrayerType.isha ||
      context.isQada) {
    return base;
  }
  // A prayer the user picked himself never moves on its own. He reported
  // choosing Иша and being taken straight to Витр because an earlier Иша of
  // the same day was already complete — which left the Иша he had asked for
  // impossible to look at or correct. An automatic context may still advance;
  // an explicit choice is an instruction, not a guess to be improved on.
  if (base.status == PrayerContextResolutionStatus.manual) return base;
  final offersWitrTransition =
      (ishaRoutine?.isCompleted ?? false) &&
      witrTemplate != null &&
      witrTemplate.enabled &&
      witrTemplate.parts.isNotEmpty;
  if (!offersWitrTransition) return base;
  return PrayerContextResolution(
    status: base.status,
    context: PrayerContext(prayerType: PrayerType.witr),
  );
}

/// Home's live recitation-attribution context: [prayerContextResolutionProvider]
/// with [_applyIshaToWitrTransition] layered on top. Kept as a separate
/// provider (rather than folded into [prayerContextResolutionProvider]
/// itself) so the base resolver's own extensive tests, several of which
/// construct a bare [ProviderContainer] with a minimal override set, are not
/// forced to also account for routine/template providers they have no
/// reason to know about.
final homePrayerContextResolutionProvider =
    Provider<AsyncValue<PrayerContextResolution>>((ref) {
      final base = ref.watch(prayerContextResolutionProvider);
      final resolution = base.valueOrNull;
      if (resolution?.context?.prayerType != PrayerType.isha) return base;
      final localDate = ref.watch(localDateProvider).today();
      final ishaRoutine = ref
          .watch(
            currentPrayerRoutineProvider((
              context: PrayerContext(prayerType: PrayerType.isha),
              localDate: localDate,
            )),
          )
          .valueOrNull;
      final witrTemplate = ref
          .watch(prayerRoutineTemplateProvider(PrayerType.witr))
          .valueOrNull;
      return AsyncData<PrayerContextResolution>(
        _applyIshaToWitrTransition(
          resolution!,
          ishaRoutine: ishaRoutine,
          witrTemplate: witrTemplate,
        ),
      );
    });

/// Schedule-derived context used for current/next timing presentation even
/// while the user keeps recitation attribution in manual mode.
final prayerScheduleContextResolutionProvider =
    StreamProvider<PrayerContextResolution>((ref) {
      final settings = _lastKnownValue(ref.watch(prayerTimeSettingsProvider));
      if (settings == null || !settings.locationConfirmed) {
        return Stream<PrayerContextResolution>.value(
          const PrayerContextResolution(
            status: PrayerContextResolutionStatus.missingSchedule,
          ),
        );
      }
      final todayState = ref.watch(prayerTodayScheduleProvider);
      final today = todayState.valueOrNull;
      if (todayState.isLoading ||
          todayState.hasError ||
          today == null ||
          !today.matchesSettings(settings)) {
        return Stream<PrayerContextResolution>.value(
          const PrayerContextResolution(
            status: PrayerContextResolutionStatus.missingSchedule,
          ),
        );
      }
      return _watchPrayerContextResolution(
        today: today,
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final themePreferenceProvider =
    StateNotifierProvider<ThemePreferenceController, AppThemePreference>((ref) {
      return ThemePreferenceController(
        repository: ref.watch(settingsRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final selectedLearningSurahProvider =
    StateNotifierProvider<SelectedLearningSurahController, String?>((ref) {
      return SelectedLearningSurahController(
        repository: ref.watch(settingsRepositoryProvider),
        timeProvider: ref.watch(timeProviderProvider),
      );
    });

final learningRollbackQueueProvider =
    StateNotifierProvider<LearningRollbackQueue, List<LearningActionOutcome>>(
      (ref) => LearningRollbackQueue(),
    );

final appActionsProvider = Provider<AppActions>((ref) {
  return AppActions(
    database: ref.watch(appDatabaseProvider),
    surahs: ref.watch(surahRepositoryProvider),
    recitations: ref.watch(recitationRepositoryProvider),
    recitationService: ref.watch(recitationApplicationServiceProvider),
    learning: ref.watch(learningRepositoryProvider),
    timeProvider: ref.watch(timeProviderProvider),
    localDates: ref.watch(localDateProvider),
    uuid: ref.watch(uuidProvider),
  );
});

final tanzilCatalogProvider = Provider<TanzilMetadataProvider>(
  (ref) => TanzilMetadataProvider(),
);

/// Seeds only verified, bundled metadata. Verse and translation content remain
/// explicitly unavailable until the user chooses a supported data source.
final catalogBootstrapProvider = FutureProvider<void>((ref) async {
  final catalog = await ref.watch(tanzilCatalogProvider).loadSurahs();
  await ref
      .watch(surahRepositoryProvider)
      .upsertCatalog(
        catalog,
        sourceId: TanzilMetadataProvider.sourceId,
        sourceVersion: TanzilMetadataProvider.version,
      );
});

final startupProvider = FutureProvider<void>((ref) async {
  await ref.watch(catalogBootstrapProvider.future);
  await ref.watch(tanzilUthmaniTextRepositoryProvider).load();
  await _normalizeRotationExclusions(ref);
  final learning = ref.watch(learningRepositoryProvider);
  final machine = LearningStateMachine(
    timeProvider: ref.watch(timeProviderProvider),
  );
  final active = await learning.watchActive().first;
  final rollbacks = <LearningActionOutcome>[];
  for (final state in active) {
    final outcome = machine.applyInactivityRollback(
      state,
      rollbackEventId: ref.watch(uuidProvider).v4(),
    );
    if (outcome.didRollback) {
      await learning.saveOutcome(outcome);
      rollbacks.add(outcome);
    }
  }
  if (rollbacks.isNotEmpty) {
    ref.read(learningRollbackQueueProvider.notifier).replace(rollbacks);
  }
});

final class QuranTranslationSelectionController {
  const QuranTranslationSelectionController({
    required this.repository,
    required this.timeProvider,
  });

  final QuranTranslationSelectionRepository repository;
  final TimeProvider timeProvider;

  Future<void> select(QuranTranslation translation) async {
    if (translation.source != QuranEncProvider.sourceId ||
        !QuranTranslationLanguageRepository.isSupported(
          translation.languageCode,
        )) {
      throw ArgumentError.value(
        '${translation.source}/${translation.languageCode}',
        'translation',
        'Only audited QuranEnc catalog entries may be selected.',
      );
    }
    final now = timeProvider.nowUtc();
    await repository.save(
      QuranTranslationSelection.fromCatalog(
        translation: translation,
        fetchedAtUtc: now,
        attribution: QuranEncProvider.attribution,
        sourceUri: Uri.parse('https://quranenc.com/'),
      ),
      updatedAtUtc: now,
    );
  }

  Future<void> clear() async {
    await repository.clear();
  }
}

final class QuranTranslationLanguageController {
  const QuranTranslationLanguageController({
    required this.repository,
    required this.timeProvider,
  });

  final QuranTranslationLanguageRepository repository;
  final TimeProvider timeProvider;

  Future<void> select(String languageCode) =>
      repository.save(languageCode, updatedAtUtc: timeProvider.nowUtc());
}

final class QuranDisplayPreferencesController {
  const QuranDisplayPreferencesController({
    required this.repository,
    required this.timeProvider,
  });

  final QuranDisplayPreferencesRepository repository;
  final TimeProvider timeProvider;

  Future<void> save(QuranDisplayPreferences value) =>
      repository.save(value, updatedAtUtc: timeProvider.nowUtc());
}

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

const String _rotationExclusionsMarker = 'rotation_exclusions_v1_normalized';

Future<void> _normalizeRotationExclusions(Ref ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  if (await settings.getBool(_rotationExclusionsMarker) == true) return;

  final surahs = ref.read(surahRepositoryProvider);
  final catalog = await surahs.getCatalog();
  for (final item in catalog) {
    if (item.surah.surahNumber == 1 && item.isMastered && item.isActive) {
      await surahs.setActive(item.surah.id, isActive: false);
      break;
    }
  }
  await settings.setBool(
    _rotationExclusionsMarker,
    true,
    updatedAtUtc: ref.read(timeProviderProvider).nowUtc(),
  );
}

final class SelectedPrayerController extends StateNotifier<PrayerContext?> {
  SelectedPrayerController({
    required this._repository,
    required this._timeProvider,
  }) : super(null) {
    unawaited(_load());
  }

  final PrayerRepository _repository;
  final TimeProvider _timeProvider;
  int _selectionRevision = 0;

  Future<void> _load() async {
    final revision = _selectionRevision;
    final stored = await _repository.getSelectedContext();
    if (revision == _selectionRevision && stored != null) state = stored;
  }

  Future<void> select(PrayerContext value) async {
    _selectionRevision += 1;
    state = value;
    await _repository.saveSelectedContext(
      value,
      updatedAtUtc: _timeProvider.nowUtc(),
    );
  }
}

final class ThemePreferenceController
    extends StateNotifier<AppThemePreference> {
  ThemePreferenceController({
    required this._repository,
    required this._timeProvider,
  }) : super(AppThemePreference.system) {
    unawaited(_load());
  }

  static const _settingKey = 'theme_preference';

  final AppSettingsRepository _repository;
  final TimeProvider _timeProvider;

  Future<void> _load() async {
    final stored = await _repository.getString(_settingKey);
    if (stored != null) state = AppThemePreference.values.byName(stored);
  }

  Future<void> select(AppThemePreference value) async {
    state = value;
    await _repository.setString(
      _settingKey,
      value.name,
      updatedAtUtc: _timeProvider.nowUtc(),
    );
  }
}

final class SelectedLearningSurahController extends StateNotifier<String?> {
  SelectedLearningSurahController({
    required this._repository,
    required this._timeProvider,
  }) : super(null) {
    unawaited(_load());
  }

  static const _settingKey = 'selected_learning_surah_id';

  final AppSettingsRepository _repository;
  final TimeProvider _timeProvider;

  Future<void> _load() async {
    state = await _repository.getString(_settingKey);
  }

  Future<void> select(String? surahId) async {
    state = surahId;
    if (surahId == null) {
      await _repository.remove(_settingKey);
      return;
    }
    await _repository.setString(
      _settingKey,
      surahId,
      updatedAtUtc: _timeProvider.nowUtc(),
    );
  }
}

final class LearningRollbackQueue
    extends StateNotifier<List<LearningActionOutcome>> {
  LearningRollbackQueue() : super(const <LearningActionOutcome>[]);

  void replace(List<LearningActionOutcome> value) {
    state = List<LearningActionOutcome>.unmodifiable(value);
  }

  void remove(String eventId) {
    state = state
        .where((outcome) => outcome.event?.id != eventId)
        .toList(growable: false);
  }
}

final class AppActions {
  const AppActions({
    required this.database,
    required this.surahs,
    required this.recitations,
    required this.recitationService,
    required this.learning,
    required this.timeProvider,
    required this.localDates,
    required this.uuid,
  });

  final AppDatabase database;
  final SurahRepository surahs;
  final RecitationRepository recitations;
  final RecitationApplicationService recitationService;
  final LearningRepository learning;
  final TimeProvider timeProvider;
  final LocalDateProvider localDates;
  final Uuid uuid;

  Future<RecitationRegistration> registerRecitation({
    required String surahId,
    required PrayerContext prayerContext,
    String? prayerSessionId,
    String? prayerSessionPartId,
    int? slotIndex,
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
    LocalDate? occurrenceLocalDate,
    bool qadaOriginIsUnknown = false,
    LocalDate? qadaFulfilledLocalDate,
  }) {
    return recitationService.registerFromApp(
      surahId: surahId,
      prayerContext: prayerContext,
      prayerSessionId: prayerSessionId,
      prayerSessionPartId: prayerSessionPartId,
      slotIndex: slotIndex,
      coveredPartIds: coveredPartIds,
      rakaatSpanCount: rakaatSpanCount,
      occurrenceLocalDate: occurrenceLocalDate,
      qadaOriginIsUnknown: qadaOriginIsUnknown,
      qadaFulfilledLocalDate: qadaFulfilledLocalDate,
    );
  }

  Future<RotationSnapshot> changeSegmentation({
    required String surahId,
    required Iterable<AyahRange> ranges,
  }) async {
    final snapshot = await surahs.getRotationSnapshot();
    final current = snapshot.surahById(surahId);
    final schemeId = uuid.v4();
    final proposed = SurahRotationScheme.fromRanges(
      id: schemeId,
      surahId: surahId,
      version: current.rotationScheme.version + 1,
      ayahCount: current.surah.ayahCount,
      ranges: ranges,
    );
    return surahs.changeRotationScheme(
      surahId: surahId,
      proposedScheme: proposed,
      createdAtUtc: timeProvider.nowUtc(),
    );
  }

  Future<LearningSurahState> startLearning(
    SurahDescriptor surah, {
    LearningPlan? plan,
  }) async {
    final resolvedPlan =
        plan ??
        LearningPlan.classicCumulative(
          targetStartAyah: 1,
          targetEndAyah: surah.ayahCount,
        );
    final existing = await learning.getBySurahId(surah.id);
    final machine = LearningStateMachine(timeProvider: timeProvider);
    if (existing == null) {
      final started = machine.start(
        id: uuid.v4(),
        surahId: surah.id,
        ayahCount: surah.ayahCount,
        plan: resolvedPlan,
      );
      await learning.saveState(started);
      return started;
    }
    if (!existing.isCompleted) {
      if (existing.plan != resolvedPlan) {
        throw StateError('An active learning plan must be changed explicitly.');
      }
      return existing;
    }
    final restarted = machine.restart(
      existing,
      plan: resolvedPlan,
      eventId: uuid.v4(),
      reason: 'returned_to_learning',
    );
    await learning.saveOutcome(restarted);
    return restarted.state;
  }

  Future<LearningSurahState> changeLearningPlan({
    required LearningSurahState state,
    required LearningPlan plan,
  }) async {
    if (state.plan == plan) return state;
    final outcome = LearningStateMachine(timeProvider: timeProvider).restart(
      state,
      plan: plan,
      eventId: uuid.v4(),
      reason: 'user_changed_learning_plan',
      planChanged: true,
    );
    await learning.saveOutcome(outcome);
    return outcome.state;
  }

  Future<LearningActionOutcome> markRepeated(LearningSurahState state) async {
    final outcome = LearningStateMachine(
      timeProvider: timeProvider,
    ).markRepeated(state, eventId: uuid.v4());
    await learning.saveOutcome(outcome);
    return outcome;
  }

  Future<LearningActionOutcome> markLearned(LearningSurahState state) async {
    final outcome = LearningStateMachine(
      timeProvider: timeProvider,
    ).markLearned(state, eventId: uuid.v4());
    await learning.saveOutcome(outcome);
    return outcome;
  }

  Future<void> completeLearning({
    required LearningSurahState state,
    required SurahDescriptor surah,
    bool addToRotation = true,
  }) async {
    await database.transaction(() async {
      final machine = LearningStateMachine(timeProvider: timeProvider);
      if (!state.isFullSurahTarget) {
        await learning.saveOutcome(machine.complete(state, eventId: uuid.v4()));
        return;
      }
      final snapshot = await surahs.getRotationSnapshot();
      final service = LearningCompletionService(learningStateMachine: machine);
      final outcome = service.completeAndAddToRotation(
        learningState: state,
        surah: surah,
        rotationSnapshot: snapshot,
        completionEventId: uuid.v4(),
        displayOrder: snapshot.surahs.length,
        addToRotation: addToRotation,
        rotationSchemeId: uuid.v4(),
      );
      await learning.saveOutcome(outcome.learning);
      MasteredSurah? existing;
      for (final mastered in snapshot.surahs) {
        if (mastered.id == surah.id) {
          existing = mastered;
          break;
        }
      }
      if (existing == null) {
        await surahs.addMastered(
          surah.id,
          activate: addToRotation && surah.isRotationEligible,
          displayOrder: snapshot.surahs.length,
        );
      } else if (!existing.isCurrentlyMastered) {
        await surahs.restoreMastery(
          surah.id,
          activate: addToRotation && surah.isRotationEligible,
          rotationSchemeId: uuid.v4(),
        );
      }
    });
  }

  Future<void> returnToLearning(String surahId) async {
    await surahs.returnToLearning(surahId);
  }

  Future<RotationSnapshot> adjustBalance({
    required String surahId,
    required int delta,
  }) {
    return recitations.applyAdjustment(
      RotationAdjustmentEvent(
        id: uuid.v4(),
        surahId: surahId,
        delta: delta,
        reason: 'confirmed_manual_migration',
        createdAtUtc: timeProvider.nowUtc(),
      ),
    );
  }
}

final class _AppWidgetSyncDriver {
  _AppWidgetSyncDriver({
    required this.coordinator,
    required this.quranReading,
    required this.timeProvider,
    required this.uuid,
    this.learningNotificationChannel =
        const MethodChannelLearningNotifications(),
  });

  final WidgetSyncCoordinator coordinator;
  final QuranReadingRepository quranReading;
  final TimeProvider timeProvider;
  final Uuid uuid;
  final LearningNotificationChannel learningNotificationChannel;

  int _revision = 0;
  bool _hasCompletedStartupSync = false;

  void update({
    required String languageCode,
    required RotationSnapshot rotation,
    required List<LearningSurahState> learning,
    required List<CatalogSurah> catalog,
    required List<RecitationHistoryEntry> history,
    required LocalDate localDate,
    required PrayerContextResolution? prayerResolution,
    required PrayerRoutineSessionSnapshot? prayerRoutine,
    required bool prayerRoutineReliable,
    required QuranDisplayPreferences displayPreferences,
    required QuranTranslationSelection? translationSelection,
    required String? selectedLearningSurahId,
    ContextualRecommendationInputs contextualInputs =
        ContextualRecommendationInputs.empty,
    RecommendationBatch? recommendationBatch,
    PrayerTodaySchedule? prayerTodaySchedule,
    PrayerContextResolution? prayerScheduleResolution,
    String? prayerLocationDisplayName,
    bool learningNotificationEnabled = false,
  }) {
    final revision = ++_revision;
    unawaited(
      _buildSnapshot(
            languageCode: languageCode,
            rotation: rotation,
            learning: List<LearningSurahState>.of(learning),
            catalog: List<CatalogSurah>.of(catalog),
            history: List<RecitationHistoryEntry>.of(history),
            localDate: localDate,
            prayerResolution: prayerResolution,
            prayerRoutine: prayerRoutine,
            prayerRoutineReliable: prayerRoutineReliable,
            displayPreferences: displayPreferences,
            translationSelection: translationSelection,
            selectedLearningSurahId: selectedLearningSurahId,
            contextualInputs: contextualInputs,
            recommendationBatch: recommendationBatch,
            prayerTodaySchedule: prayerTodaySchedule,
            prayerScheduleResolution: prayerScheduleResolution,
            prayerLocationDisplayName: prayerLocationDisplayName,
          )
          .then((snapshot) async {
            if (revision != _revision || coordinator.isDisposed) return;
            if (!_hasCompletedStartupSync) {
              _hasCompletedStartupSync = true;
              await coordinator.syncNow(snapshot);
            } else {
              coordinator.schedule(snapshot);
            }
            await _syncLearningNotification(
              enabled: learningNotificationEnabled,
              item: snapshot.learning.item,
            );
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> _syncLearningNotification({
    required bool enabled,
    required LearningWidgetItem? item,
  }) async {
    if (!enabled || item == null) {
      await learningNotificationChannel.cancel();
      return;
    }
    await learningNotificationChannel.show(
      title: item.title,
      text: '${item.stageLabel} · ${item.rangeLabel}',
    );
  }

  Future<WidgetSnapshot> _buildSnapshot({
    required String languageCode,
    required RotationSnapshot rotation,
    required List<LearningSurahState> learning,
    required List<CatalogSurah> catalog,
    required List<RecitationHistoryEntry> history,
    required LocalDate localDate,
    required PrayerContextResolution? prayerResolution,
    required PrayerRoutineSessionSnapshot? prayerRoutine,
    required bool prayerRoutineReliable,
    required QuranDisplayPreferences displayPreferences,
    required QuranTranslationSelection? translationSelection,
    required String? selectedLearningSurahId,
    ContextualRecommendationInputs contextualInputs =
        ContextualRecommendationInputs.empty,
    RecommendationBatch? recommendationBatch,
    PrayerTodaySchedule? prayerTodaySchedule,
    PrayerContextResolution? prayerScheduleResolution,
    String? prayerLocationDisplayName,
  }) async {
    final localeCode = const <String>{'ru', 'en', 'uz'}.contains(languageCode)
        ? languageCode
        : 'ru';
    final l10n = lookupAppLocalizations(Locale(localeCode));
    final widgetLocalization = WidgetLocalization.forLanguageCode(localeCode);
    final prayerContext = prayerResolution?.context;
    final prayerPart = prayerContext == null
        ? null
        : widgetLocalization.prayerRoutineProjection(
            prayerContext,
            prayerRoutine,
          );
    final markedPartIds = prayerContext == null
        ? const <String>{}
        : <String>{
            for (final entry in history)
              if (entry.event.localDate == localDate &&
                  entry.event.prayerContext == prayerContext &&
                  (prayerRoutine == null ||
                      entry.event.prayerSessionPartId ==
                          prayerPart?.prayerSessionPartId))
                ...entry.event.coveredPartIds,
          };
    final rotationProjection =
        RotationWidgetProjectionFactory(
          labels: widgetLocalization.projectionLabels,
        ).build(
          rotation: rotation,
          contextLabel: widgetLocalization.prayerContextLabel(
            prayerContext,
            isAutomatic:
                prayerResolution?.status ==
                PrayerContextResolutionStatus.automatic,
            startsAt: prayerResolution?.currentStartsAt?.toString(),
            endsAt: prayerResolution?.currentEndsAt?.toString(),
          ),
          createActionToken: uuid.v4,
          actionsEnabled:
              (prayerResolution?.canMarkDirectly ?? false) &&
              prayerRoutineReliable,
          markedPartIds: markedPartIds,
          prayerPart: prayerPart,
          contextualInputs: contextualInputs,
          batch: recommendationBatch,
        );

    final activeLearning = learning
        .where((state) => !state.isCompleted)
        .toList(growable: false);
    LearningSurahState? selectedLearning;
    for (final state in activeLearning) {
      if (state.surahId == selectedLearningSurahId) {
        selectedLearning = state;
        break;
      }
    }
    selectedLearning ??= activeLearning.isEmpty ? null : activeLearning.first;
    final descriptorById = <String, SurahDescriptor>{
      for (final item in catalog) item.surah.id: item.surah,
    };
    LearningWidgetCandidate? learningCandidate;
    final learningState = selectedLearning;
    final descriptor = learningState == null
        ? null
        : descriptorById[learningState.surahId];
    if (learningState != null && descriptor != null) {
      final startAyah = learningState.stage.startAyah;
      final endAyah = learningState.stage.endAyah;
      var readingLines = const <LearningWidgetAyahLine>[];
      try {
        readingLines = await _verifiedLearningLines(
          surahNumber: descriptor.surahNumber,
          ayahCount: descriptor.ayahCount,
          startAyah: startAyah,
          endAyah: endAyah,
          translationSelection: translationSelection,
        );
      } on Object {
        // A failed Quran integrity/content load must still publish a valid
        // metadata-only widget projection with its localized safe fallback.
      }
      learningCandidate = LearningWidgetCandidate(
        surahId: learningState.surahId,
        surahNumber: descriptor.surahNumber,
        displayName: descriptor.displayName,
        stageLabel: learningState.stage.label(l10n),
        startAyah: startAyah,
        endAyah: endAyah,
        ayahLines: readingLines,
        showArabic: displayPreferences.showArabic,
        showTransliteration: displayPreferences.showTransliteration,
        showTranslation: displayPreferences.showTranslation,
      );
    }

    return WidgetSnapshot(
      generatedAtUtc: timeProvider.nowUtc(),
      snapshotRevision: rotation.revision,
      locale: localeCode,
      rotation: rotationProjection,
      learning: WidgetProjectionBuilder(
        widgetLocalization.projectionLabels,
      ).buildLearning(learningCandidate),
      prayer: _buildPrayerProjection(
        l10n: l10n,
        localDate: localDate,
        todaySchedule: prayerTodaySchedule,
        scheduleResolution: prayerScheduleResolution,
        locationDisplayName: prayerLocationDisplayName,
      ),
    );
  }

  PrayerWidgetProjection _buildPrayerProjection({
    required AppLocalizations l10n,
    required LocalDate localDate,
    required PrayerTodaySchedule? todaySchedule,
    required PrayerContextResolution? scheduleResolution,
    required String? locationDisplayName,
  }) {
    const factory = PrayerWidgetProjectionFactory();
    if (todaySchedule == null || locationDisplayName == null) {
      return factory.unavailable(l10n.prayerScheduleUnavailable);
    }
    final times = todaySchedule.day.times;
    final boundaries = <PrayerWidgetBoundary>[
      PrayerWidgetBoundary(
        label: PrayerType.fajr.label(l10n),
        hour: times.fajr.effective.hour,
        minute: times.fajr.effective.minute,
        prayerType: PrayerType.fajr,
      ),
      PrayerWidgetBoundary(
        label: l10n.sunrise,
        hour: times.sunrise.effective.hour,
        minute: times.sunrise.effective.minute,
      ),
      PrayerWidgetBoundary(
        label: PrayerType.dhuhr.label(l10n),
        hour: times.dhuhr.effective.hour,
        minute: times.dhuhr.effective.minute,
        prayerType: PrayerType.dhuhr,
      ),
      PrayerWidgetBoundary(
        label: PrayerType.asr.label(l10n),
        hour: times.asr.effective.hour,
        minute: times.asr.effective.minute,
        prayerType: PrayerType.asr,
      ),
      PrayerWidgetBoundary(
        label: PrayerType.maghrib.label(l10n),
        hour: times.maghrib.effective.hour,
        minute: times.maghrib.effective.minute,
        prayerType: PrayerType.maghrib,
      ),
      PrayerWidgetBoundary(
        label: PrayerType.isha.label(l10n),
        hour: times.isha.effective.hour,
        minute: times.isha.effective.minute,
        prayerType: PrayerType.isha,
      ),
    ];
    final isStale = !todaySchedule.loadResult.isReliableForAutomaticContext;
    final currentPrayerType = scheduleResolution?.context?.prayerType;
    final nextPrayerType = scheduleResolution?.nextPrayerType;
    return factory.available(
      dateLabel: localDate.toString(),
      regionLabel: locationDisplayName,
      providerLabel: todaySchedule.day.provenance.source.displayName,
      boundaries: boundaries,
      currentPrayerType: currentPrayerType,
      nextPrayerType: nextPrayerType,
      currentLabel: currentPrayerType?.label(l10n),
      nextLabel: nextPrayerType?.label(l10n),
      isStale: isStale,
      staleLabel: isStale ? l10n.prayerScheduleStale : null,
    );
  }

  Future<List<LearningWidgetAyahLine>> _verifiedLearningLines({
    required int surahNumber,
    required int ayahCount,
    required int startAyah,
    required int endAyah,
    required QuranTranslationSelection? translationSelection,
  }) async {
    final reading = await quranReading.getSurah(
      surahNumber: surahNumber,
      ayahCount: ayahCount,
      translationSelection: translationSelection,
      allowTranslationNetwork: false,
    );
    return List<LearningWidgetAyahLine>.unmodifiable(
      reading
          .range(startAyah: startAyah, endAyah: endAyah)
          .map(
            (ayah) => LearningWidgetAyahLine(
              surahNumber: ayah.surahNumber,
              ayahNumber: ayah.ayahNumber,
              arabic: ayah.arabicText,
              transliteration: ayah.transliteration == null
                  ? null
                  : TanzilTransliterationMarkup.toPlainText(
                      ayah.transliteration!,
                    ),
              translation: ayah.translation,
            ),
          ),
    );
  }
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

Stream<PrayerContextResolution> _watchPrayerContextResolution({
  required PrayerTodaySchedule today,
  required TimeProvider timeProvider,
}) => Stream<PrayerContextResolution>.multi((controller) {
  Timer? boundaryTimer;
  var isCancelled = false;

  void emit() {
    controller.add(today.resolveAutomaticContext(timeProvider));
  }

  void scheduleNextBoundary() {
    if (isCancelled) return;
    boundaryTimer = Timer(_durationUntilNextMinute(timeProvider.nowUtc()), () {
      if (isCancelled) return;
      emit();
      // Recompute after every callback so app suspension or event-loop
      // delay cannot permanently shift future updates off :00.
      scheduleNextBoundary();
    });
  }

  controller.onCancel = () {
    isCancelled = true;
    boundaryTimer?.cancel();
  };
  emit();
  scheduleNextBoundary();
});

Duration _durationUntilNextMinute(DateTime now) {
  final microsecondsIntoMinute =
      now.second * Duration.microsecondsPerSecond +
      now.millisecond * Duration.microsecondsPerMillisecond +
      now.microsecond;
  return Duration(
    microseconds:
        Duration.microsecondsPerSecond * Duration.secondsPerMinute -
        microsecondsIntoMinute,
  );
}

/// A value only while the provider is idle: a reload or an error reads as null.
///
/// Deliberately conservative, and kept that way for everything that drives a
/// write — the widget snapshot, the local-date provider — where acting on a
/// value that is about to change is worse than doing nothing for a frame.
T? _settledValue<T>(AsyncValue<T> state) =>
    state.isLoading || state.hasError ? null : state.valueOrNull;

/// The last value a provider actually produced, kept across a reload.
///
/// Riverpod keeps the previous value while a provider re-subscribes;
/// [_settledValue] throws it away. That is right for a writer and wrong for
/// the prayer context, because Home derives the resolved context, the routine
/// card, the recommendation batch and the whole prayer-time strip from it. One
/// loading tick empties all four at once, and since the page then becomes much
/// shorter the scroll offset is clamped and the user is thrown back to the top
/// — the "экран прыгает после отметок" reported on 2026-09-16.
///
/// A context one frame stale is not a lie. An empty one is: it reads as "no
/// prayer selected" to a user who has selected a prayer.
T? _lastKnownValue<T>(AsyncValue<T> state) => state.valueOrNull;
