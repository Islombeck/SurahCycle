import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../quran/quran.dart';
import '../application/recall_controller.dart';
import '../../../core/domain/domain.dart';

/// The memory-check screen.
///
/// The exact text of the current ayah is not built into the widget tree until
/// the user asks for it, and the hidden state shows a fixed placeholder: a
/// blurred or greyed-out copy of the real words would still leak their length
/// and shape, which is most of the answer for a short ayah.
final class RecallScreen extends ConsumerWidget {
  const RecallScreen({
    required this.request,
    required this.surahTitle,
    this.audioControls,
    super.key,
  });

  final RecallRequest request;
  final String surahTitle;

  /// Shown only after the text is revealed, and only when the caller could
  /// supply controls whose range matches this check exactly.
  final Widget? audioControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recallControllerProvider(request));
    final controller = ref.read(recallControllerProvider(request).notifier);
    final session = state.session;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.recallModeTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '$surahTitle · '
                '${context.l10n.recallProgress(session.completedAyahCount, session.totalAyahCount)}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            if (session.isComplete)
              _RecallSummary(
                tally: state.tally,
                onClose: () => Navigator.of(context).pop(),
              )
            else ...[
              _RecallStep(
                key: ValueKey<String>('recall-step-${session.currentAyah}'),
                request: request,
                session: session,
                audioControls: audioControls,
              ),
              const SizedBox(height: 16),
              if (state.saveFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.l10n.recallSaveFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              _RecallActions(
                state: state,
                onReveal: controller.reveal,
                onSkip: controller.skip,
                onGrade: controller.grade,
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.recallSelfAssessment,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.recallPriorityNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _RecallStep extends ConsumerWidget {
  const _RecallStep({
    required this.request,
    required this.session,
    required this.audioControls,
    super.key,
  });

  final RecallRequest request;
  final RecallSession session;
  final Widget? audioControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = Text(
      context.l10n.recallHiddenTitle(session.currentAyah),
      style: Theme.of(context).textTheme.titleMedium,
    );

    if (!session.isRevealed) {
      return Card(
        key: const ValueKey<String>('recall-hidden'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              const SizedBox(height: 24),
              // A fixed box, sized from the theme and not from the ayah.
              Center(
                child: Icon(
                  Icons.visibility_off_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.recallHiddenHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final displayPreferences =
        ref.watch(quranDisplayPreferencesProvider).valueOrNull ??
        QuranDisplayPreferences.defaults;
    final reading = ref.watch(
      quranReadingSurahProvider((
        surahNumber: request.surahNumber,
        ayahCount: request.surahAyahCount,
        warmTranslation: true,
      )),
    );

    return Card(
      key: const ValueKey<String>('recall-revealed'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            const SizedBox(height: 16),
            reading.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) =>
                  Text(context.l10n.errorGeneric, textAlign: TextAlign.center),
              data: (content) => QuranAyahLayers(
                ayah: content.ayah(session.currentAyah),
                preferences: displayPreferences,
                transliterationFallback:
                    context.l10n.transliterationUnavailable,
                translationFallback: content.translationSelection == null
                    ? context.l10n.chooseTranslation
                    : context.l10n.translationUnavailableOffline,
                keyPrefix: 'recall',
              ),
            ),
            if (audioControls != null) ...<Widget>[
              const SizedBox(height: 16),
              audioControls!,
            ],
          ],
        ),
      ),
    );
  }
}

final class _RecallActions extends StatelessWidget {
  const _RecallActions({
    required this.state,
    required this.onReveal,
    required this.onSkip,
    required this.onGrade,
  });

  final RecallRunState state;
  final VoidCallback onReveal;
  final VoidCallback onSkip;
  final Future<void> Function(RecallResult result) onGrade;

  @override
  Widget build(BuildContext context) {
    final busy = state.isSaving;
    if (!state.session.isRevealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton(
            key: const ValueKey<String>('recall-reveal'),
            onPressed: busy ? null : onReveal,
            child: Text(context.l10n.recallReveal),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey<String>('recall-skip'),
            onPressed: busy ? null : onSkip,
            child: Text(context.l10n.recallSkip),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton(
          key: const ValueKey<String>('recall-grade-recalled'),
          onPressed: busy ? null : () => onGrade(RecallResult.recalled),
          child: Text(context.l10n.recallResultRecalled),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey<String>('recall-grade-mistake'),
          onPressed: busy
              ? null
              : () => onGrade(RecallResult.recalledWithMistake),
          child: Text(context.l10n.recallResultWithMistake),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey<String>('recall-grade-not-recalled'),
          onPressed: busy ? null : () => onGrade(RecallResult.notRecalled),
          child: Text(context.l10n.recallResultNotRecalled),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey<String>('recall-skip'),
          onPressed: busy ? null : onSkip,
          child: Text(context.l10n.recallSkip),
        ),
      ],
    );
  }
}

final class _RecallSummary extends StatelessWidget {
  const _RecallSummary({required this.tally, required this.onClose});

  final RecallTally tally;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('recall-summary'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.recallFinishedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.recallFinishedBody(
                tally.recalled,
                tally.recalledWithMistake,
                tally.notRecalled,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.recallPriorityNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey<String>('recall-close'),
              onPressed: onClose,
              child: Text(context.l10n.recallClose),
            ),
          ],
        ),
      ),
    );
  }
}
