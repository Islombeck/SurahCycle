// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Murajaah';

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
  String get recommendedTitle => 'Рекомендуется';

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
      'Откройте Murajaah, чтобы загрузить проверенный текст';

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
  String get chooseTranslation => 'Выберите перевод в настройках';

  @override
  String get noRussianTranslations =>
      'QuranEnc сейчас не возвращает русские переводы в официальном каталоге API. Арабский текст остаётся доступен офлайн.';

  @override
  String get translationCatalogError =>
      'Не удалось получить официальный список переводов QuranEnc.';

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
}
