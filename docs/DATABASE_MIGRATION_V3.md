# Drift migration v2 → v3

Schema v3 снимает искусственный предел четырёх частей суры. Constraint `rotation_parts.ordinal` изменён с `BETWEEN 1 AND 4` на `ordinal >= 1`; `rakaat_span_count` остаётся отдельным понятием и по-прежнему ограничен 1–4.

Production upgrade последовательно выполняет v1→v2 и v2→v3, поэтому установка поверх Sprint 1 не требует промежуточного APK. На шаге v2→v3 parent `rotation_parts` и зависимая `recitation_event_parts` пересоздаются внутри одной migration transaction. Все ids, scheme versions, ranges, cached scores/counts/timestamps и exact event coverage копируются без изменения; затем выполняется `PRAGMA foreign_key_check`, а projection version обновляется последней.

Зафиксированы snapshots `drift_schema_v1.json`, `drift_schema_v2.json` и `drift_schema_v3.json`. Migration tests отдельно покрывают v1→v3 и существующую four-part v2 database с history/coverage, после чего сохраняют новую five-part схему.
