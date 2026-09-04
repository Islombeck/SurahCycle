# Interactive Android Rotation Widget

## Контракт действия

Rotation Widget использует snapshot schema 5. Каждая eligible due-row получает
от Dart необязательный action schema 2:

```json
{
  "schemaVersion": 2,
  "actionToken": "uuid-v4",
  "surahId": "112",
  "rotationSchemeId": "scheme-id",
  "partId": null,
  "prayerSessionId": "routine:fajr:2026-09-04",
  "prayerSessionPartId": "routine:fajr:2026-09-04:part:fard",
  "slotIndex": 0
}
```

`actionToken` уникален внутри опубликованного snapshot. Для
неразделённой суры action покрывает единственную rotation part; для разделённой
строки action указывает ровно один `partId`. Если для текущего prayer context и
даты есть routine, все три session-slot поля обязательны и указывают ровно на
next free slot current part. Rows без надёжного Prayer Context, с ненадёжной
routine projection или с завершённой routine не получают action.

Snapshot также содержит готовые локализованные `currentPartLabel` и
`slotProgressLabel`. Kotlin только отображает их; он не определяет порядок
частей и не вычисляет slot progress.

Круглая кнопка mark и текстовая область — разные targets:

- круг вызывает Glance `actionRunCallback<RotationWidgetMarkAction>`;
- Kotlin преобразует уже проверенный payload в
  `HomeWidgetBackgroundIntent` и отправляет broadcast;
- текст, header и footer используют `actionStartActivity` и открывают
  приложение по строгому deep link;
- mark не открывает Activity, а tap строки не создаёт событие.

Kotlin не открывает Drift, не выбирает Prayer Context и не применяет rotation
logic. Его роль — строгая schema validation, отображение и транспорт action.

## Dart background callback

`main()` регистрирует top-level callback через официальный
`HomeWidget.registerInteractivityCallback`. Android manifest содержит
`HomeWidgetBackgroundReceiver`. При broadcast plugin запускает
headless Flutter engine и передаёт URI
`murajaah-widget://recitation?...` в callback.

Lightweight bootstrap инициализирует Flutter binding, открывает текущую Drift
database и создаёт только необходимые repositories/application services.
Полный Riverpod app graph, router, Quran providers и HTTP client не
поднимаются.

## Exact-once и stale actions

`actionToken` одновременно служит ID доменного
`RecitationEvent`. `registerFromWidget` сначала проверяет
весь event journal, включая deleted tombstones, а затем выполняет
`registerOnce`. Повторная доставка, быстрый double tap или retry с тем
же token возвращает `duplicate` и никогда не повышает rotation второй
раз. Для следующего опубликованного snapshot создаются новые tokens, поэтому
следующее осознанное нажатие работает.

До записи Dart заново проверяет:

- UUID v4 и строгую URI/schema;
- существование и active state суры;
- исключение Аль-Фатихи из rotation;
- точное совпадение текущего `rotationSchemeId`;
- отсутствие `partId` для unsplit или существование ровно этой части
  для split;
- Prayer Context и current local date на execution time;
- полную session/part/slot tuple, принадлежность session, first incomplete
  part, диапазон и exact next-free slot.

Если scheme/part/activation изменились после публикации snapshot, action
считается stale и отклоняется. Уже применённый token остаётся duplicate даже
если событие позже удалено из History; удаление не даёт старому widget intent
создать его снова.

Action schema 1 остаётся parseable только ради уже закешированных launcher
payload. Она не может обойти новую routine: execution-time repository
отклоняет slotless действие, если для exact prayer/date уже существует
session-part snapshot или включён непустой template. Если routine отсутствует,
legacy action сохраняет прежнее корректное поведение.

## Результат и восстановление UI

После registered, duplicate, rejected, malformed или failed outcome handler
пытается заново собрать rotation projection из текущей базы и обновить оба
Android widgets. Ошибка не создаёт optimistic checked state. Для failure
публикуется disabled action state; launcher возвращается к данным базы.

Bootstrap использует `await` на полном handler Future и закрывает
database только после transaction и refresh. Это важно для killed/swiped-away
headless execution.

Automatic Prayer Context разрешается из persisted settings и надёжного
локального cache/локального calculation. На widget tap нет HTTP и нет
location request. При отсутствии надёжного контекста mark fail-closed.

После успешной exact-slot записи новый snapshot отмечает суру только внутри
текущей session part, обновляет slot progress и переводит действие на
следующий слот/часть. Global `remaining` и current-part checked state остаются
разными значениями.

## Версии и совместимость

- snapshot schema 5 — текущая;
- native decoder принимает schema 2/3/4/5, причём старые snapshots остаются
  display-compatible и не получают выдуманные routine coordinates;
- action schema 2 добавляет session/part/slot как all-or-none tuple;
- action schema 1 принимается как legacy transport и проверяется fail-closed;
- Dart snapshot decoder принимает только текущую schema 5;
- main Drift database использует schema 5 для prayer routines и nullable
  event slot links; exact-once token по-прежнему не требует отдельной таблицы.

Подробный display contract и build notes:
[ANDROID_WIDGETS.md](ANDROID_WIDGETS.md).

## Проверка

Автоматические tests покрывают URI/JSON schema 1/2, malformed/partial tuple,
unsplit/split actions, stale scheme/part/session/slot, skipped и occupied slot,
переход между routine parts, inactive/unknown/Fatiha, missing Prayer Context,
exact-once/double delivery, deleted tombstone, scoped checked state, refresh
after every outcome, закрытие database после завершения background Future и
статический native contract для snapshot schema 5/routine labels.

Foreground/background/swiped-away/killed, launcher redraw и tap-to-refresh
latency требуют физического Android-устройства. Если `adb devices` не
показывает устройство, эти проверки остаются явно незавершёнными и не
подменяются unit tests.

## Primary references

- [home_widget interactive widgets](https://docs.page/ABausG/home_widget/features/interactive-widgets)
- [home_widget Android setup](https://docs.page/ABausG/home_widget/setup/android)
- [Glance interactions](https://developer.android.com/develop/ui/compose/glance/user-interaction)
