# Алгоритм обучения

Актуальная domain-модель и точные последовательности планов описаны в [LEARNING_PLANS.md](LEARNING_PLANS.md). Этот документ фиксирует общие правила state machine и persistence boundary.

## Ответственность state machine

`LearningStateMachine` управляет независимым progress каждой суры. Она получает `TimeProvider`, immutable `LearningPlan` и generic ordered `LearningStage`; UI только отображает snapshot и вызывает действия.

Для каждой суры хранятся:

```text
surahId и проверенный ayahCount
learningCycle >= 1
plan kind, target range и optional block size
current stage kind и точный ayah range
status: active | completed
lastLearningActivityAtUtc
inactivityRollbackForActivityAtUtc
```

Arabic, transliteration и translation не входят в progression state и связываются с ним только по проверенным координатам `surah:ayah`.

## Переходы

- `Повторил` создаёт `repeated`, обновляет activity timestamp, но не меняет stage.
- `Выучил` создаёт `learned` и переходит на следующий элемент `plan.stages`.
- Последний stage не завершает цикл скрыто: требуется явное completion action.
- `planChanged` и `restarted` увеличивают `learningCycle`, начинают первый stage нового плана и сохраняют before/after snapshots.
- `completed` завершает только выбранный target. Mastery всей суры возможен лишь для target `1..ayahCount`.

Добавление в rotation является отдельным явным выбором. При первом mastery используется baseline `rotationTarget - 1`; при remastery создаётся новая immutable scheme без сброса исторических totals и без накопленного старого долга. Al-Fatiha может завершить Learning, но никогда не входит в rotation.

## Бездействие и Undo

При `idleDuration >= 72 hours` активное состояние может откатиться ровно на один предыдущий ordered stage. Первый stage и completed state не откатываются. Один непрерывный idle period обрабатывается максимум один раз независимо от его длины.

Rollback создаёт `inactivityRollback`; Undo восстанавливает before snapshot, но сохраняет guard обработанного периода. Новый rollback возможен только после реального действия пользователя и следующего отдельного периода бездействия. Все timestamps хранятся в UTC; отрицательная duration из-за неверных системных часов не вызывает откат.

## Persistence

`LearningSurah` содержит текущую проекцию одной суры, а `LearningEvent` — append-style audit действий и переходов. Unique `surahId` сохраняется: новый цикл переиспользует aggregate row и не удаляет старые events. Каждый event хранит plan/stage snapshots до и после, cycle, UTC timestamp и optional reason.

Migration v4 сохраняет Sprint 4 progress как `classicCumulative`, target `1..ayahCount`, cycle 1; `newAyah N` становится range `N..N`, а `cumulative N` — `1..N`.

## Проверки

Тесты фиксируют прежнюю classic-цепочку, одноаятный target, chunked blocks/bridge/section/final review, partial target без mastery, смену плана и restart history, границу 72 часов, один rollback за idle period, Undo, независимость сур и remastery lifecycle.
