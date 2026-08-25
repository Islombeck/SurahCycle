import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/data/data.dart';
import '../core/domain/domain.dart';
import '../core/widgets/widgets.dart';
import '../features/quran/quran.dart';
import '../l10n/app_localizations.dart';

abstract interface class LocalDateProvider {
  LocalDate today();
}

final class SystemLocalDateProvider implements LocalDateProvider {
  const SystemLocalDateProvider();

  @override
  LocalDate today() => LocalDate.fromLocalDateTime(DateTime.now());
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

final quranTranslationSelectionRepositoryProvider =
    Provider<QuranTranslationSelectionRepository>((ref) {
      return QuranTranslationSelectionRepository(
        ref.watch(settingsRepositoryProvider),
      );
    });

final selectedQuranTranslationProvider =
    StreamProvider<QuranTranslationSelection?>((ref) {
      return ref
          .watch(quranTranslationSelectionRepositoryProvider)
          .watchSelected();
    });

final russianQuranTranslationsProvider =
    FutureProvider<QuranContentState<List<QuranTranslation>>>((ref) {
      return ref
          .watch(quranContentRepositoryProvider)
          .listTranslations(languageCode: 'ru', localizationLanguageCode: 'ru');
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

final prayerRepositoryProvider = Provider<PrayerRepository>(
  (ref) => PrayerRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(ref.watch(appDatabaseProvider)),
);

final timeProviderProvider = Provider<TimeProvider>(
  (ref) => const SystemTimeProvider(),
);

final localDateProvider = Provider<LocalDateProvider>(
  (ref) => const SystemLocalDateProvider(),
);

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

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

final widgetSyncCoordinatorProvider = Provider<WidgetSyncCoordinator>((ref) {
  final coordinator = WidgetSyncCoordinator(
    bridge: const HomeWidgetBridge(),
    onError: (Object _, StackTrace _) {},
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final widgetSyncDriverProvider = Provider<_AppWidgetSyncDriver>((ref) {
  return _AppWidgetSyncDriver(
    coordinator: ref.watch(widgetSyncCoordinatorProvider),
    quranText: ref.watch(tanzilUthmaniTextRepositoryProvider),
    timeProvider: ref.watch(timeProviderProvider),
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
  final selectedLearningSurahId = ref.watch(selectedLearningSurahProvider);
  if (rotation == null || learning == null || catalog == null) {
    return;
  }
  ref
      .watch(widgetSyncDriverProvider)
      .update(
        languageCode: languageCode,
        rotation: rotation,
        learning: learning,
        catalog: catalog,
        selectedLearningSurahId: selectedLearningSurahId,
      );
});

final selectedPrayerProvider =
    StateNotifierProvider<SelectedPrayerController, PrayerContext>((ref) {
      return SelectedPrayerController(
        repository: ref.watch(prayerRepositoryProvider),
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
        translation.languageCode != 'ru') {
      throw ArgumentError.value(
        '${translation.source}/${translation.languageCode}',
        'translation',
        'Only Russian catalog entries returned by QuranEnc may be selected.',
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

final class SelectedPrayerController extends StateNotifier<PrayerContext> {
  SelectedPrayerController({
    required this._repository,
    required this._timeProvider,
  }) : super(PrayerContext(prayerType: PrayerType.fajr)) {
    unawaited(_load());
  }

  final PrayerRepository _repository;
  final TimeProvider _timeProvider;

  Future<void> _load() async {
    final stored = await _repository.getSelectedContext();
    if (stored != null) state = stored;
  }

  Future<void> select(PrayerContext value) async {
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
    required this.learning,
    required this.timeProvider,
    required this.localDates,
    required this.uuid,
  });

  final AppDatabase database;
  final SurahRepository surahs;
  final RecitationRepository recitations;
  final LearningRepository learning;
  final TimeProvider timeProvider;
  final LocalDateProvider localDates;
  final Uuid uuid;

  Future<RecitationRegistration> registerRecitation({
    required String surahId,
    required PrayerContext prayerContext,
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
  }) {
    return _registerRecitation(
      surahId: surahId,
      prayerContext: prayerContext,
      coveredPartIds: coveredPartIds,
      rakaatSpanCount: rakaatSpanCount,
    );
  }

  Future<RecitationRegistration> _registerRecitation({
    required String surahId,
    required PrayerContext prayerContext,
    required Iterable<String>? coveredPartIds,
    required int rakaatSpanCount,
  }) async {
    final snapshot = await surahs.getRotationSnapshot();
    final mastered = snapshot.surahById(surahId);
    final explicitPartIds = coveredPartIds?.toList(growable: false);
    return recitations.register(
      SurahRecitationEvent(
        id: uuid.v4(),
        surahId: surahId,
        prayerContext: prayerContext,
        createdAtUtc: timeProvider.nowUtc(),
        localDate: localDates.today(),
        rotationSchemeId: explicitPartIds == null
            ? null
            : mastered.rotationScheme.id,
        coveredPartIds: explicitPartIds,
        rakaatSpanCount: rakaatSpanCount,
      ),
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

  Future<void> startLearning(SurahDescriptor surah) async {
    final existing = await learning.getBySurahId(surah.id);
    if (existing != null) return;
    final machine = LearningStateMachine(timeProvider: timeProvider);
    await learning.saveState(
      machine.start(
        id: uuid.v4(),
        surahId: surah.id,
        ayahCount: surah.ayahCount,
      ),
    );
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
  }) async {
    await database.transaction(() async {
      final snapshot = await surahs.getRotationSnapshot();
      final service = LearningCompletionService(
        learningStateMachine: LearningStateMachine(timeProvider: timeProvider),
      );
      final outcome = service.completeAndAddToRotation(
        learningState: state,
        surah: surah,
        rotationSnapshot: snapshot,
        completionEventId: uuid.v4(),
        displayOrder: snapshot.surahs.length,
      );
      await learning.saveOutcome(outcome.learning);
      final alreadyMastered = snapshot.surahs.any(
        (mastered) => mastered.id == surah.id,
      );
      if (!alreadyMastered) {
        await surahs.addMastered(
          surah.id,
          activate: surah.isRotationEligible,
          displayOrder: snapshot.surahs.length,
        );
      }
    });
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
    required this.quranText,
    required this.timeProvider,
  });

  final WidgetSyncCoordinator coordinator;
  final TanzilUthmaniTextRepository quranText;
  final TimeProvider timeProvider;

  int _revision = 0;
  bool _hasCompletedStartupSync = false;

  void update({
    required String languageCode,
    required RotationSnapshot rotation,
    required List<LearningSurahState> learning,
    required List<CatalogSurah> catalog,
    required String? selectedLearningSurahId,
  }) {
    final revision = ++_revision;
    unawaited(
      _buildSnapshot(
            languageCode: languageCode,
            rotation: rotation,
            learning: List<LearningSurahState>.of(learning),
            catalog: List<CatalogSurah>.of(catalog),
            selectedLearningSurahId: selectedLearningSurahId,
          )
          .then((snapshot) async {
            if (revision != _revision || coordinator.isDisposed) return;
            if (!_hasCompletedStartupSync) {
              _hasCompletedStartupSync = true;
              await coordinator.syncNow(snapshot);
            } else {
              coordinator.schedule(snapshot);
            }
          })
          .catchError((Object _) {}),
    );
  }

  Future<WidgetSnapshot> _buildSnapshot({
    required String languageCode,
    required RotationSnapshot rotation,
    required List<LearningSurahState> learning,
    required List<CatalogSurah> catalog,
    required String? selectedLearningSurahId,
  }) async {
    final localeCode = const <String>{'ru', 'en', 'uz'}.contains(languageCode)
        ? languageCode
        : 'ru';
    final l10n = lookupAppLocalizations(Locale(localeCode));
    final recommendations = const SurahSuggestionService().suggest(rotation);
    final recommendationRanks = <String, int>{
      for (var index = 0; index < recommendations.length; index += 1)
        recommendations[index].surah.id: index,
    };
    final recommendedPartIds = <String, String?>{
      for (final suggestion in recommendations)
        suggestion.surah.id: suggestion.recommendedPart?.id,
    };
    final candidates = <RotationWidgetCandidate>[];
    for (final surah in rotation.activeSurahs) {
      final scheme = surah.rotationScheme;
      if (!scheme.isSplit) {
        candidates.add(
          RotationWidgetCandidate.whole(
            id: scheme.id,
            surahId: surah.id,
            surahNumber: surah.surah.surahNumber,
            displayName: surah.surah.displayName,
            ayahCount: surah.surah.ayahCount,
            remaining: rotation.rotationTarget - surah.rotationScore,
            recommendationRank: recommendationRanks[surah.id],
            displayOrder: surah.displayOrder,
            lastUsedAtUtc: surah.lastUsedAtUtc,
          ),
        );
        continue;
      }
      for (final part in scheme.parts) {
        candidates.add(
          RotationWidgetCandidate.part(
            id: part.id,
            surahId: surah.id,
            surahNumber: surah.surah.surahNumber,
            displayName: surah.surah.displayName,
            partId: part.id,
            partIndex: part.partNumber,
            partCount: scheme.parts.length,
            startAyah: part.ayahRange.startAyah,
            endAyah: part.ayahRange.endAyah,
            remaining: rotation.rotationTarget - part.rotationScore,
            recommendationRank: recommendedPartIds[surah.id] == part.id
                ? recommendationRanks[surah.id]
                : null,
            displayOrder: surah.displayOrder,
            lastUsedAtUtc: part.lastUsedAtUtc,
          ),
        );
      }
    }

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
      learningCandidate = LearningWidgetCandidate(
        surahId: learningState.surahId,
        surahNumber: descriptor.surahNumber,
        displayName: descriptor.displayName,
        stageLabel: learningState.stage.kind == LearningStageKind.newAyah
            ? l10n.newAyah(learningState.stage.ayahNumber)
            : l10n.cumulativeRange(learningState.stage.endAyah),
        startAyah: startAyah,
        endAyah: endAyah,
        verifiedTextLines: await _verifiedArabicTextLines(
          surahNumber: descriptor.surahNumber,
          startAyah: startAyah,
          endAyah: endAyah,
        ),
      );
    }

    return WidgetProjectionBuilder(
      WidgetProjectionLabels(
        part: l10n.widgetPart,
        ayah: l10n.widgetAyah,
        ayahs: l10n.widgetAyahs,
        openAppToLoadText: l10n.widgetOpenAppToLoadText,
      ),
    ).build(
      generatedAtUtc: timeProvider.nowUtc(),
      locale: localeCode,
      rotationCandidates: candidates,
      learningCandidate: learningCandidate,
    );
  }

  Future<List<String>> _verifiedArabicTextLines({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    final ayahs = await quranText.getRange(
      surahNumber: surahNumber,
      startAyah: startAyah,
      endAyah: endAyah,
    );
    return List<String>.unmodifiable(ayahs.map((ayah) => ayah.arabicText));
  }
}
