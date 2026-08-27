import 'package:flutter/material.dart';

import '../core/domain/domain.dart';
import '../l10n/app_localizations.dart';

extension LocalizationBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension PrayerLocalization on PrayerType {
  String label(AppLocalizations l10n) => switch (this) {
    PrayerType.fajr => l10n.fajr,
    PrayerType.dhuhr => l10n.dhuhr,
    PrayerType.asr => l10n.asr,
    PrayerType.maghrib => l10n.maghrib,
    PrayerType.isha => l10n.isha,
    PrayerType.witr => l10n.witr,
    PrayerType.nafl => l10n.nafl,
  };
}

extension PrayerContextLocalization on PrayerContext {
  String label(AppLocalizations l10n) {
    final prayer = prayerType.label(l10n);
    return isQada ? '$prayer · ${l10n.qada}' : prayer;
  }
}

extension LearningStageLocalization on LearningStage {
  String label(AppLocalizations l10n) => switch (kind) {
    LearningStageKind.newAyah => l10n.newAyah(ayahNumber),
    LearningStageKind.cumulative when startAyah == 1 => l10n.cumulativeRange(
      endAyah,
    ),
    LearningStageKind.cumulative || LearningStageKind.reviewRange =>
      l10n.learningReviewRange(startAyah, endAyah),
    LearningStageKind.bridge => l10n.learningBridgeRange(startAyah, endAyah),
    LearningStageKind.sectionReview => l10n.learningSectionReview(
      startAyah,
      endAyah,
    ),
    LearningStageKind.finalReview => l10n.learningFinalReview(
      startAyah,
      endAyah,
    ),
  };
}
