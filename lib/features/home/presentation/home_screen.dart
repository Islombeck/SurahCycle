import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';

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
    final prayer = ref.watch(selectedPrayerProvider);
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
              ..invalidate(catalogProvider);
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
                      contextValue: prayer,
                      onTap: () => _showPrayerPicker(prayer),
                    ),
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
                        onMarkRequested: (surah) =>
                            _handleMarkRequest(surah, prayer),
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
    MasteredSurah surah,
    PrayerContext prayer,
  ) async {
    if (!surah.rotationScheme.isSplit) {
      return _registerRecitation(surah, prayer);
    }
    if (_busySurahIds.contains(surah.id) ||
        !_openCoverageSheetSurahIds.add(surah.id)) {
      return;
    }
    try {
      final selection = await showModalBottomSheet<_RecitationSelection>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _RecitationCoverageSheet(surah: surah),
      );
      if (selection == null || !mounted) return;
      await _registerRecitation(
        surah,
        prayer,
        coveredPartIds: selection.coveredPartIds,
        rakaatSpanCount: selection.rakaatSpanCount,
      );
    } finally {
      _openCoverageSheetSurahIds.remove(surah.id);
    }
  }

  Future<void> _registerRecitation(
    MasteredSurah surah,
    PrayerContext prayer, {
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
  }) async {
    if (_busySurahIds.contains(surah.id)) return;
    setState(() => _busySurahIds.add(surah.id));
    try {
      final registration = await ref
          .read(appActionsProvider)
          .registerRecitation(
            surahId: surah.id,
            prayerContext: prayer,
            coveredPartIds: coveredPartIds,
            rakaatSpanCount: rakaatSpanCount,
          );
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

  Future<void> _showPrayerPicker(PrayerContext current) async {
    var prayerType = current.prayerType;
    var isQada = current.isQada;
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
                if (prayerType.supportsQada) ...<Widget>[
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
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(PrayerContext(prayerType: prayerType, isQada: isQada)),
                  child: Text(context.l10n.confirm),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      await ref.read(selectedPrayerProvider.notifier).select(selected);
    }
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

final class _RecitationSelection {
  const _RecitationSelection({
    required this.coveredPartIds,
    required this.rakaatSpanCount,
  });

  final List<String> coveredPartIds;
  final int rakaatSpanCount;
}

final class _RecitationCoverageSheet extends StatefulWidget {
  const _RecitationCoverageSheet({required this.surah});

  final MasteredSurah surah;

  @override
  State<_RecitationCoverageSheet> createState() =>
      _RecitationCoverageSheetState();
}

final class _RecitationCoverageSheetState
    extends State<_RecitationCoverageSheet> {
  late Set<String> _selectedPartIds;
  int _rakaatSpanCount = 1;

  @override
  void initState() {
    super.initState();
    _selectedPartIds = widget.surah.rotationScheme.parts
        .map((part) => part.id)
        .toSet();
  }

  bool get _isWhole =>
      _selectedPartIds.length == widget.surah.rotationScheme.parts.length;

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
              Text(
                widget.surah.surah.displayName,
                style: Theme.of(context).textTheme.titleLarge,
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

final class _PrayerContextCard extends StatelessWidget {
  const _PrayerContextCard({required this.contextValue, required this.onTap});

  final PrayerContext contextValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                      contextValue.label(context.l10n),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}

final class _RotationContent extends StatelessWidget {
  const _RotationContent({
    required this.snapshot,
    required this.busyIds,
    required this.onMarkRequested,
  });

  final RotationSnapshot snapshot;
  final Set<String> busyIds;
  final ValueChanged<MasteredSurah> onMarkRequested;

  @override
  Widget build(BuildContext context) {
    final active = snapshot.activeSurahs.toList(growable: false)
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
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
    final suggestions = const SurahSuggestionService()
        .suggest(snapshot, limit: active.length)
        .where((suggestion) => suggestion.remaining > 0)
        .take(3)
        .toList(growable: false);
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
                    Chip(
                      avatar: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        suggestion.recommendedPart == null ||
                                !suggestion.surah.rotationScheme.isSplit
                            ? suggestion.surah.surah.displayName
                            : '${suggestion.surah.surah.displayName} · '
                                  '${context.l10n.ayahRange(suggestion.recommendedPart!.ayahRange.startAyah, suggestion.recommendedPart!.ayahRange.endAyah)}',
                      ),
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
                  onMarkRequested: () => onMarkRequested(active[index]),
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
    required this.onMarkRequested,
  });

  final MasteredSurah surah;
  final int remaining;
  final bool isBusy;
  final VoidCallback onMarkRequested;

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
        enabled: !isBusy,
        label: '${surah.surah.displayName}, $status',
        onTap: isBusy ? null : onMarkRequested,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: 48,
            child: IconButton(
              key: ValueKey<String>('mark-surah-${surah.id}'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: isBusy ? null : onMarkRequested,
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

final class _CurrentLearningCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (learning.isEmpty) return const SizedBox.shrink();
    final selected = learning.where((item) => item.surahId == selectedSurahId);
    final state = selected.isEmpty ? learning.first : selected.first;
    final matches = catalog
        .where((item) => item.surah.id == state.surahId)
        .toList(growable: false);
    final descriptor = matches.isEmpty ? null : matches.first.surah;
    final name = descriptor?.displayName ?? context.l10n.selectSurah;
    final stage = state.stage.kind == LearningStageKind.newAyah
        ? context.l10n.newAyah(state.stage.ayahNumber)
        : context.l10n.cumulativeRange(state.stage.endAyah);
    return Card(
      key: const ValueKey<String>('learning-card'),
      child: ListTile(
        onTap: onOpen,
        leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
        title: Text(name),
        subtitle: Text(stage),
        trailing: const Icon(Icons.chevron_right),
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
