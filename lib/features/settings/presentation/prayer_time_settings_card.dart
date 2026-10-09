import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/localization_extensions.dart';
import '../../../core/domain/domain.dart';
import '../../prayer_times/prayer_times.dart';

final class PrayerTimeSettingsCard extends ConsumerStatefulWidget {
  const PrayerTimeSettingsCard({super.key});

  @override
  ConsumerState<PrayerTimeSettingsCard> createState() =>
      _PrayerTimeSettingsCardState();
}

final class _PrayerTimeSettingsCardState
    extends ConsumerState<PrayerTimeSettingsCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(prayerTimeSettingsProvider);
    final today = ref.watch(prayerTodayScheduleProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey<String>('prayer-time-settings'),
        leading: const Icon(Icons.schedule_outlined),
        title: Text(context.l10n.prayerTimesTitle),
        subtitle: settings.valueOrNull == null
            ? null
            : Text(
                settings.valueOrNull!.locationConfirmed
                    ? settings.valueOrNull!.location.displayName
                    : context.l10n.selectPrayerRegion,
              ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          settings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => _SettingsError(
              onRetry: () => ref.invalidate(prayerTimeSettingsProvider),
            ),
            data: (value) => _settingsBody(value, today),
          ),
        ],
      ),
    );
  }

  Widget _settingsBody(
    PrayerTimeSettings settings,
    AsyncValue<PrayerTodaySchedule> today,
  ) {
    final canCalculate = settings.location.coordinates != null;
    final selectedSlug =
        settings.locationConfirmed &&
            settings.locationSelectionMode ==
                PrayerLocationSelectionMode.manualRegion
        ? settings.location.providerSlug
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.prayerRegion,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey<String>('prayer-region-selector'),
          initialValue:
              UzbekistanPrayerLocations.bySlug(selectedSlug ?? '') == null
              ? null
              : selectedSlug,
          // Without this the button takes the width of its **widest** item —
          // «Nukus shahri — Qoraqalpog'iston Resp.» — and on a phone that is
          // 40 logical pixels past the edge of the card. The ellipsis on the
          // items below never helps, because nothing was constraining them.
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.l10n.selectPrayerRegion,
          ),
          items: <DropdownMenuItem<String>>[
            for (final location in UzbekistanPrayerLocations.all)
              DropdownMenuItem<String>(
                value: location.providerSlug,
                child: Text(
                  UzbekistanPrayerLocations.selectorLabel(location),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy
              ? null
              : (slug) {
                  final location = slug == null
                      ? null
                      : UzbekistanPrayerLocations.bySlug(slug);
                  if (location != null) {
                    _save(
                      settings.copyWith(
                        location: location,
                        locationConfirmed: true,
                        locationSelectionMode:
                            PrayerLocationSelectionMode.manualRegion,
                        contextSelectionMode:
                            settings.contextModeExplicitlyChosen
                            ? settings.contextSelectionMode
                            : PrayerContextSelectionMode.automatic,
                        allowCalculatedFallback: location.coordinates == null
                            ? false
                            : settings.allowCalculatedFallback,
                      ),
                    );
                  }
                },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey<String>('use-prayer-location'),
          onPressed: _busy ? null : () => _useDeviceLocation(settings),
          icon: const Icon(Icons.my_location),
          label: Text(context.l10n.useMyLocation),
        ),
        Text(
          context.l10n.locationOptionalNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.prayerContextMode,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        // Stacked for the same reason as the theme selector: «Автоматически»
        // and «Ручной режим» each want about 170 logical pixels and half of
        // this card is 145, so Material broke the words. Found by the sweep
        // in `layout_at_phone_width_test.dart`, which measures every segment
        // on this screen in Russian instead of trusting the short English
        // labels.
        SegmentedButton<PrayerContextSelectionMode>(
          key: const ValueKey<String>('prayer-context-mode'),
          direction: Axis.vertical,
          segments: <ButtonSegment<PrayerContextSelectionMode>>[
            ButtonSegment<PrayerContextSelectionMode>(
              value: PrayerContextSelectionMode.manual,
              label: Text(context.l10n.prayerModeManual),
            ),
            ButtonSegment<PrayerContextSelectionMode>(
              value: PrayerContextSelectionMode.automatic,
              label: Text(context.l10n.prayerModeAutomatic),
            ),
          ],
          selected: <PrayerContextSelectionMode>{settings.contextSelectionMode},
          onSelectionChanged: _busy
              ? null
              : (selection) => _save(
                  settings.copyWith(
                    contextSelectionMode: selection.single,
                    contextModeExplicitlyChosen: true,
                  ),
                  refresh: false,
                ),
        ),
        if (settings.contextSelectionMode ==
            PrayerContextSelectionMode.automatic)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.l10n.automaticPrayerSafetyNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey<String>('calculated-fallback-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.allowCalculatedFallback),
          subtitle: Text(
            canCalculate
                ? context.l10n.calculatedFallbackNotice
                : context.l10n.calculatedFallbackCoordinatesUnavailable,
          ),
          value: canCalculate && settings.allowCalculatedFallback,
          onChanged: _busy || !canCalculate
              ? null
              : (value) => _save(
                  settings.copyWith(allowCalculatedFallback: value),
                  refresh: false,
                ),
        ),
        if (canCalculate && settings.allowCalculatedFallback) ...<Widget>[
          DropdownButtonFormField<PrayerCalculationMethod>(
            key: const ValueKey<String>('prayer-calculation-method'),
            initialValue: settings.calculationSettings.method,
            // Same reason as the region selector above, and the method names
            // are longer still.
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.calculationMethod,
            ),
            items: <DropdownMenuItem<PrayerCalculationMethod>>[
              for (final method in PrayerCalculationMethod.values)
                DropdownMenuItem<PrayerCalculationMethod>(
                  value: method,
                  child: Text(_methodLabel(method), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy
                ? null
                : (method) {
                    if (method == null) return;
                    _save(
                      settings.copyWith(
                        calculationSettings: PrayerCalculationSettings(
                          method: method,
                          asrSchool: settings.calculationSettings.asrSchool,
                          highLatitudeRule:
                              settings.calculationSettings.highLatitudeRule,
                        ),
                      ),
                      refresh: false,
                    );
                  },
          ),
          const SizedBox(height: 8),
          // «Аср: стандартный» is sixteen characters and shares a row with
          // «Аср: Hanafi». Same arithmetic, same answer.
          SegmentedButton<PrayerAsrSchool>(
            key: const ValueKey<String>('prayer-asr-school'),
            direction: Axis.vertical,
            segments: <ButtonSegment<PrayerAsrSchool>>[
              ButtonSegment<PrayerAsrSchool>(
                value: PrayerAsrSchool.hanafi,
                label: Text(context.l10n.asrHanafi),
              ),
              ButtonSegment<PrayerAsrSchool>(
                value: PrayerAsrSchool.shafi,
                label: Text(context.l10n.asrStandard),
              ),
            ],
            selected: <PrayerAsrSchool>{settings.calculationSettings.asrSchool},
            onSelectionChanged: _busy
                ? null
                : (selection) => _save(
                    settings.copyWith(
                      calculationSettings: PrayerCalculationSettings(
                        method: settings.calculationSettings.method,
                        asrSchool: selection.single,
                        highLatitudeRule:
                            settings.calculationSettings.highLatitudeRule,
                      ),
                    ),
                    refresh: false,
                  ),
          ),
        ],
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(context.l10n.manualMinuteAdjustments),
          subtitle: Text(context.l10n.rawTimesPreserved),
          children: <Widget>[
            for (final prayerType in const <PrayerType>[
              PrayerType.fajr,
              PrayerType.dhuhr,
              PrayerType.asr,
              PrayerType.maghrib,
              PrayerType.isha,
            ])
              _PrayerAdjustmentTile(
                prayerType: prayerType,
                value: settings.effectiveAdjustments.forPrayer(prayerType),
                enabled: !_busy,
                onChanged: (value) =>
                    _setAdjustment(settings, prayerType, value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (settings.locationConfirmed)
          today.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => _ScheduleError(
              onRetry: _busy ? null : () => _refresh(settings),
            ),
            data: (value) => _ScheduleDetails(
              value: value,
              onRefresh: _busy ? null : () => _refresh(settings),
            ),
          ),
        if (_busy) ...<Widget>[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Future<void> _setAdjustment(
    PrayerTimeSettings settings,
    PrayerType prayerType,
    int value,
  ) {
    final current = settings.effectiveAdjustments;
    final adjusted = PrayerTimeAdjustments(
      fajrMinutes: prayerType == PrayerType.fajr ? value : current.fajrMinutes,
      dhuhrMinutes: prayerType == PrayerType.dhuhr
          ? value
          : current.dhuhrMinutes,
      asrMinutes: prayerType == PrayerType.asr ? value : current.asrMinutes,
      maghribMinutes: prayerType == PrayerType.maghrib
          ? value
          : current.maghribMinutes,
      ishaMinutes: prayerType == PrayerType.isha ? value : current.ishaMinutes,
    );
    return _save(settings.copyWith(adjustments: adjusted), refresh: false);
  }

  Future<void> _useDeviceLocation(PrayerTimeSettings settings) async {
    setState(() => _busy = true);
    final result = await ref
        .read(devicePrayerLocationServiceProvider)
        .requestUzbekistanLocation();
    if (!mounted) return;
    try {
      final location = result.location;
      if (result.status == DevicePrayerLocationStatus.acquired &&
          location != null) {
        await ref
            .read(prayerTimeSettingsControllerProvider)
            .save(
              settings.copyWith(
                location: location,
                locationConfirmed: true,
                locationSelectionMode:
                    PrayerLocationSelectionMode.userCoordinates,
                contextSelectionMode: settings.contextModeExplicitlyChosen
                    ? settings.contextSelectionMode
                    : PrayerContextSelectionMode.automatic,
                allowCalculatedFallback: true,
              ),
              refresh: false,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.locationCalculationEnabled)),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_locationFailureLabel(result.status))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _locationFailureLabel(DevicePrayerLocationStatus status) =>
      switch (status) {
        DevicePrayerLocationStatus.servicesDisabled =>
          context.l10n.locationServicesDisabled,
        DevicePrayerLocationStatus.permissionDenied ||
        DevicePrayerLocationStatus.permissionDeniedForever =>
          context.l10n.locationDeniedChooseRegion,
        DevicePrayerLocationStatus.outsideUzbekistan =>
          context.l10n.locationOutsideUzbekistan,
        _ => context.l10n.locationFailedChooseRegion,
      };

  Future<void> _save(PrayerTimeSettings settings, {bool refresh = false}) =>
      _guard(
        () => ref
            .read(prayerTimeSettingsControllerProvider)
            .save(settings, refresh: refresh),
      );

  Future<void> _refresh(PrayerTimeSettings settings) => _guard(
    () => ref.read(prayerTimeSettingsControllerProvider).refresh(settings),
  );

  Future<void> _guard(Future<void> Function() action) async {
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

  String _methodLabel(PrayerCalculationMethod method) => switch (method) {
    PrayerCalculationMethod.muslimWorldLeague => 'Muslim World League',
    PrayerCalculationMethod.karachi => 'Karachi',
    PrayerCalculationMethod.ummAlQura => 'Umm al-Qura',
    PrayerCalculationMethod.egyptian => 'Egyptian',
    PrayerCalculationMethod.turkiye => 'Türkiye',
    PrayerCalculationMethod.dubai => 'Dubai',
    PrayerCalculationMethod.qatar => 'Qatar',
    PrayerCalculationMethod.kuwait => 'Kuwait',
    PrayerCalculationMethod.moonsightingCommittee => 'Moonsighting Committee',
    PrayerCalculationMethod.singapore => 'Singapore',
    PrayerCalculationMethod.northAmerica => 'North America (ISNA)',
  };
}

final class _PrayerAdjustmentTile extends StatelessWidget {
  const _PrayerAdjustmentTile({
    required this.prayerType,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final PrayerType prayerType;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(prayerType.label(context.l10n)),
      subtitle: Text(context.l10n.minuteAdjustment(value)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: context.l10n.decreaseMinute,
            onPressed: !enabled || value <= -30
                ? null
                : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value > 0 ? '+$value' : '$value',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: context.l10n.increaseMinute,
            onPressed: !enabled || value >= 30
                ? null
                : () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

final class _ScheduleDetails extends StatelessWidget {
  const _ScheduleDetails({required this.value, required this.onRefresh});

  final PrayerTodaySchedule value;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final result = value.loadResult;
    final schedule = result.schedule;
    final provenance = schedule.provenance;
    final times = value.day.times;
    final calculation = provenance.calculationSettings;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.prayerScheduleToday,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${context.l10n.fajr} ${times.fajr.effective} · '
              '${context.l10n.sunrise} ${times.sunrise.effective}\n'
              '${context.l10n.dhuhr} ${times.dhuhr.effective} · '
              '${context.l10n.asr} ${times.asr.effective} · '
              '${context.l10n.maghrib} ${times.maghrib.effective} · '
              '${context.l10n.isha} ${times.isha.effective}',
            ),
            const SizedBox(height: 8),
            Text(
              '${context.l10n.prayerSource}: '
              '${provenance.source.displayName}\n'
              '${context.l10n.prayerRegion}: ${schedule.location.displayName}\n'
              '${context.l10n.prayerUpdated}: '
              '${provenance.fetchedAtUtc.toIso8601String()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (calculation != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '${context.l10n.calculationMethod}: '
                '${calculation.method.name} · '
                '${context.l10n.asrSchool}: ${calculation.asrSchool.name} · '
                '${provenance.calculatorVersion}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (times.isManuallyAdjusted) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                context.l10n.timesManuallyAdjusted,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (result.isOfflineCache ||
                result.refreshError != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                result.isReliableForAutomaticContext
                    ? context.l10n.prayerOfflineCache
                    : context.l10n.prayerScheduleStale,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.refreshPrayerSchedule),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.warning_amber_outlined),
    title: Text(context.l10n.errorGeneric),
    trailing: IconButton(
      tooltip: context.l10n.retry,
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
    ),
  );
}

final class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(context.l10n.prayerScheduleUnavailable),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.retry),
      ),
    ],
  );
}
