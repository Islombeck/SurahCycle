# Learning plans

## Модель

Один learning cycle содержит immutable `LearningPlan`:

```text
kind: classicCumulative | chunked
targetStartAyah
targetEndAyah
blockSize: positive только для chunked
```

План строит детерминированный ordered list generic `LearningStage`. Stage хранит purpose (`newAyah`, `cumulative`, `reviewRange`, `bridge`, `sectionReview`, `finalReview`), точный диапазон, optional block index и sequence index. UI, persistence, progression и rollback используют эту общую модель, а не отдельные формулы для каждого вида плана.

Target обязан лежать внутри `1..ayahCount`. Полный target может завершить mastery суры; неполный target означает только `range completed`.

## Classic cumulative

`classicCumulative` сохраняет Sprint 4 behavior и остаётся default. Для target `S..E`:

```text
NEW(S)
→ NEW(S+1)
→ CUMULATIVE(S..S+1)
→ NEW(S+2)
→ CUMULATIVE(S..S+2)
→ ...
→ NEW(E)
→ CUMULATIVE(S..E)
```

Для одноаятного target сохраняется обязательная цепочка `NEW(S) → CUMULATIVE(S..S)`. Legacy full-surah sessions после v4 migration получают target `1..ayahCount` и продолжают с точно того же видимого stage.

## Chunked

`chunked` ограничивает регулярное повторение текущим блоком. UI предлагает размеры 3, 5, 7, 10 и custom; это пользовательская техника, а не религиозное правило.

Для блока `6..10` последовательность выглядит так:

```text
NEW(6)
→ NEW(7)
→ REVIEW(6..7)
→ BRIDGE(4..7)
→ NEW(8)
→ REVIEW(6..8)
→ NEW(9)
→ REVIEW(6..9)
→ NEW(10)
→ REVIEW(6..10)
```

Bridge появляется со второго блока после первых двух уже изученных аятов нового блока. Он объединяет максимум два последних аята предыдущего блока с первыми одним-двумя аятами нового и не превращается в cumulative review от начала target.

После каждого четвёртого блока добавляется `SECTION_REVIEW` диапазона этих четырёх блоков. После всех блоков всегда добавляется обязательный `FINAL_REVIEW(targetStart..targetEnd)`. Только его прохождение переводит cycle к completion.

Последний неполный блок и target из одного аята поддерживаются тем же генератором stages без выхода за границы target.

## Действия и журнал

`Повторил` оставляет stage неизменным, обновляет activity time и создаёт `repeated`. `Выучил` переходит к следующему stage и создаёт `learned`. На последнем ordered stage оно требует явного завершения; completion создаёт `completed` и не выполняет скрытую активацию rotation.

Если пользователь меняет kind, target range или block size, UI показывает подтверждение. Старый progress не преобразуется приблизительно: начинается следующий `learningCycle`, а `planChanged` сохраняет before/after plan и stage snapshots. Повторное обучение завершённой/возвращённой суры аналогично создаёт `restarted`.

## 72-hour rollback

Rollback не знает специальных формул classic/chunked. State machine находит текущий stage в ordered `plan.stages` и откатывается максимум на один предыдущий индекс, если:

```text
nowUtc - lastLearningActivityAtUtc >= 72 hours
и текущий idle period ещё не обработан
и предыдущий stage существует
```

Один непрерывный период бездействия даёт максимум один rollback. Автоматический rollback и его Undo не являются пользовательской активностью; guard сбрасывается только после `Повторил` или `Выучил`. Event содержит точные ranges до/после и текущий cycle.

## UX и выбор

После выбора суры пользователь отдельно выбирает «Классически» или «По частям», target range и, для chunked, размер блока. Для длинных сур UI может рекомендовать chunked, но не выбирает его необратимо и не скрывает classic. Смена плана всегда явная и сохраняет историю.

Learning, Home и будущие audio/widget surfaces отображают stage через общую localized projection с точным диапазоном аятов.
