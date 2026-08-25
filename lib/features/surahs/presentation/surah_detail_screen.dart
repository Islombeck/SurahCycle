import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/domain/domain.dart';

final class SurahDetailScreen extends ConsumerStatefulWidget {
  const SurahDetailScreen({required this.surahId, super.key});

  final String surahId;

  @override
  ConsumerState<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

final class _SurahDetailScreenState extends ConsumerState<SurahDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(rotationSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editSegmentation)),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(rotationSnapshotProvider),
            child: Text(context.l10n.retry),
          ),
        ),
        data: (value) {
          final matches = value.surahs
              .where((surah) => surah.id == widget.surahId)
              .toList(growable: false);
          if (matches.isEmpty) {
            return Center(child: Text(context.l10n.errorGeneric));
          }
          final surah = matches.single;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Text(
                surah.surah.displayName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${context.l10n.surahNumber(surah.surah.surahNumber)} · '
                '${context.l10n.ayahCount(surah.surah.ayahCount)}',
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(context.l10n.editAlias),
                      subtitle: Text(surah.surah.displayName),
                      onTap: _busy ? null : () => _editAlias(surah),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.repeat),
                      title: Text(
                        surah.isActive
                            ? context.l10n.activeRotation
                            : context.l10n.inactiveRotation,
                      ),
                      subtitle: surah.surah.isRotationEligible
                          ? null
                          : Text(context.l10n.fatihaRotationExcluded),
                      value: surah.isActive,
                      onChanged: _busy || !surah.surah.isRotationEligible
                          ? null
                          : (value) => _run(
                              () => ref
                                  .read(surahRepositoryProvider)
                                  .setActive(surah.id, isActive: value),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.editSegmentation,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    context.l10n.schemeVersion(surah.rotationScheme.version),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < surah.rotationScheme.parts.length;
                      index += 1
                    ) ...<Widget>[
                      ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(context.l10n.partLabel(index + 1)),
                        subtitle: Text(
                          context.l10n.ayahRange(
                            surah
                                .rotationScheme
                                .parts[index]
                                .ayahRange
                                .startAyah,
                            surah.rotationScheme.parts[index].ayahRange.endAyah,
                          ),
                        ),
                        trailing: Text(
                          '${surah.rotationScheme.parts[index].rotationScore}',
                        ),
                      ),
                      if (index != surah.rotationScheme.parts.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : () => _editSegmentation(surah),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.call_split),
                label: Text(context.l10n.manualBoundaries),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editAlias(MasteredSurah surah) async {
    final controller = TextEditingController(text: surah.surah.alias ?? '');
    final alias = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.editAlias),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.aliasHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (alias != null) {
      await _run(
        () => ref.read(surahRepositoryProvider).setAlias(surah.id, alias),
      );
    }
  }

  Future<void> _editSegmentation(MasteredSurah surah) async {
    final ranges = await showModalBottomSheet<List<AyahRange>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SegmentationSheet(surah: surah),
    );
    if (ranges == null) return;
    await _run(
      () => ref
          .read(appActionsProvider)
          .changeSegmentation(surahId: surah.id, ranges: ranges),
    );
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _SegmentationSheet extends StatefulWidget {
  const _SegmentationSheet({required this.surah});

  final MasteredSurah surah;

  @override
  State<_SegmentationSheet> createState() => _SegmentationSheetState();
}

final class _SegmentationSheetState extends State<_SegmentationSheet> {
  static const int _customSelection = 0;

  late int _partCount;
  late bool _customMode;
  late bool _manual;
  late final TextEditingController _partCountController;
  List<TextEditingController> _endControllers = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _partCount = widget.surah.rotationScheme.parts.length;
    _customMode = _partCount > 4;
    _manual = false;
    _partCountController = TextEditingController(text: '$_partCount');
    _setRanges(
      widget.surah.rotationScheme.parts.map((part) => part.ayahRange).toList(),
    );
  }

  @override
  void dispose() {
    _partCountController.dispose();
    for (final controller in _endControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setRanges(List<AyahRange> ranges) {
    for (final controller in _endControllers) {
      controller.dispose();
    }
    _endControllers = <TextEditingController>[
      for (final range in ranges.take(ranges.length - 1))
        TextEditingController(text: '${range.endAyah}'),
    ];
  }

  List<AyahRange>? get _ranges {
    if (_customMode && !_isValidPartCountText(_partCountController.text)) {
      return null;
    }
    if (_partCount == 1) {
      return <AyahRange>[
        AyahRange(startAyah: 1, endAyah: widget.surah.surah.ayahCount),
      ];
    }
    final ends = <int>[];
    for (final controller in _endControllers) {
      final value = int.tryParse(controller.text.trim());
      if (value == null) return null;
      ends.add(value);
    }
    if (ends.length != _partCount - 1) return null;
    var start = 1;
    final ranges = <AyahRange>[];
    for (var index = 0; index < ends.length; index += 1) {
      final end = ends[index];
      final remainingParts = _partCount - index - 1;
      if (end < start || end > widget.surah.surah.ayahCount - remainingParts) {
        return null;
      }
      ranges.add(AyahRange(startAyah: start, endAyah: end));
      start = end + 1;
    }
    ranges.add(
      AyahRange(startAyah: start, endAyah: widget.surah.surah.ayahCount),
    );
    return ranges;
  }

  bool _isValidPartCountText(String raw) {
    final value = int.tryParse(raw.trim());
    return value != null && value >= 1 && value <= widget.surah.surah.ayahCount;
  }

  void _selectPartCount(int value, {required bool customMode}) {
    final ranges = suggestEvenRanges(
      ayahCount: widget.surah.surah.ayahCount,
      partCount: value,
    );
    setState(() {
      _partCount = value;
      _customMode = customMode;
      _manual = false;
      _partCountController.text = '$value';
      _setRanges(ranges);
    });
  }

  void _selectMode(int value) {
    if (value != _customSelection) {
      _selectPartCount(value, customMode: false);
      return;
    }
    final proposed = widget.surah.surah.ayahCount > 4 && _partCount <= 4
        ? 5
        : _partCount;
    _selectPartCount(proposed, customMode: true);
  }

  void _updateCustomPartCount(String raw) {
    if (!_isValidPartCountText(raw)) {
      setState(() {});
      return;
    }
    final value = int.parse(raw.trim());
    final ranges = suggestEvenRanges(
      ayahCount: widget.surah.surah.ayahCount,
      partCount: value,
    );
    setState(() {
      _partCount = value;
      _manual = false;
      _setRanges(ranges);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ranges = _ranges;
    final maxPreset = widget.surah.surah.ayahCount < 4
        ? widget.surah.surah.ayahCount
        : 4;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.editSegmentation,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                key: const ValueKey<String>('segmentation-preset-selector'),
                segments: <ButtonSegment<int>>[
                  for (var count = 1; count <= maxPreset; count += 1)
                    ButtonSegment<int>(value: count, label: Text('$count')),
                  ButtonSegment<int>(
                    value: _customSelection,
                    label: Text(context.l10n.customParts),
                  ),
                ],
                selected: <int>{_customMode ? _customSelection : _partCount},
                onSelectionChanged: (selection) =>
                    _selectMode(selection.single),
              ),
              if (_customMode) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('custom-part-count'),
                  controller: _partCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.customPartCount,
                    helperText: context.l10n.customPartCountRange(
                      widget.surah.surah.ayahCount,
                    ),
                    errorText: _isValidPartCountText(_partCountController.text)
                        ? null
                        : context.l10n.customPartCountInvalid,
                  ),
                  onChanged: _updateCustomPartCount,
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _manual
                      ? context.l10n.manualBoundaries
                      : context.l10n.automaticBoundaries,
                ),
                value: _manual,
                onChanged: _partCount == 1
                    ? null
                    : (value) => setState(() => _manual = value),
              ),
              if (_manual)
                for (var index = 0; index < _endControllers.length; index += 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _endControllers[index],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.partLabel(index + 1),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
              const SizedBox(height: 8),
              if (ranges == null)
                Text(
                  context.l10n.errorGeneric,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else
                for (var index = 0; index < ranges.length; index += 1)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(context.l10n.partLabel(index + 1)),
                    subtitle: Text(
                      context.l10n.ayahRange(
                        ranges[index].startAyah,
                        ranges[index].endAyah,
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: ranges == null
                    ? null
                    : () => Navigator.of(context).pop(ranges),
                child: Text(context.l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
