# Interactive Android Rotation Widget

## Контракт действия

Rotation Widget использует snapshot schema 3. Каждая eligible due-row получает
от Dart необязательный action schema 1:

`json
{
  "schemaVersion": 1,
  "actionToken": "uuid-v4",
  "surahId": "112",
  "rotationSchemeId": "scheme-id",
  "partId": null
}
`

`actionToken` уникален внутри опубликованного snapshot. Для
неразделённой суры action покрывает единственную часть; для разделённой строки
action указывает ровно один `partId`. Rows без надёжного Prayer
Context не получают action.

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
- Prayer Context на execution time.

Если scheme/part/activation изменились после публикации snapshot, action
считается stale и отклоняется. Уже применённый token остаётся duplicate даже
если событие позже удалено из History; удаление не даёт старому widget intent
создать его снова.

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

## Версии и совместимость

- snapshot schema 3 — текущая;
- native decoder читает schema 2 как display-only migration input;
- action schema 1 независима от snapshot schema;
- Dart decoder принимает только текущую schema 3;
- main Drift database остаётся schema 3: отдельная миграция ради token не
  понадобилась.

Подробный display contract и build notes:
[ANDROID_WIDGETS.md](ANDROID_WIDGETS.md).

## Проверка

Автоматические tests покрывают URI/schema validation, unsplit/split actions,
stale scheme/part, inactive/unknown/Fatiha, missing Prayer Context,
exact-once/double delivery, deleted tombstone, refresh after every outcome,
закрытие database после завершения background Future и статический native
contract.

Foreground/background/swiped-away/killed, launcher redraw и tap-to-refresh
latency требуют физического Android-устройства. Если `adb devices` не
показывает устройство, эти проверки остаются явно незавершёнными и не
подменяются unit tests.

## Primary references

- [home_widget interactive widgets](https://docs.page/ABausG/home_widget/features/interactive-widgets)
- [home_widget Android setup](https://docs.page/ABausG/home_widget/setup/android)
- [Glance interactions](https://developer.android.com/develop/ui/compose/glance/user-interaction)
