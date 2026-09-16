import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/domain/domain.dart';

/// A month of the user's own records.
///
/// It shows what was entered and nothing else. An empty day is «Нет отметки»,
/// never a missed prayer: the app has no way to know whether a prayer was
/// performed, and saying so would be a claim about the user it has no right to
/// make. Every colour is paired with a caption, and the legend is on screen
/// rather than something to remember.
final class PrayerCalendarScreen extends ConsumerStatefulWidget {
  const PrayerCalendarScreen({super.key});

  @override
  ConsumerState<PrayerCalendarScreen> createState() =>
      _PrayerCalendarScreenState();
}

final class _PrayerCalendarScreenState
    extends ConsumerState<PrayerCalendarScreen> {
  int? _year;
  int? _month;
  LocalDate? _selected;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(localDateProvider).today();
    final year = _year ??= today.year;
    final month = _month ??= today.month;
    final days = ref.watch(
      prayerCalendarMonthProvider((year: year, month: month)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.calendarTitle),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('calendar-previous-month'),
            tooltip: context.l10n.calendarPreviousMonth,
            onPressed: () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: const ValueKey<String>('calendar-next-month'),
            tooltip: context.l10n.calendarNextMonth,
            onPressed: () => _shiftMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Text(
              MaterialLocalizations.of(
                context,
              ).formatMonthYear(DateTime(year, month)),
              key: const ValueKey<String>('calendar-month-title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            days.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(context.l10n.errorGeneric),
              ),
              data: (value) => _MonthGrid(
                days: value,
                today: today,
                selected: _selected,
                onSelect: (date) => setState(() => _selected = date),
              ),
            ),
            const SizedBox(height: 16),
            const _Legend(),
            if (_selected case final selected?) ...<Widget>[
              const SizedBox(height: 16),
              _DayDetails(
                date: selected,
                today: today,
                day: days.valueOrNull
                    ?.where((d) => d.date == selected)
                    .firstOrNull,
                onRegister: selected.compareTo(today) > 0
                    ? null
                    : () => _registerFor(selected),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Hands the chosen day to the ordinary marking flow on Home.
  ///
  /// The calendar deliberately does not grow a second way to register a
  /// recitation: there is one registration path, and this only tells it which
  /// day the next marks belong to.
  void _registerFor(LocalDate date) {
    ref.read(pendingRegistrationDateProvider.notifier).state = date;
    context.go('/');
  }

  void _shiftMonth(int delta) => setState(() {
    final shifted = DateTime.utc(_year!, _month! + delta);
    _year = shifted.year;
    _month = shifted.month;
    _selected = null;
  });
}

final class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final List<PrayerCalendarDay> days;
  final LocalDate today;
  final LocalDate? selected;
  final ValueChanged<LocalDate> onSelect;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    // A leading gap so each column is a real weekday rather than an offset the
    // reader has to compute.
    final firstWeekday = DateTime(
      days.first.date.year,
      days.first.date.month,
    ).weekday;
    final leadingGap = firstWeekday - 1;
    return GridView.count(
      key: const ValueKey<String>('calendar-month-grid'),
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: <Widget>[
        for (var index = 0; index < leadingGap; index += 1)
          const SizedBox.shrink(),
        for (final day in days)
          _DayCell(
            day: day,
            isToday: day.date == today,
            isSelected: day.date == selected,
            isFuture: day.date.compareTo(today) > 0,
            onTap: () => onSelect(day.date),
          ),
      ],
    );
  }
}

final class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  final PrayerCalendarDay day;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey<String>('calendar-day-${day.date}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : isToday
                ? scheme.outline
                : scheme.outlineVariant,
            width: isSelected || isToday ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${day.date.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isFuture ? scheme.outline : null,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Both markers are drawn when a day has both, so one kind of
                // record never hides the other behind a single colour.
                if (day.hasOrdinary)
                  _Marker(
                    color: _ordinaryColor(context),
                    outlined: day.hasPartial,
                  ),
                if (day.hasOrdinary && day.hasQada) const SizedBox(width: 3),
                if (day.hasQada) _Marker(color: _qadaColor(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _Marker extends StatelessWidget {
  const _Marker({required this.color, this.outlined = false});

  final Color color;

  /// A partly marked prayer is drawn hollow, so the difference survives a
  /// screenshot in greyscale and does not rely on colour alone.
  final bool outlined;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: outlined ? null : color,
      border: Border.all(color: color, width: 2),
    ),
  );
}

final class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey<String>('calendar-legend'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LegendRow(
            marker: _Marker(color: _ordinaryColor(context)),
            label: context.l10n.calendarLegendOrdinary,
          ),
          const SizedBox(height: 8),
          _LegendRow(
            marker: _Marker(color: _qadaColor(context)),
            label: context.l10n.calendarLegendQada,
          ),
          const SizedBox(height: 8),
          _LegendRow(
            marker: _Marker(color: _ordinaryColor(context), outlined: true),
            label: context.l10n.calendarLegendPartial,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.calendarQadaExplanation,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.calendarNoRecordExplanation,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

final class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.marker, required this.label});

  final Widget marker;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(children: <Widget>[marker, const SizedBox(width: 12), Text(label)]);
}

final class _DayDetails extends StatelessWidget {
  const _DayDetails({
    required this.date,
    required this.today,
    required this.day,
    required this.onRegister,
  });

  final LocalDate date;
  final LocalDate today;
  final PrayerCalendarDay? day;

  /// Null for a future day: a reading cannot be registered in advance.
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = day?.entries ?? const <PrayerCalendarEntry>[];
    return Card(
      key: const ValueKey<String>('calendar-day-details'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              MaterialLocalizations.of(
                context,
              ).formatFullDate(DateTime(date.year, date.month, date.day)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (date.compareTo(today) > 0)
              Text(
                l10n.calendarFutureDay,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (entries.isEmpty) ...<Widget>[
              Text(l10n.calendarNoRecord),
              const SizedBox(height: 4),
              Text(
                l10n.calendarNoRecordExplanation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      _Marker(
                        color: entry.isQada
                            ? _qadaColor(context)
                            : _ordinaryColor(context),
                        outlined: entry.isPartial,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          <String>[
                            entry.prayerType.label(l10n),
                            if (entry.isQada) l10n.calendarLegendQada,
                            if (entry.hasUnknownOrigin)
                              l10n.calendarQadaOriginUnknownEntry,
                            if (entry.isPartial) l10n.calendarPartialSuffix,
                          ].join(' · '),
                        ),
                      ),
                    ],
                  ),
                ),
            if (entries.any((entry) => entry.isQada)) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                l10n.calendarQadaFulfilledUnknown,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onRegister case final register?) ...<Widget>[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  key: const ValueKey<String>('calendar-register-for-day'),
                  onPressed: register,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(l10n.calendarRegisterForDay),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _ordinaryColor(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

/// Orange is asked for by name, and is kept distinct from the primary colour
/// in both light and dark themes rather than derived from it.
Color _qadaColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFB74D)
    : const Color(0xFFE65100);
