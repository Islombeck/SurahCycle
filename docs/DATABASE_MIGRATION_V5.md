# Database migration v5 — prayer routines

## Purpose

Schema v5 adds configurable prayer routines without inventing routine data for
existing history. It is one application-schema upgrade; existing v1, v2, v3
and v4 databases all migrate directly through the established Drift strategy
to the same v5 shape.

## New data

The migration creates:

- `prayer_routine_templates`: one revisioned, enableable template per
  `PrayerType`;
- `prayer_routine_part_templates`: ordered editable part definitions;
- `prayer_session_parts`: immutable copies used by an actual prayer session.

It also extends existing data:

- `prayer_sessions` and `recitation_events` accept the distinct `jumuah`
  prayer type;
- `recitation_events` gains nullable `prayer_session_part_id` and
  `slot_index` columns.

Schema constraints require positive rakaat counts, non-negative slot counts,
contiguous repository order, valid part/completion enum values, and no Qada
for Nafl or Jumuah. A partial unique index prevents two non-deleted events from
occupying the same session-part slot.

## Backfill policy

The migration inserts one enabled-but-empty routine template for Fajr, Dhuhr,
Jumuah, Asr, Maghrib, Isha, Witr and Nafl. An empty template has no runtime
effect, and the enabled flag remains user-editable. It deliberately inserts no
parts:

- no madhhab or worship pattern is inferred;
- no legacy prayer event is assigned to a fabricated part;
- existing behavior remains available until the user configures and enables a
  routine.

All migrated recitation rows retain their ids, journal sequence, surah,
rotation scheme, coverage, rakaat span, prayer snapshot, timestamps, deletion
state and existing optional prayer-session link. Their new
`prayer_session_part_id` and `slot_index` values are null.

## Chained v1 upgrade detail

The current `recitation_events` table has an optional foreign key to
`prayer_session_parts`. During a v1-to-v5 chain SQLite resolves that foreign
key while the earlier v1 data is copied into the current event shape.
Therefore the migration creates the empty `prayer_session_parts` table before
copying legacy recitations. The final v5 step checks table/column existence via
SQLite introspection, so creation and column addition remain idempotent across
all source versions.

No session-part rows are backfilled. They are created only when the user has
an enabled non-empty template and starts a new exact-context/date session.

## Indexes and integrity

Schema v5 adds:

```text
idx_routine_parts_order
idx_session_parts_order
idx_recitation_session_slot
```

The first two support deterministic ordered reads. The third is a partial
unique index on active events only, so a soft-deleted event releases its slot
while its tombstone id still protects widget exact-once semantics.

Every upgrade finishes with `PRAGMA foreign_key_check`. A violation aborts the
migration instead of leaving a partially trusted database.

## Verification

`test/core/data/app_database_migration_test.dart` opens generated schema
fixtures for v1, v2, v3 and v4, upgrades each to v5, and checks preservation
of legacy tables, relationships and event semantics plus the new empty
templates and nullable links. The committed schema artifacts are:

- `drift_schemas/drift_schema_v5.json`;
- `test/generated_migrations/schema_v5.dart`;
- the v5 export in `test/generated_migrations/schema.dart`.

Repository/domain tests separately verify immutable snapshots, exact slots,
revision conflicts, zero-slot parts, followed-imam completion and Undo.
