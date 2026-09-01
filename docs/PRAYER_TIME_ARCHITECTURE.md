# Архитектура Prayer Times

## Границы

Sprint 5 разделяет опубликованное расписание, математический расчёт,
persisted settings и определение Prayer Context:

`text
Settings / explicit refresh
          |
          v
PrayerScheduleUseCases
          |
          v
PrayerScheduleCoordinator
    | published first                  | opt-in fallback
    v                                  v
CachingPrayerScheduleRepository   AdhanPrayerTimeCalculator
    |                                  |
    v                                  v
NamozVaqtiUzProvider              calculated month
          \                            /
           +--> PrayerMonthSchedule --+
                        |
                        v
              PrayerContextResolver
`

Provider и calculator реализуют разные interfaces и несут разный
`PrayerTimeSourceKind`. UI всегда показывает source, provenance и
состояние cache; calculated result не может быть переименован в опубликованный.

## Загрузка и cache

`PrayerScheduleUseCases` загружает текущий месяц для Home. Явное
обновление запрашивает текущий и следующий месяц. Cache хранится отдельными
versioned JSON-файлами в application-support directory
`prayer_time_cache_v1` и не меняет Drift schema v4.

Ключ опубликованного месяца включает source, provider region и `YYYY-MM`.
Ключ расчёта дополнительно включает method, Asr school, high-latitude rule и
координаты. Это исключает повторное использование результата с другими
параметрами.

Freshness policy — 35 дней с допустимым clock skew 5 минут. При сетевой ошибке
ранее проверенный cache может отображаться как stale, но stale/future-timestamp
schedule не разрешает automatic direct mark. Corrupt external cache
fail-closed и не влияет на пользовательскую историю.

Coordinator сначала запрашивает Namoz-vaqti.uz. Локальный расчёт используется
только когда пользователь включил calculated fallback или выбрал собственные
координаты. Если расчёт также не удался, доступный опубликованный cache всё ещё
может быть показан с честным freshness state.

`loadToday` дополнительно пытается получить соседний день. На границе месяца
это best-effort загрузка соседнего месяца: её сбой не скрывает исправное
расписание текущего дня, но запрещает решение, которому нужен неподтверждённый
соседний день. До явного подтверждения региона или location расписание вообще
не запрашивается.

## Bootstrap и совместимость настроек

Новая установка начинает без доверенного местоположения:

- сохранённый Toshkent используется только как placeholder selector;
- `locationConfirmed=false`, поэтому ни Home, ни widget не считают его
  реальным местом пользователя;
- целевой режим после подтверждения location — automatic, пока пользователь
  явно не выбрал manual/automatic сам;
- до подтверждения и до появления reliable schedule контекст равен null,
  direct mark выключен; startup не подставляет фиктивный Фаджр.

Versioned settings JSON schema 2 хранит `locationConfirmed` и
`contextModeExplicitlyChosen`. Выбор региона или собственных координат ставит
первый флаг; если второй ещё false, включается automatic mode. Явное
переключение mode ставит второй флаг и после этого не переопределяется выбором
location.

Совместимость существующих установок консервативна:

- settings JSON schema 1 сохраняет записанный manual/automatic mode как явно
  выбранный; non-default region или user coordinates считаются доказанным
  выбором location, но старый default Toshkent остаётся неподтверждённым
  placeholder;
- если settings JSON отсутствует, но в старом отдельном ключе есть выбранный
  Prayer Context, это также считается явным legacy manual choice;
- во втором случае placeholder location остаётся неподтверждённым. Так
  существующий ручной контекст сохраняется без скрытого сетевого запроса и без
  молчаливого перехода в automatic mode.

## Модель времени

`PrayerDaySchedule` хранит шесть границ:

- Фаджр;
- восход;
- Зухр;
- Аср;
- Магриб;
- Иша.

Восход — граница, а не `PrayerType`. Интервал после восхода до Зухра
явно возвращает `betweenPrayers` и не подставляет Фаджр или Зухр.

Для пяти молитв хранится raw provider/calculator time и effective time после
пользовательской поправки. Допустимы отдельные offsets для Фаджра, Зухра,
Асра, Магриба и Иша; default 0. Поправка обязана сохранять строгий
хронологический порядок, иначе настройки отклоняются. Восход не корректируется.

Витр, Нафль и каза остаются ручными:

- Витр доступен как отдельный Prayer Context и поддерживает каза;
- Нафль не выводится автоматически и не поддерживает каза;
- автоматический resolver выбирает только пять дневных молитв;
- ручной режим сохраняет уже существующий выбор пользователя.

Все решения получают текущее UTC-время через `TimeProvider` и переводят
его в локальную дату с persisted timezone/offset. После следующей локальной
полуночи Riverpod provider инвалидируется, чтобы не оставить вчерашний день.

Историческое событие хранит две независимые временные координаты:

- `createdAtUtc` — фактический UTC-момент, когда пользователь добавил запись;
- `localDate` — локальный prayer day, когда чтение произошло.

`RecitationApplicationService.registerFromApp` принимает выбранный
`occurrenceLocalDate`, но всегда получает `createdAtUtc` из `TimeProvider` в
момент записи. Поэтому добавление вчерашнего чтения сегодня не переписывает
время ввода, а последующая смена timezone не меняет сохранённый prayer day.

## Историческая регистрация

Полное приложение предлагает четыре shortcuts, которые возвращают законченный
набор `PrayerContext + occurrenceLocalDate`:

- **Now** — доступный текущий контекст и сегодняшняя дата региона;
- **Previous prayer** — предыдущая из пяти молитв только по reliable schedule;
  на границе дня требует reliable previous day и никогда не придумывает Витр;
- **Yesterday** — вчерашний prayer day и явно выбранная молитва, включая Витр;
- **Custom date and prayer** — обе исторические координаты выбираются явно.

Недостающий, stale или mismatched schedule делает зависимый shortcut
недоступным, а не подставляет дату или молитву. Витр и Нафль не получают
вычисленную границу: они доступны только как ручной выбор. Прошлая дата сама по
себе не означает каза — `isQada` изменяется только отдельным явным действием
пользователя и остаётся ограничен `PrayerType.supportsQada`.

## Automatic Prayer Context

`PrayerContextResolver` принимает manual/automatic mode и явно
помеченную надёжность текущего и соседних дней.

- manual mode возвращает persisted Prayer Context;
- automatic mode требует schedule текущей локальной даты и reliable cache;
- до Фаджра Иша прошлого дня допустима только при надёжном соседнем дне;
- Фаджр заканчивается на восходе;
- после восхода и до Зухра direct mark выключен;
- Зухр, Аср и Магриб заканчиваются следующей границей;
- Иша продолжается до следующего Фаджра, если соседний день подтверждён.

Null context всегда отключает регистрацию. UI и widget не подставляют
`Fajr` или другой default при missing/stale schedule.

Minute-aligned timer обновляет отображение Home, но не является границей
корректности. Перед current automatic registration приложение повторно
вычисляет контекст по текущему `TimeProvider`, matching schedule и заново
проверенной 35-дневной freshness. Поэтому задержанная перерисовка, смена
молитвы или истечение cache между build и tap не могут записать старый
контекст. Now/Previous также повторно разрешаются при tap/confirm открытой
панели.

В automatic mode ручной выбор в полном приложении создаёт transient override
ровно для ближайшей регистрации. Он позволяет явно отметить Витр, Нафль или
каза, не меняет persisted mode и очищается после успешной записи, после чего
Home снова использует automatic resolver. Native widget этот override не
читает и продолжает показывать/записывать только доказанный текущий контекст.

## Widget execution path

Direct widget action не выполняет HTTP. Headless bootstrap открывает Drift,
читает prayer settings и:

- в manual mode читает persisted Prayer Context;
- в automatic mode читает только локальный месячный cache;
- при включённом fallback может локально рассчитать месяц по уже сохранённым
  параметрам и отдельно проверенным координатам;
- определяет контекст именно на execution time;
- при missing/unreliable schedule отклоняет mark и публикует безопасный widget
  snapshot с disabled actions.

Widget — только current-context/current-date surface. Он не предлагает
исторические shortcuts, не принимает `occurrenceLocalDate` из UI приложения и
не видит transient app override.

После action bootstrap ждёт завершения transaction и snapshot refresh и лишь
затем закрывает database. Quran download, translation warmup, location request
и любые network calls в background path отсутствуют.

## UI

Home Prayer Card показывает mode, текущий контекст или причину недоступности,
границы current/next prayer, source и cache state. Settings предоставляет:

- полный audited selector Узбекистана;
- добровольную кнопку location;
- manual/automatic Prayer Context;
- opt-in calculated fallback;
- calculation method и Hanafi/Shafi Asr;
- пять minute adjustments;
- явное обновление расписания.

Advanced registration в Home позволяет выбрать historical occurrence и
1–4 ракаата. Обычная unsplit whole-surah отметка остаётся одним tap, хранит
`rakaatSpanCount=1` и не открывает dialog. В compact History число `1` скрыто
только для этой обычной unsplit whole-surah записи; split/partial/multiple
записи и любое значение больше `1` показывают span. Details всегда показывают
число ракаатов и поясняют, что это общий span события, а не соответствие
отдельных аятов отдельным ракаатам.

## Проверки

Unit/widget tests покрывают provider URL и строгий parser, полный месяц,
неверный region/parent/month/content type/размер, cache freshness, offline
fallback, cache keys, все calculation presets, Hanafi vs Shafi, sunrise gap,
midnight boundaries, Witr/Nafl/Qada, location deny и отсутствие permission
request до tap. Reference fixtures не используются для искусственной коррекции
результатов.

Sprint 5B дополнительно проверяет null startup без fake Fajr, bootstrap новой и
legacy установки (включая отсутствующий settings JSON), adjacent-month
границы, исторические shortcuts, независимые `createdAtUtc`/`localDate`,
явный каза, transient override и compact/detail rakaat presentation.

Аудит источников и ограничения описаны в
[PRAYER_TIME_SOURCE_AUDIT.md](PRAYER_TIME_SOURCE_AUDIT.md).
