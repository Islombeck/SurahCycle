import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';

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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final localTime = entry.event.createdAtUtc.toLocal();
    final capturedDate = DateTime(
      entry.event.localDate.year,
      entry.event.localDate.month,
      entry.event.localDate.day,
    );
    final formatted =
        '${DateFormat.yMMMd(locale).format(capturedDate)} '
        '${DateFormat.Hm(locale).format(localTime)}';
    final parts = List.of(entry.coveredParts)
      ..sort((left, right) => left.partNumber.compareTo(right.partNumber));
    final coverage = entry.isWholeSurah
        ? context.l10n.wholeSurah
        : parts
              .map(
                (part) =>
                    '${context.l10n.partLabel(part.partNumber)} '
                    '(${context.l10n.ayahRange(part.ayahRange.startAyah, part.ayahRange.endAyah)})',
              )
              .join(', ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${entry.surah.surahNumber}')),
        title: Text(entry.surah.displayName),
        subtitle: Text(
          '${entry.event.prayerContext.label(context.l10n)} · $formatted\n'
          '$coverage · ${context.l10n.rakaatSpan(entry.event.rakaatSpanCount)}',
        ),
        isThreeLine: true,
        trailing: isDeleting
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: context.l10n.delete,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
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
