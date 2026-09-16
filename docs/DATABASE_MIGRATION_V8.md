# Database migration v8 — a Qada whose day is unknown

## Purpose

Asked for by the owner on 2026-09-16, in his own words: someone may be closing
**very old** debts, from before he began praying regularly, and cannot say which
day a missed prayer belongs to.

Until v8 every recitation had to claim a day. For an ordinary record that is
true — the user picks it. For a Qada of unknown origin it is not, and the app
had only two options, both wrong: guess a date, or refuse the entry.

Schema v8 adds one column, `recitation_events.qada_origin_is_unknown`, and
nothing else. Existing v1 … v7 databases all migrate directly to the same v8
shape.

## What the flag means

| Case | `local_date` | `qada_origin_is_unknown` |
| --- | --- | --- |
| Ordinary record, including one entered late | the day it was read | `false` |
| Qada with a known missed day | the day of the missed prayer | `false` |
| Qada whose missed day is unknown | the day the make-up happened | `true` |

The third row is the new one. The date kept is the only date that actually
exists — when the make-up was done — and the flag is what stops that date being
read as evidence about when the debt arose. The calendar places the entry on
that day and labels it «исходный день неизвестен» rather than putting the debt
on a day nothing supports.

`created_at_utc` is unchanged and still means the moment of entry.

## Constraints

```text
CHECK (qada_origin_is_unknown = 0 OR is_qada = 1)
```

Only a Qada can have an unknown origin. `SurahRecitationEvent` refuses the same
combination with an `ArgumentError`, and the calendar refuses to render the
claim even if a row somehow carries it — three independent places, because this
is a statement about the user's worship and a wrong one is not recoverable by
looking at the data.

Turning the Qada switch off in the registration sheet clears the unknown-day
claim with it, and re-resolving the prayer at the moment of writing clears it
again if the context stopped being a Qada.

## Backfill policy

**Nothing is backfilled and no stored row changes meaning.** Every existing
Qada named a day when it was entered, so every existing row keeps `false`. The
flag is only ever set going forward, by someone explicitly saying he cannot name
the day.

## A note on the rebuild

SQLite cannot attach a CHECK to an existing table, so v7 → v8 rebuilds
`recitation_events` through Drift's table migration. Every column is copied, so
ids, journal sequence numbers and the compound key `recitation_event_parts`
depends on all survive — the direct v7 → v8 test asserts exactly that.

A rebuild always produces the **current** table definition, which is why the
v4 → v5 step had to declare this column as new as well. During a chained
v2/v3/v4 → v8 upgrade that earlier rebuild already creates the final shape, and
v7 → v8 then finds the column present and does nothing. Without that, Drift
copies a column out of a table that does not have it yet and the upgrade fails
with `no such column`. The same guard already exists for
`resets_rotation_baseline` in the v3 → v4 step; this is the second instance of
the same trap.

## Refusing a newer database

`onUpgrade` guards `from < 1 || from > 7 || to != 8`. A database stamped with a
newer `user_version` is refused with a `StateError` rather than silently opened
by older code.

## Verification

`test/core/data/app_database_migration_test.dart` upgrades generated fixtures
for v1 … v7 to v8. The direct v7 → v8 test seeds a full v6 database plus one row
in each v7 transport table, then proves the recitation survives the rebuild with
its id, journal sequence, scheme, session part and slot intact, that its
coverage row still resolves through the compound key, that the recall attempt
and the queued sync envelope, cursor and activation are untouched, and that the
new CHECK rejects an ordinary record claiming an unknown day while accepting a
Qada that does.

`test/core/domain/qada_origin_test.dart` pins the domain guard and the
calendar's refusal to imply a date.

**Not yet verified on a real device at the time of writing.** Do not report it
as device-verified until a build carrying v8 has been installed and the owner's
own row counts checked before and after.
