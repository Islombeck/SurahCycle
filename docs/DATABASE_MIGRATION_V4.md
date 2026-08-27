# Drift migration v3 → v4

Schema v4 разделяет факт текущего владения сурой и существование её исторической записи, а также переводит Learning на versioned планы и диапазоны. Это единая миграция: отдельная v5 для Learning в Sprint 5 не создаётся.

## Новые данные

В `mastered_surahs` добавлено поле `is_currently_mastered BOOLEAN NOT NULL`. Для всех legacy-строк оно backfill-ится значением `TRUE`. Инвариант базы и домена:

```text
is_currently_mastered = FALSE  =>  is_active = FALSE
```

`learning_surahs` теперь хранит полный snapshot текущего цикла:

- `plan_kind`: `classicCumulative` или `chunked`;
- `target_start_ayah`, `target_end_ayah`;
- `block_size` только для chunked-плана;
- `stage_kind`, `stage_start_ayah`, `stage_end_ayah`;
- `learning_cycle >= 1`;
- прежние status, activity timestamp и inactivity guard.

`learning_events` хранит номер цикла, plan snapshot и stage range до и после события. В журнал добавлены auditable типы `restarted` и `planChanged`, а nullable `reason` объясняет явный переход.

В `rotation_schemes` добавлен internal marker `resets_rotation_baseline BOOLEAN NOT NULL DEFAULT FALSE`. Он отличает remastery boundary от обычной смены разбиения. При journal rebuild старая история по-прежнему пересчитывает totals и `lastUsedAtUtc`, но score новой mastery lifecycle не наследует прежний долг. Все legacy schemes получают `FALSE`.

## Стратегия upgrade

Production upgrade принимает только поддерживаемые маршруты `v1→v4`, `v2→v4` и `v3→v4`. Старые шаги выполняются последовательно:

```text
v1 → v2 → v3 → v4
v2 → v3 → v4
v3 → v4
```

SQLite не умеет добавлять или менять `CHECK` constraints in place. Поэтому `mastered_surahs` перестраивается через Drift `TableMigration`, а обе learning-таблицы перестраиваются внутри migration transaction. Сначала переименовываются legacy-таблицы, затем создаются v4-таблицы, данные копируются с явным mapping, и только после этого старые таблицы удаляются.

Legacy Learning конвертируется без изменения видимого этапа:

| v3 snapshot | v4 snapshot |
|---|---|
| `newAyah N` | classic, target `1..ayahCount`, stage `N..N`, cycle 1 |
| `cumulative N` | classic, target `1..ayahCount`, stage `1..N`, cycle 1 |

Event ids, sequences, UTC timestamps, status, last activity и rollback marker сохраняются. Для каждого legacy event создаются одинаковые classic plan snapshots `1..ayahCount` до и после перехода.

После копирования восстанавливаются индексы и два defensive SQLite trigger-а, запрещающие insert/update состояния `is_currently_mastered = 0 AND is_active != 0`. Завершение миграции проверяет `PRAGMA foreign_key_check`.

## Что сохраняется

Миграция не пересчитывает и не удаляет пользовательские факты. Сохраняются:

- mastered rows, aliases, display order и active state;
- rotation target, immutable schemes, parts и их cached projection;
- prayer sessions, recitation history, exact part coverage и rakaat count;
- rotation adjustments и journal sequences;
- весь Learning journal и текущий progress;
- typed app settings.

Существующие mastered rows считаются currently mastered, а существующие schemes продолжают обычную carry-forward semantics. Существующий classic progress продолжает ту же последовательность и ту же 72-hour rollback semantics.

## Проверка и rollback policy

Зафиксирован `drift_schemas/drift_schema_v4.json`, а generated migration helper позволяет поднимать snapshots v1–v4 в memory database. Automated tests отдельно проверяют все три upgrade-маршрута, сохранность пользовательских таблиц, backfill Learning и запрет активировать возвращённую в обучение суру.

Downgrade v4→v3 не поддерживается: он потерял бы mastery lifecycle, target ranges и cycle history. При неуспешной migration SQLite transaction оставляет предыдущую базу без частично применённой схемы.
