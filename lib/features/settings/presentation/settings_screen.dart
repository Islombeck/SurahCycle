import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/domain/domain.dart';
import '../../quran/quran.dart';

final class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

final class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _selectedSurahId;
  bool _adjusting = false;
  bool _savingTranslation = false;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themePreferenceProvider);
    final snapshot = ref.watch(rotationSnapshotProvider);
    final translations = ref.watch(russianQuranTranslationsProvider);
    final selectedTranslation = ref.watch(selectedQuranTranslationProvider);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar.large(title: Text(context.l10n.settingsTab)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.list(
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            context.l10n.darkMode,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<AppThemePreference>(
                            segments: <ButtonSegment<AppThemePreference>>[
                              ButtonSegment<AppThemePreference>(
                                value: AppThemePreference.system,
                                icon: const Icon(Icons.brightness_auto),
                                label: Text(context.l10n.themeSystem),
                              ),
                              ButtonSegment<AppThemePreference>(
                                value: AppThemePreference.light,
                                icon: const Icon(Icons.light_mode_outlined),
                                label: Text(context.l10n.themeLight),
                              ),
                              ButtonSegment<AppThemePreference>(
                                value: AppThemePreference.dark,
                                icon: const Icon(Icons.dark_mode_outlined),
                                label: Text(context.l10n.themeDark),
                              ),
                            ],
                            selected: <AppThemePreference>{theme},
                            showSelectedIcon: false,
                            onSelectionChanged: (selection) => ref
                                .read(themePreferenceProvider.notifier)
                                .select(selection.single),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            context.l10n.quranTranslation,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(context.l10n.translationCachedOffline),
                          const SizedBox(height: 12),
                          _buildTranslationChooser(
                            translations,
                            selectedTranslation.valueOrNull,
                            selectionInvalid: selectedTranslation.hasError,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(context.l10n.openHistory),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/history'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.file_download_outlined),
                          title: Text(context.l10n.exportData),
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.l10n.exportPrepared),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_outlined),
                      title: Text(context.l10n.sourceMetadata),
                      subtitle: Text(
                        '${context.l10n.tanzilTextMetadata}\n'
                        '${TanzilUthmaniTextRepository.sourceUrl}\n'
                        '${context.l10n.contentIntegrityNotice}',
                      ),
                      trailing: const Icon(Icons.offline_pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: const Icon(Icons.tune),
                      title: Text(context.l10n.advancedSettings),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: <Widget>[
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(context.l10n.balanceAdjustmentBody),
                        ),
                        const SizedBox(height: 12),
                        snapshot.when(
                          data: _buildBalanceControls,
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stackTrace) =>
                              Text(context.l10n.errorGeneric),
                        ),
                      ],
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

  Widget _buildTranslationChooser(
    AsyncValue<QuranContentState<List<QuranTranslation>>> catalog,
    QuranTranslationSelection? selected, {
    required bool selectionInvalid,
  }) {
    final catalogChooser = catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _translationError(),
      data: (state) => switch (state) {
        UnavailableQuranContent<List<QuranTranslation>>() =>
          _translationError(),
        AvailableQuranContent<List<QuranTranslation>>(:final value) =>
          _translationCatalog(value, selected),
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        catalogChooser,
        if (selectionInvalid) ...<Widget>[
          const SizedBox(height: 12),
          Text(context.l10n.translationSelectionInvalid),
        ],
        if (selected != null) ...<Widget>[
          const SizedBox(height: 12),
          _selectedTranslationMetadata(selected),
        ],
        if (selected != null || selectionInvalid)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey<String>('quran-translation-clear'),
              onPressed: _savingTranslation ? null : _clearTranslation,
              child: Text(context.l10n.clearTranslation),
            ),
          ),
      ],
    );
  }

  Widget _translationCatalog(
    List<QuranTranslation> translations,
    QuranTranslationSelection? selected,
  ) {
    if (translations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(context.l10n.noRussianTranslations),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(russianQuranTranslationsProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retry),
          ),
        ],
      );
    }
    final byIdentity = <String, QuranTranslation>{
      for (final translation in translations)
        _translationIdentity(translation): translation,
    };
    final selectedIdentity = selected == null
        ? null
        : _selectionIdentity(selected);
    QuranTranslation? availableUpdate;
    if (selected != null) {
      for (final translation in translations) {
        if (translation.source == selected.source &&
            translation.key == selected.key &&
            translation.languageCode == selected.languageCode &&
            translation.version != selected.version) {
          availableUpdate = translation;
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: const ValueKey<String>('quran-translation-selector'),
          initialValue: byIdentity.containsKey(selectedIdentity)
              ? selectedIdentity
              : null,
          decoration: InputDecoration(
            labelText: context.l10n.translationNotSelected,
          ),
          items: <DropdownMenuItem<String>>[
            for (final entry in byIdentity.entries)
              DropdownMenuItem<String>(
                value: entry.key,
                child: Text('${entry.value.title} · v${entry.value.version}'),
              ),
          ],
          onChanged: _savingTranslation
              ? null
              : (identity) {
                  final translation = byIdentity[identity];
                  if (translation != null) {
                    _selectTranslation(translation);
                  }
                },
        ),
        if (_savingTranslation) ...<Widget>[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (availableUpdate != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            context.l10n.translationUpdateAvailable(availableUpdate.version),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('quran-translation-update'),
            onPressed: _savingTranslation
                ? null
                : () => _selectTranslation(availableUpdate!),
            icon: const Icon(Icons.system_update_alt),
            label: Text(
              context.l10n.useTranslationVersion(availableUpdate.version),
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectedTranslationMetadata(QuranTranslationSelection selected) {
    return Text(
      '${selected.title}\n'
      '${selected.source} · v${selected.version}\n'
      '${selected.attribution} · ${selected.fetchedAtUtc.toIso8601String()}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _translationError() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(context.l10n.translationCatalogError),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => ref.invalidate(russianQuranTranslationsProvider),
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.retry),
      ),
    ],
  );

  String _translationIdentity(QuranTranslation value) =>
      '${value.source}|${value.key}|${value.version}';

  String _selectionIdentity(QuranTranslationSelection value) =>
      '${value.source}|${value.key}|${value.version}';

  Future<void> _selectTranslation(QuranTranslation translation) async {
    setState(() => _savingTranslation = true);
    try {
      await ref
          .read(quranTranslationSelectionControllerProvider)
          .select(translation);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _savingTranslation = false);
    }
  }

  Future<void> _clearTranslation() async {
    setState(() => _savingTranslation = true);
    try {
      await ref.read(quranTranslationSelectionControllerProvider).clear();
    } finally {
      if (mounted) setState(() => _savingTranslation = false);
    }
  }

  Widget _buildBalanceControls(RotationSnapshot snapshot) {
    final candidates =
        snapshot.surahs
            .where(
              (surah) =>
                  surah.hasEnteredRotation && surah.surah.isRotationEligible,
            )
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.surah.surahNumber.compareTo(right.surah.surahNumber),
          );
    if (candidates.isEmpty) {
      return Text(context.l10n.noActiveSurahs);
    }
    final validSelection = candidates.any((item) => item.id == _selectedSurahId)
        ? _selectedSurahId
        : candidates.first.id;
    final selected = candidates.firstWhere((item) => item.id == validSelection);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: validSelection,
          decoration: InputDecoration(labelText: context.l10n.selectSurah),
          items: <DropdownMenuItem<String>>[
            for (final item in candidates)
              DropdownMenuItem<String>(
                value: item.id,
                child: Text(item.surah.displayName),
              ),
          ],
          onChanged: _adjusting
              ? null
              : (value) => setState(() => _selectedSurahId = value),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.aheadBy(
            selected.rotationScore > snapshot.rotationTarget
                ? selected.rotationScore - snapshot.rotationTarget
                : 0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _adjusting
                    ? null
                    : () => _confirmAdjustment(validSelection!, -1),
                child: Text(context.l10n.shiftMinusOne),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: _adjusting
                    ? null
                    : () => _confirmAdjustment(validSelection!, 1),
                child: Text(context.l10n.shiftPlusOne),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmAdjustment(String surahId, int delta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.balanceAdjustment),
        content: Text(context.l10n.balanceConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _adjusting = true);
    try {
      await ref
          .read(appActionsProvider)
          .adjustBalance(surahId: surahId, delta: delta);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _adjusting = false);
    }
  }
}
