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

## Verified on the owner's device, 2026-09-17

Build `bfd982bc…` was installed over the existing app after a copy of the
database was pulled as a backup. `user_version` became **9** and every
pre-existing count was unchanged — 673 recitation events, 675 event parts, 37
prayer sessions, 57 session parts, 14 part templates, 27 mastered surahs, 4
recall attempts, 32 learning events, 10 settings, 114 metadata rows.
`PRAGMA foreign_key_check` returns nothing, and `qada_fulfilled_local_date`
is `NULL` on every row: **zero** values invented from `created_at_utc`.

**An incident during that session — and the account of it below was wrong.**

What was recorded at the time: that a tap aimed at a surah's tune icon landed on
its mark control, writing two recitations — Al-Kawthar and Al-Asr, both Asr,
2026-09-17 — into the owner's real history, and that both were then removed
through the app's own History delete. Active recitation events were 571 before
and 571 after.

**Corrected 2026-09-18, by the owner.** Those two marks were his. He was using
the phone while this session was working and marked Al-Asr and Al-Kawthar during
Asr, having forgotten that anything else was touching the device. The tap-through
did not create them.

Which inverts the conclusion. Nothing stray was cleaned up: **two genuine
recitations were deleted** on the belief that they were mine to remove. The
error was not the tap that was blamed — it was deleting rows on an assumption
about where they came from, with no evidence beyond their timestamps, and
without asking. Timing near an install is not authorship.

**The full timeline, read out of the owner's database on 2026-09-18**, because
the correction above is itself incomplete without it:

| local time, 2026-09-17 | what happened |
|---|---|
| 16:57:03 | the v9 build is installed |
| 16:58:11 / 16:58:18 | Al-Asr (seq 675) and Al-Kawthar (seq 676) are marked for Asr |
| 17:00:26 / 17:00:04 | both are deleted |
| 17:02:00 / 17:02:03 | Al-Asr (seq 677) and Al-Kawthar (seq 678) are marked again |

The last row is the one that matters: **the pair was re-entered two minutes
later and is live today**, so the Asr of 17 September records both surahs and
nothing was permanently lost. The deleted rows at 16:58 are duplicates of what
is already there. They were deliberately **not** restored — putting them back
would show each surah recited twice in one Asr, which is a worse falsehood than
the gap, and is the owner's decision rather than mine.

The recovery path was built anyway, because its absence is a real defect
regardless of this case: a deletion here is a tombstone rather than a removal,
yet nothing in the app could undo one. `RecitationRepository.restoreRecitation`
and History's "показать удалённые" exist now. See the handoff entry.

Two rules still follow from the session, and a third from the correction:

1. Take a fresh screenshot immediately before every tap on a scrolling list;
   coordinates from an earlier frame address a list that has moved.
2. **Prefer a widget test to a tap-through whenever the screen can write.** The
   field this session set out to photograph is now covered by
   `test/widget/qada_fulfilled_date_test.dart`, which proves more than a
   screenshot would, keeps proving it, and cannot write to anyone's history.
   Those tests were checked against a deliberately broken guard first: three of
   the four fail without it.
3. **Never delete a row from the owner's data on an inference about who wrote
   it.** Ask. A row that looks like it came from automation may be the owner
   praying while the automation ran, and the cost of asking is a message while
   the cost of being wrong is his history.
