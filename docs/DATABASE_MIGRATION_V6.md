# Database migration v6 — recall attempts

## Purpose

Schema v6 adds the memory-check journal introduced by the `Проверка по памяти`
mode. It is one application-schema upgrade; existing v1, v2, v3, v4 and v5
databases all migrate directly through the established Drift strategy to the
same v6 shape.

This was the single migration slot the sprint reserved. The eight-item
recommendation batch deliberately did not take it — a batch is a replaceable
presentation decision stored as versioned JSON in `app_settings`, and losing it
costs one rebuilt list. A recall attempt is user history, so it gets a real
table with foreign keys and constraints. Any further persistence needs a new,
separately justified v7.

## New data

The migration creates `recall_attempts`:

| Column | Meaning |
| --- | --- |
| `id` | stable UUID, unique |
| `sequence` | autoincrement insertion order |
| `surah_id` | restrict-referenced `surah_metadata.id` |
| `ayah_start`, `ayah_end` | exact inclusive Quran coordinates |
| `learning_cycle` | the cycle the check belonged to |
| `result` | `recalled`, `recalledWithMistake` or `notRecalled` |
| `created_at_utc` | when the user graded themselves |
| `local_date` | the user's local day, captured at write time |
| `source` | `learning` or `surah`, the surface the check started from |

Schema constraints require a non-empty id, a positive `ayah_start`, an
`ayah_end` that does not precede it, a positive learning cycle, and a known
result and source. The foreign key is `RESTRICT`, so a surah cannot be removed
from the catalog while checks reference it.

## Backfill policy

**The migration backfills nothing, and this is the point.** A recall attempt is
a statement about what the user could remember at a moment in time. There is no
honest value to invent for a day on which no check happened, so every existing
database arrives at v6 with an empty journal.

Every other table is untouched. Prayer routine templates, session-part
snapshots, recitation events with their part/slot links, learning progress and
settings all keep their exact values; v6 adds a table and changes nothing else.

## Append-only by construction

`RecallRepository` exposes `append`, reads and watches — and no update and no
delete. That is deliberate rather than an oversight: editing a record of what
someone remembered would turn an honest history into a flattering one. Device
QA data created during the Stage F verification was therefore *not* cleaned up
afterwards, because removing it would have meant going behind the guarantee the
table exists to provide.

## Effect on review priority

A recall result influences exactly one thing, described in
`docs/ROTATION_ALGORITHM.md` terms: a surah whose **most recent** check was
imperfect sorts ahead of its equals, as the weakest contextual tie-break tier —
below urgency and below both recency tiers. It can never make a surah eligible
and never outranks a more overdue one, and one clean check clears it. Only the
latest attempt counts, so a single bad day cannot pin a surah to the front.

A recall attempt never creates, cancels or substitutes a recitation-in-prayer
event, and never touches rotation credit or statistics.

## Indexes and integrity

Schema v6 adds:

```text
idx_recall_attempts_surah_sequence
idx_recall_attempts_date
```

The first supports per-surah history and the latest-result lookup; the second
supports day-scoped reads. Both are created idempotently in `beforeOpen`, like
the earlier runtime indexes.

The upgrade finishes with `PRAGMA foreign_key_check`. A violation aborts the
migration instead of leaving a partially trusted database.

## Refusing a newer database

`onUpgrade` guards `from < 1 || from > 5 || to != 6`. A database stamped with a
*newer* `user_version` — one written by a future build — is therefore refused
with a `StateError` rather than silently opened and written by older code. This
is covered by its own test.

## Verification

`test/core/data/app_database_migration_test.dart` opens generated schema
fixtures for v1, v2, v3, v4 and v5, upgrades each to v6, and checks preservation
of legacy tables, relationships and event semantics plus the new empty journal.
The direct v5→v6 test seeds a complete v5 routine scaffold — an edited template
revision, a part template, a session-part snapshot and a recitation bound to
that part and slot — and proves all of it survives, then exercises the new
table's own guards (unknown result, reversed range, unknown source, unknown
surah, duplicate id). The committed schema artifacts are:

- `drift_schemas/drift_schema_v6.json`;
- `test/generated_migrations/schema_v6.dart`;
- the v6 export in `test/generated_migrations/schema.dart`.

Domain, repository, controller and widget tests separately verify the reveal
gate, the refusal to grade before revealing, append-only persistence, ranges and
coordinate exactness.

Verified on a real device on 2026-09-15: after installing the Stage F build the
user's own database reported `user_version = 6`, so this migration has run on
real data, not only on fixtures.
