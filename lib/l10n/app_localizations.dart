import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
    Locale('uz'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'Murajaah'**
  String get appName;

  /// No description provided for @homeTab.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get homeTab;

  /// No description provided for @surahsTab.
  ///
  /// In ru, this message translates to:
  /// **'Суры'**
  String get surahsTab;

  /// No description provided for @learningTab.
  ///
  /// In ru, this message translates to:
  /// **'Обучение'**
  String get learningTab;

  /// No description provided for @statisticsTab.
  ///
  /// In ru, this message translates to:
  /// **'Статистика'**
  String get statisticsTab;

  /// No description provided for @settingsTab.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTab;

  /// No description provided for @historyTitle.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get historyTitle;

  /// No description provided for @recommendedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуется'**
  String get recommendedTitle;

  /// No description provided for @activeSurahsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Активные суры'**
  String get activeSurahsTitle;

  /// No description provided for @noActiveSurahs.
  ///
  /// In ru, this message translates to:
  /// **'Выберите выученные суры и включите их в ротацию.'**
  String get noActiveSurahs;

  /// No description provided for @contentUnavailableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Данные Корана ещё не загружены'**
  String get contentUnavailableTitle;

  /// No description provided for @contentUnavailableBody.
  ///
  /// In ru, this message translates to:
  /// **'Проверенный каталог сур доступен офлайн. Текст аятов и переводы ещё не загружены; ротация и этапы обучения продолжают работать.'**
  String get contentUnavailableBody;

  /// No description provided for @refreshContent.
  ///
  /// In ru, this message translates to:
  /// **'Проверить источник'**
  String get refreshContent;

  /// No description provided for @sourceUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Проверенный источник пока не подключён'**
  String get sourceUnavailable;

  /// No description provided for @prayerContextTitle.
  ///
  /// In ru, this message translates to:
  /// **'Контекст намаза'**
  String get prayerContextTitle;

  /// No description provided for @fajr.
  ///
  /// In ru, this message translates to:
  /// **'Фаджр'**
  String get fajr;

  /// No description provided for @dhuhr.
  ///
  /// In ru, this message translates to:
  /// **'Зухр'**
  String get dhuhr;

  /// No description provided for @asr.
  ///
  /// In ru, this message translates to:
  /// **'Аср'**
  String get asr;

  /// No description provided for @maghrib.
  ///
  /// In ru, this message translates to:
  /// **'Магриб'**
  String get maghrib;

  /// No description provided for @isha.
  ///
  /// In ru, this message translates to:
  /// **'Иша'**
  String get isha;

  /// No description provided for @witr.
  ///
  /// In ru, this message translates to:
  /// **'Витр'**
  String get witr;

  /// No description provided for @nafl.
  ///
  /// In ru, this message translates to:
  /// **'Нафль'**
  String get nafl;

  /// No description provided for @qada.
  ///
  /// In ru, this message translates to:
  /// **'Каза'**
  String get qada;

  /// No description provided for @selectPrayer.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать намаз'**
  String get selectPrayer;

  /// No description provided for @surahMarked.
  ///
  /// In ru, this message translates to:
  /// **'Сура отмечена'**
  String get surahMarked;

  /// No description provided for @undo.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get undo;

  /// No description provided for @doneForCycle.
  ///
  /// In ru, this message translates to:
  /// **'Выполнено'**
  String get doneForCycle;

  /// No description provided for @recitationsRemaining.
  ///
  /// In ru, this message translates to:
  /// **'{count}×'**
  String recitationsRemaining(int count);

  /// No description provided for @ayahCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} аятов'**
  String ayahCount(int count);

  /// No description provided for @surahNumber.
  ///
  /// In ru, this message translates to:
  /// **'Сура {number}'**
  String surahNumber(int number);

  /// No description provided for @searchSurahs.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по номеру или названию'**
  String get searchSurahs;

  /// No description provided for @noSearchResults.
  ///
  /// In ru, this message translates to:
  /// **'По этому запросу ничего не найдено.'**
  String get noSearchResults;

  /// No description provided for @masteredOnly.
  ///
  /// In ru, this message translates to:
  /// **'Выученные'**
  String get masteredOnly;

  /// No description provided for @activeRotation.
  ///
  /// In ru, this message translates to:
  /// **'В ротации'**
  String get activeRotation;

  /// No description provided for @inactiveRotation.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлена'**
  String get inactiveRotation;

  /// No description provided for @addToMastered.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в выученные'**
  String get addToMastered;

  /// No description provided for @removeFromRotation.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get removeFromRotation;

  /// No description provided for @returnToRotation.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть в ротацию'**
  String get returnToRotation;

  /// No description provided for @editAlias.
  ///
  /// In ru, this message translates to:
  /// **'Изменить название'**
  String get editAlias;

  /// No description provided for @aliasHint.
  ///
  /// In ru, this message translates to:
  /// **'Ваше название суры'**
  String get aliasHint;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @deleteHistoryConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить эту запись? Баланс будет пересчитан по сохранённым событиям.'**
  String get deleteHistoryConfirm;

  /// No description provided for @emptyHistory.
  ///
  /// In ru, this message translates to:
  /// **'Прочтений пока нет.'**
  String get emptyHistory;

  /// No description provided for @normalRecitation.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get normalRecitation;

  /// No description provided for @qadaRecitation.
  ///
  /// In ru, this message translates to:
  /// **'Каза'**
  String get qadaRecitation;

  /// No description provided for @totalRecitations.
  ///
  /// In ru, this message translates to:
  /// **'Всего прочтений'**
  String get totalRecitations;

  /// No description provided for @lastUsed.
  ///
  /// In ru, this message translates to:
  /// **'Последнее прочтение'**
  String get lastUsed;

  /// No description provided for @never.
  ///
  /// In ru, this message translates to:
  /// **'Ещё не читалась'**
  String get never;

  /// No description provided for @prayerBreakdown.
  ///
  /// In ru, this message translates to:
  /// **'По намазам'**
  String get prayerBreakdown;

  /// No description provided for @noStatistics.
  ///
  /// In ru, this message translates to:
  /// **'Статистика появится после первого прочтения.'**
  String get noStatistics;

  /// No description provided for @currentLearning.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас изучается'**
  String get currentLearning;

  /// No description provided for @showOnHome.
  ///
  /// In ru, this message translates to:
  /// **'Показывать на главной'**
  String get showOnHome;

  /// No description provided for @startLearning.
  ///
  /// In ru, this message translates to:
  /// **'Начать изучение'**
  String get startLearning;

  /// No description provided for @repeated.
  ///
  /// In ru, this message translates to:
  /// **'Повторил'**
  String get repeated;

  /// No description provided for @learned.
  ///
  /// In ru, this message translates to:
  /// **'Выучил'**
  String get learned;

  /// No description provided for @newAyah.
  ///
  /// In ru, this message translates to:
  /// **'Новый аят {number}'**
  String newAyah(int number);

  /// No description provided for @cumulativeRange.
  ///
  /// In ru, this message translates to:
  /// **'Повторение аятов 1–{end}'**
  String cumulativeRange(int end);

  /// No description provided for @learningRolledBack.
  ///
  /// In ru, this message translates to:
  /// **'После 72 часов без повторения этап откачен на один шаг.'**
  String get learningRolledBack;

  /// No description provided for @learningCompletedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сура выучена'**
  String get learningCompletedTitle;

  /// No description provided for @learningCompletedBody.
  ///
  /// In ru, this message translates to:
  /// **'Добавить её в активную ротацию?'**
  String get learningCompletedBody;

  /// No description provided for @completeAndAdd.
  ///
  /// In ru, this message translates to:
  /// **'Завершить и добавить'**
  String get completeAndAdd;

  /// No description provided for @darkMode.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get darkMode;

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @advancedSettings.
  ///
  /// In ru, this message translates to:
  /// **'Расширенные настройки'**
  String get advancedSettings;

  /// No description provided for @balanceAdjustment.
  ///
  /// In ru, this message translates to:
  /// **'Коррекция баланса'**
  String get balanceAdjustment;

  /// No description provided for @balanceAdjustmentBody.
  ///
  /// In ru, this message translates to:
  /// **'Используйте только для переноса текущего баланса. История прочтений не изменится.'**
  String get balanceAdjustmentBody;

  /// No description provided for @shiftPlusOne.
  ///
  /// In ru, this message translates to:
  /// **'Сдвинуть баланс +1'**
  String get shiftPlusOne;

  /// No description provided for @shiftMinusOne.
  ///
  /// In ru, this message translates to:
  /// **'Сдвинуть баланс −1'**
  String get shiftMinusOne;

  /// No description provided for @balanceConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Изменить только баланс этой суры? Историческая статистика останется прежней.'**
  String get balanceConfirm;

  /// No description provided for @exportData.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт данных'**
  String get exportData;

  /// No description provided for @exportPrepared.
  ///
  /// In ru, this message translates to:
  /// **'Точка экспорта подготовлена; файл будет добавлен в следующем спринте.'**
  String get exportPrepared;

  /// No description provided for @sourceMetadata.
  ///
  /// In ru, this message translates to:
  /// **'Источник данных'**
  String get sourceMetadata;

  /// No description provided for @offlineReady.
  ///
  /// In ru, this message translates to:
  /// **'Работает офлайн'**
  String get offlineReady;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие'**
  String get errorGeneric;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get loading;

  /// No description provided for @noLearningSurahs.
  ///
  /// In ru, this message translates to:
  /// **'Изучаемых сур пока нет.'**
  String get noLearningSurahs;

  /// No description provided for @openHistory.
  ///
  /// In ru, this message translates to:
  /// **'Открыть историю'**
  String get openHistory;

  /// No description provided for @aheadBy.
  ///
  /// In ru, this message translates to:
  /// **'Опережение: {count}'**
  String aheadBy(int count);

  /// No description provided for @statisticsFilter.
  ///
  /// In ru, this message translates to:
  /// **'Фильтр по намазу'**
  String get statisticsFilter;

  /// No description provided for @allPrayers.
  ///
  /// In ru, this message translates to:
  /// **'Все намазы'**
  String get allPrayers;

  /// No description provided for @isQadaLabel.
  ///
  /// In ru, this message translates to:
  /// **'Восполняемый намаз'**
  String get isQadaLabel;

  /// No description provided for @reorderHint.
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте и перетаскивайте, чтобы изменить порядок'**
  String get reorderHint;

  /// No description provided for @selectSurah.
  ///
  /// In ru, this message translates to:
  /// **'Выберите суру'**
  String get selectSurah;

  /// No description provided for @contentIntegrityNotice.
  ///
  /// In ru, this message translates to:
  /// **'Текст и метаданные показываются без изменений только после загрузки из проверенного источника.'**
  String get contentIntegrityNotice;

  /// No description provided for @editSegmentation.
  ///
  /// In ru, this message translates to:
  /// **'Части для повторения'**
  String get editSegmentation;

  /// No description provided for @wholeSurah.
  ///
  /// In ru, this message translates to:
  /// **'Вся сура'**
  String get wholeSurah;

  /// No description provided for @partLabel.
  ///
  /// In ru, this message translates to:
  /// **'Часть {number}'**
  String partLabel(Object number);

  /// No description provided for @ayahRange.
  ///
  /// In ru, this message translates to:
  /// **'Аяты {start}–{end}'**
  String ayahRange(int start, int end);

  /// No description provided for @rakaatSpan.
  ///
  /// In ru, this message translates to:
  /// **'Ракаатов: {count}'**
  String rakaatSpan(Object count);

  /// No description provided for @selectCoverage.
  ///
  /// In ru, this message translates to:
  /// **'Выберите прочитанные части'**
  String get selectCoverage;

  /// No description provided for @splitIntoParts.
  ///
  /// In ru, this message translates to:
  /// **'Разделить на {count} части'**
  String splitIntoParts(Object count);

  /// No description provided for @automaticBoundaries.
  ///
  /// In ru, this message translates to:
  /// **'Автоматические границы'**
  String get automaticBoundaries;

  /// No description provided for @manualBoundaries.
  ///
  /// In ru, this message translates to:
  /// **'Изменить границы'**
  String get manualBoundaries;

  /// No description provided for @schemeVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String schemeVersion(Object version);

  /// No description provided for @recitationActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия прочтения'**
  String get recitationActions;

  /// No description provided for @fullEquivalentRecitations.
  ///
  /// In ru, this message translates to:
  /// **'Эквивалент полных сур'**
  String get fullEquivalentRecitations;

  /// No description provided for @dueSurahsCount.
  ///
  /// In ru, this message translates to:
  /// **'К повторению: {count}'**
  String dueSurahsCount(Object count);

  /// No description provided for @widgetPart.
  ///
  /// In ru, this message translates to:
  /// **'Часть'**
  String get widgetPart;

  /// No description provided for @widgetAyah.
  ///
  /// In ru, this message translates to:
  /// **'Аят'**
  String get widgetAyah;

  /// No description provided for @widgetAyahs.
  ///
  /// In ru, this message translates to:
  /// **'Аяты'**
  String get widgetAyahs;

  /// No description provided for @widgetOpenAppToLoadText.
  ///
  /// In ru, this message translates to:
  /// **'Откройте Murajaah, чтобы загрузить проверенный текст'**
  String get widgetOpenAppToLoadText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
