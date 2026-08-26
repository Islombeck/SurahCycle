# Архитектура Prayer Times

## Границы

Sprint 4 разделяет опубликованное расписание, математический расчёт,
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
`prayer_time_cache_v1` и не меняет Drift schema v3.

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

## Проверки

Unit/widget tests покрывают provider URL и строгий parser, полный месяц,
неверный region/parent/month/content type/размер, cache freshness, offline
fallback, cache keys, все calculation presets, Hanafi vs Shafi, sunrise gap,
midnight boundaries, Witr/Nafl/Qada, location deny и отсутствие permission
request до tap. Reference fixtures не используются для искусственной коррекции
результатов.

Аудит источников и ограничения описаны в
[PRAYER_TIME_SOURCE_AUDIT.md](PRAYER_TIME_SOURCE_AUDIT.md).
