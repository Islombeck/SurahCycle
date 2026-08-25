import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';
import '../../quran/quran.dart';

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
    final initialSurahId = widget.initialSurahId;
    if (initialSurahId != null && initialSurahId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(selectedLearningSurahProvider.notifier)
              .select(initialSurahId);
        }
      });
    }
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
    final learningIds = learning.map((item) => item.surahId).toSet();
    final candidates = catalog
        .where(
          (item) => !item.isMastered && !learningIds.contains(item.surah.id),
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
      await ref.read(appActionsProvider).startLearning(selected);
      await ref
          .read(selectedLearningSurahProvider.notifier)
          .select(selected.id);
    }
  }

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
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.learningCompletedTitle),
          content: Text(
            descriptor.isRotationEligible
                ? context.l10n.learningCompletedBody
                : context.l10n.fatihaRotationExcluded,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                descriptor.isRotationEligible
                    ? context.l10n.completeAndAdd
                    : context.l10n.completeLearningOnly,
              ),
            ),
          ],
        ),
      );
      if (accepted ?? false) {
        await ref
            .read(appActionsProvider)
            .completeLearning(state: outcome.state, surah: descriptor);
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
  });

  final LearningSurahState state;
  final SurahDescriptor? descriptor;
  final bool busy;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onRepeated;
  final VoidCallback onLearned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = state.stage.kind == LearningStageKind.newAyah
        ? context.l10n.newAyah(state.stage.ayahNumber)
        : context.l10n.cumulativeRange(state.stage.endAyah);
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
                          hasSelectedTranslation:
                              content.translationSelection != null,
                          translationIssue: content.translationIssue,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
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
    required this.hasSelectedTranslation,
    required this.translationIssue,
  });

  final QuranReadingAyah ayah;
  final bool hasSelectedTranslation;
  final QuranContentIssue? translationIssue;

  @override
  Widget build(BuildContext context) {
    final translation = ayah.translation;
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
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ayah.arabicText,
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(height: 1.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              translation ?? fallback,
              style: Theme.of(context).textTheme.bodyMedium,
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
