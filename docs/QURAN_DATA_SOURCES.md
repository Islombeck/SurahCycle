# Источники Quran content

## Решение Sprint 1

В Sprint 1 в приложение включён только проверенный metadata-файл Tanzil.info. Он содержит каталог 114 сур: номер, имена и количество аятов. Арабский текст аятов, полный и пословный переводы **не встраиваются** и не подменяются данными из памяти разработчика.

Bundled dataset:

- source: `https://tanzil.net/res/text/metadata/quran-data.xml`;
- documentation: `https://tanzil.net/docs/quran_metadata`;
- version: `1.0`;
- copyright: `(C) 2008-2009 Tanzil.info`;
- license attribute: `cc-by`;
- attribution: `Tanzil.info`;
- SHA-256 зафиксированного asset: `8867C1D88191472ADEC9DB694B3CD9F135B1A2EF580574D32CF888DCB22C5C7A`.

`TanzilMetadataProvider` читает asset без сети и принимает его только при точном совпадении header, наличии ровно 114 записей, строгой последовательности уникальных номеров `1..114`, положительном `ayas` и непустых `name/tname/ename`. Строки имён не нормализуются. В пользовательский каталог как `officialName` попадает verbatim `tname`; остальные verbatim-поля остаются доступны через `TanzilSurahMetadata`.

В Sprint 1 обязательны:

- `QuranContentRepository`;
- независимые provider adapters;
- локальный versioned cache;
- provenance metadata;
- состояние UI «текст аятов и переводы ещё не загружены».

Отсутствие provider не блокирует ротацию, историю и обучение уже заведённых пользовательских сущностей, но приложение не подставляет придуманные Quran-данные. Production UI не маскирует тестовые `Test Surah A/B` под реальные суры.

## Непереговорные правила целостности

Запрещено генерировать, угадывать или восстанавливать «примерно»:

- арабский текст Корана;
- текст аята;
- полный перевод;
- пословный перевод;
- количество аятов;
- официальные метаданные суры.

Полученный текст нельзя исправлять, нормализовывать, автоматически переводить, перефразировать или «улучшать». Приложение хранит точное значение поставщика вместе с источником и версией. Структурная валидация ответа допустима, но она либо принимает dataset целиком, либо отклоняет его; она не чинит религиозный текст.

Синтетические названия и artificial ayah IDs допустимы только в unit/widget tests и должны быть явно отделены от production data.

## Граница repository

Домен и UI зависят от интерфейса, а не от конкретного API:

```text
QuranContentRepository
  listTranslations(languageCode?, localizationLanguageCode?)
  getSurahTranslation(translation, surahNumber, refresh?)
```

Каждая операция возвращает типизированный результат: `available`, `notDownloaded`, `updateAvailable`, `unavailable` либо `failed`, а также `QuranSourceMetadata` для доступного dataset. Ошибка сети не стирает последний проверенный cache.

Provider adapter отвечает только за официальный транспорт, декодирование структуры и provenance. Repository выбирает cache/provider, а presentation отображает явные состояния. Ни один слой не вставляет fallback-текст «для красоты».

## Модели

### Canonical metadata

```text
SurahMetadata
  providerId
  sourceVersion
  id
  number
  arabicName?
  transliteratedName?
  localizedName?
  ayahCount
```

Поля nullable, если утверждённый dataset их не предоставляет. Пользовательский `customDisplayName` хранится рядом с `MasteredSurah`, а не переписывает canonical metadata.

### Ayah

```text
QuranAyah
  surahNumber
  ayahNumber
  arabicText?
  fullTranslation?
  translationSource?
  translationVersion?
```

### Word

```text
QuranWord
  surahNumber
  ayahNumber
  position
  arabicText
  translation?
```

Отсутствующее поле остаётся отсутствующим. Нельзя собирать полный перевод из пословного или наоборот без явного утверждённого dataset.

### Provenance

Для каждого набора сохраняются:

```text
source/provider
dataset or translationKey
version
language
fetchedAtUtc
attribution
license/usage information
source URL or official identifier
integrity checksum, если опубликован или вычислен при загрузке
```

Метаданные происхождения должны позволять понять, какой именно набор сейчас отображён, и удалить/заменить его независимо от пользовательской истории.

## Кандидаты providers

Кандидаты ниже — архитектурные adapters, а не утверждение о разрешении включить их данные в дистрибутив.

### `QuranEncProvider`

Реализован adapter документированных публичных translation endpoints QuranEnc. Он получает каталог переводов без hardcoded translation key, ограничивает timeout/размер ответа, валидирует координаты и сохраняет строку перевода без изменений вместе с `translationKey`, языком, версией и attribution. Поле Arabic из translation response намеренно игнорируется: этот provider в Sprint 1 утверждён только как источник переводов. Provider не включён автоматически и не участвует в запуске основной offline-функциональности.

### `QuranAcademyProvider` / Digital Quran

Подготовлена только backend-proxy граница. Прямые credentials в мобильном приложении запрещены; adapter разрешено активировать только через документированный официальный интерфейс и наш будущий backend.

- HTML scraping запрещён;
- неофициальные private endpoints запрещены;
- если требуется регистрация приложения, соблюдаются опубликованные условия;
- если требуется секрет, который нельзя безопасно хранить в мобильном клиенте, adapter остаётся выключенным до появления backend proxy;
- официальный downloadable dataset с подходящей лицензией предпочтительнее scraping.

### Другие источники

Новый provider проходит ту же проверку и реализует тот же repository contract. Его добавление не должно требовать изменения ротации, learning state machine или пользовательских таблиц.

## Проверка перед подключением

Provider допускается в production только после документированной проверки:

1. URL и владелец официального источника подтверждены.
2. Используется публично документированный API или официальный downloadable dataset.
3. Лицензия разрешает конкретные действия: загрузку, локальный cache, отображение и при необходимости redistribution в приложении.
4. Записаны обязательные attribution и notice.
5. Понятны версия, обновления и политика исправлений поставщика.
6. Проверено, требуются ли credentials и можно ли безопасно использовать их в public mobile client.
7. Получен контрольный sample без ручного изменения текста; проверены схема и полнота.
8. Определена стратегия удаления/отката проблемной версии.
9. Решение и дата проверки зафиксированы в репозитории.

Если любой пункт неясен, dataset не включается.

## Cache и offline

Контент загружается сначала во staging-область. После проверки структуры, связности метаданных и provenance dataset атомарно становится активным. Неуспешное обновление оставляет предыдущую проверенную версию доступной offline.

Минимальные cache-сущности:

- `SurahMetadataCache`;
- `QuranAyahCache`;
- `QuranWordCache`;
- `QuranSourceMetadata`.

Cache version привязывает записи к provider/dataset/version/language. При смене перевода старая и новая версии не смешиваются. Очистка cache не имеет foreign-key cascade на `MasteredSurah`, `RecitationEvent` или `LearningEvent`.

Quran cache не обязан входить в пользовательский export: его безопаснее повторно получить из того же проверенного источника. История пользователя хранит стабильный `surahId/number` и при необходимости ссылку на использованную metadata version.

## UI при отсутствии данных

Допустимые состояния:

- «Каталог сур доступен; текст аятов и переводы ещё не загружены»;
- «Источник пока не настроен»;
- «Нет сети; используется ранее загруженная версия»;
- «Обновление не удалось; сохранённая версия не изменена».

Недопустимо показывать выдуманный арабский текст, перевод или `ayahCount`. Проверенный `ayahCount` берётся из Tanzil metadata. Элементы, которым нужен текст аята, показывают явное unloaded-состояние; ротация и learning state machine продолжают работать по сохранённым метаданным.

## Секреты и транспорт

- client secret никогда не помещается в Dart source, assets, `.env` приложения, APK или IPA;
- public API key допускается только после проверки модели угроз и условий provider, но не коммитится как «секрет»;
- секретный API вызывается будущим backend по TLS; mobile получает краткоживущий/публичный контракт без provider secret;
- ответы ограничиваются по размеру, имеют timeout и валидируются перед записью;
- логи не содержат credentials или полный payload;
- сертификаты и keystore не хранятся в Git.

Будущая серверная схема описана в [SERVER_PLAN.md](SERVER_PLAN.md).
