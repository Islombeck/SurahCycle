# Mastery lifecycle

## Два независимых состояния

Наличие строки `MasteredSurah` больше не означает, что сура сейчас считается выученной. Строка является долговечной aggregate/projection записью, к которой привязаны история, схемы и статистика.

| `isCurrentlyMastered` | `isActive` | Значение |
|---:|---:|---|
| true | false | выучена, но выключена из ротации |
| true | true | выучена и участвует в ротации |
| false | false | возвращена в Learning; история сохранена |
| false | true | недопустимое состояние |

Catalog и Learning candidates используют именно `isCurrentlyMastered`, а rotation projection дополнительно требует `isActive`. Инвариант проверяется в domain constructors, repository transitions, DB `CHECK` и defensive triggers.

## «Убрать из выученных»

Это semantic transition, а не `DELETE`:

1. `isCurrentlyMastered` становится `false`;
2. `isActive` становится `false`;
3. сура снова появляется среди Learning candidates;
4. aliases, display order, scores, totals, last-used timestamps, immutable rotation schemes, recitation history, adjustments и Learning events остаются без изменения.

Одинаковый UX используется и для случайно добавленной суры. Внутреннюю разницу между пустой и богатой историей пользователю объяснять не требуется.

Physical delete не является обычной product-операцией. Он допустим только как отдельный developer/advanced cleanup после проверки отсутствия history, adjustments, learning events, scheme references и других FK.

## Повторное обучение

На одну суру остаётся одна `LearningSurah` row. Повторный старт не пытается вставить вторую строку с конфликтующим `surahId`, а создаёт новый `learningCycle` в существующей aggregate:

- старые Learning events остаются;
- progress начинается с первого stage явно выбранного нового плана;
- событие `restarted` сохраняет старый и новый plan/stage snapshot и причину;
- явная смена плана использует такой же новый cycle с событием `planChanged`.

Завершение неполного target range фиксирует завершённый диапазон, но не восстанавливает mastery всей суры.

## Повторное завершение всей суры

После mandatory final stage полного диапазона пользователь явно завершает цикл:

- `isCurrentlyMastered` восстанавливается в `true`;
- исторические totals/statistics и `lastUsedAtUtc` сохраняются;
- создаётся отдельная versioned scheme новой mastery lifecycle;
- без согласия на ротацию сура остаётся inactive, а текущая lifecycle ещё не считается вошедшей в rotation;
- при согласии scheme сразу активируется;
- baseline новой схемы привязан к текущему `rotationTarget` (`target - 1`), поэтому прежний разрыв не превращается в огромный накопленный долг.

Старая активная схема supersede-ится journal boundary, но не удаляется: старые события продолжают ссылаться на точную историческую версию. Если пользователь сначала завершил «без ротации», а включил суру позже, baseline подготовленной схемы финализируется относительно target в момент первого включения. До этого у неё нет recitation/adjustment events; после активации она является обычной immutable исторической версией. Journal rebuild сохраняет этот remastery score baseline, одновременно корректно пересчитывая historical totals после удаления старого события.

## Al-Fatiha

Al-Fatiha проходит тот же mastery/relearning lifecycle и может быть Learning candidate. Единственное специальное правило остаётся неизменным: она никогда не становится active и никогда не входит в rotation, даже если пользователь выбирает «добавить в ротацию» после повторного обучения.

## Проверки

Domain и integration tests фиксируют возврат в Learning, сохранение history/statistics, отключение ротации, повторный cycle, восстановление mastery без старого долга и отдельное правило Al-Fatiha.
