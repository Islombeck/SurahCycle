// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'SurahCycle';

  @override
  String get homeTab => 'Главная';

  @override
  String get surahsTab => 'Суры';

  @override
  String get learningTab => 'Обучение';

  @override
  String get statisticsTab => 'Статистика';

  @override
  String get settingsTab => 'Настройки';

  @override
  String get historyTitle => 'История';

  @override
  String recommendationRank(int rank) {
    return 'Рекомендация $rank';
  }

  @override
  String get activeSurahsTitle => 'Активные суры';

  @override
  String get noActiveSurahs =>
      'Выберите выученные суры и включите их в ротацию.';

  @override
  String get contentUnavailableTitle => 'Данные Корана ещё не загружены';

  @override
  String get contentUnavailableBody =>
      'Проверенный каталог сур доступен офлайн. Текст аятов и переводы ещё не загружены; ротация и этапы обучения продолжают работать.';

  @override
  String get refreshContent => 'Проверить источник';

  @override
  String get sourceUnavailable => 'Проверенный источник пока не подключён';

  @override
  String get prayerContextTitle => 'Контекст намаза';

  @override
  String get fajr => 'Фаджр';

  @override
  String get dhuhr => 'Зухр';

  @override
  String get jumuah => 'Жума';

  @override
  String get asr => 'Аср';

  @override
  String get maghrib => 'Магриб';

  @override
  String get isha => 'Иша';

  @override
  String get witr => 'Витр';

  @override
  String get nafl => 'Нафль';

  @override
  String get qada => 'Каза';

  @override
  String get selectPrayer => 'Выбрать намаз';

  @override
  String get surahMarked => 'Сура отмечена';

  @override
  String get undo => 'Отменить';

  @override
  String get doneForCycle => 'Выполнено';

  @override
  String get recitedInCurrentPart => 'Прочитано в этой части';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get learningNotificationTitle => 'Тихое напоминание о заучивании';

  @override
  String get learningNotificationSubtitle =>
      'Беззвучное уведомление о том, что повторить дальше. По умолчанию выключено.';

  @override
  String get learningNotificationPermissionDenied =>
      'Разрешение на уведомления не выдано, напоминание остаётся выключенным.';

  @override
  String recitationsRemaining(int count) {
    return '$count×';
  }

  @override
  String ayahCount(int count) {
    return '$count аятов';
  }

  @override
  String surahNumber(int number) {
    return 'Сура $number';
  }

  @override
  String get searchSurahs => 'Поиск по номеру или названию';

  @override
  String get noSearchResults => 'По этому запросу ничего не найдено.';

  @override
  String get masteredOnly => 'Выученные';

  @override
  String get activeRotation => 'В ротации';

  @override
  String get inactiveRotation => 'Приостановлена';

  @override
  String get addToMastered => 'Добавить в выученные';

  @override
  String get removeFromRotation => 'Приостановить';

  @override
  String get returnToRotation => 'Вернуть в ротацию';

  @override
  String get editAlias => 'Изменить название';

  @override
  String get aliasHint => 'Ваше название суры';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteHistoryConfirm =>
      'Удалить эту запись? Баланс будет пересчитан по сохранённым событиям.';

  @override
  String get emptyHistory => 'Прочтений пока нет.';

  @override
  String get normalRecitation => 'Обычный';

  @override
  String get qadaRecitation => 'Каза';

  @override
  String get totalRecitations => 'Всего прочтений';

  @override
  String get lastUsed => 'Последнее прочтение';

  @override
  String get never => 'Ещё не читалась';

  @override
  String get prayerBreakdown => 'По намазам';

  @override
  String get noStatistics => 'Статистика появится после первого прочтения.';

  @override
  String get currentLearning => 'Сейчас изучается';

  @override
  String get showOnHome => 'Показывать на главной';

  @override
  String get startLearning => 'Начать изучение';

  @override
  String get repeated => 'Повторил';

  @override
  String get learned => 'Выучил';

  @override
  String newAyah(int number) {
    return 'Новый аят $number';
  }

  @override
  String cumulativeRange(int end) {
    return 'Повторение аятов 1–$end';
  }

  @override
  String get learningRolledBack =>
      'После 72 часов без повторения этап откачен на один шаг.';

  @override
  String get learningCompletedTitle => 'Сура выучена';

  @override
  String get learningCompletedBody => 'Добавить её в активную ротацию?';

  @override
  String get completeAndAdd => 'Завершить и добавить';

  @override
  String get darkMode => 'Тёмная тема';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get advancedSettings => 'Расширенные настройки';

  @override
  String get balanceAdjustment => 'Коррекция баланса';

  @override
  String get balanceAdjustmentBody =>
      'Используйте только для переноса текущего баланса. История прочтений не изменится.';

  @override
  String get shiftPlusOne => 'Сдвинуть баланс +1';

  @override
  String get shiftMinusOne => 'Сдвинуть баланс −1';

  @override
  String get balanceConfirm =>
      'Изменить только баланс этой суры? Историческая статистика останется прежней.';

  @override
  String get exportData => 'Экспорт данных';

  @override
  String get exportPrepared =>
      'Точка экспорта подготовлена; файл будет добавлен в следующем спринте.';

  @override
  String get sourceMetadata => 'Источник данных';

  @override
  String get offlineReady => 'Работает офлайн';

  @override
  String get retry => 'Повторить';

  @override
  String get errorGeneric => 'Не удалось выполнить действие';

  @override
  String get registrationContextChanged =>
      'Дата или намаз изменились. Отметка не сохранена. Повторите действие для выбранного намаза.';

  @override
  String get loading => 'Загрузка…';

  @override
  String get noLearningSurahs => 'Изучаемых сур пока нет.';

  @override
  String get openHistory => 'Открыть историю';

  @override
  String aheadBy(int count) {
    return 'Опережение: $count';
  }

  @override
  String get statisticsFilter => 'Фильтр по намазу';

  @override
  String get allPrayers => 'Все намазы';

  @override
  String get isQadaLabel => 'Восполняемый намаз';

  @override
  String get reorderHint =>
      'Удерживайте и перетаскивайте, чтобы изменить порядок';

  @override
  String get selectSurah => 'Выберите суру';

  @override
  String get contentIntegrityNotice =>
      'Текст и метаданные показываются без изменений только после загрузки из проверенного источника.';

  @override
  String get editSegmentation => 'Части для повторения';

  @override
  String get wholeSurah => 'Вся сура';

  @override
  String partLabel(Object number) {
    return 'Часть $number';
  }

  @override
  String ayahRange(int start, int end) {
    return 'Аяты $start–$end';
  }

  @override
  String rakaatSpan(Object count) {
    return 'Ракаатов: $count';
  }

  @override
  String get selectCoverage => 'Выберите прочитанные части';

  @override
  String splitIntoParts(Object count) {
    return 'Разделить на $count части';
  }

  @override
  String get automaticBoundaries => 'Автоматические границы';

  @override
  String get manualBoundaries => 'Изменить границы';

  @override
  String schemeVersion(Object version) {
    return 'Версия $version';
  }

  @override
  String get recitationActions => 'Действия прочтения';

  @override
  String get fullEquivalentRecitations => 'Эквивалент полных сур';

  @override
  String dueSurahsCount(Object count) {
    return 'К повторению: $count';
  }

  @override
  String get widgetPart => 'Часть';

  @override
  String get widgetAyah => 'Аят';

  @override
  String get widgetAyahs => 'Аяты';

  @override
  String get widgetOpenAppToLoadText =>
      'Откройте SurahCycle, чтобы загрузить проверенный текст';

  @override
  String get customParts => 'Свой';

  @override
  String get customPartCount => 'Количество частей';

  @override
  String customPartCountRange(int max) {
    return 'От 1 до $max';
  }

  @override
  String get customPartCountInvalid => 'Введите допустимое количество частей';

  @override
  String get fatihaRotationExcluded =>
      'Аль-Фатиха сохраняется в выученных, но не участвует в обычной ротации.';

  @override
  String get completeLearningOnly => 'Завершить обучение';

  @override
  String get arabicTextOfflineReady =>
      'Проверенный арабский текст Tanzil доступен офлайн.';

  @override
  String get quranTranslation => 'Перевод Корана';

  @override
  String get translationLanguage => 'Язык перевода';

  @override
  String get translationLanguageRussian => 'Русский';

  @override
  String get translationLanguageUzbek => 'Узбекский';

  @override
  String get chooseTranslation => 'Выберите перевод в настройках';

  @override
  String get noTranslationsForLanguage =>
      'Для выбранного языка сейчас нет доступных проверенных переводов QuranEnc. Арабский текст остаётся доступен офлайн.';

  @override
  String get additionalUzbekTranslationsUnavailable =>
      'Al-Mukhtasar (uzbek_mokhtasar) и Al-Muyassar (uzbek_moyassar): ключи официального каталога подтверждены, но API-корпусы пока недоступны.';

  @override
  String get translationCatalogError =>
      'Не удалось получить официальный список переводов QuranEnc.';

  @override
  String get translationNoNetwork =>
      'Нет сети. Уже скачанные переводы остаются доступны офлайн.';

  @override
  String get translationSourceError =>
      'Источник перевода отклонил запрос. Попробуйте позже.';

  @override
  String get translationValidationFailed =>
      'Ответ источника повреждён или не прошёл проверку. Он не сохранён.';

  @override
  String get translationCatalogFromCache =>
      'Показан сохранённый офлайн-каталог.';

  @override
  String get translationRefreshFailedCached =>
      'Обновить источник не удалось; сохранённые проверенные данные оставлены без изменений.';

  @override
  String get translationNotSelected => 'Перевод не выбран';

  @override
  String get translationCachedOffline =>
      'Выбранный перевод сохраняется для офлайн-чтения по мере открытия сур.';

  @override
  String get translationUnavailableOffline =>
      'Для этого аята перевод ещё не сохранён. Арабский текст доступен, пока перевод загружается в фоне.';

  @override
  String get clearTranslation => 'Очистить выбор перевода';

  @override
  String get translationSelectionInvalid =>
      'Сохранённый выбор перевода повреждён или больше не поддерживается. Арабский текст остаётся доступен.';

  @override
  String get translationVersionChanged =>
      'Версия выбранного перевода изменилась. Подтвердите новую версию в настройках; арабский текст остаётся доступен.';

  @override
  String translationUpdateAvailable(String version) {
    return 'Доступна новая версия выбранного перевода: v$version. Обновление выполняется только по вашему выбору.';
  }

  @override
  String useTranslationVersion(String version) {
    return 'Использовать v$version';
  }

  @override
  String get tanzilTextMetadata =>
      'Tanzil Project · Uthmani Quran Text v1.1 · CC BY 3.0';

  @override
  String get tanzilTransliterationMetadata =>
      'Tanzil · English Transliteration · снимок 2010-09-06 · 6236 аятов';

  @override
  String get transliterationNonCommercialNotice =>
      'Условия набора транскрипции разрешают только некоммерческое использование; коммерческий production-релиз требует отдельного разрешения.';

  @override
  String get quranDisplayLayers => 'Слои текста Корана';

  @override
  String get showArabicText => 'Показывать арабский текст';

  @override
  String get showTransliteration => 'Показывать транскрипцию';

  @override
  String get transliterationProfile => 'Профиль транслитерации';

  @override
  String get transliterationProfileLatinTanzil => 'Латиница — Tanzil';

  @override
  String get transliterationProfileCyrillic => 'Кириллица';

  @override
  String get transliterationProfileCyrillicUnavailable =>
      'Кириллица — проверенный источник пока не подключён';

  @override
  String get showTranslation => 'Показывать перевод';

  @override
  String get transliterationSourceShort =>
      'Транскрипция (латинская транслитерация) · Tanzil · офлайн';

  @override
  String get transliterationUnavailable =>
      'Проверенная транскрипция недоступна.';

  @override
  String get prayerTimesTitle => 'Время намаза';

  @override
  String get prayerRegion => 'Регион';

  @override
  String get selectPrayerRegion => 'Выберите регион вручную';

  @override
  String get useMyLocation => 'Использовать моё местоположение';

  @override
  String get locationOptionalNotice =>
      'Необязательно. Геопозиция запрашивается только после нажатия, без фонового доступа.';

  @override
  String get prayerContextMode => 'Контекст отметки';

  @override
  String get prayerModeManual => 'Ручной режим';

  @override
  String get prayerModeAutomatic => 'Автоматически';

  @override
  String get useJumuahForNextRecitation => 'Отметить следующее чтение как Жума';

  @override
  String get automaticPrayerSafetyNotice =>
      'Автовыбор работает только по свежему надёжному расписанию. После восхода до Зухра отметка потребует ручного выбора.';

  @override
  String get allowCalculatedFallback => 'Разрешить локальный расчёт';

  @override
  String get calculatedFallbackNotice =>
      'Это отдельный расчётный источник, а не официальное расписание ОМИ. По умолчанию: Karachi, Аср Hanafi.';

  @override
  String get calculatedFallbackCoordinatesUnavailable =>
      'Для этого региона поставщика нет отдельно проверенных координат, поэтому локальный расчёт недоступен.';

  @override
  String get calculationMethod => 'Расчётный метод';

  @override
  String get asrHanafi => 'Аср: Hanafi';

  @override
  String get asrStandard => 'Аср: стандартный';

  @override
  String get manualMinuteAdjustments => 'Ручные поправки в минутах';

  @override
  String get rawTimesPreserved =>
      'Исходное время источника сохраняется; показывается отдельное скорректированное значение.';

  @override
  String minuteAdjustment(int value) {
    return 'Поправка: $value мин';
  }

  @override
  String get decreaseMinute => 'Уменьшить на минуту';

  @override
  String get increaseMinute => 'Увеличить на минуту';

  @override
  String get locationCalculationEnabled =>
      'Местоположение сохранено для локального расчёта.';

  @override
  String get locationServicesDisabled =>
      'Геолокация выключена. Выберите регион вручную.';

  @override
  String get locationDeniedChooseRegion =>
      'Доступ к геопозиции не предоставлен. Выберите регион вручную.';

  @override
  String get locationOutsideUzbekistan =>
      'Для этой точки нет проверенной настройки часового пояса. Выберите регион вручную.';

  @override
  String get locationFailedChooseRegion =>
      'Не удалось получить геопозицию. Выберите регион вручную.';

  @override
  String get prayerScheduleToday => 'Расписание на сегодня';

  @override
  String get sunrise => 'Восход';

  @override
  String get prayerSource => 'Источник';

  @override
  String get prayerUpdated => 'Обновлено';

  @override
  String get asrSchool => 'Расчёт Асра';

  @override
  String get timesManuallyAdjusted =>
      'Время скорректировано вручную; исходные значения сохранены.';

  @override
  String get prayerOfflineCache => 'Используется свежий офлайн-кеш.';

  @override
  String get refreshPrayerSchedule => 'Обновить текущий и следующий месяц';

  @override
  String prayerStartsAt(String start) {
    return 'С $start';
  }

  @override
  String prayerTimeRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String nextPrayerAt(String prayer, String time) {
    return 'Далее: $prayer в $time';
  }

  @override
  String get betweenPrayers => 'Между намазами';

  @override
  String get prayerScheduleStale => 'Расписание устарело — автовыбор отключён';

  @override
  String get prayerScheduleUnavailable =>
      'Расписание недоступно — выберите намаз вручную';

  @override
  String widgetManualPrayerContext(String prayer) {
    return 'Ручной: $prayer · Ротация';
  }

  @override
  String widgetAutomaticPrayerContext(String prayer) {
    return '$prayer · Авто · Ротация';
  }

  @override
  String widgetAutomaticPrayerRange(String prayer, String start, String end) {
    return '$prayer · $start–$end · Ротация';
  }

  @override
  String widgetAutomaticPrayerStart(String prayer, String start) {
    return '$prayer · с $start · Ротация';
  }

  @override
  String get widgetSelectPrayerInApp => 'Выберите намаз в SurahCycle';

  @override
  String get widgetActionNotCompleted =>
      'Не удалось отметить. Показаны актуальные данные.';

  @override
  String get learningHow => 'Как учить?';

  @override
  String get learningClassic => 'Классически';

  @override
  String get learningChunked => 'По частям';

  @override
  String get learningChunkedRecommended =>
      'Для длинной суры удобнее учить по частям. Выбор можно изменить.';

  @override
  String get learningTargetRange => 'Диапазон обучения';

  @override
  String get learningTargetStart => 'Первый аят';

  @override
  String get learningTargetEnd => 'Последний аят';

  @override
  String get learningBlockSize => 'Размер блока';

  @override
  String get learningCustomBlockSize => 'Свой размер';

  @override
  String get changeLearningPlan => 'Изменить план';

  @override
  String get confirmPlanChangeTitle => 'Начать новый цикл?';

  @override
  String get confirmPlanChangeBody =>
      'Текущий прогресс будет начат заново по новому плану. История обучения сохранится.';

  @override
  String learningReviewRange(int start, int end) {
    return 'Повторение аятов $start–$end';
  }

  @override
  String learningBridgeRange(int start, int end) {
    return 'Связка блоков · аяты $start–$end';
  }

  @override
  String learningSectionReview(int start, int end) {
    return 'Повторить раздел · аяты $start–$end';
  }

  @override
  String learningFinalReview(int start, int end) {
    return 'Итоговое повторение · аяты $start–$end';
  }

  @override
  String get rangeCompletedTitle => 'Диапазон завершён';

  @override
  String get rangeCompletedBody =>
      'Изученный диапазон сохранён. Вся сура не отмечена как выученная.';

  @override
  String get completeWithoutRotation => 'Завершить без ротации';

  @override
  String get addToRotationQuestion => 'Добавить в ротацию?';

  @override
  String get returnToLearning => 'Убрать из выученных';

  @override
  String get returnToLearningTitle => 'Вернуть суру в обучение?';

  @override
  String get returnToLearningBody =>
      'Сура выйдет из ротации. История, статистика, разбиение и прежние оценки сохранятся.';

  @override
  String historyAddedAt(String dateTime) {
    return 'Добавлено $dateTime';
  }

  @override
  String get historyDetailsTitle => 'Детали прочтения';

  @override
  String get historyOpenDetails => 'Открыть детали прочтения';

  @override
  String get historyOccurrenceLabel => 'Когда и в каком намазе прочитано';

  @override
  String get historyCoverageLabel => 'Прочитанный отрывок';

  @override
  String get historyRakaatSpanExplanation =>
      'Это только число ракаатов, которые заняло прочтение. Отдельные аяты не привязаны к конкретным ракаатам.';

  @override
  String get partLabelOptional => 'Название (необязательно)';

  @override
  String routineNoQadaPart(String kind) {
    return 'В этом намазе нет части вида «$kind». Каза отмечает только обязательную часть, поэтому для каза здесь нечего будет отметить.';
  }

  @override
  String get historyShowDeleted => 'Показать удалённые';

  @override
  String get historyHideDeleted => 'Скрыть удалённые';

  @override
  String historyDeletedAt(String dateTime) {
    return 'Удалено $dateTime';
  }

  @override
  String get historyRestore => 'Восстановить';

  @override
  String get historyRestored => 'Запись восстановлена';

  @override
  String get historyNoDeleted => 'Удалённых прочтений нет.';

  @override
  String get registrationWhenTitle => 'Когда и в каком намазе прочитано';

  @override
  String get registrationNow => 'Сейчас';

  @override
  String get registrationPreviousPrayer => 'Предыдущий намаз';

  @override
  String get registrationYesterday => 'Вчера';

  @override
  String get registrationChooseDatePrayer => 'Выбрать дату и намаз';

  @override
  String registrationOccurrenceDate(String date) {
    return 'Дата прочтения: $date';
  }

  @override
  String get prayerRoutines => 'Порядок частей намаза';

  @override
  String get prayerRoutineDescription =>
      'Настройте части намаза по порядку: число ракаатов и обязательных слотов для сур.';

  @override
  String get routineEnabled => 'Использовать этот порядок';

  @override
  String get routineEmpty =>
      'Частей пока нет. Добавьте то, что хотите отслеживать.';

  @override
  String routinePartSummary(int rakaatCount, int slotCount) {
    return '$rakaatCount рак. · слотов для сур: $slotCount';
  }

  @override
  String get addPrayerPart => 'Добавить часть намаза';

  @override
  String get editPrayerPart => 'Изменить часть намаза';

  @override
  String get deletePrayerPartTitle => 'Удалить часть намаза?';

  @override
  String deletePrayerPartBody(String label) {
    return 'Удалить «$label»? Уже прочитанное не изменится.';
  }

  @override
  String get applyToCurrentPrayerTitle => 'Применить и к текущему намазу?';

  @override
  String applyToCurrentPrayerBody(String prayer, String date) {
    return '$prayer, $date — часть ещё в плане. Чтений в ней нет, поэтому её можно убрать и оттуда.';
  }

  @override
  String applyToCurrentPrayerComposition(String parts) {
    return 'Останется: $parts';
  }

  @override
  String get applyToCurrentPrayerEmpty =>
      'План намаза будет собран заново по шаблону.';

  @override
  String get applyToCurrentPrayerAction => 'Убрать из текущего';

  @override
  String get keepCurrentPrayerUnchanged => 'Оставить как есть';

  @override
  String applyToCurrentPrayerKept(String label) {
    return '«$label» осталась: в ней уже есть прочитанное.';
  }

  @override
  String get calendarTitle => 'Календарь';

  @override
  String get openCalendar => 'Открыть календарь';

  @override
  String get calendarPreviousMonth => 'Предыдущий месяц';

  @override
  String get calendarNextMonth => 'Следующий месяц';

  @override
  String get calendarLegendOrdinary => 'Обычная отметка';

  @override
  String get calendarLegendQada => 'Каза';

  @override
  String get calendarLegendPartial => 'Отмечено частично';

  @override
  String get calendarNoRecord => 'Нет отметки';

  @override
  String get calendarNoRecordExplanation =>
      'Это значит, что запись не вносилась, а не что намаз пропущен.';

  @override
  String get calendarPartialSuffix => 'частично';

  @override
  String get calendarQadaExplanation =>
      'Каза показан на дне того намаза, который восполнен.';

  @override
  String get calendarQadaFulfilledUnknown =>
      'День фактического восполнения не сохранён для прежних записей.';

  @override
  String get calendarFutureDay =>
      'Будущий день. Отметить чтение заранее нельзя.';

  @override
  String get qadaOriginUnknown => 'День пропущенного намаза неизвестен';

  @override
  String historyQadaMadeUpOn(String date) {
    return 'Восполнено: $date';
  }

  @override
  String get qadaOriginUnknownHint =>
      'Для очень старых долгов. Запись встанет на день восполнения, и это будет прямо указано.';

  @override
  String get calendarQadaOriginUnknownEntry => 'исходный день неизвестен';

  @override
  String get calendarRegisterForDay => 'Отметить за этот день';

  @override
  String pendingRegistrationBanner(String date) {
    return 'Отмечаю за $date';
  }

  @override
  String get pendingRegistrationCancel => 'Вернуться к сегодня';

  @override
  String get pendingRegistrationPickPrayer =>
      'Для прошедшего дня намаз выбирается вручную.';

  @override
  String qadaFulfilledOn(String date) {
    return 'Восполнено: $date';
  }

  @override
  String get qadaFulfilledHint =>
      'День, когда вы фактически прочитали. По умолчанию сегодня; измените, если вносите позже.';

  @override
  String get changeQadaFulfilledDate => 'Изменить день восполнения';

  @override
  String get partKind => 'Тип части';

  @override
  String get customPartLabel => 'Своё название';

  @override
  String get customPartLabelRequired => 'Введите название.';

  @override
  String get rakaatCountLabel => 'Число ракаатов';

  @override
  String get positiveNumberRequired => 'Введите положительное число.';

  @override
  String get surahSlotsLabel => 'Обязательные слоты для сур';

  @override
  String get nonNegativeNumberRequired =>
      'Введите ноль или положительное число.';

  @override
  String get allowsFollowingImam => 'Можно завершить, следуя за имамом';

  @override
  String get partKindFard => 'Фард';

  @override
  String get partKindSunnah => 'Сунна';

  @override
  String get partKindWitr => 'Витр';

  @override
  String get partKindNafl => 'Нафль';

  @override
  String get partKindCustom => 'Другое';

  @override
  String prayerRoutineCurrentPart(String prayer, String part) {
    return '$prayer · $part';
  }

  @override
  String prayerRoutineSlotProgress(int done, int total) {
    return 'Слоты для сур: $done/$total';
  }

  @override
  String get prayerRoutineComplete => 'Порядок намаза завершён';

  @override
  String get prayerRoutineNoAvailableSlot =>
      'В текущей части намаза нет доступного слота для суры.';

  @override
  String get followedImamAction => 'Следовал за имамом';

  @override
  String get followedImamConfirmTitle => 'Завершить с имамом?';

  @override
  String get followedImamConfirmBody =>
      'Эта часть будет завершена без события прочтения и без зачёта в ротации.';

  @override
  String get followedImamCompleted => 'Завершено вслед за имамом';

  @override
  String get returnToAutomaticPrayer => 'Вернуться к авто';

  @override
  String get routineEditFailed =>
      'Не удалось сохранить изменение порядка намаза';

  @override
  String get routineEditConflict =>
      'Порядок намаза изменился. Показано актуальное состояние — повторите действие.';

  @override
  String get recallModeTitle => 'Проверка по памяти';

  @override
  String get recallStartAction => 'Проверить по памяти';

  @override
  String get recallRangeTitle => 'Какие аяты?';

  @override
  String get recallRangeFrom => 'С аята';

  @override
  String get recallRangeTo => 'По аят';

  @override
  String get recallRangeInvalid =>
      'Последний аят не может быть раньше первого.';

  @override
  String get recallBegin => 'Начать';

  @override
  String recallHiddenTitle(int number) {
    return 'Аят $number';
  }

  @override
  String get recallHiddenHint =>
      'Прочитайте его по памяти, затем откройте текст.';

  @override
  String get recallReveal => 'Показать аят';

  @override
  String get recallResultRecalled => 'Вспомнил';

  @override
  String get recallResultWithMistake => 'С ошибкой';

  @override
  String get recallResultNotRecalled => 'Не вспомнил';

  @override
  String get recallSkip => 'Дальше';

  @override
  String recallProgress(int done, int total) {
    return '$done из $total';
  }

  @override
  String get recallFinishedTitle => 'Проверка завершена';

  @override
  String recallFinishedBody(int recalled, int withMistake, int notRecalled) {
    return 'Вспомнил: $recalled · С ошибкой: $withMistake · Не вспомнил: $notRecalled';
  }

  @override
  String get recallSelfAssessment =>
      'Оценку ставите вы сами — приложение не слушает и не проверяет чтение.';

  @override
  String get recallPriorityNote =>
      'Аяты, отмеченные как ошибка, поднимаются в предложениях для повторения. Больше ничего не меняется.';

  @override
  String get recallSaveFailed => 'Не удалось сохранить результат';

  @override
  String get recallClose => 'Готово';

  @override
  String get recallHistoryTitle => 'Проверки по памяти';

  @override
  String get recallNoHistory => 'Проверок пока нет.';

  @override
  String recallSurahSummary(int recalled, int imperfect) {
    return '$recalled вспомнил · $imperfect повторить';
  }

  @override
  String get accountTitle => 'Аккаунт';

  @override
  String get accountCardSubtitle => 'Вход не включает синхронизацию';

  @override
  String get accountOpenAction => 'Открыть';

  @override
  String get accountSignedOutTitle => 'Вход не выполнен';

  @override
  String get accountSignedOutBody =>
      'История хранится на этом устройстве. Вход создаёт аккаунт и только — ничего вашего никуда не отправляется.';

  @override
  String get accountSignInWithGoogle => 'Войти через Google';

  @override
  String get accountSignInWithYandex => 'Войти через Яндекс';

  @override
  String get accountSignedInTitle => 'Вход выполнен';

  @override
  String accountLinkedProviders(String providers) {
    return 'Привязано: $providers';
  }

  @override
  String get accountSignOut => 'Выйти';

  @override
  String get accountSyncOffTitle => 'Синхронизация выключена';

  @override
  String get accountSyncOffBody =>
      'Ничего не отправляется и не загружается. Синхронизации пока нет вовсе, а когда появится — останется отдельным явным решением.';

  @override
  String get accountPreviewButton => 'Проверить, что будет объединено';

  @override
  String get accountPreviewTitle => 'Что было бы объединено';

  @override
  String accountPreviewCounts(int local, int remote, int shared) {
    return 'Только на устройстве: $local · Только в аккаунте: $remote · Есть в обоих: $shared';
  }

  @override
  String accountPreviewConflicts(int count) {
    return 'Расходятся: $count';
  }

  @override
  String accountPreviewUndetermined(int count) {
    return 'Сравнить нечем: $count';
  }

  @override
  String accountPreviewBackup(String id) {
    return 'Резервная копия создана до проверки: $id';
  }

  @override
  String get accountPreviewNoChoiceYet =>
      'Это только отчёт: пока ничего не отправлено и не изменено. Решение — ниже, и оно ваше.';

  @override
  String get accountPreviewFailedTitle => 'Отчёт не составлен';

  @override
  String get accountPreviewFailedBody =>
      'Не удалось прочитать одну из сторон. Ничего не изменено — попробуйте позже.';

  @override
  String get accountChooseMerge => 'Объединить с аккаунтом';

  @override
  String get accountChooseKeepLocal => 'Оставить только на устройстве';

  @override
  String get accountMergeConfirmTitle => 'Объединить с аккаунтом?';

  @override
  String accountMergeConfirmBody(String id) {
    return 'История с этого устройства встанет в очередь на отправку. Локальные записи не удаляются и не переписываются. Резервная копия уже сделана: $id';
  }

  @override
  String get accountMergeConfirmAction => 'Объединить';

  @override
  String get accountKeepLocalConfirmTitle => 'Оставить только на устройстве?';

  @override
  String get accountKeepLocalConfirmBody =>
      'Аккаунт останется только для входа. Ничего не отправится, а очередь отправки будет очищена. Решение можно пересмотреть позже.';

  @override
  String get accountKeepLocalConfirmAction => 'Оставить локальным';

  @override
  String get accountChoiceCancel => 'Отмена';

  @override
  String get accountMergedTitle => 'Объединение включено';

  @override
  String get accountMergedBody =>
      'История поставлена в очередь. Отправка пойдёт, когда появится сеть.';

  @override
  String get accountKeptLocalTitle => 'Устройство оставлено локальным';

  @override
  String get accountKeptLocalBody =>
      'Ничего не отправляется. Аккаунт используется только для входа.';

  @override
  String get accountChoiceFailedTitle => 'Решение не применено';

  @override
  String get accountChoiceFailedBody =>
      'Ничего не изменено, синхронизация осталась выключенной. Составьте отчёт заново и ответьте ещё раз.';

  @override
  String get accountUnavailableTitle => 'В этой сборке нет облака';

  @override
  String get accountUnavailableBody =>
      'Приложение полностью работает без аккаунта.';

  @override
  String get accountMisconfiguredTitle => 'Настройки облака неверны';

  @override
  String get accountMisconfiguredBody =>
      'Это проблема сборки, а не вашего соединения.';

  @override
  String get accountUnknownTitle => 'Не удалось связаться с аккаунтом';

  @override
  String get accountUnknownBody =>
      'Возможно, нет сети. Это не значит, что вас разлогинили.';

  @override
  String get accountRetry => 'Повторить';

  @override
  String get accountSignInFailed => 'Вход не завершился';

  @override
  String get accountSignOutFailed => 'Не удалось выйти';

  @override
  String get accountProviderGoogle => 'Google';

  @override
  String get accountProviderYandex => 'Яндекс';

  @override
  String coverageAlreadyMarked(int count) {
    return 'Уже отмечено за этот намаз: $count. Эти части не выбраны — отметьте их, если читали второй раз.';
  }

  @override
  String get coveragePartAlreadyMarked => 'уже отмечено';

  @override
  String get accountSyncNow => 'Синхронизировать сейчас';

  @override
  String accountSyncNowResult(int pushed, int remaining) {
    return 'Отправлено: $pushed · Осталось в очереди: $remaining';
  }

  @override
  String get accountSyncNowFailed =>
      'Связаться с аккаунтом не удалось. Очередь сохранена и уйдёт позже.';

  @override
  String get accountSyncOnTitle => 'Синхронизация включена';

  @override
  String accountSyncCounts(int queued, int refused) {
    return 'Ждут отправки: $queued · Отклонено: $refused';
  }
}
