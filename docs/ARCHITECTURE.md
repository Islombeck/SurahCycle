# Архитектура Murajaah — Sprint 5

## Эволюция архитектуры

Sprints 2–3 сохранили local-first архитектуру Sprint 1 и добавили
версионируемое разбиение, event journal, проверенный Quran content и два
Android widget. Sprint 4 расширяет те же границы, не меняя Drift schema v3:

- домен ротации использует версионируемые `SurahRotationScheme` и `SurahRotationPart`; эффективное состояние суры выводится из минимального состояния её частей;
- Drift v3 хранит неизменяемую схему, части и coverage каждого события отдельно от текущей проекции;
- Arabic, transliteration и translation приходят через независимые проверяемые repository boundaries и связываются только по координатам аята;
- prayer schedules разделены на published provider, local calculation, external cache и чистый Prayer Context resolver;
- Android-виджеты получают готовый versioned JSON snapshot через `home_widget`; Kotlin/Glance не открывает Drift и не повторяет доменные алгоритмы, а интерактивный circle только транспортирует versioned action обратно в Dart.

Sprint 5 переводит пользовательскую базу на Drift schema v4 для mastery и
learning lifecycle. Изменения Sprint 5B в Prayer Context используют уже
существующие поля события и отдельный versioned settings JSON schema 2:

- `createdAtUtc` остаётся фактическим моментом записи, а `localDate` становится
  явно выбираемым occurrence prayer day;
- startup и automatic resolution имеют null/loading state и не создают
  фиктивный Prayer Context;
- исторические shortcuts реализованы чистым application resolver и доступны
  только полному приложению;
- native widget остаётся current-context/current-date boundary и fail-closed.

Одна пользовательская отметка создаёт один `RecitationEvent`, а выбранные части записываются отношением `recitation_event_parts` в той же транзакции. `rakaatSpanCount` описывает, на сколько ракаатов распространялось это действие, но не моделирует каждый ракаат отдельно. Смена разбиения создаёт новую схему; прежняя схема и coverage истории не переписываются.

Default `rakaatSpanCount=1`. Compact History скрывает это значение только для
обычной unsplit whole-surah регистрации; split/partial/multiple span остаётся
видимым, а details всегда показывает число и пояснение об отсутствии per-rakaat
ayah mapping.

Все записи из UI и direct widget action проходят через один
`RecitationApplicationService`/repository boundary. Этот же поток
обновляет Drift-проекцию, рекомендации и после commit планирует новый widget
snapshot. Ошибка синхронизации виджета не откатывает корректное пользовательское
событие.

## Принципы

- **Local-first:** локальная база — источник истины для пользовательских действий.
- **Feature-first:** код группируется по пользовательской функции, а не в глобальные папки «models/services/widgets».
- **Чистая доменная логика:** ротация и обучение не зависят от Flutter UI, базы, сети и системных часов.
- **События + проекции:** неизменяемые факты хранятся отдельно от быстрых вычисляемых snapshot.
- **Разделение контента:** Quran content можно обновить или очистить без потери истории пользователя.
- **Проверяемость:** время, UUID и внешние поставщики доступны через абстракции.
- **Портируемость:** домен не содержит Android-only решений; iOS использует тот же код приложения.

## Технологические границы

Текущий стек: Flutter/Dart, Material 3, Riverpod, `go_router`,
Drift/SQLite, Flutter localization, `home_widget`, Android Glance,
`adhan_dart` и `geolocator`. HTTP-клиенты существуют только
в Quran и published prayer provider boundaries. Location service вызывается
только после явного действия пользователя. Новая зависимость добавляется,
только если она сокращает риск или существенный объём собственного
инфраструктурного кода.

Ориентир структуры:

```text
lib/
  app/                 конфигурация, маршруты, темы, локализация
  core/                база, время, идентификаторы, общие ошибки
    widgets/           versioned snapshot, projection builder, sync и deep links
  features/
    surahs/            выученные суры и aliases
    rotation/          RotationEngine, проекции, рекомендации
    prayer/            PrayerContext и регистрация чтения
    learning/          LearningStateMachine
    statistics/        запросы истории и статистики
    quran/             repository, providers и cache
    prayer_times/      published/calculated schedules, cache и resolver
    settings/          настройки и ручная миграция баланса
```

Внутри сложной feature допустимы уровни:

- `presentation` — widgets, controllers/providers, UI-state;
- `application` — use cases и транзакционные сценарии;
- `domain` — сущности, value objects и чистые алгоритмы;
- `data` — Drift DAO, repository implementation и network adapter.

UI не выполняет SQL, не меняет счётчики напрямую и не вызывает `DateTime.now()` для бизнес-решений.

## Поток локальной операции

Регистрация прочтения проходит одной транзакцией:

1. application use case валидирует активную суру, текущую схему, непустое coverage, 1–4 ракаата и Prayer Context;
2. сохраняет снимок состояния непосредственно перед действием для краткоживущего Undo;
3. добавляет `RecitationEvent` с UUID, фактическим `createdAtUtc`, выбранным
   occurrence `localDate` и всеми строками coverage;
4. `RotationEngine` атомарно применяет событие к выбранным частям;
5. сохраняются новый snapshot и версия проекции;
6. наблюдаемые Riverpod-состояния обновляют главный экран, рекомендации и статистику, а coordinator после commit публикует widget snapshot.

Сеть в этом потоке отсутствует. При ошибке транзакции ни событие, ни часть проекции не считаются сохранёнными.

## Стратегия состояния: snapshot + event journal

Выбран единый журнал доменных событий и пересчитываемые snapshot/projections.

- `RecitationEvent` — исторический факт чтения.
- `RotationAdjustmentEvent` — отдельная ручная коррекция баланса с `delta`, причиной и временем; она не является чтением.
- строка `MasteredSurah` хранит неизменяемый baseline первого входа и текущее состояние активности; временное отключение не меняет baseline;
- `LearningEvent` хранит действия обучения, откаты и завершение;
- `RotationSnapshot`/текущие поля `MasteredSurah` ускоряют открытие приложения, но не являются единственным источником восстановления.

`totalRecitations` — производная full-equivalent величина: минимум неудалённых credits по частям активной схемы. Число `RecitationEvent` хранится и показывается отдельно как action count. Ни одна из этих метрик не редактируется вручную и не выводится из другой.

`rotationScore` восстанавливается как baseline первого включения плюс неудалённые чтения и отдельные корректировки. Удаление исторического чтения исключает его из проекции и запускает rebuild в одной транзакции. При обычном удалении достигнутый `rotationTarget` используется как floor и не уменьшается; подробнее — в [ROTATION_ALGORITHM.md](ROTATION_ALGORITHM.md).

Snapshot хранит номер схемы/алгоритма и позицию журнала. Если версия не совпала, snapshot отсутствует либо нарушены инварианты, проекция строится заново. Такой подход позволяет исправлять алгоритм миграцией без выдумывания истории.

## Модель данных

Названия таблиц реализации могут отличаться, но смысл и границы сохраняются.

### Пользовательские данные

| Сущность | Основные поля | Назначение |
|---|---|---|
| `MasteredSurah` | `surahId`, `customDisplayName`, `displayOrder`, `isActive`, `rotationScore`, timestamps | пользовательская запись выученной суры и текущая проекция |
| `RotationScheme` | id, `surahId`, version, ayah-count snapshot, baseline, journal boundaries | неизменяемая версия разбиения суры |
| `RotationPart` | id, `schemeId`, ordinal, ayah range, cached score/count/time | непрерывная часть и её текущая проекция |
| `RotationState` | singleton/id, `rotationTarget` (начально `1`), projection version | глобальная проекция цикла |
| `RotationAdjustmentEvent` | id, `surahId`, signed `delta`, reason, UTC time | ручной перенос баланса без изменения истории чтений |
| `PrayerSession` | id, `prayerType`, `isQada`, UTC/local time | контекст одного или нескольких чтений; может быть упрощён до snapshot контекста в событии |
| `RecitationEvent` | UUID, `surahId`, `rotationSchemeId`, `rakaatSpanCount`, prayer snapshot, `createdAtUtc`, occurrence `localDate`, deletion marker | неизменяемый факт одного пользовательского действия |
| `RecitationEventPart` | `eventId`, `schemeId`, `partId` | точное историческое coverage одного события |
| `LearningSurah` | `surahId`, status, stage kind, current ayah/range, `lastUserActivityAtUtc`, inactivity guard | текущая проекция независимого прогресса |
| `LearningEvent` | UUID, `surahId`, type, before/after stage, UTC time, metadata | `repeated`, `learned`, inactivity rollback, undo, completion |
| `AppSetting` | key, typed/serialized value | тема, выбранный контекст, текущая карточка обучения и другие настройки |

Baseline первого включения хранится в `MasteredSurah.activationBaselineScore`, а baseline каждой версии разбиения — в `RotationScheme`. Текущая активность нужна для будущих действий, но не для пересчёта уже состоявшихся чтений. Если синхронизация потребует исторического воспроизведения членства между устройствами, membership events добавляются миграцией схемы.

`customDisplayName` — пользовательский alias и не изменяет официальные метаданные. Официальный номер суры хранится отдельно и остаётся стабильным ключом.

### Quran content

| Сущность | Основные поля | Назначение |
|---|---|---|
| `SurahMetadataCache` | provider id, surah id/number, names, `ayahCount`, source version | только проверенные метаданные поставщика |
| `QuranAyahCache` | surah/ayah, exact Arabic text или translation, source/version | versioned offline-кеш без автоматического изменения текста |
| `QuranWordCache` | surah/ayah/position, exact Arabic word, exact translation, source/version | будущий пословный режим |
| `QuranSourceMetadata` | provider, translation key, version, language, fetchedAt, attribution, license/usage data | происхождение каждого набора контента |

Контентные таблицы не имеют каскадного удаления пользовательских событий.
Bundled Tanzil metadata v1.0 заполняет каталог, а pinned Tanzil Uthmani v1.1
и Tanzil `en.transliteration` читаются из независимо проверяемых
assets и доступны offline без записи в Quran cache. QuranEnc cache хранит
только явно выбранный пользователем version-pinned перевод.

## Инварианты домена

- `rotationTarget >= 1`.
- При отсутствии активных сур target не увеличивается.
- Одна регистрация может увеличить target максимум на один, даже если условие цикла остаётся истинным.
- Первое включение выученной суры задаёт `rotationScore = rotationTarget - 1`.
- Отключение и повторное включение сохраняют score и сами по себе не меняют target.
- Ручная корректировка score не создаёт `RecitationEvent`.
- Возможность каза задаётся нейтральным capability `supportsQada`: пять обязательных типов и Витр поддерживают её, Нафль — нет.
- В активной схеме от одной до `ayahCount` частей, которые без пробелов и пересечений покрывают `1..ayahCount`.
- Coverage всегда относится к той же суре и той же версии схемы, что и событие.
- Пользовательское удаление требует подтверждения; Undo последней регистрации восстанавливает полный pre-action snapshot.
- Quran text, перевод и `ayahCount` принимаются только от проверенного provider без «улучшений».
- Widget `actionToken` является UUID v4 и ID journal event; однажды
  встреченный token, включая tombstone удалённого события, не применяется
  повторно.
- Automatic Prayer Context не создаётся из stale/missing schedule и не
  подменяется молитвой по умолчанию.
- Прошлая `localDate` не означает каза: `isQada` изменяется только явным
  выбором и проверяется через `PrayerType.supportsQada`.
- `rakaatSpanCount` по умолчанию равен 1 и не создаёт соответствия между
  отдельными ракаатами и аятами.

## Prayer Context

Доменное перечисление содержит пять обязательных намазов, Витр и Нафль. `isQada` проверяется через `PrayerType.supportsQada`, без богословского флага `isObligatory`. Некорректно только сочетание типа без capability и `isQada=true`; сейчас это Нафль.

Событие хранит snapshot контекста (`prayerType`, `isQada`), даже если есть ссылка на `PrayerSession`. Поэтому последующее изменение UI-настройки не переписывает историю.

`PrayerRegistrationShortcutResolver` формирует полную пару
`PrayerContext + occurrenceLocalDate` для четырёх app-only сценариев:

- Now использует доступный current resolution;
- Previous prayer использует только пять schedule-derived молитв и требует
  reliable current/adjacent day;
- Yesterday оставляет prayer type ручным, поэтому поддерживает Витр;
- Custom date and prayer принимает обе координаты явно.

Витр и Нафль не выводятся из расписания. В automatic mode ручной выбор в UI
создаёт transient override для одной регистрации и затем очищается, не меняя
persisted mode. Native widget не подписан на этот provider.

## Время и идентификаторы

- `createdAtUtc` сохраняется как фактический UTC-момент ввода записи;
- `localDate` сохраняется отдельно как occurrence prayer day и может быть
  явно прошлой датой;
- доменные решения получают время через `Clock`/`TimeProvider`;
- UUID создаётся через инъецируемый генератор;
- изменение timezone после записи не меняет историческую локальную дату.

## Quran provider boundary

`QuranContentRepository` возвращает типизированные результаты и
provenance metadata. Arabic, transliteration и translation независимы.
`QuranAyahLayers` объединяет их только по exact
`surahNumber/ayahNumber` и display preferences.

QuranEnc adapter сначала читает документированный catalog. Пустой успешный RU
catalog разрешает только audited
`KnownOfficialQuranEncTranslations`. Каждый direct key обязан пройти
runtime probe и pinned per-surah hash. Cache commit выполняется после проверки
полного диапазона `1..ayahCount`; предыдущий verified cache переживает
сетевую ошибку. HTML scraping, private endpoints и generated Quran strings
запрещены.

## Prayer-time boundary

Published `NamozVaqtiUzPrayerTimeProvider`, disposable external month
cache и `AdhanPrayerTimeCalculator` не знают о Drift events.
`PrayerScheduleCoordinator` предпочитает опубликованный месяц и
переходит к честно маркированному расчёту только при пользовательском opt-in.
Raw и effective adjusted times хранятся раздельно.

`PrayerContextResolver` — чистый consumer schedule, mode и
`TimeProvider`. Sunrise остаётся gap. Витр, Нафль и каза не выводятся
автоматически. Stale/future/mismatched schedule даёт null context и отключает
direct mark. Детали: [PRAYER_TIME_ARCHITECTURE.md](PRAYER_TIME_ARCHITECTURE.md).

Новая установка содержит только неподтверждённый placeholder location. После
явного выбора региона/location включается automatic mode, если пользователь ещё
не выбирал mode сам; до reliable schedule resolver и widget остаются
fail-closed. Settings JSON schema 2 хранит `locationConfirmed` и
`contextModeExplicitlyChosen`.

Legacy migration не меняет намерение пользователя. JSON schema 1 сохраняет
mode как явно выбранный; non-default region/user coordinates подтверждают
location, но старый default Toshkent остаётся безопасным unconfirmed
placeholder. Если settings JSON вообще отсутствует, но отдельно сохранён
Prayer Context, repository возвращает manual mode с
`contextModeExplicitlyChosen=true`, также не подтверждая placeholder.

Minute timer поддерживает presentation, но write boundary не доверяет
захваченному UI-state: current automatic context и cache freshness повторно
разрешаются непосредственно перед регистрацией. Now/Previous в открытой
historical sheet тоже пересчитываются при выборе и подтверждении.

## Interactive widget boundary

Snapshot schema 3 содержит display-ready rows и необязательные action schema 1.
Kotlin валидирует и передаёт action официальному home_widget background
receiver. Headless Dart заново проверяет текущую схему, часть, active state и
Prayer Context, затем вызывает тот же `RecitationApplicationService`.
На tap нет HTTP. После любого outcome snapshot перестраивается из базы; database
закрывается только после awaited transaction/refresh. Детали:
[INTERACTIVE_ANDROID_WIDGET.md](INTERACTIVE_ANDROID_WIDGET.md).

Widget action не принимает historical occurrence и не читает transient
app override. Дата и Prayer Context определяются заново на execution time из
persisted current settings; при недоказанном контексте действие отклоняется.

## Расширения вне Sprint 5

- `RecitationRuleService` — точка подключения будущих подтверждённых правил; сейчас разрешает любой выбор.
- интерфейс export/sync отделён от Drift DAO, чтобы позже передавать пользовательские события серверу;
- notification/audio/qibla и дополнительная религиозная логика требуют
  отдельного product/source review;
- iOS WidgetKit и iOS location QA вынесены в отдельный sprint;
- backend adapter будет добавлен рядом с локальным repository, не вместо него.

## Безопасность и приватность

- секреты поставщиков, keystore, Apple certificates и credential-файлы не входят в репозиторий или APK/IPA;
- API, требующий client secret, в будущем вызывается только через backend proxy;
- запрещены scraping HTML и неофициальные private endpoints;
- пользовательские события не отправляются наружу в Sprint 5;
- координаты запрашиваются только по явному tap, не сохраняются как
  background-location history и не отправляются Namoz-vaqti.uz;
- в логах не должны появляться полная история пользователя, токены или полный payload Quran API;
- входящие данные provider валидируются по типам, номерам сур/аятов и версии до помещения в cache, но сам религиозный текст не нормализуется;
- экспорт/backup в будущем является явным действием пользователя и не включает Quran cache по умолчанию;
- удаление истории и сброс баланса подтверждаются; обычная регистрация остаётся быстрой;
- app-level шифрование локальной БД не заявляется как реализованное: текущая версия полагается на sandbox и защиту устройства, а усиление хранения требует отдельного threat model.

## Миграции и отказоустойчивость

Drift schema version изменяется только с описанной миграцией. Перед миграцией, затрагивающей проекции, сохраняется журнал; после неё проекции можно rebuild. Повреждение Quran cache не должно затронуть пользовательские таблицы: cache разрешено очистить и загрузить заново после проверки источника.

Операции записи событий, удаления, Undo и обновления snapshot выполняются транзакционно. Нарушение инварианта приводит к безопасной ошибке и сохранению предыдущего состояния, а не к частичному увеличению счётчиков.
