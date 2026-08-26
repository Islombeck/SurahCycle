import 'package:flutter/widgets.dart';

import '../core/domain/domain.dart';
import '../core/widgets/widget_projection_builder.dart';
import '../l10n/app_localizations.dart';

final class WidgetLocalization {
  WidgetLocalization._(this.languageCode, this.l10n);

  factory WidgetLocalization.forLanguageCode(String languageCode) {
    final resolved = const <String>{'ru', 'en', 'uz'}.contains(languageCode)
        ? languageCode
        : 'ru';
    return WidgetLocalization._(
      resolved,
      lookupAppLocalizations(Locale(resolved)),
    );
  }

  final String languageCode;
  final AppLocalizations l10n;

  WidgetProjectionLabels get projectionLabels => WidgetProjectionLabels(
    part: l10n.widgetPart,
    ayah: l10n.widgetAyah,
    ayahs: l10n.widgetAyahs,
    openAppToLoadText: l10n.widgetOpenAppToLoadText,
  );

  String prayerContextLabel(
    PrayerContext? context, {
    bool isAutomatic = false,
    String? startsAt,
    String? endsAt,
  }) {
    if (context == null) return l10n.widgetSelectPrayerInApp;
    final prayer = switch (context.prayerType) {
      PrayerType.fajr => l10n.fajr,
      PrayerType.dhuhr => l10n.dhuhr,
      PrayerType.asr => l10n.asr,
      PrayerType.maghrib => l10n.maghrib,
      PrayerType.isha => l10n.isha,
      PrayerType.witr => l10n.witr,
      PrayerType.nafl => l10n.nafl,
    };
    final label = context.isQada ? '${l10n.qada}: $prayer' : prayer;
    if (isAutomatic) {
      if (startsAt != null && endsAt != null) {
        return l10n.widgetAutomaticPrayerRange(label, startsAt, endsAt);
      }
      if (startsAt != null) {
        return l10n.widgetAutomaticPrayerStart(label, startsAt);
      }
      return l10n.widgetAutomaticPrayerContext(label);
    }
    return l10n.widgetManualPrayerContext(label);
  }
}
