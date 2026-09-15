import 'package:flutter/material.dart';

import '../../../app/localization_extensions.dart';

/// An inclusive ayah range, already validated against the surah's length.
final class RecallRange {
  const RecallRange({required this.start, required this.end});

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Asks which ayahs to check, bounded by the surah's verified ayah count.
Future<RecallRange?> showRecallRangeSheet({
  required BuildContext context,
  required int ayahCount,
  required int initialStart,
  required int initialEnd,
}) => showModalBottomSheet<RecallRange>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _RecallRangeSheet(
    ayahCount: ayahCount,
    initialStart: initialStart.clamp(1, ayahCount),
    initialEnd: initialEnd.clamp(1, ayahCount),
  ),
);

final class _RecallRangeSheet extends StatefulWidget {
  const _RecallRangeSheet({
    required this.ayahCount,
    required this.initialStart,
    required this.initialEnd,
  });

  final int ayahCount;
  final int initialStart;
  final int initialEnd;

  @override
  State<_RecallRangeSheet> createState() => _RecallRangeSheetState();
}

final class _RecallRangeSheetState extends State<_RecallRangeSheet> {
  late int _start = widget.initialStart;
  late int _end = widget.initialEnd;

  bool get _isValid => _end >= _start;

  @override
  Widget build(BuildContext context) {
    final numbers = <int>[
      for (var ayah = 1; ayah <= widget.ayahCount; ayah += 1) ayah,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.recallRangeTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey<String>('recall-range-start'),
                    initialValue: _start,
                    decoration: InputDecoration(
                      labelText: context.l10n.recallRangeFrom,
                    ),
                    items: <DropdownMenuItem<int>>[
                      for (final ayah in numbers)
                        DropdownMenuItem<int>(
                          value: ayah,
                          child: Text('$ayah'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _start = value;
                        if (_end < _start) _end = _start;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey<String>('recall-range-end'),
                    initialValue: _end,
                    decoration: InputDecoration(
                      labelText: context.l10n.recallRangeTo,
                    ),
                    items: <DropdownMenuItem<int>>[
                      for (final ayah in numbers)
                        DropdownMenuItem<int>(
                          value: ayah,
                          child: Text('$ayah'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _end = value);
                    },
                  ),
                ),
              ],
            ),
            if (!_isValid) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                context.l10n.recallRangeInvalid,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey<String>('recall-range-begin'),
              onPressed: _isValid
                  ? () => Navigator.of(
                      context,
                    ).pop(RecallRange(start: _start, end: _end))
                  : null,
              child: Text(context.l10n.recallBegin),
            ),
          ],
        ),
      ),
    );
  }
}
