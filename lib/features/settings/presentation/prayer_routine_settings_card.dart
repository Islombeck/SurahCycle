import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';
import '../application/prayer_routine_editor.dart';

/// Manual, denomination-neutral editor for the ordered parts of each prayer.
final class PrayerRoutineSettingsCard extends ConsumerStatefulWidget {
  const PrayerRoutineSettingsCard({super.key});

  @override
  ConsumerState<PrayerRoutineSettingsCard> createState() =>
      _PrayerRoutineSettingsCardState();
}

final class _PrayerRoutineSettingsCardState
    extends ConsumerState<PrayerRoutineSettingsCard> {
  PrayerType _selectedPrayer = PrayerType.fajr;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final template = ref.watch(prayerRoutineTemplateProvider(_selectedPrayer));
    return Card(
      key: const ValueKey<String>('prayer-routine-settings'),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.format_list_numbered),
        title: Text(context.l10n.prayerRoutines),
        subtitle: Text(context.l10n.prayerRoutineDescription),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          DropdownButtonFormField<PrayerType>(
            key: const ValueKey<String>('prayer-routine-prayer-selector'),
            initialValue: _selectedPrayer,
            decoration: InputDecoration(labelText: context.l10n.selectPrayer),
            items: <DropdownMenuItem<PrayerType>>[
              for (final type in PrayerType.values)
                DropdownMenuItem<PrayerType>(
                  value: type,
                  child: Text(type.label(context.l10n)),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _selectedPrayer = value);
                  },
          ),
          const SizedBox(height: 12),
          template.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(context.l10n.errorGeneric),
              trailing: IconButton(
                tooltip: context.l10n.retry,
                onPressed: () => ref.invalidate(
                  prayerRoutineTemplateProvider(_selectedPrayer),
                ),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: _buildTemplate,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplate(PrayerRoutineTemplate template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          key: const ValueKey<String>('prayer-routine-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.routineEnabled),
          value: template.enabled,
          onChanged: _busy
              ? null
              : (enabled) => _run(
                  () => _editor.setEnabled(
                    prayerType: template.prayerType,
                    enabled: enabled,
                  ),
                ),
        ),
        if (_missingObligatoryPart(template))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              key: const ValueKey<String>('routine-no-qada-part-warning'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.routineNoQadaPart(
                      _kindLabel(
                        PrayerQadaPolicy.obligatoryPartKind(
                          template.prayerType,
                        )!,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (template.parts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(context.l10n.routineEmpty),
          )
        else
          ReorderableListView.builder(
            key: ValueKey<String>(
              'prayer-routine-parts-${template.prayerType.name}',
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: template.parts.length,
            onReorderItem: _busy
                ? (_, _) {}
                : (oldIndex, newIndex) =>
                      _reorder(template, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final part = template.parts[index];
              return ListTile(
                key: ValueKey<String>('prayer-routine-part-${part.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drag_handle),
                title: Text(_partLabel(part)),
                subtitle: Text(
                  context.l10n.routinePartSummary(
                    part.rakaatCount,
                    part.requiredSurahSlots,
                  ),
                ),
                onTap: _busy ? null : () => _editPart(template, part),
                trailing: IconButton(
                  key: ValueKey<String>(
                    'delete-prayer-routine-part-${part.id}',
                  ),
                  tooltip: context.l10n.delete,
                  onPressed: _busy ? null : () => _deletePart(template, part),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          key: const ValueKey<String>('add-prayer-routine-part'),
          onPressed: _busy ? null : () => _addPart(template),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addPrayerPart),
        ),
      ],
    );
  }

  Future<void> _addPart(PrayerRoutineTemplate template) async {
    final id = ref.read(uuidProvider).v4();
    final draft = PrayerRoutineDefaults.newUserPart(
      prayerType: template.prayerType,
      id: id,
      stableKey: 'part:$id',
      orderIndex: template.parts.length,
      kind: PrayerRoutinePartKind.fard,
      rakaatCount: 2,
      requiredSurahSlots: 2,
    );
    final result = await _showPartDialog(draft, isNew: true);
    if (result == null || !mounted) return;
    await _run(
      () => _editor.addPart(prayerType: template.prayerType, part: result),
    );
  }

  Future<void> _editPart(
    PrayerRoutineTemplate template,
    PrayerRoutinePartTemplate part,
  ) async {
    final result = await _showPartDialog(part, isNew: false);
    if (result == null || !mounted) return;
    await _run(
      () => _editor.updatePart(
        prayerType: template.prayerType,
        replacement: result,
      ),
    );
  }

  Future<void> _deletePart(
    PrayerRoutineTemplate template,
    PrayerRoutinePartTemplate part,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deletePrayerPartTitle),
        content: Text(context.l10n.deletePrayerPartBody(_partLabel(part))),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('cancel-delete-prayer-part'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-delete-prayer-part'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () =>
          _editor.deletePart(prayerType: template.prayerType, partId: part.id),
    );
    if (!mounted) return;
    await _offerToApplyToCurrentSession(template.prayerType);
  }

  /// The second, explicitly scoped half of a delete.
  ///
  /// Deleting from the template changes tomorrow; the prayer the owner is
  /// looking at right now keeps the snapshot it was created with, which is why
  /// a delete that had in fact saved looked like it had not. This asks, once,
  /// whether to apply it there too — naming the date, the prayer and what the
  /// plan will be left with, so the scope of the change is visible before it
  /// happens. Anything already recited is never touched, and is reported back
  /// rather than silently skipped.
  Future<void> _offerToApplyToCurrentSession(PrayerType prayerType) async {
    final context = PrayerContext(prayerType: prayerType);
    final localDate = ref.read(localDateProvider).today();
    final repository = ref.read(prayerRoutineRepositoryProvider);
    final current = await repository.findCurrentSession(
      context: context,
      localDate: localDate,
    );
    if (!mounted) return;
    final stale = current?.parts
        .where(
          (progress) =>
              progress.part.completedAtUtc == null &&
              !_templateHasStableKey(prayerType, progress.part.stableKey),
        )
        .toList();
    if (stale == null || stale.isEmpty) return;

    final remaining = current!.parts
        .where((progress) => !stale.contains(progress))
        .map((progress) => progress.part.label)
        .toList();
    final l10n = this.context.l10n;
    final apply = await showDialog<bool>(
      context: this.context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.applyToCurrentPrayerTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.applyToCurrentPrayerBody(
                prayerType.label(l10n),
                '$localDate',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              remaining.isEmpty
                  ? l10n.applyToCurrentPrayerEmpty
                  : l10n.applyToCurrentPrayerComposition(remaining.join(' · ')),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('keep-current-prayer-unchanged'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.keepCurrentPrayerUnchanged),
          ),
          FilledButton(
            key: const ValueKey<String>('apply-to-current-prayer'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.applyToCurrentPrayerAction),
          ),
        ],
      ),
    );
    if (apply != true || !mounted) return;
    setState(() => _busy = true);
    final PrayerRoutineSessionReconciliation outcome;
    try {
      outcome = await repository.applyTemplateToCurrentSession(
        context: context,
        localDate: localDate,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final kept = outcome.keptBecauseUsedParts;
    if (!mounted || kept.isEmpty) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          kept
              .map((part) => l10n.applyToCurrentPrayerKept(part.label))
              .join('\n'),
        ),
      ),
    );
  }

  bool _templateHasStableKey(PrayerType prayerType, String stableKey) {
    final template = ref
        .read(prayerRoutineTemplateProvider(prayerType))
        .valueOrNull;
    return template == null ||
        template.parts.any((part) => part.stableKey == stableKey);
  }

  /// [newIndex] arrives **already adjusted** for the removal at [oldIndex]:
  /// `ReorderableListView.onReorderItem` subtracts one itself and only calls
  /// back when the index actually changed. Repeating that adjustment here made
  /// a one-step move down collapse onto its own index and return without
  /// saving — the "переставить не сохраняется" the owner reported — and made a
  /// longer move land one slot short of the drop.
  Future<void> _reorder(
    PrayerRoutineTemplate template,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex == oldIndex) return;
    final ids = template.parts.map((part) => part.id).toList();
    final id = ids.removeAt(oldIndex);
    ids.insert(newIndex, id);
    await _run(
      () => _editor.reorderParts(
        prayerType: template.prayerType,
        orderedPartIds: ids,
      ),
    );
  }

  Future<PrayerRoutinePartTemplate?> _showPartDialog(
    PrayerRoutinePartTemplate initial, {
    required bool isNew,
  }) => showDialog<PrayerRoutinePartTemplate>(
    context: context,
    builder: (dialogContext) => _PrayerRoutinePartDialog(
      initial: initial,
      isNew: isNew,
      isNewJumuahPart: isNew && _selectedPrayer == PrayerType.jumuah,
    ),
  );

  /// The owner's own name for the part if he gave it one, and the kind's name
  /// otherwise — for every kind, not only `custom`.
  String _partLabel(PrayerRoutinePartTemplate part) =>
      part.customLabel ?? _kindLabel(part.kind);

  /// Whether this prayer can be made up but has nothing carrying the
  /// obligation.
  ///
  /// Silent until now, and the silence was the problem: a routine built only
  /// from custom parts looks complete and works for an ordinary prayer, while
  /// its Qada has nothing to show and never says why.
  bool _missingObligatoryPart(PrayerRoutineTemplate template) {
    final obligatory = PrayerQadaPolicy.obligatoryPartKind(template.prayerType);
    if (obligatory == null) return false;
    return !template.parts.any((part) => part.kind == obligatory);
  }

  String _kindLabel(PrayerRoutinePartKind kind) => switch (kind) {
    PrayerRoutinePartKind.fard => context.l10n.partKindFard,
    PrayerRoutinePartKind.sunnah => context.l10n.partKindSunnah,
    PrayerRoutinePartKind.witr => context.l10n.partKindWitr,
    PrayerRoutinePartKind.nafl => context.l10n.partKindNafl,
    PrayerRoutinePartKind.custom => context.l10n.partKindCustom,
  };

  PrayerRoutineEditor get _editor => ref.read(prayerRoutineEditorProvider);

  /// The editor never throws: it reports a typed outcome so this screen can
  /// distinguish "someone else changed it" from "it actually failed", and can
  /// offer a bounded, user-driven retry instead of silently repeating writes.
  Future<void> _run(Future<PrayerRoutineEditOutcome> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!mounted) return;
      switch (outcome) {
        case PrayerRoutineEditApplied():
        case PrayerRoutineEditUnchanged():
          break;
        case PrayerRoutineEditConflict():
          _showOutcome(context.l10n.routineEditConflict);
        case PrayerRoutineEditFailed():
          _showOutcome(context.l10n.routineEditFailed, retry: action);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showOutcome(
    String message, {
    Future<PrayerRoutineEditOutcome> Function()? retry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: retry == null
            ? null
            : SnackBarAction(
                label: context.l10n.retry,
                onPressed: () => _run(retry),
              ),
      ),
    );
  }
}

final class _PrayerRoutinePartDialog extends StatefulWidget {
  const _PrayerRoutinePartDialog({
    required this.initial,
    required this.isNew,
    required this.isNewJumuahPart,
  });

  final PrayerRoutinePartTemplate initial;
  final bool isNew;
  final bool isNewJumuahPart;

  @override
  State<_PrayerRoutinePartDialog> createState() =>
      _PrayerRoutinePartDialogState();
}

final class _PrayerRoutinePartDialogState
    extends State<_PrayerRoutinePartDialog> {
  final _formKey = GlobalKey<FormState>();
  late PrayerRoutinePartKind _kind;
  late bool _allowsFollowingImam;
  late final TextEditingController _label;
  late final TextEditingController _rakaat;
  late final TextEditingController _slots;

  @override
  void initState() {
    super.initState();
    _kind = widget.initial.kind;
    _allowsFollowingImam = widget.initial.allowsFollowingImam;
    _label = TextEditingController(text: widget.initial.customLabel);
    _rakaat = TextEditingController(text: '${widget.initial.rakaatCount}');
    _slots = TextEditingController(
      text: '${widget.initial.requiredSurahSlots}',
    );
  }

  @override
  void dispose() {
    _label.dispose();
    _rakaat.dispose();
    _slots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isNew ? context.l10n.addPrayerPart : context.l10n.editPrayerPart,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<PrayerRoutinePartKind>(
                key: const ValueKey<String>('prayer-part-kind'),
                initialValue: _kind,
                decoration: InputDecoration(labelText: context.l10n.partKind),
                items: <DropdownMenuItem<PrayerRoutinePartKind>>[
                  for (final value in PrayerRoutinePartKind.values)
                    DropdownMenuItem<PrayerRoutinePartKind>(
                      value: value,
                      child: Text(_kindLabel(context, value)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _kind = value;
                    if (_kind != PrayerRoutinePartKind.fard) {
                      _allowsFollowingImam = false;
                    } else if (widget.isNewJumuahPart) {
                      _allowsFollowingImam = true;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              // Offered for every kind, not only `custom`. It used to be
              // custom-only, and that forced a choice with a consequence
              // nobody could see: the owner wanted his Witr part called
              // «Важиб», the only way to name a part was to make it custom,
              // and a custom part is not the obligation of any prayer — so
              // Qada for Witr silently had nothing to show. Naming a part and
              // saying what it *is* are two different questions and are now
              // asked separately.
              TextFormField(
                key: const ValueKey<String>('prayer-part-custom-label'),
                controller: _label,
                decoration: InputDecoration(
                  labelText: _kind == PrayerRoutinePartKind.custom
                      ? context.l10n.customPartLabel
                      : context.l10n.partLabelOptional,
                ),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    _kind == PrayerRoutinePartKind.custom &&
                        (value == null || value.trim().isEmpty)
                    ? context.l10n.customPartLabelRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('prayer-part-rakaat-count'),
                controller: _rakaat,
                decoration: InputDecoration(
                  labelText: context.l10n.rakaatCountLabel,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                    ? context.l10n.positiveNumberRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('prayer-part-slot-count'),
                controller: _slots,
                decoration: InputDecoration(
                  labelText: context.l10n.surahSlotsLabel,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) => int.tryParse(value ?? '') == null
                    ? context.l10n.nonNegativeNumberRequired
                    : null,
              ),
              if (_kind == PrayerRoutinePartKind.fard)
                SwitchListTile(
                  key: const ValueKey<String>('prayer-part-follow-imam'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.allowsFollowingImam),
                  value: _allowsFollowingImam,
                  onChanged: (value) =>
                      setState(() => _allowsFollowingImam = value),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('cancel-prayer-part'),
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey<String>('save-prayer-part'),
          onPressed: _save,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      PrayerRoutinePartTemplate(
        id: widget.initial.id,
        stableKey: widget.initial.stableKey,
        orderIndex: widget.initial.orderIndex,
        kind: _kind,
        // An empty field means "no name of its own", not an empty name.
        customLabel: _label.text.trim().isEmpty ? null : _label.text.trim(),
        rakaatCount: int.parse(_rakaat.text),
        requiredSurahSlots: int.parse(_slots.text),
        allowsFollowingImam: _allowsFollowingImam,
        defaultCompletionMode: PrayerPartCompletionMode.recitations,
      ),
    );
  }

  String _kindLabel(BuildContext context, PrayerRoutinePartKind kind) =>
      switch (kind) {
        PrayerRoutinePartKind.fard => context.l10n.partKindFard,
        PrayerRoutinePartKind.sunnah => context.l10n.partKindSunnah,
        PrayerRoutinePartKind.witr => context.l10n.partKindWitr,
        PrayerRoutinePartKind.nafl => context.l10n.partKindNafl,
        PrayerRoutinePartKind.custom => context.l10n.partKindCustom,
      };
}
