import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';
import '../../quran/audio/presentation/learning_audio_controls.dart';
import '../../quran/quran.dart';
import '../application/recall_controller.dart';
import 'recall_range_sheet.dart';
import 'recall_screen.dart';

final class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key, this.initialSurahId});

  final String? initialSurahId;

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

final class _LearningScreenState extends ConsumerState<LearningScreen> {
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectRequestedSurah(widget.initialSurahId);
  }

  /// A warm deep link reuses this same screen inside the shell, so the request
  /// arrives as a changed widget rather than a fresh [initState].
  @override
  void didUpdateWidget(LearningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSurahId != oldWidget.initialSurahId) {
      _selectRequestedSurah(widget.initialSurahId);
    }
  }

  void _selectRequestedSurah(String? surahId) {
    if (surahId == null || surahId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedLearningSurahProvider.notifier).select(surahId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final learning = ref.watch(allLearningProvider);
    final catalog = ref.watch(fullCatalogProvider);
    final selectedSurahId = ref.watch(selectedLearningSurahProvider);
    final descriptors = <String, SurahDescriptor>{
      for (final item in catalog.valueOrNull ?? const <CatalogSurah>[])
        item.surah.id: item.surah,
    };
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar.large(
              title: Text(context.l10n.learningTab),
              actions: <Widget>[
                IconButton(
                  tooltip: context.l10n.startLearning,
                  onPressed: catalog.hasValue
                      ? () => _showSurahPicker(
                          catalog.value ?? const <CatalogSurah>[],
                          learning.valueOrNull ?? const <LearningSurahState>[],
                        )
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.list(
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(context.l10n.arabicTextOfflineReady),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  learning.when(
                    data: (items) {
                      final active = items
                          .where((item) => !item.isCompleted)
                          .toList(growable: false);
                      if (active.isEmpty) {
                        return _EmptyLearning(
                          onStart: () => _showSurahPicker(
                            catalog.valueOrNull ?? const <CatalogSurah>[],
                            items,
                          ),
                        );
                      }
                      return Column(
                        children: <Widget>[
                          for (final state in active)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _LearningCard(
                                state: state,
                                descriptor: descriptors[state.surahId],
                                busy: _busyIds.contains(state.id),
                                isSelected: state.surahId == selectedSurahId,
                                onSelect: () => ref
                                    .read(
                                      selectedLearningSurahProvider.notifier,
                                    )
                                    .select(state.surahId),
                                onRepeated: () => _markRepeated(state),
                                onLearned: () => _markLearned(
                                  state,
                                  descriptors[state.surahId],
                                ),
                                onChangePlan: () => _changePlan(
                                  state,
                                  descriptors[state.surahId],
                                ),
                                onRecall: () => _startRecall(
                                  state,
                                  descriptors[state.surahId],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, stackTrace) => Center(
                      child: FilledButton.icon(
                        onPressed: () => ref.invalidate(allLearningProvider),
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.retry),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSurahPicker(
    List<CatalogSurah> catalog,
    List<LearningSurahState> learning,
  ) async {
    final learningBySurahId = <String, LearningSurahState>{
      for (final item in learning) item.surahId: item,
    };
    final candidates = catalog
        .where(
          (item) =>
              !item.isMastered &&
              (learningBySurahId[item.surah.id]?.isCompleted ?? true),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.noLearningSurahs)));
      }
      return;
    }
    final selected = await showModalBottomSheet<SurahDescriptor>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.l10n.selectSurah,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final surah = candidates[index].surah;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${surah.surahNumber}'),
                      ),
                      title: Text(surah.displayName),
                      subtitle: Text(context.l10n.ayahCount(surah.ayahCount)),
                      onTap: () => Navigator.of(context).pop(surah),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      if (!mounted) return;
      final plan = await _showLearningPlanEditor(
        selected,
        initialPlan: learningBySurahId[selected.id]?.plan,
      );
      if (plan == null) return;
      await ref.read(appActionsProvider).startLearning(selected, plan: plan);
      await ref
          .read(selectedLearningSurahProvider.notifier)
          .select(selected.id);
    }
  }

  /// Opens a memory check for one surah.
  ///
  /// The default range is the stage the user is already on, because that is
  /// what they were just asked to memorise. Narrowing it is allowed, and the
  /// learning stage itself is never touched by the check.
  Future<void> _startRecall(
    LearningSurahState state,
    SurahDescriptor? descriptor,
  ) async {
    if (descriptor == null) return;
    final range = await showRecallRangeSheet(
      context: context,
      ayahCount: descriptor.ayahCount,
      initialStart: state.stage.startAyah,
      initialEnd: state.stage.endAyah,
    );
    if (range == null || !mounted) return;

    // Audio plays the learning stage, so it is offered only when the checked
    // range is exactly that stage. A narrower check gets no audio rather than
    // audio for the wrong ayahs.
    final matchesStage =
        range.start == state.stage.startAyah &&
        range.end == state.stage.endAyah;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => RecallScreen(
          request: RecallRequest(
            surahId: state.surahId,
            surahNumber: descriptor.surahNumber,
            surahAyahCount: descriptor.ayahCount,
            ayahStart: range.start,
            ayahEnd: range.end,
            learningCycle: state.learningCycle,
            source: RecallSource.learning,
          ),
          surahTitle: descriptor.displayName,
          audioControls: matchesStage
              ? LearningAudioControls(
                  key: ValueKey<String>('recall-audio-${state.id}'),
                  learningState: state,
                  surahNumber: descriptor.surahNumber,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _changePlan(
    LearningSurahState state,
    SurahDescriptor? descriptor,
  ) async {
    if (descriptor == null) return;
    final plan = await _showLearningPlanEditor(
      descriptor,
      initialPlan: state.plan,
    );
    if (plan == null || plan == state.plan || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmPlanChangeTitle),
        content: Text(context.l10n.confirmPlanChangeBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await _guard(state.id, () async {
      await ref
          .read(appActionsProvider)
          .changeLearningPlan(state: state, plan: plan);
    });
  }

  Future<LearningPlan?> _showLearningPlanEditor(
    SurahDescriptor surah, {
    LearningPlan? initialPlan,
  }) => showModalBottomSheet<LearningPlan>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _LearningPlanSheet(surah: surah, initialPlan: initialPlan),
  );

  Future<void> _markRepeated(LearningSurahState state) async {
    await _guard(state.id, () async {
      await ref.read(appActionsProvider).markRepeated(state);
    });
  }

  Future<void> _markLearned(
    LearningSurahState state,
    SurahDescriptor? descriptor,
  ) async {
    await _guard(state.id, () async {
      final outcome = await ref.read(appActionsProvider).markLearned(state);
      if (!outcome.completionRequired || descriptor == null || !mounted) return;
      final choice = await showDialog<_LearningCompletionChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            outcome.state.isFullSurahTarget
                ? context.l10n.learningCompletedTitle
                : context.l10n.rangeCompletedTitle,
          ),
          content: Text(
            !outcome.state.isFullSurahTarget
                ? context.l10n.rangeCompletedBody
                : descriptor.isRotationEligible
                ? context.l10n.addToRotationQuestion
                : context.l10n.fatihaRotationExcluded,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            if (outcome.state.isFullSurahTarget &&
                descriptor.isRotationEligible)
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_LearningCompletionChoice.completeOnly),
                child: Text(context.l10n.completeWithoutRotation),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                outcome.state.isFullSurahTarget && descriptor.isRotationEligible
                    ? _LearningCompletionChoice.addToRotation
                    : _LearningCompletionChoice.completeOnly,
              ),
              child: Text(
                outcome.state.isFullSurahTarget && descriptor.isRotationEligible
                    ? context.l10n.completeAndAdd
                    : context.l10n.completeLearningOnly,
              ),
            ),
          ],
        ),
      );
      if (choice != null) {
        await ref
            .read(appActionsProvider)
            .completeLearning(
              state: outcome.state,
              surah: descriptor,
              addToRotation: choice == _LearningCompletionChoice.addToRotation,
            );
        await ref.read(selectedLearningSurahProvider.notifier).select(null);
      }
    });
  }

  Future<void> _guard(String id, Future<void> Function() action) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }
}

final class _LearningCard extends ConsumerWidget {
  const _LearningCard({
    required this.state,
    required this.descriptor,
    required this.busy,
    required this.isSelected,
    required this.onSelect,
    required this.onRepeated,
    required this.onLearned,
    required this.onChangePlan,
    required this.onRecall,
  });

  final LearningSurahState state;
  final SurahDescriptor? descriptor;
  final bool busy;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onRepeated;
  final VoidCallback onLearned;
  final VoidCallback onChangePlan;
  final VoidCallback onRecall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayPreferences =
        ref.watch(quranDisplayPreferencesProvider).valueOrNull ??
        QuranDisplayPreferences.defaults;
    final stage = state.stage.label(context.l10n);
    final reading = descriptor == null
        ? null
        : ref.watch(
            quranReadingSurahProvider((
              surahNumber: descriptor!.surahNumber,
              ayahCount: descriptor!.ayahCount,
              warmTranslation: isSelected,
            )),
          );
    return Card(
      key: ValueKey<String>('learning-surah-${state.surahId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(child: Text('${descriptor?.surahNumber ?? '—'}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        descriptor?.displayName ?? context.l10n.selectSurah,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(stage),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: context.l10n.changeLearningPlan,
                        onPressed: onChangePlan,
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton(
                        tooltip: isSelected
                            ? context.l10n.currentLearning
                            : context.l10n.showOnHome,
                        onPressed: onSelect,
                        icon: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (reading == null)
              Text(context.l10n.errorGeneric)
            else
              reading.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => Text(
                  context.l10n.errorGeneric,
                  textAlign: TextAlign.center,
                ),
                data: (content) => Column(
                  children: <Widget>[
                    for (final ayah in content.range(
                      startAyah: state.stage.startAyah,
                      endAyah: state.stage.endAyah,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LearningAyahCard(
                          ayah: ayah,
                          displayPreferences: displayPreferences,
                          hasSelectedTranslation:
                              content.translationSelection != null,
                          translationIssue: content.translationIssue,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (isSelected && descriptor != null) ...[
              LearningAudioControls(
                key: ValueKey<String>('learning-audio-${state.id}'),
                learningState: state,
                surahNumber: descriptor!.surahNumber,
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              key: ValueKey<String>('recall-start-${state.surahId}'),
              onPressed: descriptor == null || busy ? null : onRecall,
              icon: const Icon(Icons.visibility_off_outlined),
              label: Text(context.l10n.recallStartAction),
            ),
            if (ref.watch(recallSummariesProvider).valueOrNull?[state.surahId]
                case final summary? when summary.total > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.recallSurahSummary(
                    summary.recalled,
                    summary.imperfect,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onRepeated,
                    child: Text(context.l10n.repeated),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: ValueKey<String>('learned-${state.surahId}'),
                    onPressed: busy ? null : onLearned,
                    child: Text(context.l10n.learned),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _LearningAyahCard extends StatelessWidget {
  const _LearningAyahCard({
    required this.ayah,
    required this.displayPreferences,
    required this.hasSelectedTranslation,
    required this.translationIssue,
  });

  final QuranReadingAyah ayah;
  final QuranDisplayPreferences displayPreferences;
  final bool hasSelectedTranslation;
  final QuranContentIssue? translationIssue;

  @override
  Widget build(BuildContext context) {
    final fallback = switch (translationIssue) {
      QuranContentIssue(
        reason: QuranContentUnavailableReason.versionMismatch,
      ) =>
        context.l10n.translationVersionChanged,
      QuranContentIssue(code: 'quran_translation_selection_invalid') =>
        context.l10n.translationSelectionInvalid,
      _ =>
        hasSelectedTranslation
            ? context.l10n.translationUnavailableOffline
            : context.l10n.chooseTranslation,
    };
    return DecoratedBox(
      key: ValueKey<String>(
        'learning-ayah-${ayah.surahNumber}-${ayah.ayahNumber}',
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${ayah.ayahNumber}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            QuranAyahLayers(
              ayah: ayah,
              preferences: displayPreferences,
              transliterationFallback: context.l10n.transliterationUnavailable,
              translationFallback: fallback,
              keyPrefix: 'learning',
            ),
          ],
        ),
      ),
    );
  }
}

final class _EmptyLearning extends StatelessWidget {
  const _EmptyLearning({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(Icons.school_outlined, size: 48),
            const SizedBox(height: 12),
            Text(context.l10n.noLearningSurahs),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.startLearning),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LearningCompletionChoice { completeOnly, addToRotation }

final class _LearningPlanSheet extends StatefulWidget {
  const _LearningPlanSheet({required this.surah, this.initialPlan});

  final SurahDescriptor surah;
  final LearningPlan? initialPlan;

  @override
  State<_LearningPlanSheet> createState() => _LearningPlanSheetState();
}

final class _LearningPlanSheetState extends State<_LearningPlanSheet> {
  static const _presets = <int>[3, 5, 7, 10];

  late LearningPlanKind _kind;
  late int _startAyah;
  late int _endAyah;
  late int _blockSize;
  late bool _customBlockSize;
  late final TextEditingController _customBlockController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPlan;
    _kind = initial?.kind ?? LearningPlanKind.classicCumulative;
    _startAyah = initial?.targetStartAyah ?? 1;
    _endAyah = initial?.targetEndAyah ?? widget.surah.ayahCount;
    _blockSize = initial?.blockSize ?? 5;
    _customBlockSize = !_presets.contains(_blockSize);
    _customBlockController = TextEditingController(text: '$_blockSize');
  }

  @override
  void dispose() {
    _customBlockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final customValue = int.tryParse(_customBlockController.text.trim());
    final canSubmit =
        _startAyah <= _endAyah &&
        (_kind == LearningPlanKind.classicCumulative ||
            (!_customBlockSize || (customValue != null && customValue > 0)));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.surah.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.learningHow,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<LearningPlanKind>(
                segments: <ButtonSegment<LearningPlanKind>>[
                  ButtonSegment<LearningPlanKind>(
                    value: LearningPlanKind.classicCumulative,
                    icon: const Icon(Icons.timeline),
                    label: Text(context.l10n.learningClassic),
                  ),
                  ButtonSegment<LearningPlanKind>(
                    value: LearningPlanKind.chunked,
                    icon: const Icon(Icons.view_week_outlined),
                    label: Text(context.l10n.learningChunked),
                  ),
                ],
                selected: <LearningPlanKind>{_kind},
                onSelectionChanged: (value) {
                  setState(() => _kind = value.single);
                },
              ),
              if (widget.surah.ayahCount >= 20) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  context.l10n.learningChunkedRecommended,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 20),
              Text(
                context.l10n.learningTargetRange,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _startAyah,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.learningTargetStart,
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (
                          var ayah = 1;
                          ayah <= widget.surah.ayahCount;
                          ayah += 1
                        )
                          DropdownMenuItem<int>(
                            value: ayah,
                            child: Text('$ayah'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _startAyah = value;
                          if (_endAyah < value) _endAyah = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey<String>('learning-end-$_startAyah'),
                      initialValue: _endAyah,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.learningTargetEnd,
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (
                          var ayah = _startAyah;
                          ayah <= widget.surah.ayahCount;
                          ayah += 1
                        )
                          DropdownMenuItem<int>(
                            value: ayah,
                            child: Text('$ayah'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _endAyah = value);
                      },
                    ),
                  ),
                ],
              ),
              if (_kind == LearningPlanKind.chunked) ...<Widget>[
                const SizedBox(height: 20),
                Text(
                  context.l10n.learningBlockSize,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final preset in _presets)
                      ChoiceChip(
                        label: Text(context.l10n.ayahCount(preset)),
                        selected: !_customBlockSize && _blockSize == preset,
                        onSelected: (_) {
                          setState(() {
                            _blockSize = preset;
                            _customBlockSize = false;
                          });
                        },
                      ),
                    ChoiceChip(
                      label: Text(context.l10n.learningCustomBlockSize),
                      selected: _customBlockSize,
                      onSelected: (_) {
                        setState(() => _customBlockSize = true);
                      },
                    ),
                  ],
                ),
                if (_customBlockSize) ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customBlockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.learningBlockSize,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canSubmit
                    ? () {
                        final plan = _kind == LearningPlanKind.classicCumulative
                            ? LearningPlan.classicCumulative(
                                targetStartAyah: _startAyah,
                                targetEndAyah: _endAyah,
                              )
                            : LearningPlan.chunked(
                                targetStartAyah: _startAyah,
                                targetEndAyah: _endAyah,
                                blockSize: _customBlockSize
                                    ? customValue!
                                    : _blockSize,
                              );
                        Navigator.of(context).pop(plan);
                      }
                    : null,
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
