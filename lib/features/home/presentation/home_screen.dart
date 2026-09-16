import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';
import '../../prayer_times/prayer_times.dart';
import '../../quran/quran.dart';
import 'widgets/recommendation_rank_badge.dart';

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.primaryNavigationIndexListenable});

  final ValueListenable<int>? primaryNavigationIndexListenable;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const Duration _recitationSnackBarDuration = Duration(seconds: 4);

  final Set<String> _busySurahIds = <String>{};
  final Set<String> _openCoverageSheetSurahIds = <String>{};
  final Set<String> _busyRoutinePartIds = <String>{};

  @override
  void initState() {
    super.initState();
    widget.primaryNavigationIndexListenable?.addListener(
      _handlePrimaryNavigationChanged,
    );
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(
      oldWidget.primaryNavigationIndexListenable,
      widget.primaryNavigationIndexListenable,
    )) {
      return;
    }
    oldWidget.primaryNavigationIndexListenable?.removeListener(
      _handlePrimaryNavigationChanged,
    );
    widget.primaryNavigationIndexListenable?.addListener(
      _handlePrimaryNavigationChanged,
    );
  }

  @override
  void dispose() {
    widget.primaryNavigationIndexListenable?.removeListener(
      _handlePrimaryNavigationChanged,
    );
    super.dispose();
  }

  bool get _isPrimaryHomeSectionActive =>
      switch (widget.primaryNavigationIndexListenable?.value) {
        null || 0 => true,
        _ => false,
      };

  void _handlePrimaryNavigationChanged() {
    if (!mounted || _isPrimaryHomeSectionActive) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
  }

  @override
  Widget build(BuildContext context) {
    final rotation = ref.watch(rotationSnapshotProvider);
    final learning = ref.watch(activeLearningProvider);
    final catalog = ref.watch(fullCatalogProvider);
    final manualPrayer = ref.watch(selectedPrayerProvider);
    final prayerResolution = _settledAsyncValue(
      ref.watch(homePrayerContextResolutionProvider),
    );
    // Presentation only: neither of these is a family key, so keeping the last
    // known value across a reload cannot make the screen thrash.
    final scheduleResolution = _lastKnownAsyncValue(
      ref.watch(prayerScheduleContextResolutionProvider),
    );
    final prayerSettings = _lastKnownAsyncValue(
      ref.watch(prayerTimeSettingsProvider),
    );
    final prayerSchedule = _matchingPrayerSchedule(
      ref.watch(prayerTodayScheduleProvider),
      prayerSettings,
    );
    final canOfferJumuahOverride = _canOfferJumuahOverride(
      resolution: prayerResolution,
      settings: prayerSettings,
      schedule: prayerSchedule,
    );
    final localDate = ref.watch(localDateProvider).today();
    final resolvedPrayerContext = prayerResolution?.context;
    final AsyncValue<PrayerRoutineSessionSnapshot?>? currentRoutine =
        resolvedPrayerContext == null
        ? null
        : ref.watch(
            currentPrayerRoutineProvider((
              context: resolvedPrayerContext,
              localDate: localDate,
            )),
          );
    final recommendationBatch = resolvedPrayerContext == null
        ? null
        : ref
              .watch(
                currentRecommendationBatchProvider((
                  context: resolvedPrayerContext,
                  localDate: localDate,
                )),
              )
              .valueOrNull;
    final completedSurahIds = resolvedPrayerContext == null
        ? const <String>{}
        : ref.watch(
            recitedInCurrentOccurrenceProvider((
              context: resolvedPrayerContext,
              localDate: localDate,
            )),
          );
    var routineMarkingEnabled = true;
    if (currentRoutine != null) {
      final routine = currentRoutine.valueOrNull;
      routineMarkingEnabled =
          routine == null || routine.currentPart?.nextSlotIndex != null;
    }
    final selectedLearningSurahId = ref.watch(selectedLearningSurahProvider);
    final rollbackQueue = ref.watch(learningRollbackQueueProvider);
    if (currentRoutine?.valueOrNull != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _rememberRoutineCardHeight(),
      );
    }

    return Scaffold(
      key: const ValueKey<String>('home-screen'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(rotationSnapshotProvider)
              ..invalidate(activeLearningProvider)
              ..invalidate(catalogProvider)
              ..invalidate(currentPrayerRoutineProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar.large(
                title: Text(context.l10n.appName),
                actions: <Widget>[
                  IconButton(
                    key: const ValueKey<String>('open-calendar'),
                    tooltip: context.l10n.openCalendar,
                    onPressed: () => context.go('/calendar'),
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                  IconButton(
                    tooltip: context.l10n.openHistory,
                    onPressed: () => context.push('/history'),
                    icon: const Icon(Icons.history),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.list(
                  children: <Widget>[
                    _PrayerContextCard(
                      resolution: prayerResolution,
                      scheduleResolution: scheduleResolution,
                      settings: prayerSettings,
                      schedule: prayerSchedule,
                      // What is in effect wins over what was once persisted.
                      // The other order showed Магриб ticked while the card
                      // read Иша, because a sticky override never writes the
                      // stored selection.
                      onTap: () => _showPrayerPicker(
                        prayerResolution?.context ?? manualPrayer,
                      ),
                      onJumuahOverride: canOfferJumuahOverride
                          ? () => _setPrayerContextOverride(
                              PrayerContext(prayerType: PrayerType.jumuah),
                            )
                          : null,
                      onReturnToAutomatic:
                          ref.watch(activePrayerContextOverrideProvider) == null
                          ? null
                          : () =>
                                ref
                                        .read(
                                          prayerContextOverrideProvider
                                              .notifier,
                                        )
                                        .state =
                                    null,
                    ),
                    if (currentRoutine != null) ...<Widget>[
                      currentRoutine.when(
                        data: (routine) => routine == null
                            ? const SizedBox.shrink()
                            : KeyedSubtree(
                                key: _routineCardKey,
                                child: _PrayerRoutineCard(
                                  snapshot: routine,
                                  prayerContext: resolvedPrayerContext!,
                                  busyPartIds: _busyRoutinePartIds,
                                  onFollowedImam: _completeByFollowingImam,
                                ),
                              ),
                        // Switching prayers loads a different routine, and
                        // collapsing to nothing while it arrives made the page
                        // shrink and then grow again — the two jumps the owner
                        // reported. Holding the space the last card occupied
                        // keeps the scroll position still without showing the
                        // previous prayer's parts under the new prayer's name.
                        loading: () => SizedBox(height: _lastRoutineCardHeight),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (currentRoutine == null) const SizedBox(height: 16),
                    if (rollbackQueue.isNotEmpty)
                      _RollbackNotice(
                        outcome: rollbackQueue.first,
                        onUndo: () =>
                            _undoLearningRollback(rollbackQueue.first),
                      ),
                    if (rollbackQueue.isNotEmpty) const SizedBox(height: 16),
                    rotation.when(
                      data: (snapshot) => _RotationContent(
                        snapshot: snapshot,
                        busyIds: _busySurahIds,
                        markingEnabled: routineMarkingEnabled,
                        batch: recommendationBatch,
                        completedSurahIds: completedSurahIds,
                        stabilize: (rows) => _stabilizeRowOrder(
                          rows,
                          contextKey:
                              '${resolvedPrayerContext?.prayerType.name}|'
                              '${resolvedPrayerContext?.isQada}|$localDate',
                        ),
                        onMarkRequested: (surah) => _handleMarkRequest(surah),
                        onAdvancedMarkRequested: (surah) =>
                            _handleMarkRequest(surah, advanced: true),
                      ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, stackTrace) => _InlineError(
                        onRetry: () => ref.invalidate(rotationSnapshotProvider),
                      ),
                    ),
                    const SizedBox(height: 16),
                    learning.when(
                      data: (items) => _CurrentLearningCard(
                        learning: items,
                        catalog: catalog.valueOrNull ?? const <CatalogSurah>[],
                        selectedSurahId: selectedLearningSurahId,
                        onOpen: () => context.go('/learning'),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// How tall the routine card was when it was last on screen.
  ///
  /// Used to hold that space while a different prayer's routine loads, so the
  /// page does not shrink and grow again. Measured rather than guessed,
  /// because the card's height is the number of parts and no constant is right
  /// for every prayer.
  final GlobalKey _routineCardKey = GlobalKey();
  double _lastRoutineCardHeight = 0;

  void _rememberRoutineCardHeight() {
    final box =
        _routineCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final height = box.size.height;
    // No setState: this is read by the *next* build, and asking for one here
    // would schedule a rebuild that changes nothing.
    if (height > 0) _lastRoutineCardHeight = height;
  }

  /// Remembered row order for the active-surah list.
  ///
  /// Marking a surah changes how overdue it is, which changes the operational
  /// order, which moved the next row out from under the user's finger. This is
  /// a presentation cache written during build on purpose: the value is
  /// consumed in the same frame that computes it, so there is nothing to
  /// notify and `setState` would only schedule a redundant rebuild.
  String? _rowOrderContextKey;
  List<String> _rowOrder = const <String>[];

  List<MasteredSurah> _stabilizeRowOrder(
    List<MasteredSurah> rows, {
    required String contextKey,
  }) {
    if (_rowOrderContextKey != contextKey) {
      _rowOrderContextKey = contextKey;
      _rowOrder = <String>[for (final row in rows) row.id];
      return rows;
    }
    final order = const StableOrderService().reorder(
      previous: _rowOrder,
      current: <String>[for (final row in rows) row.id],
    );
    _rowOrder = order;
    final byId = <String, MasteredSurah>{for (final row in rows) row.id: row};
    return <MasteredSurah>[for (final id in order) ?byId[id]];
  }

  /// What the prayer picker should open on: whatever is actually in effect.
  ///
  /// A sticky override never writes the persisted selection, so reading the
  /// stored value first showed a prayer the user had left behind — Магриб
  /// ticked while the card read Иша, on video.
  PrayerContext? _pickerInitialContext() =>
      _settledAsyncValue(
        ref.read(homePrayerContextResolutionProvider),
      )?.context ??
      ref.read(selectedPrayerProvider);

  /// The one UI entry point for marking a surah.
  Future<void> _handleMarkRequest(
    MasteredSurah surah, {
    bool advanced = false,
  }) async {
    var actionPrayer = await _resolvePrayerForAction();
    if (!mounted) return;
    if (actionPrayer == null) {
      final selected = await _showPrayerPicker(_pickerInitialContext());
      if (selected == null || !mounted) return;
      actionPrayer = _ActionPrayerContext(
        context: selected,
        isAutomatic: false,
      );
    }
    if (!surah.rotationScheme.isSplit && !advanced) {
      return _registerRecitation(surah, actionPrayer.context);
    }
    if (_busySurahIds.contains(surah.id) ||
        !_openCoverageSheetSurahIds.add(surah.id)) {
      return;
    }
    try {
      final prayerSettings = await _loadPrayerTimeSettings();
      if (!mounted) return;
      final selection = await showModalBottomSheet<_RecitationSelection>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _RecitationCoverageSheet(
          surah: surah,
          initialPrayerContext: actionPrayer!.context,
          initialPrayerIsAutomatic: actionPrayer.isAutomatic,
          initialOccurrenceLocalDate: ref.read(localDateProvider).today(),
          timeProvider: ref.read(timeProviderProvider),
          localDates: ref.read(localDateProvider),
          utcOffsetMinutes: prayerSettings.locationConfirmed
              ? prayerSettings.location.utcOffsetMinutes
              : null,
          todaySchedule: prayerSettings.locationConfirmed
              ? _matchingPrayerSchedule(
                  ref.read(prayerTodayScheduleProvider),
                  prayerSettings,
                )
              : null,
        ),
      );
      if (selection == null || !mounted) return;
      var prayerContext = selection.prayerContext;
      var occurrenceLocalDate = selection.occurrenceLocalDate;
      if (actionPrayer.isAutomatic &&
          selection.shortcut == PrayerRegistrationShortcut.now) {
        var latest = await _resolvePrayerForAction();
        if (!mounted) return;
        if (latest == null) {
          final selected = await _showPrayerPicker(_pickerInitialContext());
          if (selected == null || !mounted) return;
          latest = _ActionPrayerContext(context: selected, isAutomatic: false);
        }
        prayerContext = latest.context;
        occurrenceLocalDate = ref.read(localDateProvider).today();
      }
      await _registerRecitation(
        surah,
        prayerContext,
        coveredPartIds: selection.coveredPartIds,
        rakaatSpanCount: selection.rakaatSpanCount,
        occurrenceLocalDate: occurrenceLocalDate,
      );
    } finally {
      _openCoverageSheetSurahIds.remove(surah.id);
    }
  }

  /// Automatic attribution is resolved at the action boundary. A timer keeps
  /// Home current for presentation, but a delayed rebuild can never authorize
  /// a write with an old prayer or an expired schedule.
  Future<_ActionPrayerContext?> _resolvePrayerForAction() async {
    final settings = await _loadPrayerTimeSettings();
    if (settings.contextSelectionMode == PrayerContextSelectionMode.manual) {
      final selected =
          ref.read(selectedPrayerProvider) ??
          await ref.read(prayerRepositoryProvider).getSelectedContext();
      return selected == null
          ? null
          : _ActionPrayerContext(context: selected, isAutomatic: false);
    }

    final override = ref.read(activePrayerContextOverrideProvider);
    if (override != null) {
      return _ActionPrayerContext(context: override, isAutomatic: false);
    }
    if (!settings.locationConfirmed) return null;
    final today = _matchingPrayerSchedule(
      ref.read(prayerTodayScheduleProvider),
      settings,
    );
    if (today == null) return null;
    final resolution = today.resolveAutomaticContext(
      ref.read(timeProviderProvider),
    );
    final context = resolution.context;
    return context == null
        ? null
        : _ActionPrayerContext(context: context, isAutomatic: true);
  }

  Future<PrayerTimeSettings> _loadPrayerTimeSettings() async {
    final state = ref.read(prayerTimeSettingsProvider);
    final settled = _settledAsyncValue(state);
    if (settled != null) return settled;
    final prayerRepository = ref.read(prayerRepositoryProvider);
    return ref
        .read(prayerTimeSettingsRepositoryProvider)
        .load(
          legacyManualContextExists: () async =>
              await prayerRepository.getSelectedContext() != null,
        );
  }

  Future<void> _registerRecitation(
    MasteredSurah surah,
    PrayerContext prayer, {
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
    LocalDate? occurrenceLocalDate,
  }) async {
    if (_busySurahIds.contains(surah.id)) return;
    setState(() => _busySurahIds.add(surah.id));
    try {
      final localDate =
          occurrenceLocalDate ?? ref.read(localDateProvider).today();
      final routine = await ref
          .read(prayerRoutineRepositoryProvider)
          .ensureCurrentSession(
            context: prayer,
            localDate: localDate,
            startedAtUtc: ref.read(timeProviderProvider).nowUtc(),
          );
      final routinePart = routine?.currentPart;
      final slotIndex = routinePart?.nextSlotIndex;
      if (routine != null && slotIndex == null) {
        if (mounted && _isPrimaryHomeSectionActive) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
          messenger.showSnackBar(
            SnackBar(
              key: const ValueKey<String>(
                'prayer-routine-unavailable-snackbar',
              ),
              content: Text(
                routine.isCompleted
                    ? context.l10n.prayerRoutineComplete
                    : context.l10n.prayerRoutineNoAvailableSlot,
              ),
            ),
          );
        }
        return;
      }
      final registration = await ref
          .read(appActionsProvider)
          .registerRecitation(
            surahId: surah.id,
            prayerContext: prayer,
            prayerSessionId: slotIndex == null ? null : routine!.session.id,
            prayerSessionPartId: slotIndex == null
                ? null
                : routinePart!.part.id,
            slotIndex: slotIndex,
            coveredPartIds: coveredPartIds,
            rakaatSpanCount: rakaatSpanCount,
            occurrenceLocalDate: localDate,
          );
      // A manual context deliberately survives this mark: it is cleared only
      // by the explicit "back to automatic" action or once its local date has
      // passed. Re-picking Witr or Nafl for every surah was the reported bug.
      if (!mounted || !_isPrimaryHomeSectionActive) return;
      final messenger = ScaffoldMessenger.of(context);
      // An action makes SnackBar persistent by default in current Flutter.
      // Remove any older Undo action and opt out of that persistence explicitly.
      messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
      messenger.showSnackBar(
        SnackBar(
          key: ValueKey<String>('recitation-snackbar-${registration.event.id}'),
          duration: _recitationSnackBarDuration,
          persist: false,
          content: Text(context.l10n.surahMarked),
          action: SnackBarAction(
            key: const ValueKey<String>('undo-recitation'),
            label: context.l10n.undo,
            onPressed: () async {
              await ref
                  .read(recitationRepositoryProvider)
                  .undo(registration.undoToken);
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted && _isPrimaryHomeSectionActive) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _busySurahIds.remove(surah.id));
    }
  }

  Future<void> _completeByFollowingImam(
    PrayerSessionPartProgress progress,
  ) async {
    final part = progress.part;
    if (_busyRoutinePartIds.contains(part.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.followedImamConfirmTitle),
        content: Text(context.l10n.followedImamConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('cancel-followed-imam'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-followed-imam'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyRoutinePartIds.add(part.id));
    try {
      final completion = await ref
          .read(prayerRoutineRepositoryProvider)
          .completeByFollowingImam(
            prayerSessionPartId: part.id,
            completedAtUtc: ref.read(timeProviderProvider).nowUtc(),
          );
      // Same rule as an ordinary mark: following the imam does not end a
      // manually chosen context.
      ref.invalidate(currentPrayerRoutineProvider);
      final undoToken = completion.undoToken;
      if (!mounted || undoToken == null) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
      messenger.showSnackBar(
        SnackBar(
          duration: _recitationSnackBarDuration,
          persist: false,
          content: Text(context.l10n.followedImamCompleted),
          action: SnackBarAction(
            key: const ValueKey<String>('undo-followed-imam'),
            label: context.l10n.undo,
            onPressed: () async {
              final undone = await ref
                  .read(prayerRoutineRepositoryProvider)
                  .undoFollowedImam(undoToken);
              if (undone && mounted) {
                ref.invalidate(currentPrayerRoutineProvider);
              }
            },
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _busyRoutinePartIds.remove(part.id));
    }
  }

  Future<PrayerContext?> _showPrayerPicker(PrayerContext? current) async {
    var prayerType = current?.prayerType;
    var isQada = current?.isQada ?? false;
    final selected = await showModalBottomSheet<PrayerContext>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.selectPrayer,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final type in PrayerType.values)
                      ChoiceChip(
                        label: Text(type.label(context.l10n)),
                        selected: type == prayerType,
                        onSelected: (_) => setModalState(() {
                          prayerType = type;
                          if (!type.supportsQada) isQada = false;
                        }),
                      ),
                  ],
                ),
                if (prayerType?.supportsQada ?? false) ...<Widget>[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.isQadaLabel),
                    value: isQada,
                    onChanged: (value) => setModalState(() => isQada = value),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: prayerType == null
                      ? null
                      : () => Navigator.of(context).pop(
                          PrayerContext(
                            prayerType: prayerType!,
                            isQada: isQada,
                          ),
                        ),
                  child: Text(context.l10n.confirm),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      final prayerTimeSettings = await _loadPrayerTimeSettings();
      if (prayerTimeSettings.contextSelectionMode ==
          PrayerContextSelectionMode.manual) {
        await ref.read(selectedPrayerProvider.notifier).select(selected);
      } else {
        _setPrayerContextOverride(selected);
      }
    }
    return selected;
  }

  /// Scopes the override to the local date it was chosen for, so it can stay
  /// selected across a series of marks without ever leaking into the next day.
  void _setPrayerContextOverride(PrayerContext context) {
    ref
        .read(prayerContextOverrideProvider.notifier)
        .state = PrayerContextOverride(
      context: context,
      localDate: ref.read(localDateProvider).today(),
    );
  }

  Future<void> _undoLearningRollback(LearningActionOutcome outcome) async {
    final event = outcome.event;
    if (event == null) return;
    final machine = LearningStateMachine(
      timeProvider: ref.read(timeProviderProvider),
    );
    final undo = machine.undo(outcome);
    if (!undo.didUndo) return;
    await ref
        .read(learningRepositoryProvider)
        .undoOutcome(outcome, restoredState: undo.value);
    ref.read(learningRollbackQueueProvider.notifier).remove(event.id);
  }
}

final class _ActionPrayerContext {
  const _ActionPrayerContext({
    required this.context,
    required this.isAutomatic,
  });

  final PrayerContext context;
  final bool isAutomatic;
}

final class _PrayerRoutineCard extends StatelessWidget {
  const _PrayerRoutineCard({
    required this.snapshot,
    required this.prayerContext,
    required this.busyPartIds,
    required this.onFollowedImam,
  });

  final PrayerRoutineSessionSnapshot snapshot;
  final PrayerContext prayerContext;
  final Set<String> busyPartIds;
  final ValueChanged<PrayerSessionPartProgress> onFollowedImam;

  @override
  Widget build(BuildContext context) {
    final current = snapshot.currentPart;
    return Card(
      key: const ValueKey<String>('current-prayer-routine'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              current == null
                  ? context.l10n.prayerRoutineComplete
                  : context.l10n.prayerRoutineCurrentPart(
                      prayerContext.prayerType.label(context.l10n),
                      _sessionPartLabel(context, current.part),
                    ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final progress in snapshot.parts)
              _PrayerRoutinePartTile(
                progress: progress,
                isCurrent: progress.part.id == current?.part.id,
                isBusy: busyPartIds.contains(progress.part.id),
                onFollowedImam: onFollowedImam,
              ),
          ],
        ),
      ),
    );
  }
}

final class _PrayerRoutinePartTile extends StatelessWidget {
  const _PrayerRoutinePartTile({
    required this.progress,
    required this.isCurrent,
    required this.isBusy,
    required this.onFollowedImam,
  });

  final PrayerSessionPartProgress progress;
  final bool isCurrent;
  final bool isBusy;
  final ValueChanged<PrayerSessionPartProgress> onFollowedImam;

  @override
  Widget build(BuildContext context) {
    final part = progress.part;
    final canFollowImam =
        isCurrent &&
        !part.isCompleted &&
        part.kind == PrayerRoutinePartKind.fard &&
        part.allowsFollowingImam &&
        progress.completedSlotCount == 0;
    final progressLabel = part.wasFollowedImam
        ? context.l10n.followedImamCompleted
        : context.l10n.prayerRoutineSlotProgress(
            progress.completedSlotCount,
            part.requiredSurahSlots,
          );
    return Semantics(
      selected: isCurrent,
      child: ListTile(
        key: ValueKey<String>('current-prayer-part-${part.id}'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          part.isCompleted
              ? Icons.check_circle
              : isCurrent
              ? Icons.play_circle_outline
              : Icons.radio_button_unchecked,
          color: part.isCompleted || isCurrent
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        title: Text(_sessionPartLabel(context, part)),
        subtitle: Text(
          '${context.l10n.routinePartSummary(part.rakaatCount, part.requiredSurahSlots)}\n'
          '$progressLabel',
        ),
        isThreeLine: true,
        trailing: canFollowImam
            ? TextButton(
                key: ValueKey<String>('followed-imam-${part.id}'),
                onPressed: isBusy ? null : () => onFollowedImam(progress),
                child: Text(context.l10n.followedImamAction),
              )
            : null,
      ),
    );
  }
}

String _sessionPartLabel(BuildContext context, PrayerSessionPart part) =>
    part.kind == PrayerRoutinePartKind.custom
    ? part.label
    : switch (part.kind) {
        PrayerRoutinePartKind.fard => context.l10n.partKindFard,
        PrayerRoutinePartKind.sunnah => context.l10n.partKindSunnah,
        PrayerRoutinePartKind.witr => context.l10n.partKindWitr,
        PrayerRoutinePartKind.nafl => context.l10n.partKindNafl,
        PrayerRoutinePartKind.custom => part.label,
      };

final class _RecitationSelection {
  const _RecitationSelection({
    required this.coveredPartIds,
    required this.rakaatSpanCount,
    required this.prayerContext,
    required this.occurrenceLocalDate,
    required this.shortcut,
  });

  final List<String> coveredPartIds;
  final int rakaatSpanCount;
  final PrayerContext prayerContext;
  final LocalDate occurrenceLocalDate;
  final PrayerRegistrationShortcut shortcut;
}

final class _RecitationCoverageSheet extends StatefulWidget {
  const _RecitationCoverageSheet({
    required this.surah,
    required this.initialPrayerContext,
    required this.initialPrayerIsAutomatic,
    required this.initialOccurrenceLocalDate,
    required this.timeProvider,
    required this.localDates,
    required this.utcOffsetMinutes,
    required this.todaySchedule,
  });

  final MasteredSurah surah;
  final PrayerContext initialPrayerContext;
  final bool initialPrayerIsAutomatic;
  final LocalDate initialOccurrenceLocalDate;
  final TimeProvider timeProvider;
  final LocalDateProvider localDates;
  final int? utcOffsetMinutes;
  final PrayerTodaySchedule? todaySchedule;

  @override
  State<_RecitationCoverageSheet> createState() =>
      _RecitationCoverageSheetState();
}

final class _RecitationCoverageSheetState
    extends State<_RecitationCoverageSheet> {
  late Set<String> _selectedPartIds;
  int _rakaatSpanCount = 1;
  late PrayerContext _prayerContext;
  late LocalDate _occurrenceLocalDate;
  PrayerRegistrationShortcut _registrationShortcut =
      PrayerRegistrationShortcut.now;

  @override
  void initState() {
    super.initState();
    _selectedPartIds = widget.surah.rotationScheme.parts
        .map((part) => part.id)
        .toSet();
    _prayerContext = widget.initialPrayerContext;
    _occurrenceLocalDate = widget.initialOccurrenceLocalDate;
  }

  bool get _isWhole =>
      _selectedPartIds.length == widget.surah.rotationScheme.parts.length;

  Future<void> _selectPrayerOccurrence() async {
    final selected = await showModalBottomSheet<PrayerRegistrationSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PrayerOccurrenceSheet(
        initialPrayerContext: _prayerContext,
        initialOccurrenceLocalDate: _occurrenceLocalDate,
        currentPrayerContext: widget.initialPrayerContext,
        currentPrayerIsAutomatic: widget.initialPrayerIsAutomatic,
        currentLocalDate: widget.initialOccurrenceLocalDate,
        timeProvider: widget.timeProvider,
        localDates: widget.localDates,
        utcOffsetMinutes: widget.utcOffsetMinutes,
        todaySchedule: widget.todaySchedule,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _prayerContext = selected.prayerContext;
      _occurrenceLocalDate = selected.occurrenceLocalDate;
      _registrationShortcut = selected.shortcut;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 48),
                    child: Text(
                      widget.surah.surah.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  PositionedDirectional(
                    top: -12,
                    end: 0,
                    child: IconButton(
                      key: const ValueKey<String>(
                        'select-registration-occurrence',
                      ),
                      tooltip: context.l10n.registrationWhenTitle,
                      onPressed: _selectPrayerOccurrence,
                      icon: const Icon(Icons.event_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(context.l10n.selectCoverage),
              const SizedBox(height: 12),
              ChoiceChip(
                key: const ValueKey<String>('coverage-whole-surah'),
                label: Text(context.l10n.wholeSurah),
                selected: _isWhole,
                onSelected: (_) => setState(() {
                  _selectedPartIds = widget.surah.rotationScheme.parts
                      .map((part) => part.id)
                      .toSet();
                }),
              ),
              const SizedBox(height: 8),
              for (final part in widget.surah.rotationScheme.parts)
                CheckboxListTile(
                  key: ValueKey<String>('coverage-part-${part.partNumber}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.partLabel(part.partNumber)),
                  subtitle: Text(
                    context.l10n.ayahRange(
                      part.ayahRange.startAyah,
                      part.ayahRange.endAyah,
                    ),
                  ),
                  value: _selectedPartIds.contains(part.id),
                  onChanged: (selected) => setState(() {
                    if (selected ?? false) {
                      _selectedPartIds.add(part.id);
                    } else {
                      _selectedPartIds.remove(part.id);
                    }
                  }),
                ),
              const SizedBox(height: 8),
              Text(
                context.l10n.rakaatSpan(_rakaatSpanCount),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                key: const ValueKey<String>('rakaat-span-selector'),
                segments: <ButtonSegment<int>>[
                  for (var count = 1; count <= 4; count += 1)
                    ButtonSegment<int>(value: count, label: Text('$count')),
                ],
                selected: <int>{_rakaatSpanCount},
                onSelectionChanged: (selection) =>
                    setState(() => _rakaatSpanCount = selection.single),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey<String>('confirm-recitation-coverage'),
                onPressed: _selectedPartIds.isEmpty
                    ? null
                    : () {
                        final selected = <String>[
                          for (final part in widget.surah.rotationScheme.parts)
                            if (_selectedPartIds.contains(part.id)) part.id,
                        ];
                        Navigator.of(context).pop(
                          _RecitationSelection(
                            coveredPartIds: List<String>.unmodifiable(selected),
                            rakaatSpanCount: _rakaatSpanCount,
                            prayerContext: _prayerContext,
                            occurrenceLocalDate: _occurrenceLocalDate,
                            shortcut: _registrationShortcut,
                          ),
                        );
                      },
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PrayerOccurrenceSheet extends StatefulWidget {
  const _PrayerOccurrenceSheet({
    required this.initialPrayerContext,
    required this.initialOccurrenceLocalDate,
    required this.currentPrayerContext,
    required this.currentPrayerIsAutomatic,
    required this.currentLocalDate,
    required this.timeProvider,
    required this.localDates,
    required this.utcOffsetMinutes,
    required this.todaySchedule,
  });

  final PrayerContext initialPrayerContext;
  final LocalDate initialOccurrenceLocalDate;
  final PrayerContext currentPrayerContext;
  final bool currentPrayerIsAutomatic;
  final LocalDate currentLocalDate;
  final TimeProvider timeProvider;
  final LocalDateProvider localDates;
  final int? utcOffsetMinutes;
  final PrayerTodaySchedule? todaySchedule;

  @override
  State<_PrayerOccurrenceSheet> createState() => _PrayerOccurrenceSheetState();
}

final class _PrayerOccurrenceSheetState extends State<_PrayerOccurrenceSheet> {
  late PrayerContext _prayerContext;
  late LocalDate _occurrenceLocalDate;
  late PrayerRegistrationShortcut _shortcut;

  @override
  void initState() {
    super.initState();
    _prayerContext = widget.initialPrayerContext;
    _occurrenceLocalDate = widget.initialOccurrenceLocalDate;
    _shortcut =
        _occurrenceLocalDate == widget.currentLocalDate &&
            _prayerContext == widget.currentPrayerContext
        ? PrayerRegistrationShortcut.now
        : PrayerRegistrationShortcut.customDateAndPrayer;
  }

  PrayerRegistrationShortcutResult get _previousPrayer {
    final today = widget.todaySchedule;
    final nowUtc = widget.timeProvider.nowUtc();
    return PrayerRegistrationShortcutResolver(
      widget.timeProvider,
    ).resolvePreviousPrayer(
      currentDaySchedule: today?.day,
      currentDayScheduleIsReliable:
          today?.currentDayIsReliableAt(nowUtc) ?? false,
      previousDaySchedule: today?.previousDay,
      previousDayScheduleIsReliable:
          today?.previousDayIsReliableAt(nowUtc) ?? false,
    );
  }

  PrayerRegistrationShortcutResult get _now {
    if (!widget.currentPrayerIsAutomatic) {
      return PrayerRegistrationShortcutResult.resolved(
        PrayerRegistrationSelection(
          shortcut: PrayerRegistrationShortcut.now,
          occurrenceLocalDate: widget.localDates.today(),
          prayerContext: widget.currentPrayerContext,
        ),
      );
    }
    final today = widget.todaySchedule;
    if (today == null) {
      return const PrayerRegistrationShortcutResult.unavailable(
        PrayerRegistrationShortcutStatus.missingSchedule,
      );
    }
    return PrayerRegistrationShortcutResolver(widget.timeProvider).resolveNow(
      currentResolution: today.resolveAutomaticContext(widget.timeProvider),
      utcOffsetMinutes: today.day.utcOffsetMinutes,
    );
  }

  void _selectNow() {
    final selection = _now.selection;
    if (selection == null) return;
    setState(() {
      _shortcut = selection.shortcut;
      _occurrenceLocalDate = selection.occurrenceLocalDate;
      _prayerContext = selection.prayerContext;
    });
  }

  void _selectPreviousPrayer() {
    final selection = _previousPrayer.selection;
    if (selection == null) return;
    setState(() {
      _shortcut = selection.shortcut;
      _occurrenceLocalDate = selection.occurrenceLocalDate;
      _prayerContext = selection.prayerContext;
    });
  }

  void _selectYesterday() => setState(() {
    _shortcut = PrayerRegistrationShortcut.yesterday;
    final offset = widget.utcOffsetMinutes;
    if (offset != null) {
      final selection = PrayerRegistrationShortcutResolver(widget.timeProvider)
          .resolveYesterday(
            prayerContext: _prayerContext,
            utcOffsetMinutes: offset,
          )
          .selection!;
      _occurrenceLocalDate = selection.occurrenceLocalDate;
      return;
    }
    _occurrenceLocalDate = _shiftLocalDate(widget.localDates.today(), -1);
  });

  Future<void> _selectCustomDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _asDateTime(_occurrenceLocalDate),
      firstDate: DateTime(2000),
      lastDate: _asDateTime(widget.localDates.today()),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _shortcut = PrayerRegistrationShortcut.customDateAndPrayer;
      _occurrenceLocalDate = LocalDate.fromLocalDateTime(selected);
    });
  }

  void _selectPrayerType(PrayerType type) => setState(() {
    if (_shortcut == PrayerRegistrationShortcut.now ||
        _shortcut == PrayerRegistrationShortcut.previousPrayer) {
      _shortcut = PrayerRegistrationShortcut.customDateAndPrayer;
    }
    _prayerContext = PrayerContext(
      prayerType: type,
      isQada: type.supportsQada ? _prayerContext.isQada : false,
    );
  });

  void _selectQada(bool value) => setState(() {
    if (_shortcut == PrayerRegistrationShortcut.now ||
        _shortcut == PrayerRegistrationShortcut.previousPrayer) {
      _shortcut = PrayerRegistrationShortcut.customDateAndPrayer;
    }
    _prayerContext = PrayerContext(
      prayerType: _prayerContext.prayerType,
      isQada: value,
    );
  });

  PrayerRegistrationSelection _yesterdaySelection() {
    final offset = widget.utcOffsetMinutes;
    if (offset != null) {
      return PrayerRegistrationShortcutResolver(widget.timeProvider)
          .resolveYesterday(
            prayerContext: _prayerContext,
            utcOffsetMinutes: offset,
          )
          .selection!;
    }
    return PrayerRegistrationSelection(
      shortcut: PrayerRegistrationShortcut.yesterday,
      occurrenceLocalDate: _shiftLocalDate(widget.localDates.today(), -1),
      prayerContext: _prayerContext,
    );
  }

  PrayerRegistrationSelection? _selectionForConfirmation() =>
      switch (_shortcut) {
        PrayerRegistrationShortcut.now => _now.selection,
        PrayerRegistrationShortcut.previousPrayer => _previousPrayer.selection,
        PrayerRegistrationShortcut.yesterday => _yesterdaySelection(),
        PrayerRegistrationShortcut.customDateAndPrayer =>
          PrayerRegistrationShortcutResolver(widget.timeProvider)
              .resolveCustom(
                occurrenceLocalDate: _occurrenceLocalDate,
                prayerContext: _prayerContext,
              )
              .selection,
      };

  @override
  Widget build(BuildContext context) {
    final now = _now.selection;
    final previous = _previousPrayer.selection;
    final canConfirm = _selectionForConfirmation() != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.registrationWhenTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    key: const ValueKey<String>('registration-now'),
                    label: Text(context.l10n.registrationNow),
                    selected: _shortcut == PrayerRegistrationShortcut.now,
                    onSelected: now == null ? null : (_) => _selectNow(),
                  ),
                  ChoiceChip(
                    key: const ValueKey<String>('registration-previous-prayer'),
                    label: Text(context.l10n.registrationPreviousPrayer),
                    selected:
                        _shortcut == PrayerRegistrationShortcut.previousPrayer,
                    onSelected: previous == null
                        ? null
                        : (_) => _selectPreviousPrayer(),
                  ),
                  ChoiceChip(
                    key: const ValueKey<String>('registration-yesterday'),
                    label: Text(context.l10n.registrationYesterday),
                    selected: _shortcut == PrayerRegistrationShortcut.yesterday,
                    onSelected: (_) => _selectYesterday(),
                  ),
                  ActionChip(
                    key: const ValueKey<String>('registration-custom-date'),
                    label: Text(context.l10n.registrationChooseDatePrayer),
                    onPressed: _selectCustomDate,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.registrationOccurrenceDate(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(_asDateTime(_occurrenceLocalDate)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final type in PrayerType.values)
                    ChoiceChip(
                      key: ValueKey<String>('registration-prayer-${type.name}'),
                      label: Text(type.label(context.l10n)),
                      selected: _prayerContext.prayerType == type,
                      onSelected: (_) => _selectPrayerType(type),
                    ),
                ],
              ),
              if (_prayerContext.prayerType.supportsQada)
                SwitchListTile(
                  key: const ValueKey<String>('registration-qada'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.isQadaLabel),
                  value: _prayerContext.isQada,
                  onChanged: _selectQada,
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey<String>('confirm-registration-occurrence'),
                onPressed: !canConfirm
                    ? null
                    : () {
                        final selection = _selectionForConfirmation();
                        if (selection != null) {
                          Navigator.of(context).pop(selection);
                        }
                      },
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _asDateTime(LocalDate date) =>
    DateTime(date.year, date.month, date.day);

LocalDate _shiftLocalDate(LocalDate date, int days) {
  final shifted = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(Duration(days: days));
  return LocalDate.fromLocalDateTime(shifted);
}

/// The schedule to draw, or null when there is genuinely nothing to draw.
///
/// A reloading schedule still holds the one it last produced, and
/// [PrayerTodaySchedule.matchesSettings] already decides whether that value is
/// about the settings in force — a far better test than "is this provider busy
/// this frame". Hiding the strip on every loading tick is visible jank, and the
/// value is presentational: it keys nothing.
PrayerTodaySchedule? _matchingPrayerSchedule(
  AsyncValue<PrayerTodaySchedule> state,
  PrayerTimeSettings? settings,
) {
  final value = state.valueOrNull;
  if (settings == null ||
      !settings.locationConfirmed ||
      value == null ||
      !value.matchesSettings(settings)) {
    return null;
  }
  return value;
}

/// A value only while the provider is idle.
///
/// Used for the resolved context, and deliberately so. That context is a
/// **family key** here — the routine, the batch and the occurrence are all
/// watched as `family((context: ..., localDate: ...))`. Feeding a stale
/// context back in makes the screen alternate between two family instances,
/// each disposing the other's element and invalidating the provider that
/// produced it: a rebuild loop that hangs the app. Presentation reads
/// [_lastKnownAsyncValue] instead.
T? _settledAsyncValue<T>(AsyncValue<T> state) =>
    state.isLoading || state.hasError ? null : state.valueOrNull;

/// The last value a provider produced, kept across a reload.
///
/// Only for values this screen *draws*, never for a family key. Hiding the
/// mode line and the whole prayer-time strip on every loading tick is what
/// made the card read «Выбрать намаз · Автоматически» mid-session.
T? _lastKnownAsyncValue<T>(AsyncValue<T> state) => state.valueOrNull;

bool _canOfferJumuahOverride({
  required PrayerContextResolution? resolution,
  required PrayerTimeSettings? settings,
  required PrayerTodaySchedule? schedule,
}) {
  if (settings?.contextSelectionMode != PrayerContextSelectionMode.automatic ||
      resolution?.status != PrayerContextResolutionStatus.automatic ||
      resolution?.context?.prayerType != PrayerType.dhuhr ||
      schedule == null) {
    return false;
  }
  final date = schedule.day.date;
  return DateTime.utc(date.year, date.month, date.day).weekday ==
      DateTime.friday;
}

final class _PrayerContextCard extends StatelessWidget {
  const _PrayerContextCard({
    required this.resolution,
    required this.scheduleResolution,
    required this.settings,
    required this.schedule,
    required this.onTap,
    required this.onJumuahOverride,
    required this.onReturnToAutomatic,
  });

  final PrayerContextResolution? resolution;
  final PrayerContextResolution? scheduleResolution;
  final PrayerTimeSettings? settings;
  final PrayerTodaySchedule? schedule;
  final VoidCallback onTap;
  final VoidCallback? onJumuahOverride;

  /// Non-null only while a manual context is actually overriding automatic
  /// resolution, so the user always has one visible way back.
  final VoidCallback? onReturnToAutomatic;

  @override
  Widget build(BuildContext context) {
    final resolved = resolution;
    final prayerContext = resolved?.context;
    final title =
        prayerContext?.label(context.l10n) ??
        _resolutionLabel(context, resolved?.status);
    final timing =
        settings?.contextSelectionMode == PrayerContextSelectionMode.automatic
        ? resolved
        : scheduleResolution;
    final details = <String>[
      resolved?.status == PrayerContextResolutionStatus.manual ||
              settings?.contextSelectionMode ==
                  PrayerContextSelectionMode.manual
          ? context.l10n.prayerModeManual
          : context.l10n.prayerModeAutomatic,
      if (timing?.currentStartsAt != null)
        timing?.currentEndsAt == null
            ? context.l10n.prayerStartsAt('${timing!.currentStartsAt}')
            : context.l10n.prayerTimeRange(
                '${timing!.currentStartsAt}',
                '${timing.currentEndsAt}',
              ),
      if (timing?.nextPrayerType != null && timing?.nextPrayerAt != null)
        context.l10n.nextPrayerAt(
          timing!.nextPrayerType!.label(context.l10n),
          '${timing.nextPrayerAt}',
        ),
      if (schedule case final loaded?)
        '${loaded.loadResult.schedule.provenance.source.displayName} · '
            '${loaded.loadResult.schedule.location.displayName}',
    ];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: const Icon(Icons.mosque_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.prayerContextTitle,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          key: const ValueKey<String>('prayer-context-title'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details.join('\n'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
          if (schedule case final loaded?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _PrayerScheduleStrip(
                schedule: loaded,
                scheduleResolution: scheduleResolution,
              ),
            ),
          if (onJumuahOverride != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ActionChip(
                  key: const ValueKey<String>('use-jumuah-for-next-recitation'),
                  avatar: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(context.l10n.useJumuahForNextRecitation),
                  onPressed: onJumuahOverride,
                ),
              ),
            ),
          if (onReturnToAutomatic != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ActionChip(
                  key: const ValueKey<String>('return-to-automatic-prayer'),
                  avatar: const Icon(Icons.autorenew, size: 18),
                  label: Text(context.l10n.returnToAutomaticPrayer),
                  onPressed: onReturnToAutomatic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _resolutionLabel(
    BuildContext context,
    PrayerContextResolutionStatus? status,
  ) => switch (status) {
    PrayerContextResolutionStatus.betweenPrayers => context.l10n.betweenPrayers,
    PrayerContextResolutionStatus.unreliableSchedule =>
      context.l10n.prayerScheduleStale,
    PrayerContextResolutionStatus.missingSchedule ||
    PrayerContextResolutionStatus.scheduleDateMismatch =>
      context.l10n.prayerScheduleUnavailable,
    _ => context.l10n.selectPrayer,
  };
}

/// A compact "Today" strip of the six daily boundaries. Sunrise is rendered
/// as an informational boundary, never as a selectable [PrayerType]. Current
/// and next are visually distinct; every other configured context (Witr,
/// Nafl, Qada, Jumuah) stays reachable through the header tap above, since
/// none of those has a schedule-derived time to show here.
final class _PrayerScheduleStrip extends StatelessWidget {
  const _PrayerScheduleStrip({
    required this.schedule,
    required this.scheduleResolution,
  });

  final PrayerTodaySchedule schedule;
  final PrayerContextResolution? scheduleResolution;

  @override
  Widget build(BuildContext context) {
    final times = schedule.day.times;
    final currentType = scheduleResolution?.context?.prayerType;
    final nextType = scheduleResolution?.nextPrayerType;
    final entries = <(String label, String time, PrayerType? type)>[
      (
        PrayerType.fajr.label(context.l10n),
        '${times.fajr.effective}',
        PrayerType.fajr,
      ),
      (context.l10n.sunrise, '${times.sunrise.effective}', null),
      (
        PrayerType.dhuhr.label(context.l10n),
        '${times.dhuhr.effective}',
        PrayerType.dhuhr,
      ),
      (
        PrayerType.asr.label(context.l10n),
        '${times.asr.effective}',
        PrayerType.asr,
      ),
      (
        PrayerType.maghrib.label(context.l10n),
        '${times.maghrib.effective}',
        PrayerType.maghrib,
      ),
      (
        PrayerType.isha.label(context.l10n),
        '${times.isha.effective}',
        PrayerType.isha,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final entry in entries) ...<Widget>[
            _PrayerScheduleEntry(
              label: entry.$1,
              timeLabel: entry.$2,
              isCurrent: entry.$3 != null && entry.$3 == currentType,
              isNext: entry.$3 != null && entry.$3 == nextType,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

final class _PrayerScheduleEntry extends StatelessWidget {
  const _PrayerScheduleEntry({
    required this.label,
    required this.timeLabel,
    required this.isCurrent,
    required this.isNext,
  });

  final String label;
  final String timeLabel;
  final bool isCurrent;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>('prayer-schedule-entry-$label'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? scheme.primaryContainer : null,
        border: isNext && !isCurrent
            ? Border.all(color: scheme.primary, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: isCurrent ? FontWeight.bold : null,
              color: isCurrent ? scheme.onPrimaryContainer : null,
            ),
          ),
          Text(
            timeLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: (isCurrent || isNext) ? FontWeight.bold : null,
              color: isCurrent ? scheme.onPrimaryContainer : null,
            ),
          ),
        ],
      ),
    );
  }
}

final class _RotationContent extends StatelessWidget {
  const _RotationContent({
    required this.snapshot,
    required this.busyIds,
    required this.markingEnabled,
    required this.batch,
    required this.completedSurahIds,
    required this.stabilize,
    required this.onMarkRequested,
    required this.onAdvancedMarkRequested,
  });

  final RotationSnapshot snapshot;
  final Set<String> busyIds;
  final bool markingEnabled;
  final RecommendationBatch? batch;
  final Set<String> completedSurahIds;

  /// Applies the caller's remembered row order to a freshly computed list.
  final List<MasteredSurah> Function(List<MasteredSurah>) stabilize;
  final ValueChanged<MasteredSurah> onMarkRequested;
  final ValueChanged<MasteredSurah> onAdvancedMarkRequested;

  @override
  Widget build(BuildContext context) {
    // Outside a resolved prayer there is no batch to keep stable — and no
    // direct marking either — so the plain computed order still applies.
    final hasBatch = batch != null && !batch!.isEmpty;
    final fallback = hasBatch
        ? const <SurahSuggestion>[]
        : const ContextualSurahSuggestionService().suggestWith(
            snapshot,
            ContextualRecommendationInputs.empty,
          );
    final List<MasteredSurah> unstableActive;
    final Map<String, int> positions;
    final Map<String, int> occurrences;
    if (hasBatch) {
      // The batch drives the order and the ranks. It is a stored decision, so
      // a marked surah keeps its position and renders as completed instead of
      // dropping out and shrinking the block.
      final ordered = const SurahOperationalOrderService().order(snapshot);
      final batchIds = batch!.surahIds.toList();
      positions = <String, int>{
        for (var index = 0; index < batchIds.length; index += 1)
          batchIds[index]: index,
      };
      occurrences = <String, int>{
        for (final entry in batch!.entries) entry.surahId: entry.occurrence,
      };
      unstableActive = <MasteredSurah>[
        for (final surahId in batchIds)
          ...ordered.where((surah) => surah.id == surahId),
        ...ordered.where((surah) => !positions.containsKey(surah.id)),
      ];
    } else {
      positions = <String, int>{
        for (final suggestion in fallback)
          suggestion.surah.id: suggestion.recommendationRank,
      };
      occurrences = const <String, int>{};
      unstableActive = const SurahOperationalOrderService().order(
        snapshot,
        recommendations: fallback,
      );
    }
    // The operational order changes the moment a surah is marked, because
    // marking is what changes how overdue it is. Re-sorting mid-tap moved the
    // next row out from under the user's finger; [stabilize] keeps rows where
    // he last saw them until the context itself changes.
    final active = stabilize(unstableActive);
    if (active.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const Icon(Icons.playlist_add_check_circle_outlined, size: 48),
              const SizedBox(height: 12),
              Text(context.l10n.noActiveSurahs, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    final dueSurahCount = active
        .where((surah) => snapshot.remainingFor(surah.id) > 0)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.l10n.activeSurahsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              context.l10n.dueSurahsCount(dueSurahCount),
              key: const ValueKey<String>('due-surah-count'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (
                var index = 0;
                index < active.length;
                index += 1
              ) ...<Widget>[
                _SurahRotationTile(
                  surah: active[index],
                  remaining: snapshot.remainingFor(active[index].id),
                  isBusy: busyIds.contains(active[index].id),
                  isEnabled: markingEnabled,
                  recommendationRank: positions[active[index].id],
                  occurrence: occurrences[active[index].id] ?? 1,
                  isRecitedInCurrentPart: completedSurahIds.contains(
                    active[index].id,
                  ),
                  onMarkRequested: () => onMarkRequested(active[index]),
                  onAdvancedMarkRequested: active[index].rotationScheme.isSplit
                      ? null
                      : () => onAdvancedMarkRequested(active[index]),
                ),
                if (index != active.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

final class _SurahRotationTile extends StatelessWidget {
  const _SurahRotationTile({
    required this.surah,
    required this.remaining,
    required this.isBusy,
    required this.isEnabled,
    required this.recommendationRank,
    required this.isRecitedInCurrentPart,
    required this.onMarkRequested,
    required this.onAdvancedMarkRequested,
    this.occurrence = 1,
  });

  final MasteredSurah surah;
  final int remaining;
  final bool isBusy;
  final bool isEnabled;
  final int? recommendationRank;
  final bool isRecitedInCurrentPart;

  /// Second appearance in the current recommendation cycle, shown honestly as
  /// `2×`. It never doubles a recitation event or affects statistics.
  final int occurrence;
  final VoidCallback onMarkRequested;
  final VoidCallback? onAdvancedMarkRequested;

  @override
  Widget build(BuildContext context) {
    final status = remaining < 0
        ? context.l10n.aheadBy(-remaining)
        : remaining == 0
        ? context.l10n.doneForCycle
        : remaining == 1
        ? context.l10n.recitationsRemaining(1)
        : context.l10n.recitationsRemaining(remaining);
    return ListTile(
      key: ValueKey<String>('active-surah-${surah.id}'),
      leading: Semantics(
        button: true,
        enabled: isEnabled && !isBusy,
        label: '${surah.surah.displayName}, $status',
        onTap: !isEnabled || isBusy ? null : onMarkRequested,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: 48,
            child: IconButton(
              key: ValueKey<String>('mark-surah-${surah.id}'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: !isEnabled || isBusy ? null : onMarkRequested,
              icon: isBusy
                  ? SizedBox.square(
                      key: ValueKey<String>('mark-surah-busy-${surah.id}'),
                      dimension: 24,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _RemainingIndicator(remaining: remaining),
            ),
          ),
        ),
      ),
      title: Row(
        children: <Widget>[
          if (recommendationRank != null) ...<Widget>[
            RecommendationRankBadge(
              rank: recommendationRank! + 1,
              isCompleted: isRecitedInCurrentPart,
            ),
            if (occurrence > 1) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                '$occurrence×',
                key: ValueKey<String>('recommendation-repeat-${surah.id}'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              surah.surah.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isRecitedInCurrentPart) ...<Widget>[
            const SizedBox(width: 6),
            Tooltip(
              message: context.l10n.recitedInCurrentPart,
              child: Icon(
                Icons.check_circle,
                key: ValueKey<String>('recited-in-current-part-${surah.id}'),
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
      trailing: onAdvancedMarkRequested == null
          ? null
          : IconButton(
              key: ValueKey<String>('advanced-mark-surah-${surah.id}'),
              tooltip: context.l10n.selectCoverage,
              onPressed: !isEnabled || isBusy ? null : onAdvancedMarkRequested,
              icon: const Icon(Icons.tune),
            ),
      subtitle: Text(
        '${context.l10n.surahNumber(surah.surah.surahNumber)} · '
        '${context.l10n.ayahCount(surah.surah.ayahCount)}',
      ),
    );
  }
}

final class _RemainingIndicator extends StatelessWidget {
  const _RemainingIndicator({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (remaining <= 0) {
      final ahead = -remaining;
      return SizedBox.square(
        dimension: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: const Icon(Icons.check),
              ),
            ),
            if (ahead > 0)
              PositionedDirectional(
                end: -7,
                bottom: -3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      ahead == 1 ? '-x' : '-${ahead}x',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline, width: 2),
        ),
        child: Center(
          child: remaining == 1
              ? const SizedBox.shrink()
              : Text(
                  '$remaining×',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
        ),
      ),
    );
  }
}

final class _CurrentLearningCard extends ConsumerWidget {
  const _CurrentLearningCard({
    required this.learning,
    required this.catalog,
    required this.selectedSurahId,
    required this.onOpen,
  });

  final List<LearningSurahState> learning;
  final List<CatalogSurah> catalog;
  final String? selectedSurahId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayPreferences =
        ref.watch(quranDisplayPreferencesProvider).valueOrNull ??
        QuranDisplayPreferences.defaults;
    if (learning.isEmpty) return const SizedBox.shrink();
    final selected = learning.where((item) => item.surahId == selectedSurahId);
    final state = selected.isEmpty ? learning.first : selected.first;
    final matches = catalog
        .where((item) => item.surah.id == state.surahId)
        .toList(growable: false);
    final descriptor = matches.isEmpty ? null : matches.first.surah;
    final name = descriptor?.displayName ?? context.l10n.selectSurah;
    final stage = state.stage.label(context.l10n);
    final reading = descriptor == null
        ? null
        : ref
              .watch(
                quranReadingSurahProvider((
                  surahNumber: descriptor.surahNumber,
                  ayahCount: descriptor.ayahCount,
                  warmTranslation: true,
                )),
              )
              .valueOrNull;
    final currentAyah = reading?.ayah(state.stage.endAyah);
    final hasVisibleLayer =
        currentAyah != null &&
        (displayPreferences.showArabic ||
            (displayPreferences.showTransliteration &&
                currentAyah.transliteration != null) ||
            (displayPreferences.showTranslation &&
                currentAyah.translation != null));
    return Card(
      key: const ValueKey<String>('learning-card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const CircleAvatar(child: Icon(Icons.school_outlined)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(stage),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (hasVisibleLayer) ...<Widget>[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: QuranAyahLayers(
                      ayah: currentAyah,
                      preferences: displayPreferences,
                      compact: true,
                      keyPrefix: 'home-learning',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _RollbackNotice extends StatelessWidget {
  const _RollbackNotice({required this.outcome, required this.onUndo});

  final LearningActionOutcome outcome;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.history_toggle_off),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.learningRolledBack)),
            TextButton(onPressed: onUndo, child: Text(context.l10n.undo)),
          ],
        ),
      ),
    );
  }
}

final class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Text(context.l10n.errorGeneric),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}
