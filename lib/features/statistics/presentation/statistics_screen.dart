import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';

final class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

final class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  PrayerContext? _filter;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(recitationStatsProvider);
    final prayerStats = _filter == null
        ? stats
        : ref.watch(recitationStatsForPrayerProvider(_filter!));
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar.large(title: Text(context.l10n.statisticsTab)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverToBoxAdapter(
                child: stats.when(
                  data: (value) {
                    if (value.actionCount == 0) {
                      return const _EmptyStatistics();
                    }
                    final scoped = _filter == null
                        ? value
                        : prayerStats.valueOrNull;
                    final filtered =
                        scoped?.bySurah ?? const <SurahRecitationStat>[];
                    final filteredTotal = scoped?.total ?? 0;
                    final filteredActionCount = scoped?.actionCount ?? 0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _TotalCard(
                          total: filteredTotal,
                          actionCount: filteredActionCount,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.statisticsFilter,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
                                child: ChoiceChip(
                                  label: Text(context.l10n.allPrayers),
                                  selected: _filter == null,
                                  onSelected: (_) =>
                                      setState(() => _filter = null),
                                ),
                              ),
                              for (final item in value.byPrayer)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${item.context.label(context.l10n)} '
                                      '(${item.count}/${item.actionCount})',
                                    ),
                                    selected: _filter == item.context,
                                    onSelected: (_) =>
                                        setState(() => _filter = item.context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_filter != null && prayerStats.isLoading)
                          const LinearProgressIndicator(),
                        if (_filter != null && prayerStats.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(context.l10n.errorGeneric),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.surahsTab,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: filtered.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    context.l10n.noStatistics,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : Column(
                                  children: <Widget>[
                                    for (
                                      var index = 0;
                                      index < filtered.length;
                                      index += 1
                                    ) ...<Widget>[
                                      _SurahStatTile(stat: filtered[index]),
                                      if (index != filtered.length - 1)
                                        const Divider(height: 1),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.prayerBreakdown,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: <Widget>[
                              for (final item in value.byPrayer)
                                ListTile(
                                  title: Text(item.context.label(context.l10n)),
                                  trailing: Text(
                                    '${item.count} · ${item.actionCount}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => Center(
                    child: FilledButton.icon(
                      onPressed: () => ref.invalidate(recitationStatsProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.retry),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.actionCount});

  final int total;
  final int actionCount;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          const CircleAvatar(child: Icon(Icons.auto_graph)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.l10n.fullEquivalentRecitations),
                Text(
                  '${context.l10n.recitationActions}: $actionCount',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text('$total', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ),
  );
}

final class _SurahStatTile extends StatelessWidget {
  const _SurahStatTile({required this.stat});

  final SurahRecitationStat stat;

  @override
  Widget build(BuildContext context) {
    final lastUsed = stat.lastUsedAtUtc;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      leading: CircleAvatar(child: Text('${stat.surah.surahNumber}')),
      title: Text(stat.surah.displayName),
      subtitle: Text(
        '${context.l10n.recitationActions}: ${stat.actionCount}'
        '${stat.byPart.isEmpty ? '' : ' · ${_partBreakdown(context)}'}\n'
        '${lastUsed == null ? '${context.l10n.lastUsed}: ${context.l10n.never}' : '${context.l10n.lastUsed}: '
                  '${DateFormat.yMMMd(locale).add_Hm().format(lastUsed.toLocal())}'}',
      ),
      isThreeLine: true,
      trailing: Text(
        '${stat.count}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  String _partBreakdown(BuildContext context) {
    final entries = stat.byPart.entries.toList(growable: false);
    return <String>[
      for (var index = 0; index < entries.length; index += 1)
        '${context.l10n.partLabel(index + 1)}: ${entries[index].value}',
    ].join(', ');
  }
}

final class _EmptyStatistics extends StatelessWidget {
  const _EmptyStatistics();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: <Widget>[
        const Icon(Icons.bar_chart_outlined, size: 56),
        const SizedBox(height: 12),
        Text(context.l10n.noStatistics, textAlign: TextAlign.center),
      ],
    ),
  );
}
