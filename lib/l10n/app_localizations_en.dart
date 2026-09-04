// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Murajaah';

  @override
  String get homeTab => 'Home';

  @override
  String get surahsTab => 'Surahs';

  @override
  String get learningTab => 'Learning';

  @override
  String get statisticsTab => 'Statistics';

  @override
  String get settingsTab => 'Settings';

  @override
  String get historyTitle => 'History';

  @override
  String get recommendedTitle => 'Recommended';

  @override
  String recommendationRank(int rank) {
    return 'Recommendation $rank';
  }

  @override
  String get activeSurahsTitle => 'Active surahs';

  @override
  String get noActiveSurahs =>
      'Select mastered surahs and add them to rotation.';

  @override
  String get contentUnavailableTitle => 'Quran content is not downloaded yet';

  @override
  String get contentUnavailableBody =>
      'The verified surah catalog is available offline. Ayah text and translations are not downloaded yet; rotation and learning stages still work.';

  @override
  String get refreshContent => 'Check source';

  @override
  String get sourceUnavailable => 'A verified source is not connected yet';

  @override
  String get prayerContextTitle => 'Prayer context';

  @override
  String get fajr => 'Fajr';

  @override
  String get dhuhr => 'Dhuhr';

  @override
  String get jumuah => 'Jumuah';

  @override
  String get asr => 'Asr';

  @override
  String get maghrib => 'Maghrib';

  @override
  String get isha => 'Isha';

  @override
  String get witr => 'Witr';

  @override
  String get nafl => 'Nafl';

  @override
  String get qada => 'Qada';

  @override
  String get selectPrayer => 'Select prayer';

  @override
  String get surahMarked => 'Surah marked';

  @override
  String get undo => 'Undo';

  @override
  String get doneForCycle => 'Complete';

  @override
  String recitationsRemaining(int count) {
    return '$count×';
  }

  @override
  String ayahCount(int count) {
    return '$count ayahs';
  }

  @override
  String surahNumber(int number) {
    return 'Surah $number';
  }

  @override
  String get searchSurahs => 'Search by number or name';

  @override
  String get noSearchResults => 'No surahs match this search.';

  @override
  String get masteredOnly => 'Mastered';

  @override
  String get activeRotation => 'In rotation';

  @override
  String get inactiveRotation => 'Paused';

  @override
  String get addToMastered => 'Add to mastered';

  @override
  String get removeFromRotation => 'Pause';

  @override
  String get returnToRotation => 'Return to rotation';

  @override
  String get editAlias => 'Edit name';

  @override
  String get aliasHint => 'Your surah name';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get deleteHistoryConfirm =>
      'Delete this entry? Balance will be rebuilt from saved events.';

  @override
  String get emptyHistory => 'No recitations yet.';

  @override
  String get normalRecitation => 'Regular';

  @override
  String get qadaRecitation => 'Qada';

  @override
  String get totalRecitations => 'Total recitations';

  @override
  String get lastUsed => 'Last recitation';

  @override
  String get never => 'Not recited yet';

  @override
  String get prayerBreakdown => 'By prayer';

  @override
  String get noStatistics =>
      'Statistics will appear after the first recitation.';

  @override
  String get currentLearning => 'Currently learning';

  @override
  String get showOnHome => 'Show on Home';

  @override
  String get startLearning => 'Start learning';

  @override
  String get repeated => 'Repeated';

  @override
  String get learned => 'Learned';

  @override
  String newAyah(int number) {
    return 'New ayah $number';
  }

  @override
  String cumulativeRange(int end) {
    return 'Review ayahs 1–$end';
  }

  @override
  String get learningRolledBack =>
      'After 72 hours without review, the stage moved back once.';

  @override
  String get learningCompletedTitle => 'Surah learned';

  @override
  String get learningCompletedBody => 'Add it to active rotation?';

  @override
  String get completeAndAdd => 'Complete and add';

  @override
  String get darkMode => 'Dark theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get balanceAdjustment => 'Balance adjustment';

  @override
  String get balanceAdjustmentBody =>
      'Use only to migrate an existing balance. Recitation history will not change.';

  @override
  String get shiftPlusOne => 'Shift balance +1';

  @override
  String get shiftMinusOne => 'Shift balance −1';

  @override
  String get balanceConfirm =>
      'Change only this surah\'s balance? Historical statistics stay unchanged.';

  @override
  String get exportData => 'Export data';

  @override
  String get exportPrepared =>
      'The export boundary is ready; file sharing is planned for the next sprint.';

  @override
  String get sourceMetadata => 'Data source';

  @override
  String get offlineReady => 'Works offline';

  @override
  String get retry => 'Retry';

  @override
  String get errorGeneric => 'The action could not be completed';

  @override
  String get loading => 'Loading…';

  @override
  String get noLearningSurahs => 'No surahs are being learned.';

  @override
  String get openHistory => 'Open history';

  @override
  String aheadBy(int count) {
    return 'Ahead by $count';
  }

  @override
  String get statisticsFilter => 'Prayer filter';

  @override
  String get allPrayers => 'All prayers';

  @override
  String get isQadaLabel => 'Make-up prayer';

  @override
  String get reorderHint => 'Long-press and drag to reorder';

  @override
  String get selectSurah => 'Select a surah';

  @override
  String get contentIntegrityNotice =>
      'Text and metadata are shown unchanged only after loading them from a verified source.';

  @override
  String get editSegmentation => 'Recitation parts';

  @override
  String get wholeSurah => 'Whole surah';

  @override
  String partLabel(Object number) {
    return 'Part $number';
  }

  @override
  String ayahRange(int start, int end) {
    return 'Ayahs $start–$end';
  }

  @override
  String rakaatSpan(Object count) {
    return 'Rakaats: $count';
  }

  @override
  String get selectCoverage => 'Select the recited parts';

  @override
  String splitIntoParts(Object count) {
    return 'Split into $count parts';
  }

  @override
  String get automaticBoundaries => 'Automatic boundaries';

  @override
  String get manualBoundaries => 'Edit boundaries';

  @override
  String schemeVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get recitationActions => 'Recitation actions';

  @override
  String get fullEquivalentRecitations => 'Full-surah equivalents';

  @override
  String dueSurahsCount(Object count) {
    return 'Due: $count';
  }

  @override
  String get widgetPart => 'Part';

  @override
  String get widgetAyah => 'Ayah';

  @override
  String get widgetAyahs => 'Ayahs';

  @override
  String get widgetOpenAppToLoadText => 'Open Murajaah to load verified text';

  @override
  String get customParts => 'Custom';

  @override
  String get customPartCount => 'Number of parts';

  @override
  String customPartCountRange(int max) {
    return 'From 1 to $max';
  }

  @override
  String get customPartCountInvalid => 'Enter a valid number of parts';

  @override
  String get fatihaRotationExcluded =>
      'Al-Fatiha remains mastered but is excluded from the regular rotation.';

  @override
  String get completeLearningOnly => 'Complete learning';

  @override
  String get arabicTextOfflineReady =>
      'Verified Tanzil Arabic text is available offline.';

  @override
  String get quranTranslation => 'Quran translation';

  @override
  String get translationLanguage => 'Translation language';

  @override
  String get translationLanguageRussian => 'Russian';

  @override
  String get translationLanguageUzbek => 'Uzbek';

  @override
  String get chooseTranslation => 'Choose a translation in Settings';

  @override
  String get noTranslationsForLanguage =>
      'QuranEnc currently has no available verified translations for this language. Arabic remains available offline.';

  @override
  String get additionalUzbekTranslationsUnavailable =>
      'Al-Mukhtasar (uzbek_mokhtasar) and Al-Muyassar (uzbek_moyassar): official catalog keys are confirmed, but their API corpora are not currently available.';

  @override
  String get translationCatalogError =>
      'The official QuranEnc translation list could not be loaded.';

  @override
  String get translationNoNetwork =>
      'No network connection. Previously downloaded translations remain available offline.';

  @override
  String get translationSourceError =>
      'The translation source rejected the request. Try again later.';

  @override
  String get translationValidationFailed =>
      'The source response is corrupt or failed validation. It was not stored.';

  @override
  String get translationCatalogFromCache =>
      'Showing the saved offline catalog.';

  @override
  String get translationRefreshFailedCached =>
      'The source could not be refreshed; saved verified data was left unchanged.';

  @override
  String get translationNotSelected => 'No translation selected';

  @override
  String get translationCachedOffline =>
      'The selected translation is cached for offline reading as surahs are opened.';

  @override
  String get translationUnavailableOffline =>
      'The translation for this ayah is not stored yet. Arabic remains available while it downloads in the background.';

  @override
  String get clearTranslation => 'Clear translation selection';

  @override
  String get translationSelectionInvalid =>
      'The saved translation selection is invalid or no longer supported. Arabic remains available.';

  @override
  String get translationVersionChanged =>
      'The selected translation version has changed. Confirm the new version in Settings; Arabic remains available.';

  @override
  String translationUpdateAvailable(String version) {
    return 'A new version of the selected translation is available: v$version. It will update only if you choose it.';
  }

  @override
  String useTranslationVersion(String version) {
    return 'Use v$version';
  }

  @override
  String get tanzilTextMetadata =>
      'Tanzil Project · Uthmani Quran Text v1.1 · CC BY 3.0';

  @override
  String get tanzilTransliterationMetadata =>
      'Tanzil · English Transliteration · 2010-09-06 snapshot · 6,236 ayahs';

  @override
  String get transliterationNonCommercialNotice =>
      'The transliteration dataset permits non-commercial use only; a commercial production release requires separate permission.';

  @override
  String get quranDisplayLayers => 'Quran text layers';

  @override
  String get showArabicText => 'Show Arabic text';

  @override
  String get showTransliteration => 'Show transliteration';

  @override
  String get transliterationProfile => 'Transliteration profile';

  @override
  String get transliterationProfileLatinTanzil => 'Latin — Tanzil';

  @override
  String get transliterationProfileCyrillic => 'Cyrillic';

  @override
  String get transliterationProfileCyrillicUnavailable =>
      'Cyrillic — a verified source has not been connected yet';

  @override
  String get showTranslation => 'Show translation';

  @override
  String get transliterationSourceShort =>
      'Latin transliteration · Tanzil · offline';

  @override
  String get transliterationUnavailable =>
      'Verified transliteration is unavailable.';

  @override
  String get prayerTimesTitle => 'Prayer times';

  @override
  String get prayerRegion => 'Region';

  @override
  String get selectPrayerRegion => 'Choose a region manually';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get locationOptionalNotice =>
      'Optional. Location is requested only after this tap, with no background access.';

  @override
  String get prayerContextMode => 'Marking context';

  @override
  String get prayerModeManual => 'Manual mode';

  @override
  String get prayerModeAutomatic => 'Automatic';

  @override
  String get useJumuahForNextRecitation => 'Use Jumuah for next recitation';

  @override
  String get automaticPrayerSafetyNotice =>
      'Automatic selection works only with a fresh reliable schedule. From sunrise until Dhuhr, marking requires a manual choice.';

  @override
  String get allowCalculatedFallback => 'Allow local calculation';

  @override
  String get calculatedFallbackNotice =>
      'This is a separate calculated source, not an official OMI timetable. Defaults: Karachi and Hanafi Asr.';

  @override
  String get calculatedFallbackCoordinatesUnavailable =>
      'Local calculation is unavailable for this provider region because no separately audited coordinates are stored.';

  @override
  String get calculationMethod => 'Calculation method';

  @override
  String get asrHanafi => 'Asr: Hanafi';

  @override
  String get asrStandard => 'Asr: standard';

  @override
  String get manualMinuteAdjustments => 'Manual minute adjustments';

  @override
  String get rawTimesPreserved =>
      'Raw source times are preserved; adjusted values are shown separately.';

  @override
  String minuteAdjustment(int value) {
    return 'Adjustment: $value min';
  }

  @override
  String get decreaseMinute => 'Decrease by one minute';

  @override
  String get increaseMinute => 'Increase by one minute';

  @override
  String get locationCalculationEnabled =>
      'Location saved for local calculation.';

  @override
  String get locationServicesDisabled =>
      'Location services are off. Choose a region manually.';

  @override
  String get locationDeniedChooseRegion =>
      'Location access was not granted. Choose a region manually.';

  @override
  String get locationOutsideUzbekistan =>
      'No verified timezone setting exists for this point. Choose a region manually.';

  @override
  String get locationFailedChooseRegion =>
      'Location could not be obtained. Choose a region manually.';

  @override
  String get prayerScheduleToday => 'Today\'s schedule';

  @override
  String get sunrise => 'Sunrise';

  @override
  String get prayerSource => 'Source';

  @override
  String get prayerUpdated => 'Updated';

  @override
  String get asrSchool => 'Asr school';

  @override
  String get timesManuallyAdjusted =>
      'Times were adjusted manually; raw values are preserved.';

  @override
  String get prayerOfflineCache => 'Using a fresh offline cache.';

  @override
  String get refreshPrayerSchedule => 'Refresh current and next month';

  @override
  String prayerStartsAt(String start) {
    return 'From $start';
  }

  @override
  String prayerTimeRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String nextPrayerAt(String prayer, String time) {
    return 'Next: $prayer at $time';
  }

  @override
  String get betweenPrayers => 'Between prayers';

  @override
  String get prayerScheduleStale =>
      'The schedule is stale — automatic selection is disabled';

  @override
  String get prayerScheduleUnavailable =>
      'Schedule unavailable — choose a prayer manually';

  @override
  String widgetManualPrayerContext(String prayer) {
    return 'Manual: $prayer · Rotation';
  }

  @override
  String widgetAutomaticPrayerContext(String prayer) {
    return '$prayer · Auto · Rotation';
  }

  @override
  String widgetAutomaticPrayerRange(String prayer, String start, String end) {
    return '$prayer · $start–$end · Rotation';
  }

  @override
  String widgetAutomaticPrayerStart(String prayer, String start) {
    return '$prayer · from $start · Rotation';
  }

  @override
  String get widgetSelectPrayerInApp => 'Choose a prayer in Murajaah';

  @override
  String get widgetActionNotCompleted =>
      'Could not mark. Current data restored.';

  @override
  String get learningHow => 'How do you want to learn?';

  @override
  String get learningClassic => 'Classic';

  @override
  String get learningChunked => 'In chunks';

  @override
  String get learningChunkedRecommended =>
      'Chunks are usually easier for a long surah. You can change this choice.';

  @override
  String get learningTargetRange => 'Learning range';

  @override
  String get learningTargetStart => 'First ayah';

  @override
  String get learningTargetEnd => 'Last ayah';

  @override
  String get learningBlockSize => 'Block size';

  @override
  String get learningCustomBlockSize => 'Custom size';

  @override
  String get changeLearningPlan => 'Change plan';

  @override
  String get confirmPlanChangeTitle => 'Start a new cycle?';

  @override
  String get confirmPlanChangeBody =>
      'Current progress will restart with the new plan. Learning history will be preserved.';

  @override
  String learningReviewRange(int start, int end) {
    return 'Review ayahs $start–$end';
  }

  @override
  String learningBridgeRange(int start, int end) {
    return 'Bridge blocks · ayahs $start–$end';
  }

  @override
  String learningSectionReview(int start, int end) {
    return 'Review section · ayahs $start–$end';
  }

  @override
  String learningFinalReview(int start, int end) {
    return 'Final review · ayahs $start–$end';
  }

  @override
  String get rangeCompletedTitle => 'Range completed';

  @override
  String get rangeCompletedBody =>
      'The learned range was saved. The whole surah was not marked as mastered.';

  @override
  String get completeWithoutRotation => 'Complete without rotation';

  @override
  String get addToRotationQuestion => 'Add to rotation?';

  @override
  String get returnToLearning => 'Remove from mastered';

  @override
  String get returnToLearningTitle => 'Return this surah to learning?';

  @override
  String get returnToLearningBody =>
      'The surah will leave rotation. History, statistics, segmentation, and previous scores will remain.';

  @override
  String historyAddedAt(String dateTime) {
    return 'Added $dateTime';
  }

  @override
  String get historyDetailsTitle => 'Recitation details';

  @override
  String get historyOpenDetails => 'Open recitation details';

  @override
  String get historyOccurrenceLabel => 'Recited during';

  @override
  String get historyCoverageLabel => 'Recited passage';

  @override
  String get historyRakaatSpanExplanation =>
      'This is only the number of rakaats spanned by the recitation. Individual ayahs are not mapped to specific rakaats.';

  @override
  String get registrationWhenTitle => 'When and during which prayer';

  @override
  String get registrationNow => 'Now';

  @override
  String get registrationPreviousPrayer => 'Previous prayer';

  @override
  String get registrationYesterday => 'Yesterday';

  @override
  String get registrationChooseDatePrayer => 'Choose date and prayer';

  @override
  String registrationOccurrenceDate(String date) {
    return 'Recitation date: $date';
  }

  @override
  String get prayerRoutines => 'Prayer routines';

  @override
  String get prayerRoutineDescription =>
      'Set the ordered prayer parts, rakaat count, and required surah slots.';

  @override
  String get routineEnabled => 'Use this routine';

  @override
  String get routineEmpty => 'No parts yet. Add the parts you want to track.';

  @override
  String routinePartSummary(int rakaatCount, int slotCount) {
    return '$rakaatCount rakaats · $slotCount surah slots';
  }

  @override
  String get addPrayerPart => 'Add prayer part';

  @override
  String get editPrayerPart => 'Edit prayer part';

  @override
  String get deletePrayerPartTitle => 'Delete prayer part?';

  @override
  String deletePrayerPartBody(String label) {
    return 'Delete “$label”? Existing prayer sessions will not change.';
  }

  @override
  String get partKind => 'Part type';

  @override
  String get customPartLabel => 'Custom label';

  @override
  String get customPartLabelRequired => 'Enter a label.';

  @override
  String get rakaatCountLabel => 'Rakaat count';

  @override
  String get positiveNumberRequired => 'Enter a positive number.';

  @override
  String get surahSlotsLabel => 'Required surah slots';

  @override
  String get nonNegativeNumberRequired => 'Enter zero or a positive number.';

  @override
  String get allowsFollowingImam => 'Can be completed by following the imam';

  @override
  String get partKindFard => 'Fard';

  @override
  String get partKindSunnah => 'Sunnah';

  @override
  String get partKindWitr => 'Witr';

  @override
  String get partKindNafl => 'Nafl';

  @override
  String get partKindCustom => 'Custom';

  @override
  String prayerRoutineCurrentPart(String prayer, String part) {
    return '$prayer · $part';
  }

  @override
  String prayerRoutineSlotProgress(int done, int total) {
    return 'Surah slots: $done/$total';
  }

  @override
  String get prayerRoutineComplete => 'Prayer routine complete';

  @override
  String get prayerRoutineNoAvailableSlot =>
      'The current prayer part has no available surah slot.';

  @override
  String get followedImamAction => 'Followed the imam';

  @override
  String get followedImamConfirmTitle => 'Complete with the imam?';

  @override
  String get followedImamConfirmBody =>
      'This part will be completed without a recitation event or rotation credit.';

  @override
  String get followedImamCompleted => 'Completed by following the imam';
}
