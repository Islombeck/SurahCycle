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
      ref.watch(prayerContextResolutionProvider),
    );
    final scheduleResolution = _settledAsyncValue(
      ref.watch(prayerScheduleContextResolutionProvider),
    );
    final prayerSettings = _settledAsyncValue(
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
    var routineMarkingEnabled = true;
    if (currentRoutine != null) {
      final routine = currentRoutine.valueOrNull;
      routineMarkingEnabled =
          routine == null || routine.currentPart?.nextSlotIndex != null;
    }
    final selectedLearningSurahId = ref.watch(selectedLearningSurahProvider);
    final rollbackQueue = ref.watch(learningRollbackQueueProvider);

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
                      onTap: () => _showPrayerPicker(
                        manualPrayer ?? prayerResolution?.context,
                      ),
                      onJumuahOverride: canOfferJumuahOverride
                          ? () =>
                                ref
                                    .read(
                                      prayerContextOverrideProvider.notifier,
                                    )
                                    .state = PrayerContext(
                                  prayerType: PrayerType.jumuah,
                                )
                          : null,
                    ),
                    if (currentRoutine != null) ...<Widget>[
                      currentRoutine.when(
                        data: (routine) => routine == null
                            ? const SizedBox.shrink()
                            : _PrayerRoutineCard(
                                snapshot: routine,
                                prayerContext: resolvedPrayerContext!,
                                busyPartIds: _busyRoutinePartIds,
                                onFollowedImam: _completeByFollowingImam,
                              ),
                        loading: () => const SizedBox.shrink(),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                      ),
                      if (currentRoutine.valueOrNull != null)
                        const SizedBox(height: 16),
                    ],
                    if (currentRoutine?.valueOrNull == null)
                      const SizedBox(height: 16),
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

  /// The one UI entry point for marking a surah.
  Future<void> _handleMarkRequest(
    MasteredSurah surah, {
    bool advanced = false,
  }) async {
    var actionPrayer = await _resolvePrayerForAction();
    if (!mounted) return;
    if (actionPrayer == null) {
      final selected = await _showPrayerPicker(
        ref.read(selectedPrayerProvider),
      );
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
          final selected = await _showPrayerPicker(
            ref.read(selectedPrayerProvider),
          );
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

    final override = ref.read(prayerContextOverrideProvider);
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
      if (ref.read(prayerContextOverrideProvider) != null) {
        ref.read(prayerContextOverrideProvider.notifier).state = null;
      }
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
      if (ref.read(prayerContextOverrideProvider) != null) {
        ref.read(prayerContextOverrideProvider.notifier).state = null;
      }
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
        ref.read(prayerContextOverrideProvider.notifier).state = selected;
      }
    }
    return selected;
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

PrayerTodaySchedule? _matchingPrayerSchedule(
  AsyncValue<PrayerTodaySchedule> state,
  PrayerTimeSettings? settings,
) {
  final value = state.valueOrNull;
  if (settings == null ||
      !settings.locationConfirmed ||
      state.isLoading ||
      state.hasError ||
      value == null ||
      !value.matchesSettings(settings)) {
    return null;
  }
  return value;
}

T? _settledAsyncValue<T>(AsyncValue<T> state) =>
    state.isLoading || state.hasError ? null : state.valueOrNull;

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
  });

  final PrayerContextResolution? resolution;
  final PrayerContextResolution? scheduleResolution;
  final PrayerTimeSettings? settings;
  final PrayerTodaySchedule? schedule;
  final VoidCallback onTap;
  final VoidCallback? onJumuahOverride;

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

final class _RotationContent extends StatelessWidget {
  const _RotationContent({
    required this.snapshot,
    required this.busyIds,
    required this.markingEnabled,
    required this.onMarkRequested,
    required this.onAdvancedMarkRequested,
  });

  final RotationSnapshot snapshot;
  final Set<String> busyIds;
  final bool markingEnabled;
  final ValueChanged<MasteredSurah> onMarkRequested;
  final ValueChanged<MasteredSurah> onAdvancedMarkRequested;

  @override
  Widget build(BuildContext context) {
    final suggestions = const SurahSuggestionService().suggest(snapshot);
    final active = const SurahOperationalOrderService().order(
      snapshot,
      recommendations: suggestions,
    );
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
        if (suggestions.isNotEmpty) ...<Widget>[
          Text(
            context.l10n.recommendedTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final suggestion in suggestions)
                    RecommendationChip(
                      rank: suggestion.recommendationRank + 1,
                      label:
                          suggestion.recommendedPart == null ||
                              !suggestion.surah.rotationScheme.isSplit
                          ? suggestion.surah.surah.displayName
                          : '${suggestion.surah.surah.displayName} · '
                                '${context.l10n.ayahRange(suggestion.recommendedPart!.ayahRange.startAyah, suggestion.recommendedPart!.ayahRange.endAyah)}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
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
    required this.onMarkRequested,
    required this.onAdvancedMarkRequested,
  });

  final MasteredSurah surah;
  final int remaining;
  final bool isBusy;
  final bool isEnabled;
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
      title: Text(surah.surah.displayName),
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
