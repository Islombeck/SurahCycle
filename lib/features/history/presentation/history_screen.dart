import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';

final class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

final class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _deletingIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(recitationHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.historyTitle)),
      body: SafeArea(
        top: false,
        child: history.when(
          data: (entries) => entries.isEmpty
              ? _EmptyHistory(onRefresh: _refresh)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _HistoryTile(
                        entry: entry,
                        isDeleting: _deletingIds.contains(entry.event.id),
                        onDelete: () => _delete(entry),
                      );
                    },
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(recitationHistoryProvider);
    await ref.read(recitationHistoryProvider.future);
  }

  Future<void> _delete(RecitationHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(context.l10n.deleteHistoryConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingIds.add(entry.event.id));
    try {
      await ref
          .read(recitationRepositoryProvider)
          .deleteRecitation(
            entry.event.id,
            deletedAtUtc: ref.read(timeProviderProvider).nowUtc(),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(entry.event.id));
    }
  }
}

final class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.isDeleting,
    required this.onDelete,
  });

  final RecitationHistoryEntry entry;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final parts = List.of(entry.coveredParts)
      ..sort((left, right) => left.partNumber.compareTo(right.partNumber));
    final presentation = _HistoryEntryPresentation.from(
      context: context,
      entry: entry,
      sortedParts: parts,
    );
    return Card(
      child: ListTile(
        key: ValueKey<String>('history-entry-${entry.event.id}'),
        leading: CircleAvatar(child: Text('${entry.surah.surahNumber}')),
        title: Text(entry.surah.displayName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                presentation.occurrence,
                key: ValueKey<String>('history-occurrence-${entry.event.id}'),
              ),
              Text(
                presentation.compactCoverage,
                key: ValueKey<String>('history-coverage-${entry.event.id}'),
              ),
              Text(
                presentation.added,
                key: ValueKey<String>('history-added-${entry.event.id}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        isThreeLine: true,
        onTap: () => _showDetails(context, presentation),
        trailing: isDeleting
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    key: ValueKey<String>(
                      'history-open-details-${entry.event.id}',
                    ),
                    tooltip: context.l10n.historyOpenDetails,
                    onPressed: () => _showDetails(context, presentation),
                    icon: const Icon(Icons.info_outline),
                  ),
                  IconButton(
                    tooltip: context.l10n.delete,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    _HistoryEntryPresentation presentation,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  context.l10n.historyDetailsTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.surah.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _HistoryDetailSection(
                icon: Icons.event_available_outlined,
                label: context.l10n.historyOccurrenceLabel,
                value: presentation.occurrence,
              ),
              _HistoryDetailSection(
                icon: Icons.menu_book_outlined,
                label: context.l10n.historyCoverageLabel,
                value: presentation.coverage,
              ),
              _HistoryDetailSection(
                key: ValueKey<String>(
                  'history-details-rakaats-${entry.event.id}',
                ),
                icon: Icons.format_list_numbered,
                label: context.l10n.rakaatSpan(entry.event.rakaatSpanCount),
                value: context.l10n.historyRakaatSpanExplanation,
              ),
              _HistoryDetailSection(
                icon: Icons.add_task_outlined,
                label: presentation.added,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _HistoryEntryPresentation {
  const _HistoryEntryPresentation({
    required this.occurrence,
    required this.coverage,
    required this.compactCoverage,
    required this.added,
  });

  factory _HistoryEntryPresentation.from({
    required BuildContext context,
    required RecitationHistoryEntry entry,
    required List<SurahRotationPart> sortedParts,
  }) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final addedLocalTime = entry.event.createdAtUtc.toLocal();
    final occurrenceDate = DateTime(
      entry.event.localDate.year,
      entry.event.localDate.month,
      entry.event.localDate.day,
    );
    final sameYear = occurrenceDate.year == addedLocalTime.year;
    final occurrenceDateText =
        (sameYear ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale)).format(
          occurrenceDate,
        );
    final addedDateText =
        (sameYear ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale)).format(
          addedLocalTime,
        );
    final addedDateTimeText =
        '$addedDateText ${DateFormat.Hm(locale).format(addedLocalTime)}';
    final coverage = entry.isWholeSurah
        ? context.l10n.wholeSurah
        : sortedParts
              .map(
                (part) =>
                    '${context.l10n.partLabel(part.partNumber)} '
                    '(${context.l10n.ayahRange(part.ayahRange.startAyah, part.ayahRange.endAyah)})',
              )
              .join(', ');
    final hasSingleExplicitWholePart =
        sortedParts.length == 1 &&
        sortedParts.single.ayahRange.startAyah == 1 &&
        sortedParts.single.ayahRange.endAyah == entry.surah.ayahCount;
    // The primary unsplit one-tap path intentionally stores no explicit
    // scheme coverage. Repository projection still identifies it as whole;
    // an empty part list is therefore the ordinary low-noise case too.
    final isOrdinaryUnsplitWholeSurah =
        entry.isWholeSurah &&
        (sortedParts.isEmpty || hasSingleExplicitWholePart);
    final showCompactRakaatCount =
        entry.event.rakaatSpanCount > 1 || !isOrdinaryUnsplitWholeSurah;
    return _HistoryEntryPresentation(
      occurrence:
          '${entry.event.prayerContext.label(context.l10n)} · '
          '$occurrenceDateText',
      coverage: coverage,
      compactCoverage: showCompactRakaatCount
          ? '$coverage · ${context.l10n.rakaatSpan(entry.event.rakaatSpanCount)}'
          : coverage,
      added: context.l10n.historyAddedAt(addedDateTimeText),
    );
  }

  final String occurrence;
  final String coverage;
  final String compactCoverage;
  final String added;
}

final class _HistoryDetailSection extends StatelessWidget {
  const _HistoryDetailSection({
    super.key,
    required this.icon,
    required this.label,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              if (value case final value?) ...<Widget>[
                const SizedBox(height: 2),
                Text(value),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

final class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.history, size: 56),
          const SizedBox(height: 12),
          Text(context.l10n.emptyHistory),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retry),
          ),
        ],
      ),
    ),
  );
}
