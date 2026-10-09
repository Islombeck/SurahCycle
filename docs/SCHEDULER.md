# Scheduler — design to agree before code (2026-10-09)

Written for: the owner, to agree or correct, and whoever builds it after.
Backlog item 29. Nothing here is built yet; schema v12 is not written until
this is agreed, because a migration on his phone is an owner-visible event.

## What he has already decided

- The day is divided by the real prayer schedule into intervals.
- Each prayer gets a **duration he sets himself** ("about 20 minutes for
  Maghrib"); the screen says it is his estimate and never presents a prayer
  as taking a fixed, authoritative time.
- A task has a title and an estimated duration and may be **split** into
  chunks that land in different free intervals.
- A visual timeline of the day: prayer blocks, free gaps, chunks.
- Tasks are **daily or one-off** — a field, not two entities.
- An undone chunk **is not moved**; it stays as the record of that day.
- Moving is **manual only**.
- **Notifications are allowed** — opt-in and silent, like everything here.
- Works with no network and no account.

## The model

Two tables, schema **v12**, with a migration test from every earlier
version (the rule every bump here has followed).

**`planner_tasks`** — what he wants to do.

| column | meaning |
|---|---|
| `id` | uuid |
| `title` | his words |
| `estimated_minutes` | > 0 |
| `recurrence` | `once` \| `daily` (CHECK) |
| `once_local_date` | the day of a one-off task; required iff `once` (CHECK) |
| `active_from_local_date` | first day a daily task applies |
| `archived_at_utc` | null while active; a task is archived, never deleted, so its days keep meaning |
| `created_at_utc`, `updated_at_utc` | the v10 touch-trigger convention |

**`planner_chunks`** — a piece of a task placed on a day.

| column | meaning |
|---|---|
| `id` | uuid |
| `task_id` | FK, `ON DELETE RESTRICT` |
| `local_date` | the day it belongs to |
| `start_minute` | minutes after local midnight; null while not placed in a gap |
| `duration_minutes` | > 0 |
| `status` | `planned` \| `done` \| `skipped` (CHECK) |
| `completed_at_utc` | when he marked it done |
| `moved_to_chunk_id` | set when he moved it by hand; the original stays, saying "moved", the new one carries on |

**Prayer durations** live in `app_settings` (one JSON value, per prayer, in
minutes), not in the schema: they are a preference, not a record.

Two rules carried over from the rest of the app, deliberately:

- **A day of a daily task is not materialised in advance.** "Did he do it
  on Tuesday?" is answered from the task's active range and the chunks that
  exist — the same way the calendar answers "was this prayer recorded" from
  what was recorded, without inventing an empty row for every day. A chunk
  row appears only when he places, splits, finishes or skips something.
- **The timeline is a projection, not stored**: today's schedule from the
  prayer-time providers, plus his durations, plus the chunks. Changing a
  duration redraws; it rewrites nothing.

## The timeline

From today's schedule (the same `prayerTodaySchedule` the widgets read):
a block from each prayer's start for his duration; Sunrise is not a block
(it is not a prayer); on Friday Jumuah's duration replaces Dhuhr's; Witr is
inside his Isha estimate unless he gives it its own. Everything between
blocks is a free gap. Before Fajr and after Isha are gaps too.

**Splitting**: a task's estimate is offered as one chunk; "split" divides it
and each piece is placed into a gap he taps, or into the first gap it fits
("suggest" — a suggestion he accepts, never a silent placement).

**Days past**: shown read-only, undone chunks marked undone, with "move to
another day" as the one action.

## Notifications

Silent, opt-in, its own switch and its own Android channel, at the start of
a placed chunk. The honest constraint: without the exact-alarm permission
Android may deliver it **up to ten minutes late** (the same inexact window
the prayer widget uses). Asking for exact alarms means sending him to a
system settings screen and is a Play policy question; the plan is inexact
unless he says the lateness matters.

## Not in the first version

- **Sync.** The account log's `entityType` is an enum in the live Appwrite
  table; adding planner types is a cloud migration. First version is
  local-only and says so; sync is its own step.
- iOS. Nothing here is Android-specific except the notification.

## Order of work, each step a commit, suite green between

1. Schema v12 + migration tests from v1..v11 + repositories.
2. Prayer durations setting + the read-only timeline of today.
3. Tasks: create, edit, archive; daily vs one-off.
4. Chunks: place, split, suggest, done, skip; past days read-only; manual move.
5. The silent notification.
6. Install on his phone, backup first, v11→v12 run on a copy of his
   database before it runs on the phone.

## Open — his to decide

1. **Where it lives.** Five tabs today, and on his 360-point screen a sixth
   leaves each label about 60 points («Статистика» already uses most of
   its room). Options: an icon on Home next to the calendar (the calendar
   got exactly this); or a sixth tab.
2. **Prayer durations to start with.** Empty until he fills them (nothing
   presented as a norm), or prefilled with his own numbers if he gives them.
