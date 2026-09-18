# Schema v10 — six tables learn when they last changed

## Why

Comparing this device against an account needs exactly one thing per record:
when it last changed. Five tables could already answer — the append-only
journals (`recitation_events`, `rotation_adjustments`, `learning_events`,
`recall_attempts`) by `created_at_utc`, and `app_settings` by its own
`updated_at_utc`. Six could not:

| table | entity type |
|---|---|
| `mastered_surahs` | `masteredSurah` |
| `rotation_states` | `rotationState` |
| `rotation_schemes` | `rotationScheme` |
| `prayer_routine_templates` | `prayerRoutineTemplate` |
| `prayer_sessions` | `prayerSession` |
| `learning_surahs` | `learningState` |

That had two consequences. A first-sync preview had to report every roster
entry, scheme, routine, prayer session and learning plan as **undetermined** —
present on both sides, agreement unknowable. And last-writer-wins was not
available for them at all, because "newest wins" cannot choose between two
records that carry no dates. This migration closes both.

## What changed

Each of the six tables gains `updated_at_utc INTEGER NULL` — Drift's usual
storage for `DateTime`, whole seconds since the epoch.

`migrator.addColumn`, **not** a table rebuild. The column is plain and nullable
with no CHECK attached, so none of the rebuild hazards apply, and this file has
already been bitten four times by the rule that a rebuild produces the *current*
table definition and must therefore declare every column added after it. Not
rebuilding is the safer of the two options.

Two existing rebuilds did have to be taught about the new column, and the fourth
occurrence of that trap was found by a failing test rather than by reading:

- `_migrateVersionThreeToFour` rebuilds `mastered_surahs` → now lists
  `masteredSurahs.updatedAtUtc`;
- `_migrateVersionFourToFive` rebuilds `prayer_sessions` → now lists
  `prayerSessions.updatedAtUtc`.

The v3→v4 learning rebuild needed nothing: it copies with an explicit column
list, so the new column simply stays null.

## Nothing is backfilled, and that is the point

A row written before v10 keeps `NULL` until something next writes to it.

Stamping the migration time onto every existing row was the obvious shortcut and
is wrong: it looks like an answer while being arbitrary. Two devices upgrading on
different days would hand a later merge a winner decided by install order. Null
is not knowing, and `SyncMergePreview.undeterminedCount` reports it out loud
instead of hiding it. The gap then closes on its own, one row at a time, as the
user goes on using the app.

## A trigger keeps it, not the repositories

`trg_<table>_touch_insert` and `trg_<table>_touch_update`, twelve in all, set the
column from SQLite's own clock.

The alternative was roughly twenty write sites across five repositories, each of
which would have had to remember — and the next one added would not have. A
trigger cannot be forgotten, it covers writes that never go through a repository,
and it does not touch a single line of the code the owner uses daily.

Three details are load-bearing:

- `CAST(strftime('%s', 'now') AS INTEGER)`. `strftime` returns text, and Drift
  reads this column as an integer; a string would come back as no date at all.
- The update trigger guards on `WHEN NEW.updated_at_utc IS OLD.updated_at_utc`.
  With `recursive_triggers` off — SQLite's default — the inner `UPDATE` cannot
  re-fire it anyway. The guard is what makes that independent of a pragma this
  code does not set, so the behaviour cannot change underneath it later.
- That same guard means **a caller supplying its own timestamp keeps it**. This
  is what will let an applied remote change carry the originating device's time
  rather than being restamped "now" on arrival, which would make every synced
  row look newer than the row it came from. Pinned by a test.

## Verified

- `flutter analyze` → `No issues found!`
- Full `flutter test --timeout 90s` → **975/975**.
- The migration suite covers `v1→v10`, `v2→v10`, `v3→v10`, `v4→v10`, `v5→v10`,
  `v6→v10`, `v7→v10`, `v8→v10` and a dedicated `v9→v10`, plus the guard that a
  database stamped with a newer `user_version` is refused rather than silently
  downgraded.
- The `v9→v10` test pins all four behaviours that matter: the column exists, a
  pre-existing row is still null, an insert stamps it, an update on a legacy row
  closes the gap, and an explicitly supplied timestamp survives.

**Not yet run on a real device.** The owner's phone is at v9 from the 2026-09-17
install. Before it is, pull a copy of `murajaah_user.sqlite` as a backup, as was
done for v7, v8 and v9.

## One test-only surprise, worth knowing

Drift hands `updated_at_utc` back as a **local** `DateTime`, not a UTC one, so
comparing it to `DateTime.utc(...)` with `==` fails anywhere but UTC. Compare
instants with `isAtSameMomentAs`. `DriftSyncInventory` already forces UTC when it
reads the column through a raw select.
