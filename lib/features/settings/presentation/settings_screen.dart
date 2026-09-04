import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/domain/domain.dart';
import '../../quran/quran.dart';
import 'learning_notification_settings_card.dart';
import 'prayer_routine_settings_card.dart';
import 'prayer_time_settings_card.dart';

final class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

final class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _selectedSurahId;
  bool _adjusting = false;
  bool _savingTranslation = false;
  bool _savingTranslationLanguage = false;
  bool _savingTransliterationProfile = false;
  bool _savingQuranDisplayPreferences = false;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themePreferenceProvider);
    final snapshot = ref.watch(rotationSnapshotProvider);
    final selectedTranslation = ref.watch(selectedQuranTranslationProvider);
    final translationLanguage = ref.watch(quranTranslationLanguageProvider);
    final uiLanguageCode = Localizations.localeOf(context).languageCode;
    final translationLanguageCode = resolveQuranTranslationLanguage(
      uiLanguageCode: uiLanguageCode,
      explicitlySelectedLanguageCode: translationLanguage.valueOrNull,
      selectedTranslationLanguageCode:
          selectedTranslation.valueOrNull?.languageCode,
    );
    final translations = ref.watch(
      quranTranslationsProvider((
        languageCode: translationLanguageCode,
        localizationLanguageCode: uiLanguageCode,
      )),
    );
    final displayPreferences = ref.watch(quranDisplayPreferencesProvider);
    final transliterationProfile = ref.watch(
      selectedQuranTransliterationProfileProvider,
    );
    final transliterationProfileRegistry = ref.watch(
      quranTransliterationProfileRegistryProvider,
    );
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
                  const PrayerTimeSettingsCard(),
                  const SizedBox(height: 8),
                  const PrayerRoutineSettingsCard(),
                  const SizedBox(height: 8),
                  const LearningNotificationSettingsCard(),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: displayPreferences.when(
                        data: (preferences) => _buildQuranDisplayPreferences(
                          preferences,
                          transliterationProfile.valueOrNull ??
                              transliterationProfileRegistry.defaultProfile,
                          profileSettingInvalid:
                              transliterationProfile.hasError,
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, stackTrace) => ListTile(
                          leading: const Icon(Icons.warning_amber_outlined),
                          title: Text(context.l10n.quranDisplayLayers),
                          subtitle: Text(context.l10n.errorGeneric),
                          trailing: IconButton(
                            tooltip: context.l10n.retry,
                            onPressed: () =>
                                ref.invalidate(quranDisplayPreferencesProvider),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    key: const ValueKey<String>(
                      'quran-translation-settings-card',
                    ),
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
                          _buildTranslationLanguageChooser(
                            translationLanguageCode,
                            settingInvalid: translationLanguage.hasError,
                          ),
                          const SizedBox(height: 12),
                          Text(context.l10n.translationCachedOffline),
                          const SizedBox(height: 12),
                          _buildTranslationChooser(
                            translations,
                            selectedTranslation.valueOrNull,
                            selectionInvalid: selectedTranslation.hasError,
                          ),
                          if (translationLanguageCode ==
                              QuranTranslationLanguageRepository
                                  .uzbek) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              context
                                  .l10n
                                  .additionalUzbekTranslationsUnavailable,
                              key: const ValueKey<String>(
                                'additional-uzbek-translations-unavailable',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
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
                        '${context.l10n.tanzilTransliterationMetadata}\n'
                        '${TanzilEnglishTransliterationRepository.sourceUrl}\n'
                        '${context.l10n.transliterationNonCommercialNotice}\n'
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

  Widget _buildTranslationLanguageChooser(
    String selectedLanguageCode, {
    required bool settingInvalid,
  }) {
    return DropdownButtonFormField<String>(
      key: const ValueKey<String>('quran-translation-language-selector'),
      initialValue: selectedLanguageCode,
      decoration: InputDecoration(
        labelText: context.l10n.translationLanguage,
        errorText: settingInvalid ? context.l10n.errorGeneric : null,
      ),
      items: <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(
          value: QuranTranslationLanguageRepository.russian,
          child: Text(context.l10n.translationLanguageRussian),
        ),
        DropdownMenuItem<String>(
          value: QuranTranslationLanguageRepository.uzbek,
          child: Text(context.l10n.translationLanguageUzbek),
        ),
      ],
      onChanged: _savingTranslationLanguage
          ? null
          : (languageCode) {
              if (languageCode != null &&
                  languageCode != selectedLanguageCode) {
                _selectTranslationLanguage(languageCode);
              }
            },
    );
  }

  Future<void> _selectTranslationLanguage(String languageCode) async {
    setState(() => _savingTranslationLanguage = true);
    try {
      await ref
          .read(quranTranslationLanguageControllerProvider)
          .select(languageCode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _savingTranslationLanguage = false);
    }
  }

  Widget _buildQuranDisplayPreferences(
    QuranDisplayPreferences preferences,
    QuranTransliterationProfile selectedProfile, {
    required bool profileSettingInvalid,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            context.l10n.quranDisplayLayers,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SwitchListTile(
          key: const ValueKey<String>('show-arabic-switch'),
          title: Text(context.l10n.showArabicText),
          value: preferences.showArabic,
          onChanged: _savingQuranDisplayPreferences
              ? null
              : (value) => _saveQuranDisplayPreferences(
                  preferences.copyWith(showArabic: value),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DropdownButtonFormField<String>(
            key: const ValueKey<String>('quran-transliteration-profile'),
            initialValue: selectedProfile.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.transliterationProfile,
              errorText: profileSettingInvalid
                  ? context.l10n.errorGeneric
                  : null,
            ),
            items: <DropdownMenuItem<String>>[
              for (final profile
                  in QuranTransliterationProfileRegistry.profiles)
                DropdownMenuItem<String>(
                  value: profile.id,
                  enabled: profile.isAvailableOffline,
                  child: Text(
                    _transliterationProfileLabel(profile),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _savingTransliterationProfile
                ? null
                : (profileId) {
                    if (profileId == null || profileId == selectedProfile.id) {
                      return;
                    }
                    final profile = const QuranTransliterationProfileRegistry()
                        .requireById(profileId);
                    if (profile.isAvailableOffline) {
                      _selectTransliterationProfile(profile);
                    }
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            context.l10n.transliterationProfileCyrillicUnavailable,
            key: const ValueKey<String>(
              'quran-transliteration-cyrillic-unavailable',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        SwitchListTile(
          key: const ValueKey<String>('show-transliteration-switch'),
          title: Text(context.l10n.showTransliteration),
          subtitle: Text(context.l10n.transliterationSourceShort),
          value: preferences.showTransliteration,
          onChanged: _savingQuranDisplayPreferences
              ? null
              : (value) => _saveQuranDisplayPreferences(
                  preferences.copyWith(showTransliteration: value),
                ),
        ),
        SwitchListTile(
          key: const ValueKey<String>('show-translation-switch'),
          title: Text(context.l10n.showTranslation),
          value: preferences.showTranslation,
          onChanged: _savingQuranDisplayPreferences
              ? null
              : (value) => _saveQuranDisplayPreferences(
                  preferences.copyWith(showTranslation: value),
                ),
        ),
      ],
    );
  }

  String _transliterationProfileLabel(QuranTransliterationProfile profile) =>
      switch (profile.script) {
        QuranTransliterationScript.latin =>
          context.l10n.transliterationProfileLatinTanzil,
        QuranTransliterationScript.cyrillic =>
          context.l10n.transliterationProfileCyrillicUnavailable,
      };

  Future<void> _selectTransliterationProfile(
    QuranTransliterationProfile profile,
  ) async {
    setState(() => _savingTransliterationProfile = true);
    try {
      await ref
          .read(quranTransliterationProfileControllerProvider)
          .select(profile);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _savingTransliterationProfile = false);
    }
  }

  Future<void> _saveQuranDisplayPreferences(
    QuranDisplayPreferences preferences,
  ) async {
    setState(() => _savingQuranDisplayPreferences = true);
    try {
      await ref
          .read(quranDisplayPreferencesControllerProvider)
          .save(preferences);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _savingQuranDisplayPreferences = false);
    }
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
        UnavailableQuranContent<List<QuranTranslation>>(:final issue) =>
          _translationError(issue),
        AvailableQuranContent<List<QuranTranslation>>(
          :final value,
          :final fromCache,
          :final issue,
        ) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _translationCatalog(value, selected),
              if (fromCache) ...<Widget>[
                const SizedBox(height: 8),
                Text(context.l10n.translationCatalogFromCache),
              ],
              if (issue != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_translationIssueLabel(issue, cachedDataAvailable: true)),
              ],
            ],
          ),
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
          Text(context.l10n.noTranslationsForLanguage),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(quranTranslationsProvider),
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
                child: Text(
                  '${entry.value.title} · ${entry.value.source} · '
                  'v${entry.value.version}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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

  Widget _translationError([QuranContentIssue? issue]) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        issue == null
            ? context.l10n.translationCatalogError
            : _translationIssueLabel(issue),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => ref.invalidate(quranTranslationsProvider),
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.retry),
      ),
    ],
  );

  String _translationIssueLabel(
    QuranContentIssue issue, {
    bool cachedDataAvailable = false,
  }) => switch (issue.reason) {
    QuranContentUnavailableReason.networkFailure =>
      cachedDataAvailable
          ? context.l10n.translationRefreshFailedCached
          : context.l10n.translationNoNetwork,
    QuranContentUnavailableReason.invalidProviderResponse ||
    QuranContentUnavailableReason.versionMismatch =>
      context.l10n.translationValidationFailed,
    QuranContentUnavailableReason.providerRejectedRequest =>
      context.l10n.translationSourceError,
    _ => context.l10n.translationCatalogError,
  };

  String _translationIdentity(QuranTranslation value) =>
      '${value.source}|${value.languageCode}|${value.key}|${value.version}';

  String _selectionIdentity(QuranTranslationSelection value) =>
      '${value.source}|${value.languageCode}|${value.key}|${value.version}';

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
