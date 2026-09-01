# Product Spec — Sprint 5

## Продуктовая цель

Murajaah заменяет ручной список повторения сур: помогает равномерно
использовать выученные суры, быстро фиксировать чтение в Prayer Context и
постепенно учить новые суры. Основные действия local-first, без обязательного
аккаунта, сервера или постоянного Интернета.

Главный принцип: корректность пользовательской истории, Prayer Context и Quran
content важнее количества функций.

## Реализованный объём

Sprint 5 сохраняет весь объём Sprints 1–4:

- мигрируемая Drift schema v4 и локальный event journal;
- список выученных сур, aliases, порядок и active/inactive rotation;
- versioned whole/split schemes, exact part coverage и 1–4 ракаата;
- `RotationEngine`, due state, до восьми объяснимых ranked
  recommendations и отдельные full-equivalent/action/part-credit metrics;
- manual Prayer Context с Фаджром, Зухром, Асром, Магрибом, Иша, Витром,
  Нафлем и capability каза;
- atomic registration, краткоживущий Undo, History Delete и projection rebuild;
- независимая `LearningStateMachine` с cumulative stages;
- RU/EN/UZ Material 3 UI;
- Android Rotation/Learning widgets;
- Tanzil metadata v1.0 и exact Uthmani v1.1 Arabic offline;
- отдельный язык перевода, явный RU/UZ QuranEnc translation selector и versioned offline cache;
- профиль `Latin — Tanzil`; Cyrillic видим, но недоступен до подключения полного проверенного источника.

Ключевой объём Sprint 4:

1. Геометрически стабильный recommendation rank badge 1–8. Один компонент
   используется при text scale 1.0, 1.3 и 1.5; rank не смешивается с номером
   суры.
2. Диагностику пустого RU QuranEnc catalog и audited fallback registry
   `russian_rwwad` / `russian_aboadel` с runtime probes и
   corpus/surah SHA-256 pins.
3. Pinned Tanzil `en.transliteration` как независимый verified
   offline repository. Transliteration не генерируется из Arabic.
4. Три независимых Quran display layers: Arabic, transliteration и translation.
   Settings применяются к Learning, Home Learning Card и Learning Widget.
5. Structured Learning Widget ayah blocks, связывающие три слоя одной
   координатой.
6. Direct mark из круглого control Rotation Widget через официальный
   home_widget background flow, exact-once `actionToken` и повторную
   Dart validation.
7. Опубликованное месячное расписание Namoz-vaqti.uz, audited selector
   Узбекистана, offline cache и видимый provenance.
8. Добровольную location только после tap и без background tracking.
9. Opt-in local calculation через `adhan_dart` с method, Hanafi/Shafi
   Asr, high-latitude rule и ручными minute adjustments.
10. Manual/automatic Prayer Context с fail-closed поведением при stale/missing
    schedule и явным sunrise gap.

Sprint 5B добавляет:

1. Регистрацию чтения за текущий или прошлый prayer day без искажения момента,
   когда запись была добавлена.
2. Shortcuts Now, Previous prayer, Yesterday и Custom date and prayer с
   fail-closed разрешением даты и контекста.
3. Безопасный startup: новая установка не доверяет placeholder-региону и не
   подставляет Фаджр до подтверждения location и reliable schedule.
4. Совместимость с ранее выбранным manual mode, включая установку с сохранённым
   Prayer Context, но без prayer-time settings JSON.
5. One-event manual override в automatic mode только внутри приложения;
   native widget остаётся current-context/current-date.
6. Default один ракаат, advanced выбор 1–4 и менее шумное отображение ракаатов
   в History без моделирования соответствия аятов отдельным ракаатам.

Функции вне scope перечислены в [BACKLOG.md](BACKLOG.md).

## Главный сценарий ротации

Пользователь выбирает выученные суры и включает их в rotation. Новая сура
получает один шаг долга относительно текущей цели; повторное включение не
теряет прежний score. Аль-Фатиха остаётся в catalog, Learning и History, но
не участвует в rotation.

Home показывает до восьми рекомендаций с фиксированным rank badge, затем все
active surahs. У whole row круглая кнопка одним tap создаёт одно событие с
одним ракаатом и без dialog; отдельная advanced-кнопка открывает historical,
coverage и rakaat options. У split row основная кнопка в приложении открывает
выбор одной/нескольких/всех частей и 1–4 ракаатов. В Android widget каждая
split-row отмечает только показанную часть и использует один ракаат.

После commit пересчитываются rotation и widgets. Undo восстанавливает точный
pre-action snapshot. History Delete требует подтверждения, сохраняет tombstone
event ID и не позволяет старому widget action создать событие повторно.

## Learning audio

The selected Learning card can stream its current stage from a dynamic Hafs catalog. The user chooses a reciter/moshaf and repeat count (1, 3, 5, 10, or explicit infinity), can play, pause/resume, and stop, and sees the riwaya and timing capability. With verified timing, a new-ayah stage plays that ayah and a review stage plays its exact range. Without verified timing, the product says so and offers only the full surah. Background playback exposes Android media controls and never reuses the ordinary Learning notification as a media session.

## Quran content

### Источники

- names/ayah counts: bundled Tanzil metadata v1.0;
- Arabic: bundled Tanzil Uthmani v1.1, exact offline corpus;
- transliteration: bundled Tanzil English Transliteration
  `en.transliteration`, exact offline corpus;
- translation: выбранный пользователем audited QuranEnc dataset, загруженный
  через документированный JSON API и сохранённый versioned cache.

Каждый corpus проверяет hash, expected metadata и все 6 236 coordinates.
Religious strings не trim-ятся, не нормализуются, не исправляются и не
генерируются. Missing layer остаётся missing и не блокирует остальные.

Документы:

- [QURAN_DATA_SOURCES.md](QURAN_DATA_SOURCES.md);
- [QURAN_TRANSLITERATION.md](QURAN_TRANSLITERATION.md);
- [QURAN_TRANSLATION_LICENSE_AUDIT.md](QURAN_TRANSLATION_LICENSE_AUDIT.md).

### Display settings

Три switches управляют Arabic, transliteration и translation независимо.
По умолчанию все включены. Хотя бы один слой всегда может быть отображён;
presentation сохраняет coordinate alignment.

Learning Screen показывает каждый аят вертикальным блоком: Arabic RTL,
transliteration и translation. Cumulative stage показывает весь накопленный
range, а не только последний аят. Home Learning Card использует тот же порядок
в compact layout. Learning Widget получает до трёх последних аятов диапазона и
выбирает слои по тем же persisted settings; translation появляется только
после verified cache.

### Translation UX

Пустой успешный RU catalog — отдельное диагностируемое состояние upstream.
Только при нём provider проверяет два заранее audited official keys. Каждый key
должен пройти live direct probe и pinned hash; ни один не выбирается
автоматически. UI показывает точные title/source/version и состояния
downloaded, unavailable и failure. Последний проверенный cache остаётся
доступным offline.

Bundled Tanzil Transliteration разрешён только для текущей
private/testing/non-commercial сборки. Commercial/monetized release с этим
asset заблокирован до отдельного разрешения.

## Prayer Times

### Основной provider

Пользователь явно подтверждает область, город или location. До этого выбранный
в selector Toshkent остаётся только placeholder и не запускает загрузку.
Namoz-vaqti.uz загружает полный текущий месяц, а явный refresh — текущий и
следующий. UI показывает raw/effective times, source, provider region,
fetched/cache state и attribution. Это расписание на основе официальных
источников Узбекистана, но не «official OMI API».

Cache внешней месячной data отделён от пользовательской Drift database. Сбой
сети не стирает предыдущий месяц. Stale schedule разрешено показать, но не
использовать для automatic direct mark.

### Location и calculation

GPS не требуется. Кнопка «Использовать моё местоположение» запрашивает
permission только после tap; deny возвращает пользователя к manual selector.
Background location отсутствует.

Calculated fallback выключен по умолчанию и подписан как расчёт. Доступны
presets библиотеки `adhan_dart`, Hanafi/Shafi Asr и high-latitude
rules. Default Uzbekistan fallback — Karachi + Hanafi, но не метод ОМИ.
Пользователь может добавить отдельные offsets для Фаджра, Зухра, Асра,
Магриба и Иша; raw provider/calculator values сохраняются.

### Manual и automatic Prayer Context

Manual mode использует сохранённый выбор, включая Витр, Нафль и каза.
Automatic mode выбирает только Фаджр/Зухр/Аср/Магриб/Иша по надёжному schedule
текущей локальной даты:

- до восхода — Фаджр;
- восход → Зухр — gap без direct mark;
- затем контекст действует до следующей prayer boundary;
- Иша пересекает полночь только с надёжным соседним днём.

Home Card показывает current interval, next prayer и причину disabled state.
Widget вычисляет контекст на execution time только из persisted settings,
локального cache или локального calculation; HTTP на tap отсутствует.

У новой установки mode по умолчанию automatic, но он начинает работать только
после явного подтверждения location и получения reliable schedule. До этого
контекст отсутствует и direct mark выключен; fake Fajr не создаётся. Явный
выбор manual/automatic запоминается и больше не меняется автоматически при
выборе location.

Миграция сохраняет поведение существующих пользователей. Settings JSON schema
1 сохраняет mode; non-default region или user coordinates считаются явным
выбором location, но старый default Toshkent остаётся неподтверждённым
placeholder. Если settings JSON отсутствует, но отдельно сохранён Prayer
Context, установка остаётся в manual mode без подтверждения placeholder.

Ручной выбор во время automatic mode действует как one-event app-only
override и очищается после успешной регистрации. Он не переключает persisted
mode. Native widget override не видит и продолжает использовать только
текущий контекст, доказанный persisted settings и schedule.

### Историческая регистрация

Каждая запись разделяет момент ввода и день события:

- `createdAtUtc` — когда пользователь нажал подтверждение;
- `localDate` — выбранный локальный prayer day чтения.

Now использует доступный текущий контекст; Previous prayer — только предыдущую
из пяти schedule-derived молитв и reliable соседний день при переходе через
границу даты; Yesterday оставляет молитву ручным выбором; Custom позволяет
явно выбрать дату и молитву. Витр не вычисляется и не подставляется расписанием,
но доступен для Yesterday/Custom и ручного Now. Прошлая дата не включает каза:
`isQada` остаётся отдельным явным выбором пользователя.

History показывает prayer type и occurrence date отдельно от строки «Добавлено»
с реальным временем ввода. В compact row значение «1 ракаат» скрывается только
для обычного unsplit whole-surah one-tap; split/partial/multiple span виден.
Details всегда показывает число и пояснение: приложение хранит span события,
но не сопоставляет конкретные аяты конкретным ракаатам.

Current automatic context повторно разрешается в момент действия, а freshness
schedule пересчитывается по текущим часам. Поэтому запись не доверяет
контексту, который был показан до смены молитвы или до истечения cache;
панели Now/Previous также перепроверяют выбор при подтверждении.

Подробности:

- [PRAYER_TIME_SOURCE_AUDIT.md](PRAYER_TIME_SOURCE_AUDIT.md);
- [PRAYER_TIME_ARCHITECTURE.md](PRAYER_TIME_ARCHITECTURE.md).

## Android widgets

Rotation Widget показывает due-only projection. Круг mark вызывает headless
Dart callback; текст строки открывает app. `actionToken` становится ID
event journal, поэтому redelivery и double tap exact-once. Перед записью
повторно проверяются surah, active state, current scheme, part и execution-time
Prayer Context. Stale action отклоняется и widget перестраивается из базы.
Исторические shortcuts и transient app override в widget не передаются: его
mark всегда относится к текущей локальной дате и execution-time контексту.

Learning Widget показывает coordinate-bound Arabic/transliteration/translation.
Kotlin/Glance не исполняет доменные правила и не открывает Drift.

Контракты:

- [ANDROID_WIDGETS.md](ANDROID_WIDGETS.md);
- [INTERACTIVE_ANDROID_WIDGET.md](INTERACTIVE_ANDROID_WIDGET.md).

## Offline и сохранность

Rotation, manual registration, History, Statistics, Settings и Learning
работают локально. Arabic и transliteration bundled. Загруженная translation и
monthly prayer schedule остаются offline. Сбой content/schedule provider не
повреждает event journal. Automatic mark fail-closed, если его контекст нельзя
доказать.

## UX и доступность

- одна явная зона mark и отдельная navigation target;
- fixed badge geometry при поддерживаемых text scales;
- Material 3, светлая/тёмная темы и RU/EN/UZ;
- Arabic RTL; transliteration/translation используют обычное направление;
- source/provenance видимы;
- destructive History/reset actions требуют подтверждения;
- нет рекламы, streaks, социальных функций и лишнего onboarding.

## Критерии приёмки Sprint 5

Автоматически проверяются:

- Sprint 3 regression suite и новые domain/provider/widget tests;
- три Quran layers и их combinations;
- verified translation/transliteration integrity;
- полный prayer provider/cache/calculator/resolver flow;
- new-user и legacy bootstrap без fake default prayer;
- historical shortcuts, past-date/non-Qada и Witr manual scenarios;
- независимые occurrence/created timestamps и rakaat History presentation;
- direct widget validation, exact-once и native contract;
- Flutter analyzer, Kotlin tests/compile и debug APK build.

На физическом Android отдельно проверяются launcher rendering, circle/text
targets, foreground/background/swiped-away/killed callback, History/Delete
refresh, airplane-mode cache, permission flow и latency. Если ADB не видит
device, документ не объявляет эти проверки выполненными.

Этот spec описывает реализованное поведение; фактические результаты конкретного
прогона приводятся в Sprint report, а не предполагаются здесь.
