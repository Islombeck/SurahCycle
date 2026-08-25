# Drift migration v1 → v2

## Цель

`AppDatabase.schemaVersion` повышена с 1 до 2 без destructive fallback. Миграция сохраняет пользовательские, learning, settings и Quran-cache данные, добавляя версионируемое разбиение, exact event coverage, rakaat span и Витр.

Зафиксированные схемы находятся в `drift_schemas/drift_schema_v1.json` и `drift_schemas/drift_schema_v2.json`. Тест использует официальный Drift `SchemaVerifier`: создаёт настоящую v1-базу, заполняет все legacy-категории, выполняет production migration и открывает результат через текущие repositories.

## Новые таблицы и поля

- `rotation_schemes`: immutable version, ayah-count snapshot, baseline и journal boundaries;
- `rotation_parts`: диапазоны и cached part projections;
- `recitation_event_parts`: exact coverage с составными внешними ключами;
- `recitation_events.rotation_scheme_id` и `rakaat_span_count`;
- `rotation_adjustments.rotation_scheme_id`.

CHECK constraints разрешают `rakaat_span_count` только 1–4, известные prayer types включая `witr`, а `is_qada=true` — только типам с `supportsQada`. UNIQUE/composite foreign keys запрещают связать событие или adjustment со схемой другой суры, coverage — с другой схемой события, а part — с чужой схемой.

## Преобразование legacy-данных

Для каждой строки `mastered_surahs` создаётся детерминированная неразделённая схема:

```text
scheme id = v1:<surahId>:scheme:1
part id   = v1:<surahId>:scheme:1:part:1
range     = 1..verified ayahCount
```

Baseline берётся из сохранённого `activationBaselineScore` (или безопасного состояния никогда не активированной суры), а cached score/count/time переносятся без нормализации. Каждый live и tombstoned legacy `RecitationEvent` связывается с этой схемой и единственной частью, получает `rakaat_span_count = 1`. Каждый legacy adjustment получает ту же историческую схему. Id, `journalSequence`, timestamps, local date, prayer session, qada и deletion marker сохраняются.

Таблицы, структура которых меняется, пересоздаются внутри upgrade-транзакции с временными именами. Все остальные таблицы остаются на месте. После копирования удаляются только временные v1-таблицы; projection version обновляется последней, когда все новые отношения уже валидны.

## Проверки сохранности

Migration test проверяет:

- все строки и значимые поля `surah_metadata`, `mastered_surahs`, `rotation_states`, prayer sessions, live/tombstoned recitations и adjustments;
- learning state/events, typed settings и их timestamps;
- детерминированные схемы, диапазоны и coverage;
- отсутствие временных `%_v1` таблиц и пустой `PRAGMA foreign_key_check`;
- post-migration смену схемы, multi-part event, Witr+Qada и repository rebuild;
- raw SQL rejection для invalid rakaat, Nafl+Qada, orphan/cross-surah scheme, event/scheme mismatch и part/scheme mismatch.

SQLite migration выполняется атомарно: при исключении Drift откатывает upgrade, поэтому приложение не продолжает работу с частично преобразованной схемой. Destructive delete/recreate базы не используется.

## Команды проверки

```powershell
flutter test --no-pub test/core/data/app_database_migration_test.dart
flutter test --no-pub test/core/data/data_persistence_test.dart test/core/data/split_rotation_persistence_test.dart
```

Для следующего изменения схемы сначала экспортируется новый JSON snapshot, затем добавляется последовательная миграция 2→3 и отдельный fixture-test. Старый v1 snapshot не редактируется.
