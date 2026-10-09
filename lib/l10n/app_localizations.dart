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
  /// **'SurahCycle'**
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

  /// No description provided for @recommendationRank.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендация {rank}'**
  String recommendationRank(int rank);

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

  /// No description provided for @jumuah.
  ///
  /// In ru, this message translates to:
  /// **'Жума'**
  String get jumuah;

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

  /// No description provided for @recitedInThisPrayer.
  ///
  /// In ru, this message translates to:
  /// **'Прочитано в этом намазе'**
  String get recitedInThisPrayer;

  /// No description provided for @notificationsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notificationsTitle;

  /// No description provided for @learningNotificationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тихое напоминание о заучивании'**
  String get learningNotificationTitle;

  /// No description provided for @learningNotificationSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Беззвучное уведомление о том, что повторить дальше. По умолчанию выключено.'**
  String get learningNotificationSubtitle;

  /// No description provided for @learningNotificationPermissionDenied.
  ///
  /// In ru, this message translates to:
  /// **'Разрешение на уведомления не выдано, напоминание остаётся выключенным.'**
  String get learningNotificationPermissionDenied;

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

  /// No description provided for @registrationContextChanged.
  ///
  /// In ru, this message translates to:
  /// **'Дата или намаз изменились. Отметка не сохранена. Повторите действие для выбранного намаза.'**
  String get registrationContextChanged;

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
  /// **'Откройте SurahCycle, чтобы загрузить проверенный текст'**
  String get widgetOpenAppToLoadText;

  /// No description provided for @customParts.
  ///
  /// In ru, this message translates to:
  /// **'Свой'**
  String get customParts;

  /// No description provided for @customPartCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество частей'**
  String get customPartCount;

  /// No description provided for @customPartCountRange.
  ///
  /// In ru, this message translates to:
  /// **'От 1 до {max}'**
  String customPartCountRange(int max);

  /// No description provided for @customPartCountInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите допустимое количество частей'**
  String get customPartCountInvalid;

  /// No description provided for @fatihaRotationExcluded.
  ///
  /// In ru, this message translates to:
  /// **'Аль-Фатиха сохраняется в выученных, но не участвует в обычной ротации.'**
  String get fatihaRotationExcluded;

  /// No description provided for @completeLearningOnly.
  ///
  /// In ru, this message translates to:
  /// **'Завершить обучение'**
  String get completeLearningOnly;

  /// No description provided for @arabicTextOfflineReady.
  ///
  /// In ru, this message translates to:
  /// **'Проверенный арабский текст Tanzil доступен офлайн.'**
  String get arabicTextOfflineReady;

  /// No description provided for @quranTranslation.
  ///
  /// In ru, this message translates to:
  /// **'Перевод Корана'**
  String get quranTranslation;

  /// No description provided for @translationLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык перевода'**
  String get translationLanguage;

  /// No description provided for @translationLanguageRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get translationLanguageRussian;

  /// No description provided for @translationLanguageUzbek.
  ///
  /// In ru, this message translates to:
  /// **'Узбекский'**
  String get translationLanguageUzbek;

  /// No description provided for @chooseTranslation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите перевод в настройках'**
  String get chooseTranslation;

  /// No description provided for @noTranslationsForLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Для выбранного языка сейчас нет доступных проверенных переводов QuranEnc. Арабский текст остаётся доступен офлайн.'**
  String get noTranslationsForLanguage;

  /// No description provided for @additionalUzbekTranslationsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Al-Mukhtasar (uzbek_mokhtasar) и Al-Muyassar (uzbek_moyassar): ключи официального каталога подтверждены, но API-корпусы пока недоступны.'**
  String get additionalUzbekTranslationsUnavailable;

  /// No description provided for @translationCatalogError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить официальный список переводов QuranEnc.'**
  String get translationCatalogError;

  /// No description provided for @translationNoNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети. Уже скачанные переводы остаются доступны офлайн.'**
  String get translationNoNetwork;

  /// No description provided for @translationSourceError.
  ///
  /// In ru, this message translates to:
  /// **'Источник перевода отклонил запрос. Попробуйте позже.'**
  String get translationSourceError;

  /// No description provided for @translationValidationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ответ источника повреждён или не прошёл проверку. Он не сохранён.'**
  String get translationValidationFailed;

  /// No description provided for @translationCatalogFromCache.
  ///
  /// In ru, this message translates to:
  /// **'Показан сохранённый офлайн-каталог.'**
  String get translationCatalogFromCache;

  /// No description provided for @translationRefreshFailedCached.
  ///
  /// In ru, this message translates to:
  /// **'Обновить источник не удалось; сохранённые проверенные данные оставлены без изменений.'**
  String get translationRefreshFailedCached;

  /// No description provided for @translationNotSelected.
  ///
  /// In ru, this message translates to:
  /// **'Перевод не выбран'**
  String get translationNotSelected;

  /// No description provided for @translationCachedOffline.
  ///
  /// In ru, this message translates to:
  /// **'Выбранный перевод сохраняется для офлайн-чтения по мере открытия сур.'**
  String get translationCachedOffline;

  /// No description provided for @translationUnavailableOffline.
  ///
  /// In ru, this message translates to:
  /// **'Для этого аята перевод ещё не сохранён. Арабский текст доступен, пока перевод загружается в фоне.'**
  String get translationUnavailableOffline;

  /// No description provided for @clearTranslation.
  ///
  /// In ru, this message translates to:
  /// **'Очистить выбор перевода'**
  String get clearTranslation;

  /// No description provided for @translationSelectionInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённый выбор перевода повреждён или больше не поддерживается. Арабский текст остаётся доступен.'**
  String get translationSelectionInvalid;

  /// No description provided for @translationVersionChanged.
  ///
  /// In ru, this message translates to:
  /// **'Версия выбранного перевода изменилась. Подтвердите новую версию в настройках; арабский текст остаётся доступен.'**
  String get translationVersionChanged;

  /// No description provided for @translationUpdateAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступна новая версия выбранного перевода: v{version}. Обновление выполняется только по вашему выбору.'**
  String translationUpdateAvailable(String version);

  /// No description provided for @useTranslationVersion.
  ///
  /// In ru, this message translates to:
  /// **'Использовать v{version}'**
  String useTranslationVersion(String version);

  /// No description provided for @tanzilTextMetadata.
  ///
  /// In ru, this message translates to:
  /// **'Tanzil Project · Uthmani Quran Text v1.1 · CC BY 3.0'**
  String get tanzilTextMetadata;

  /// No description provided for @tanzilTransliterationMetadata.
  ///
  /// In ru, this message translates to:
  /// **'Tanzil · English Transliteration · снимок 2010-09-06 · 6236 аятов'**
  String get tanzilTransliterationMetadata;

  /// No description provided for @transliterationNonCommercialNotice.
  ///
  /// In ru, this message translates to:
  /// **'Условия набора транскрипции разрешают только некоммерческое использование; коммерческий production-релиз требует отдельного разрешения.'**
  String get transliterationNonCommercialNotice;

  /// No description provided for @quranDisplayLayers.
  ///
  /// In ru, this message translates to:
  /// **'Слои текста Корана'**
  String get quranDisplayLayers;

  /// No description provided for @showArabicText.
  ///
  /// In ru, this message translates to:
  /// **'Показывать арабский текст'**
  String get showArabicText;

  /// No description provided for @showTransliteration.
  ///
  /// In ru, this message translates to:
  /// **'Показывать транскрипцию'**
  String get showTransliteration;

  /// No description provided for @transliterationProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль транслитерации'**
  String get transliterationProfile;

  /// No description provided for @transliterationProfileLatinTanzil.
  ///
  /// In ru, this message translates to:
  /// **'Латиница — Tanzil'**
  String get transliterationProfileLatinTanzil;

  /// No description provided for @transliterationProfileCyrillic.
  ///
  /// In ru, this message translates to:
  /// **'Кириллица'**
  String get transliterationProfileCyrillic;

  /// No description provided for @transliterationProfileCyrillicUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Кириллица — проверенный источник пока не подключён'**
  String get transliterationProfileCyrillicUnavailable;

  /// No description provided for @showTranslation.
  ///
  /// In ru, this message translates to:
  /// **'Показывать перевод'**
  String get showTranslation;

  /// No description provided for @transliterationSourceShort.
  ///
  /// In ru, this message translates to:
  /// **'Транскрипция (латинская транслитерация) · Tanzil · офлайн'**
  String get transliterationSourceShort;

  /// No description provided for @transliterationUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Проверенная транскрипция недоступна.'**
  String get transliterationUnavailable;

  /// No description provided for @prayerTimesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Время намаза'**
  String get prayerTimesTitle;

  /// No description provided for @prayerRegion.
  ///
  /// In ru, this message translates to:
  /// **'Регион'**
  String get prayerRegion;

  /// No description provided for @selectPrayerRegion.
  ///
  /// In ru, this message translates to:
  /// **'Выберите регион вручную'**
  String get selectPrayerRegion;

  /// No description provided for @useMyLocation.
  ///
  /// In ru, this message translates to:
  /// **'Использовать моё местоположение'**
  String get useMyLocation;

  /// No description provided for @locationOptionalNotice.
  ///
  /// In ru, this message translates to:
  /// **'Необязательно. Геопозиция запрашивается только после нажатия, без фонового доступа.'**
  String get locationOptionalNotice;

  /// No description provided for @prayerContextMode.
  ///
  /// In ru, this message translates to:
  /// **'Контекст отметки'**
  String get prayerContextMode;

  /// No description provided for @prayerModeManual.
  ///
  /// In ru, this message translates to:
  /// **'Ручной режим'**
  String get prayerModeManual;

  /// No description provided for @prayerModeAutomatic.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически'**
  String get prayerModeAutomatic;

  /// No description provided for @useJumuahForNextRecitation.
  ///
  /// In ru, this message translates to:
  /// **'Отметить следующее чтение как Жума'**
  String get useJumuahForNextRecitation;

  /// No description provided for @automaticPrayerSafetyNotice.
  ///
  /// In ru, this message translates to:
  /// **'Автовыбор работает только по свежему надёжному расписанию. После восхода до Зухра отметка потребует ручного выбора.'**
  String get automaticPrayerSafetyNotice;

  /// No description provided for @allowCalculatedFallback.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить локальный расчёт'**
  String get allowCalculatedFallback;

  /// No description provided for @calculatedFallbackNotice.
  ///
  /// In ru, this message translates to:
  /// **'Это отдельный расчётный источник, а не официальное расписание ОМИ. По умолчанию: Karachi, Аср Hanafi.'**
  String get calculatedFallbackNotice;

  /// No description provided for @calculatedFallbackCoordinatesUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Для этого региона поставщика нет отдельно проверенных координат, поэтому локальный расчёт недоступен.'**
  String get calculatedFallbackCoordinatesUnavailable;

  /// No description provided for @calculationMethod.
  ///
  /// In ru, this message translates to:
  /// **'Расчётный метод'**
  String get calculationMethod;

  /// No description provided for @asrHanafi.
  ///
  /// In ru, this message translates to:
  /// **'Аср: Hanafi'**
  String get asrHanafi;

  /// No description provided for @asrStandard.
  ///
  /// In ru, this message translates to:
  /// **'Аср: стандартный'**
  String get asrStandard;

  /// No description provided for @manualMinuteAdjustments.
  ///
  /// In ru, this message translates to:
  /// **'Ручные поправки в минутах'**
  String get manualMinuteAdjustments;

  /// No description provided for @rawTimesPreserved.
  ///
  /// In ru, this message translates to:
  /// **'Исходное время источника сохраняется; показывается отдельное скорректированное значение.'**
  String get rawTimesPreserved;

  /// No description provided for @minuteAdjustment.
  ///
  /// In ru, this message translates to:
  /// **'Поправка: {value} мин'**
  String minuteAdjustment(int value);

  /// No description provided for @decreaseMinute.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить на минуту'**
  String get decreaseMinute;

  /// No description provided for @increaseMinute.
  ///
  /// In ru, this message translates to:
  /// **'Увеличить на минуту'**
  String get increaseMinute;

  /// No description provided for @locationCalculationEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Местоположение сохранено для локального расчёта.'**
  String get locationCalculationEnabled;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Геолокация выключена. Выберите регион вручную.'**
  String get locationServicesDisabled;

  /// No description provided for @locationDeniedChooseRegion.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к геопозиции не предоставлен. Выберите регион вручную.'**
  String get locationDeniedChooseRegion;

  /// No description provided for @locationOutsideUzbekistan.
  ///
  /// In ru, this message translates to:
  /// **'Для этой точки нет проверенной настройки часового пояса. Выберите регион вручную.'**
  String get locationOutsideUzbekistan;

  /// No description provided for @locationFailedChooseRegion.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить геопозицию. Выберите регион вручную.'**
  String get locationFailedChooseRegion;

  /// No description provided for @prayerScheduleToday.
  ///
  /// In ru, this message translates to:
  /// **'Расписание на сегодня'**
  String get prayerScheduleToday;

  /// No description provided for @sunrise.
  ///
  /// In ru, this message translates to:
  /// **'Восход'**
  String get sunrise;

  /// No description provided for @prayerSource.
  ///
  /// In ru, this message translates to:
  /// **'Источник'**
  String get prayerSource;

  /// No description provided for @prayerUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено'**
  String get prayerUpdated;

  /// No description provided for @asrSchool.
  ///
  /// In ru, this message translates to:
  /// **'Расчёт Асра'**
  String get asrSchool;

  /// No description provided for @timesManuallyAdjusted.
  ///
  /// In ru, this message translates to:
  /// **'Время скорректировано вручную; исходные значения сохранены.'**
  String get timesManuallyAdjusted;

  /// No description provided for @prayerOfflineCache.
  ///
  /// In ru, this message translates to:
  /// **'Используется свежий офлайн-кеш.'**
  String get prayerOfflineCache;

  /// No description provided for @refreshPrayerSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Обновить текущий и следующий месяц'**
  String get refreshPrayerSchedule;

  /// No description provided for @prayerStartsAt.
  ///
  /// In ru, this message translates to:
  /// **'С {start}'**
  String prayerStartsAt(String start);

  /// No description provided for @prayerTimeRange.
  ///
  /// In ru, this message translates to:
  /// **'{start}–{end}'**
  String prayerTimeRange(String start, String end);

  /// No description provided for @nextPrayerAt.
  ///
  /// In ru, this message translates to:
  /// **'Далее: {prayer} в {time}'**
  String nextPrayerAt(String prayer, String time);

  /// No description provided for @betweenPrayers.
  ///
  /// In ru, this message translates to:
  /// **'Между намазами'**
  String get betweenPrayers;

  /// No description provided for @prayerScheduleStale.
  ///
  /// In ru, this message translates to:
  /// **'Расписание устарело — автовыбор отключён'**
  String get prayerScheduleStale;

  /// No description provided for @prayerScheduleUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Расписание недоступно — выберите намаз вручную'**
  String get prayerScheduleUnavailable;

  /// No description provided for @widgetManualPrayerContext.
  ///
  /// In ru, this message translates to:
  /// **'Ручной: {prayer} · Ротация'**
  String widgetManualPrayerContext(String prayer);

  /// No description provided for @widgetAutomaticPrayerContext.
  ///
  /// In ru, this message translates to:
  /// **'{prayer} · Авто · Ротация'**
  String widgetAutomaticPrayerContext(String prayer);

  /// No description provided for @widgetAutomaticPrayerRange.
  ///
  /// In ru, this message translates to:
  /// **'{prayer} · {start}–{end} · Ротация'**
  String widgetAutomaticPrayerRange(String prayer, String start, String end);

  /// No description provided for @widgetAutomaticPrayerStart.
  ///
  /// In ru, this message translates to:
  /// **'{prayer} · с {start} · Ротация'**
  String widgetAutomaticPrayerStart(String prayer, String start);

  /// No description provided for @widgetSelectPrayerInApp.
  ///
  /// In ru, this message translates to:
  /// **'Выберите намаз в SurahCycle'**
  String get widgetSelectPrayerInApp;

  /// No description provided for @widgetActionNotCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отметить. Показаны актуальные данные.'**
  String get widgetActionNotCompleted;

  /// No description provided for @learningHow.
  ///
  /// In ru, this message translates to:
  /// **'Как учить?'**
  String get learningHow;

  /// No description provided for @learningClassic.
  ///
  /// In ru, this message translates to:
  /// **'Классически'**
  String get learningClassic;

  /// No description provided for @learningChunked.
  ///
  /// In ru, this message translates to:
  /// **'По частям'**
  String get learningChunked;

  /// No description provided for @learningChunkedRecommended.
  ///
  /// In ru, this message translates to:
  /// **'Для длинной суры удобнее учить по частям. Выбор можно изменить.'**
  String get learningChunkedRecommended;

  /// No description provided for @learningTargetRange.
  ///
  /// In ru, this message translates to:
  /// **'Диапазон обучения'**
  String get learningTargetRange;

  /// No description provided for @learningTargetStart.
  ///
  /// In ru, this message translates to:
  /// **'Первый аят'**
  String get learningTargetStart;

  /// No description provided for @learningTargetEnd.
  ///
  /// In ru, this message translates to:
  /// **'Последний аят'**
  String get learningTargetEnd;

  /// No description provided for @learningBlockSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер блока'**
  String get learningBlockSize;

  /// No description provided for @learningCustomBlockSize.
  ///
  /// In ru, this message translates to:
  /// **'Свой размер'**
  String get learningCustomBlockSize;

  /// No description provided for @changeLearningPlan.
  ///
  /// In ru, this message translates to:
  /// **'Изменить план'**
  String get changeLearningPlan;

  /// No description provided for @confirmPlanChangeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Начать новый цикл?'**
  String get confirmPlanChangeTitle;

  /// No description provided for @confirmPlanChangeBody.
  ///
  /// In ru, this message translates to:
  /// **'Текущий прогресс будет начат заново по новому плану. История обучения сохранится.'**
  String get confirmPlanChangeBody;

  /// No description provided for @learningReviewRange.
  ///
  /// In ru, this message translates to:
  /// **'Повторение аятов {start}–{end}'**
  String learningReviewRange(int start, int end);

  /// No description provided for @learningBridgeRange.
  ///
  /// In ru, this message translates to:
  /// **'Связка блоков · аяты {start}–{end}'**
  String learningBridgeRange(int start, int end);

  /// No description provided for @learningSectionReview.
  ///
  /// In ru, this message translates to:
  /// **'Повторить раздел · аяты {start}–{end}'**
  String learningSectionReview(int start, int end);

  /// No description provided for @learningFinalReview.
  ///
  /// In ru, this message translates to:
  /// **'Итоговое повторение · аяты {start}–{end}'**
  String learningFinalReview(int start, int end);

  /// No description provided for @rangeCompletedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Диапазон завершён'**
  String get rangeCompletedTitle;

  /// No description provided for @rangeCompletedBody.
  ///
  /// In ru, this message translates to:
  /// **'Изученный диапазон сохранён. Вся сура не отмечена как выученная.'**
  String get rangeCompletedBody;

  /// No description provided for @completeWithoutRotation.
  ///
  /// In ru, this message translates to:
  /// **'Завершить без ротации'**
  String get completeWithoutRotation;

  /// No description provided for @addToRotationQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в ротацию?'**
  String get addToRotationQuestion;

  /// No description provided for @returnToLearning.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из выученных'**
  String get returnToLearning;

  /// No description provided for @returnToLearningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть суру в обучение?'**
  String get returnToLearningTitle;

  /// No description provided for @returnToLearningBody.
  ///
  /// In ru, this message translates to:
  /// **'Сура выйдет из ротации. История, статистика, разбиение и прежние оценки сохранятся.'**
  String get returnToLearningBody;

  /// No description provided for @historyAddedAt.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено {dateTime}'**
  String historyAddedAt(String dateTime);

  /// No description provided for @historyDetailsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Детали прочтения'**
  String get historyDetailsTitle;

  /// No description provided for @historyOpenDetails.
  ///
  /// In ru, this message translates to:
  /// **'Открыть детали прочтения'**
  String get historyOpenDetails;

  /// No description provided for @historyOccurrenceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Когда и в каком намазе прочитано'**
  String get historyOccurrenceLabel;

  /// No description provided for @historyCoverageLabel.
  ///
  /// In ru, this message translates to:
  /// **'Прочитанный отрывок'**
  String get historyCoverageLabel;

  /// No description provided for @historyRakaatSpanExplanation.
  ///
  /// In ru, this message translates to:
  /// **'Это только число ракаатов, которые заняло прочтение. Отдельные аяты не привязаны к конкретным ракаатам.'**
  String get historyRakaatSpanExplanation;

  /// No description provided for @partLabelOptional.
  ///
  /// In ru, this message translates to:
  /// **'Название (необязательно)'**
  String get partLabelOptional;

  /// No description provided for @routineNoQadaPart.
  ///
  /// In ru, this message translates to:
  /// **'В этом намазе нет части вида «{kind}». Каза отмечает только обязательную часть, поэтому для каза здесь нечего будет отметить.'**
  String routineNoQadaPart(String kind);

  /// No description provided for @historyShowDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Показать удалённые'**
  String get historyShowDeleted;

  /// No description provided for @historyHideDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть удалённые'**
  String get historyHideDeleted;

  /// No description provided for @historyDeletedAt.
  ///
  /// In ru, this message translates to:
  /// **'Удалено {dateTime}'**
  String historyDeletedAt(String dateTime);

  /// No description provided for @historyRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get historyRestore;

  /// No description provided for @historyRestored.
  ///
  /// In ru, this message translates to:
  /// **'Запись восстановлена'**
  String get historyRestored;

  /// No description provided for @historyNoDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Удалённых прочтений нет.'**
  String get historyNoDeleted;

  /// No description provided for @registrationWhenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Когда и в каком намазе прочитано'**
  String get registrationWhenTitle;

  /// No description provided for @registrationNow.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас'**
  String get registrationNow;

  /// No description provided for @registrationPreviousPrayer.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий намаз'**
  String get registrationPreviousPrayer;

  /// No description provided for @registrationYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get registrationYesterday;

  /// No description provided for @registrationChooseDatePrayer.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать дату и намаз'**
  String get registrationChooseDatePrayer;

  /// No description provided for @registrationOccurrenceDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата прочтения: {date}'**
  String registrationOccurrenceDate(String date);

  /// No description provided for @prayerRoutines.
  ///
  /// In ru, this message translates to:
  /// **'Порядок частей намаза'**
  String get prayerRoutines;

  /// No description provided for @prayerRoutineDescription.
  ///
  /// In ru, this message translates to:
  /// **'Настройте части намаза по порядку: число ракаатов и обязательных слотов для сур.'**
  String get prayerRoutineDescription;

  /// No description provided for @routineEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Использовать этот порядок'**
  String get routineEnabled;

  /// No description provided for @routineEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Частей пока нет. Добавьте то, что хотите отслеживать.'**
  String get routineEmpty;

  /// No description provided for @routinePartSummary.
  ///
  /// In ru, this message translates to:
  /// **'{rakaatCount} рак. · слотов для сур: {slotCount}'**
  String routinePartSummary(int rakaatCount, int slotCount);

  /// No description provided for @addPrayerPart.
  ///
  /// In ru, this message translates to:
  /// **'Добавить часть намаза'**
  String get addPrayerPart;

  /// No description provided for @editPrayerPart.
  ///
  /// In ru, this message translates to:
  /// **'Изменить часть намаза'**
  String get editPrayerPart;

  /// No description provided for @deletePrayerPartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить часть намаза?'**
  String get deletePrayerPartTitle;

  /// No description provided for @deletePrayerPartBody.
  ///
  /// In ru, this message translates to:
  /// **'Удалить «{label}»? Уже прочитанное не изменится.'**
  String deletePrayerPartBody(String label);

  /// No description provided for @applyToCurrentPrayerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Применить и к текущему намазу?'**
  String get applyToCurrentPrayerTitle;

  /// No description provided for @applyToCurrentPrayerBody.
  ///
  /// In ru, this message translates to:
  /// **'{prayer}, {date} — часть ещё в плане. Чтений в ней нет, поэтому её можно убрать и оттуда.'**
  String applyToCurrentPrayerBody(String prayer, String date);

  /// No description provided for @applyToCurrentPrayerComposition.
  ///
  /// In ru, this message translates to:
  /// **'Останется: {parts}'**
  String applyToCurrentPrayerComposition(String parts);

  /// No description provided for @applyToCurrentPrayerEmpty.
  ///
  /// In ru, this message translates to:
  /// **'План намаза будет собран заново по шаблону.'**
  String get applyToCurrentPrayerEmpty;

  /// No description provided for @applyToCurrentPrayerAction.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из текущего'**
  String get applyToCurrentPrayerAction;

  /// No description provided for @keepCurrentPrayerUnchanged.
  ///
  /// In ru, this message translates to:
  /// **'Оставить как есть'**
  String get keepCurrentPrayerUnchanged;

  /// No description provided for @applyToCurrentPrayerKept.
  ///
  /// In ru, this message translates to:
  /// **'«{label}» осталась: в ней уже есть прочитанное.'**
  String applyToCurrentPrayerKept(String label);

  /// No description provided for @calendarTitle.
  ///
  /// In ru, this message translates to:
  /// **'Календарь'**
  String get calendarTitle;

  /// No description provided for @openCalendar.
  ///
  /// In ru, this message translates to:
  /// **'Открыть календарь'**
  String get openCalendar;

  /// No description provided for @calendarPreviousMonth.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий месяц'**
  String get calendarPreviousMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In ru, this message translates to:
  /// **'Следующий месяц'**
  String get calendarNextMonth;

  /// No description provided for @calendarLegendOrdinary.
  ///
  /// In ru, this message translates to:
  /// **'Обычная отметка'**
  String get calendarLegendOrdinary;

  /// No description provided for @calendarLegendQada.
  ///
  /// In ru, this message translates to:
  /// **'Каза'**
  String get calendarLegendQada;

  /// No description provided for @calendarLegendPartial.
  ///
  /// In ru, this message translates to:
  /// **'Отмечено частично'**
  String get calendarLegendPartial;

  /// No description provided for @calendarNoRecord.
  ///
  /// In ru, this message translates to:
  /// **'Нет отметки'**
  String get calendarNoRecord;

  /// No description provided for @calendarNoRecordExplanation.
  ///
  /// In ru, this message translates to:
  /// **'Это значит, что запись не вносилась, а не что намаз пропущен.'**
  String get calendarNoRecordExplanation;

  /// No description provided for @calendarPartialSuffix.
  ///
  /// In ru, this message translates to:
  /// **'частично'**
  String get calendarPartialSuffix;

  /// No description provided for @calendarQadaExplanation.
  ///
  /// In ru, this message translates to:
  /// **'Каза показан на дне того намаза, который восполнен.'**
  String get calendarQadaExplanation;

  /// No description provided for @calendarQadaFulfilledUnknown.
  ///
  /// In ru, this message translates to:
  /// **'День фактического восполнения не сохранён для прежних записей.'**
  String get calendarQadaFulfilledUnknown;

  /// No description provided for @calendarFutureDay.
  ///
  /// In ru, this message translates to:
  /// **'Будущий день. Отметить чтение заранее нельзя.'**
  String get calendarFutureDay;

  /// No description provided for @qadaOriginUnknown.
  ///
  /// In ru, this message translates to:
  /// **'День пропущенного намаза неизвестен'**
  String get qadaOriginUnknown;

  /// No description provided for @historyQadaMadeUpOn.
  ///
  /// In ru, this message translates to:
  /// **'Восполнено: {date}'**
  String historyQadaMadeUpOn(String date);

  /// No description provided for @qadaOriginUnknownHint.
  ///
  /// In ru, this message translates to:
  /// **'Для очень старых долгов. Запись встанет на день восполнения, и это будет прямо указано.'**
  String get qadaOriginUnknownHint;

  /// No description provided for @calendarQadaOriginUnknownEntry.
  ///
  /// In ru, this message translates to:
  /// **'исходный день неизвестен'**
  String get calendarQadaOriginUnknownEntry;

  /// No description provided for @calendarRegisterForDay.
  ///
  /// In ru, this message translates to:
  /// **'Отметить за этот день'**
  String get calendarRegisterForDay;

  /// No description provided for @pendingRegistrationBanner.
  ///
  /// In ru, this message translates to:
  /// **'Отмечаю за {date}'**
  String pendingRegistrationBanner(String date);

  /// No description provided for @pendingRegistrationCancel.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться к сегодня'**
  String get pendingRegistrationCancel;

  /// No description provided for @pendingRegistrationPickPrayer.
  ///
  /// In ru, this message translates to:
  /// **'Для прошедшего дня намаз выбирается вручную.'**
  String get pendingRegistrationPickPrayer;

  /// No description provided for @qadaFulfilledOn.
  ///
  /// In ru, this message translates to:
  /// **'Восполнено: {date}'**
  String qadaFulfilledOn(String date);

  /// No description provided for @qadaFulfilledHint.
  ///
  /// In ru, this message translates to:
  /// **'День, когда вы фактически прочитали. По умолчанию сегодня; измените, если вносите позже.'**
  String get qadaFulfilledHint;

  /// No description provided for @changeQadaFulfilledDate.
  ///
  /// In ru, this message translates to:
  /// **'Изменить день восполнения'**
  String get changeQadaFulfilledDate;

  /// No description provided for @partKind.
  ///
  /// In ru, this message translates to:
  /// **'Тип части'**
  String get partKind;

  /// No description provided for @customPartLabel.
  ///
  /// In ru, this message translates to:
  /// **'Своё название'**
  String get customPartLabel;

  /// No description provided for @customPartLabelRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название.'**
  String get customPartLabelRequired;

  /// No description provided for @rakaatCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Число ракаатов'**
  String get rakaatCountLabel;

  /// No description provided for @positiveNumberRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите положительное число.'**
  String get positiveNumberRequired;

  /// No description provided for @surahSlotsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Обязательные слоты для сур'**
  String get surahSlotsLabel;

  /// No description provided for @nonNegativeNumberRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите ноль или положительное число.'**
  String get nonNegativeNumberRequired;

  /// No description provided for @allowsFollowingImam.
  ///
  /// In ru, this message translates to:
  /// **'Можно завершить, следуя за имамом'**
  String get allowsFollowingImam;

  /// No description provided for @partKindFard.
  ///
  /// In ru, this message translates to:
  /// **'Фард'**
  String get partKindFard;

  /// No description provided for @partKindSunnah.
  ///
  /// In ru, this message translates to:
  /// **'Сунна'**
  String get partKindSunnah;

  /// No description provided for @partKindWitr.
  ///
  /// In ru, this message translates to:
  /// **'Витр'**
  String get partKindWitr;

  /// No description provided for @partKindNafl.
  ///
  /// In ru, this message translates to:
  /// **'Нафль'**
  String get partKindNafl;

  /// No description provided for @partKindCustom.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get partKindCustom;

  /// No description provided for @prayerRoutineCurrentPart.
  ///
  /// In ru, this message translates to:
  /// **'{prayer} · {part}'**
  String prayerRoutineCurrentPart(String prayer, String part);

  /// No description provided for @prayerRoutineSlotProgress.
  ///
  /// In ru, this message translates to:
  /// **'Слоты для сур: {done}/{total}'**
  String prayerRoutineSlotProgress(int done, int total);

  /// No description provided for @prayerRoutineComplete.
  ///
  /// In ru, this message translates to:
  /// **'Порядок намаза завершён'**
  String get prayerRoutineComplete;

  /// No description provided for @prayerRoutineManualDeadEnd.
  ///
  /// In ru, this message translates to:
  /// **'Намаз выбран вручную, поэтому следующий сам не включится. Пока он не выбран, отметить ниже ничего нельзя.'**
  String get prayerRoutineManualDeadEnd;

  /// No description provided for @prayerRoutineChooseNextPrayer.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать намаз'**
  String get prayerRoutineChooseNextPrayer;

  /// No description provided for @prayerRoutineNoAvailableSlot.
  ///
  /// In ru, this message translates to:
  /// **'В текущей части намаза нет доступного слота для суры.'**
  String get prayerRoutineNoAvailableSlot;

  /// No description provided for @followedImamAction.
  ///
  /// In ru, this message translates to:
  /// **'Следовал за имамом'**
  String get followedImamAction;

  /// No description provided for @followedImamConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Завершить с имамом?'**
  String get followedImamConfirmTitle;

  /// No description provided for @followedImamConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Эта часть будет завершена без события прочтения и без зачёта в ротации.'**
  String get followedImamConfirmBody;

  /// No description provided for @followedImamCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершено вслед за имамом'**
  String get followedImamCompleted;

  /// No description provided for @returnToAutomaticPrayer.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться к авто'**
  String get returnToAutomaticPrayer;

  /// No description provided for @routineEditFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить изменение порядка намаза'**
  String get routineEditFailed;

  /// No description provided for @routineEditConflict.
  ///
  /// In ru, this message translates to:
  /// **'Порядок намаза изменился. Показано актуальное состояние — повторите действие.'**
  String get routineEditConflict;

  /// No description provided for @recallModeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка по памяти'**
  String get recallModeTitle;

  /// No description provided for @recallStartAction.
  ///
  /// In ru, this message translates to:
  /// **'Проверить по памяти'**
  String get recallStartAction;

  /// No description provided for @recallRangeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Какие аяты?'**
  String get recallRangeTitle;

  /// No description provided for @recallRangeFrom.
  ///
  /// In ru, this message translates to:
  /// **'С аята'**
  String get recallRangeFrom;

  /// No description provided for @recallRangeTo.
  ///
  /// In ru, this message translates to:
  /// **'По аят'**
  String get recallRangeTo;

  /// No description provided for @recallRangeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Последний аят не может быть раньше первого.'**
  String get recallRangeInvalid;

  /// No description provided for @recallBegin.
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get recallBegin;

  /// No description provided for @recallHiddenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аят {number}'**
  String recallHiddenTitle(int number);

  /// No description provided for @recallHiddenHint.
  ///
  /// In ru, this message translates to:
  /// **'Прочитайте его по памяти, затем откройте текст.'**
  String get recallHiddenHint;

  /// No description provided for @recallReveal.
  ///
  /// In ru, this message translates to:
  /// **'Показать аят'**
  String get recallReveal;

  /// No description provided for @recallResultRecalled.
  ///
  /// In ru, this message translates to:
  /// **'Вспомнил'**
  String get recallResultRecalled;

  /// No description provided for @recallResultWithMistake.
  ///
  /// In ru, this message translates to:
  /// **'С ошибкой'**
  String get recallResultWithMistake;

  /// No description provided for @recallResultNotRecalled.
  ///
  /// In ru, this message translates to:
  /// **'Не вспомнил'**
  String get recallResultNotRecalled;

  /// No description provided for @recallSkip.
  ///
  /// In ru, this message translates to:
  /// **'Дальше'**
  String get recallSkip;

  /// No description provided for @recallProgress.
  ///
  /// In ru, this message translates to:
  /// **'{done} из {total}'**
  String recallProgress(int done, int total);

  /// No description provided for @recallFinishedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка завершена'**
  String get recallFinishedTitle;

  /// No description provided for @recallFinishedBody.
  ///
  /// In ru, this message translates to:
  /// **'Вспомнил: {recalled} · С ошибкой: {withMistake} · Не вспомнил: {notRecalled}'**
  String recallFinishedBody(int recalled, int withMistake, int notRecalled);

  /// No description provided for @recallSelfAssessment.
  ///
  /// In ru, this message translates to:
  /// **'Оценку ставите вы сами — приложение не слушает и не проверяет чтение.'**
  String get recallSelfAssessment;

  /// No description provided for @recallPriorityNote.
  ///
  /// In ru, this message translates to:
  /// **'Аяты, отмеченные как ошибка, поднимаются в предложениях для повторения. Больше ничего не меняется.'**
  String get recallPriorityNote;

  /// No description provided for @recallSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить результат'**
  String get recallSaveFailed;

  /// No description provided for @recallClose.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get recallClose;

  /// No description provided for @recallHistoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверки по памяти'**
  String get recallHistoryTitle;

  /// No description provided for @recallNoHistory.
  ///
  /// In ru, this message translates to:
  /// **'Проверок пока нет.'**
  String get recallNoHistory;

  /// No description provided for @recallSurahSummary.
  ///
  /// In ru, this message translates to:
  /// **'{recalled} вспомнил · {imperfect} повторить'**
  String recallSurahSummary(int recalled, int imperfect);

  /// No description provided for @accountTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get accountTitle;

  /// No description provided for @accountCardSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход не включает синхронизацию'**
  String get accountCardSubtitle;

  /// No description provided for @accountOpenAction.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get accountOpenAction;

  /// No description provided for @accountSignedOutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход не выполнен'**
  String get accountSignedOutTitle;

  /// No description provided for @accountSignedOutBody.
  ///
  /// In ru, this message translates to:
  /// **'История хранится на этом устройстве. Вход создаёт аккаунт и только — ничего вашего никуда не отправляется.'**
  String get accountSignedOutBody;

  /// No description provided for @accountSignInWithGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Google'**
  String get accountSignInWithGoogle;

  /// No description provided for @accountSignInWithYandex.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Яндекс'**
  String get accountSignInWithYandex;

  /// No description provided for @accountSignedInTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход выполнен'**
  String get accountSignedInTitle;

  /// No description provided for @accountLinkedProviders.
  ///
  /// In ru, this message translates to:
  /// **'Привязано: {providers}'**
  String accountLinkedProviders(String providers);

  /// No description provided for @accountSignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get accountSignOut;

  /// No description provided for @accountSyncOffTitle.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация выключена'**
  String get accountSyncOffTitle;

  /// No description provided for @accountSyncOffBody.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не отправляется и не загружается. Синхронизации пока нет вовсе, а когда появится — останется отдельным явным решением.'**
  String get accountSyncOffBody;

  /// No description provided for @accountPreviewButton.
  ///
  /// In ru, this message translates to:
  /// **'Проверить, что будет объединено'**
  String get accountPreviewButton;

  /// No description provided for @accountPreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Что было бы объединено'**
  String get accountPreviewTitle;

  /// No description provided for @accountPreviewCounts.
  ///
  /// In ru, this message translates to:
  /// **'Только на устройстве: {local} · Только в аккаунте: {remote} · Есть в обоих: {shared}'**
  String accountPreviewCounts(int local, int remote, int shared);

  /// No description provided for @accountPreviewConflicts.
  ///
  /// In ru, this message translates to:
  /// **'Расходятся: {count}'**
  String accountPreviewConflicts(int count);

  /// No description provided for @accountPreviewUndetermined.
  ///
  /// In ru, this message translates to:
  /// **'Сравнить нечем: {count}'**
  String accountPreviewUndetermined(int count);

  /// No description provided for @accountPreviewBackup.
  ///
  /// In ru, this message translates to:
  /// **'Резервная копия создана до проверки: {id}'**
  String accountPreviewBackup(String id);

  /// No description provided for @accountPreviewNoChoiceYet.
  ///
  /// In ru, this message translates to:
  /// **'Это только отчёт: пока ничего не отправлено и не изменено. Решение — ниже, и оно ваше.'**
  String get accountPreviewNoChoiceYet;

  /// No description provided for @accountPreviewFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отчёт не составлен'**
  String get accountPreviewFailedTitle;

  /// No description provided for @accountPreviewFailedBody.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать одну из сторон. Ничего не изменено — попробуйте позже.'**
  String get accountPreviewFailedBody;

  /// No description provided for @accountChooseMerge.
  ///
  /// In ru, this message translates to:
  /// **'Объединить с аккаунтом'**
  String get accountChooseMerge;

  /// No description provided for @accountChooseKeepLocal.
  ///
  /// In ru, this message translates to:
  /// **'Оставить только на устройстве'**
  String get accountChooseKeepLocal;

  /// No description provided for @accountMergeConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Объединить с аккаунтом?'**
  String get accountMergeConfirmTitle;

  /// No description provided for @accountMergeConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'История с этого устройства встанет в очередь на отправку. Локальные записи не удаляются и не переписываются. Резервная копия уже сделана: {id}'**
  String accountMergeConfirmBody(String id);

  /// No description provided for @accountMergeConfirmAction.
  ///
  /// In ru, this message translates to:
  /// **'Объединить'**
  String get accountMergeConfirmAction;

  /// No description provided for @accountKeepLocalConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оставить только на устройстве?'**
  String get accountKeepLocalConfirmTitle;

  /// No description provided for @accountKeepLocalConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт останется только для входа. Ничего не отправится, а очередь отправки будет очищена. Решение можно пересмотреть позже.'**
  String get accountKeepLocalConfirmBody;

  /// No description provided for @accountKeepLocalConfirmAction.
  ///
  /// In ru, this message translates to:
  /// **'Оставить локальным'**
  String get accountKeepLocalConfirmAction;

  /// No description provided for @accountChoiceCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get accountChoiceCancel;

  /// No description provided for @accountMergedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Объединение включено'**
  String get accountMergedTitle;

  /// No description provided for @accountMergedBody.
  ///
  /// In ru, this message translates to:
  /// **'История поставлена в очередь. Отправка пойдёт, когда появится сеть.'**
  String get accountMergedBody;

  /// No description provided for @accountKeptLocalTitle.
  ///
  /// In ru, this message translates to:
  /// **'Устройство оставлено локальным'**
  String get accountKeptLocalTitle;

  /// No description provided for @accountKeptLocalBody.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не отправляется. Аккаунт используется только для входа.'**
  String get accountKeptLocalBody;

  /// No description provided for @accountChoiceFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Решение не применено'**
  String get accountChoiceFailedTitle;

  /// No description provided for @accountChoiceFailedBody.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не изменено, синхронизация осталась выключенной. Составьте отчёт заново и ответьте ещё раз.'**
  String get accountChoiceFailedBody;

  /// No description provided for @accountUnavailableTitle.
  ///
  /// In ru, this message translates to:
  /// **'В этой сборке нет облака'**
  String get accountUnavailableTitle;

  /// No description provided for @accountUnavailableBody.
  ///
  /// In ru, this message translates to:
  /// **'Приложение полностью работает без аккаунта.'**
  String get accountUnavailableBody;

  /// No description provided for @accountMisconfiguredTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки облака неверны'**
  String get accountMisconfiguredTitle;

  /// No description provided for @accountMisconfiguredBody.
  ///
  /// In ru, this message translates to:
  /// **'Это проблема сборки, а не вашего соединения.'**
  String get accountMisconfiguredBody;

  /// No description provided for @accountUnknownTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось связаться с аккаунтом'**
  String get accountUnknownTitle;

  /// No description provided for @accountUnknownBody.
  ///
  /// In ru, this message translates to:
  /// **'Возможно, нет сети. Это не значит, что вас разлогинили.'**
  String get accountUnknownBody;

  /// No description provided for @accountPausedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проект приостановлен'**
  String get accountPausedTitle;

  /// No description provided for @accountPausedBody.
  ///
  /// In ru, this message translates to:
  /// **'Сервер отвечает, но проект приостановлен за неактивность и отклоняет все запросы — вход в том числе. Его нужно восстановить в консоли Appwrite. Ничего не потеряно: изменения ждут в очереди на телефоне и уйдут сами.'**
  String get accountPausedBody;

  /// No description provided for @accountRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get accountRetry;

  /// No description provided for @accountSignInFailed.
  ///
  /// In ru, this message translates to:
  /// **'Вход не завершился'**
  String get accountSignInFailed;

  /// No description provided for @accountSignOutFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выйти'**
  String get accountSignOutFailed;

  /// No description provided for @accountProviderGoogle.
  ///
  /// In ru, this message translates to:
  /// **'Google'**
  String get accountProviderGoogle;

  /// No description provided for @accountProviderYandex.
  ///
  /// In ru, this message translates to:
  /// **'Яндекс'**
  String get accountProviderYandex;

  /// No description provided for @coverageAlreadyMarked.
  ///
  /// In ru, this message translates to:
  /// **'Уже отмечено за этот намаз: {count}. Эти части не выбраны — отметьте их, если читали второй раз.'**
  String coverageAlreadyMarked(int count);

  /// No description provided for @coveragePartAlreadyMarked.
  ///
  /// In ru, this message translates to:
  /// **'уже отмечено'**
  String get coveragePartAlreadyMarked;

  /// No description provided for @accountBackfillIncompleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Часть истории осталась здесь'**
  String get accountBackfillIncompleteTitle;

  /// No description provided for @accountBackfillIncomplete.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить записей: {count} ({fields}). Они остались на устройстве.'**
  String accountBackfillIncomplete(int count, String fields);

  /// No description provided for @accountRetryRefused.
  ///
  /// In ru, this message translates to:
  /// **'Отправить заново отклонённые: {count}'**
  String accountRetryRefused(int count);

  /// No description provided for @accountRetryRefusedResult.
  ///
  /// In ru, this message translates to:
  /// **'Возвращено в очередь: {count}'**
  String accountRetryRefusedResult(int count);

  /// No description provided for @accountSyncNow.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать сейчас'**
  String get accountSyncNow;

  /// No description provided for @accountSyncNowResult.
  ///
  /// In ru, this message translates to:
  /// **'Отправлено: {pushed} · Осталось в очереди: {remaining}'**
  String accountSyncNowResult(int pushed, int remaining);

  /// No description provided for @accountSyncNowFailed.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с аккаунтом не удалось. Очередь сохранена и уйдёт позже.'**
  String get accountSyncNowFailed;

  /// No description provided for @accountSyncOnTitle.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация включена'**
  String get accountSyncOnTitle;

  /// No description provided for @accountSyncCounts.
  ///
  /// In ru, this message translates to:
  /// **'Ждут отправки: {queued} · Отклонено: {refused}'**
  String accountSyncCounts(int queued, int refused);

  /// No description provided for @accountSyncFailingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Последний обмен не завершился'**
  String get accountSyncFailingTitle;

  /// No description provided for @accountSyncFailingBody.
  ///
  /// In ru, this message translates to:
  /// **'Что-то не удалось отправить или получить. Приложение попробует снова — записи на этом устройстве в безопасности.'**
  String get accountSyncFailingBody;

  /// Region label when prayer times come from the phone's own coordinates rather than a chosen region. Shown on Home, in Settings and on the prayer widgets.
  ///
  /// In ru, this message translates to:
  /// **'Моё местоположение'**
  String get prayerLocationDevice;

  /// Name of the calculated prayer-time source, as opposed to a published schedule.
  ///
  /// In ru, this message translates to:
  /// **'Локальный расчёт'**
  String get prayerSourceLocalCalculation;
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
