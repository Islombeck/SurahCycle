# Database migration v9 — the day a Qada was actually made up

## Purpose

§E of the owner's brief asks that a Qada store, separately, the day of the
missed prayer **and** the day the make-up actually happened — the second one
editable, because a debt is usually entered later than it is prayed.

Three dates, three different questions, and only conflating them loses
information:

| Field | Question it answers |
| --- | --- |
| `local_date` | which prayer is this making up |
| `qada_fulfilled_local_date` | when was it actually prayed |
| `created_at_utc` | when was it typed in |

Someone reconstructing last week's misses today has three distinct answers and
every one of them is true. Before v9 only the first and third existed, so "when
did he pray it" was either lost or silently read off the entry timestamp.

Schema v9 adds one nullable column, `recitation_events.qada_fulfilled_local_date`,
and nothing else. Every v1 … v8 database migrates directly to the same v9 shape.

## Constraints

```text
CHECK (qada_fulfilled_local_date IS NULL OR is_qada = 1)
```

Only a Qada is made up; an ordinary record happened on its own day and a second
date there would describe nothing. `SurahRecitationEvent` refuses the same
combination with an `ArgumentError`, so the rule holds in the domain as well as
in the schema.

The v8 rule that only a Qada may carry `qada_origin_is_unknown` is unchanged.
Deliberately **not** added: a constraint forcing a fulfilment date whenever the
origin is unknown. Existing rows could violate it, and a CHECK that legacy data
can break is worse than the gap it closes.

## Backfill policy

**Nothing is back-filled.** Every stored row keeps `NULL`, meaning "not
recorded". Deriving it from `created_at_utc` would look helpful and would turn
"we do not know" into a date the user never gave — precisely the mistake this
column exists to prevent. The direct v8 → v9 test asserts the null rather than
letting it pass unexamined.

## The rebuild rule, now stated as a rule

SQLite cannot attach a CHECK to an existing table, so v8 → v9 rebuilds
`recitation_events` through Drift's table migration, copying every column so
that ids, journal sequence numbers and the compound key
`recitation_event_parts` depends on all survive.

A rebuild always produces the **current** table definition. So every rebuild
must declare every column added *after* it, or Drift copies a column out of a
table that does not have it yet and the upgrade dies with `no such column`.

This has now bitten three times — `resets_rotation_baseline` in v3 → v4,
`qada_origin_is_unknown` in v4 → v5, and this column in v7 → v8. It is no
longer a surprise; it is a rule:

> **Every `TableMigration` lists every column added after the version it
> belongs to.**

The chained upgrade tests (v1 … v6 → v9) are what catch a violation, because a
direct v8 → v9 upgrade never exercises the earlier rebuilds.

## Refusing a newer database

`onUpgrade` guards `from < 1 || from > 8 || to != 9`. A database stamped with a
newer `user_version` is refused with a `StateError` rather than silently opened
by older code.

## Verification

`test/core/data/app_database_migration_test.dart` upgrades generated fixtures
for v1 … v8 to v9. The direct v8 → v9 test seeds a full v6 database plus the v7
transport rows, then proves the recitation survives the rebuild with its id and
journal sequence intact, that its coverage row still resolves through the
compound key, that the queued sync envelope is untouched, that the new column is
`NULL` rather than invented, that the CHECK rejects an ordinary record carrying
a make-up day, and that a Qada may hold a `local_date` and a
`qada_fulfilled_local_date` that genuinely differ.

## The UI half

The registration sheet now offers the make-up day whenever the prayer is a Qada
**and** its original day is known. With an unknown origin the field is hidden:
the record already sits on the day it was made up, so a second date would ask
the same question twice — and both fields are written with that same day, so
stored Qada rows have one shape rather than two.

The picker is bounded at both ends. Not before the day the prayer belongs to,
because a prayer cannot be made up before it was due; not after today, because
neither is a day on which it could have been prayed. The same rule is enforced
in `SurahRecitationEvent`, so a caller that skips the sheet cannot store an
impossible pair.

Default is today, which is right for the ordinary case — praying a debt and
recording it immediately — and one tap away from correct for a late entry.

**Not yet verified on a real device.** Do not report v9 as device-verified
until a build carrying it has been installed and the owner's row counts checked
before and after.
