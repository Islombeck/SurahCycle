import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';

final class SurahsScreen extends ConsumerStatefulWidget {
  const SurahsScreen({super.key});

  @override
  ConsumerState<SurahsScreen> createState() => _SurahsScreenState();
}

final class _SurahsScreenState extends ConsumerState<SurahsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(catalogSearchProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar.large(title: Text(context.l10n.surahsTab)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.list(
                children: <Widget>[
                  TextField(
                    key: const ValueKey<String>('surah-search'),
                    controller: _searchController,
                    onChanged: (value) =>
                        ref.read(catalogSearchProvider.notifier).state = value,
                    decoration: InputDecoration(
                      hintText: context.l10n.searchSurahs,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: ref.watch(catalogSearchProvider).isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                ref.read(catalogSearchProvider.notifier).state =
                                    '';
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.verified_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(context.l10n.contentIntegrityNotice),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  catalog.when(
                    data: (items) => items.isEmpty
                        ? ref.watch(catalogSearchProvider).trim().isEmpty
                              ? const _ContentUnavailable()
                              : const _NoSearchResults()
                        : _CatalogList(items: items),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => _CatalogError(
                      onRetry: () => ref.invalidate(catalogProvider),
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
}

final class _CatalogList extends ConsumerStatefulWidget {
  const _CatalogList({required this.items});

  final List<CatalogSurah> items;

  @override
  ConsumerState<_CatalogList> createState() => _CatalogListState();
}

final class _CatalogListState extends ConsumerState<_CatalogList> {
  final Set<String> _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final canReorder = ref.watch(catalogSearchProvider).trim().isEmpty;
    final mastered = widget.items.where((item) => item.isMastered).toList();
    final available = widget.items.where((item) => !item.isMastered).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (mastered.isNotEmpty) ...<Widget>[
          Text(
            context.l10n.masteredOnly,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          if (canReorder) ...<Widget>[
            Text(
              context.l10n.reorderHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: canReorder
                ? ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mastered.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      final reordered = List<CatalogSurah>.of(mastered);
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);
                      await ref
                          .read(surahRepositoryProvider)
                          .reorder(
                            reordered.map((item) => item.surah.id).toList(),
                          );
                    },
                    itemBuilder: (context, index) =>
                        _masteredTile(mastered[index]),
                  )
                : Column(
                    children: <Widget>[
                      for (
                        var index = 0;
                        index < mastered.length;
                        index += 1
                      ) ...<Widget>[
                        _masteredTile(mastered[index]),
                        if (index != mastered.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 24),
        ],
        if (available.isNotEmpty) ...<Widget>[
          Text(
            context.l10n.addToMastered,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (var index = 0; index < available.length; index += 1)
                  Column(
                    children: <Widget>[
                      _AvailableTile(
                        item: available[index],
                        busy: _busy.contains(available[index].surah.id),
                        onAdd: () => _add(available[index]),
                      ),
                      if (index != available.length - 1)
                        const Divider(height: 1),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _masteredTile(CatalogSurah item) => _MasteredTile(
    key: ValueKey<String>('mastered-${item.surah.id}'),
    item: item,
    busy: _busy.contains(item.surah.id),
    onToggle: (value) => _setActive(item, value),
    onOpen: () => context.push('/surah/${item.surah.id}'),
  );

  Future<void> _add(CatalogSurah item) async {
    await _guard(item.surah.id, () async {
      await ref.read(surahRepositoryProvider).addMastered(item.surah.id);
    });
  }

  Future<void> _setActive(CatalogSurah item, bool value) async {
    await _guard(item.surah.id, () async {
      await ref
          .read(surahRepositoryProvider)
          .setActive(item.surah.id, isActive: value);
    });
  }

  Future<void> _guard(String id, Future<void> Function() action) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }
}

final class _MasteredTile extends StatelessWidget {
  const _MasteredTile({
    super.key,
    required this.item,
    required this.busy,
    required this.onToggle,
    required this.onOpen,
  });

  final CatalogSurah item;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.drag_handle),
      title: Text(item.surah.displayName),
      subtitle: Text(
        '${context.l10n.surahNumber(item.surah.surahNumber)} · '
        '${context.l10n.ayahCount(item.surah.ayahCount)}'
        '${item.surah.isRotationEligible ? '' : '\n${context.l10n.fatihaRotationExcluded}'}',
      ),
      onTap: onOpen,
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: item.isActive,
              onChanged: item.surah.isRotationEligible ? onToggle : null,
            ),
    );
  }
}

final class _AvailableTile extends StatelessWidget {
  const _AvailableTile({
    required this.item,
    required this.busy,
    required this.onAdd,
  });

  final CatalogSurah item;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey<String>('catalog-surah-${item.surah.id}'),
      leading: CircleAvatar(child: Text('${item.surah.surahNumber}')),
      title: Text(item.surah.displayName),
      subtitle: Text(context.l10n.ayahCount(item.surah.ayahCount)),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: context.l10n.addToMastered,
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
    );
  }
}

final class _ContentUnavailable extends StatelessWidget {
  const _ContentUnavailable();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              context.l10n.contentUnavailableTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.contentUnavailableBody,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

final class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          const Icon(Icons.search_off, size: 48),
          const SizedBox(height: 12),
          Text(context.l10n.noSearchResults, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

final class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.retry),
      ),
    );
  }
}
