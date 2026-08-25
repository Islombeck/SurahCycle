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
  String get chooseTranslation => 'Choose a translation in Settings';

  @override
  String get noRussianTranslations =>
      'QuranEnc currently returns no Russian translations in its official API catalog. Arabic remains available offline.';

  @override
  String get translationCatalogError =>
      'The official QuranEnc translation list could not be loaded.';

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
}
