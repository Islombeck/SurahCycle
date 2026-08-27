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

  /// No description provided for @chooseTranslation.
  ///
  /// In ru, this message translates to:
  /// **'Выберите перевод в настройках'**
  String get chooseTranslation;

  /// No description provided for @noRussianTranslations.
  ///
  /// In ru, this message translates to:
  /// **'У QuranEnc сейчас нет доступных проверенных русских переводов. Арабский текст остаётся доступен офлайн.'**
  String get noRussianTranslations;

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
  /// **'Выберите намаз в Murajaah'**
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
