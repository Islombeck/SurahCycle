# Database migration v7 — durable sync transport

## Purpose

Schema v7 adds the three tables real account sync needs on the device: a durable
outbox, a pull cursor, and the record of whether an account has been allowed to
touch this device's data. It is one application-schema upgrade; existing v1, v2,
v3, v4, v5 and v6 databases all migrate directly to the same v7 shape.

`docs/DATABASE_MIGRATION_V6.md` closed with "any further persistence needs a
new, separately justified v7". This is that justification: the sync contracts
shipped in Stage G against an in-memory outbox, which cannot make the one
promise the feature rests on — a change the user already watched succeed
locally must not disappear because the process died before the network came
back.

**Nothing in `lib/app/` or `lib/features/` references these tables.** They ship
with the migration; the wiring ships with a real gateway.

## New data

### `sync_outbox_entries`

| Column | Meaning |
| --- | --- |
| `owner_key` | whose queue this is — `local`, or `user:<id>` |
| `envelope_id` | the envelope's own id; primary key together with `owner_key` |
| `entity_key` | `entityType:entityId` — what the change is about, across devices |
| `status` | `pending` (retry queue) or `quarantined` (permanently rejected) |
| `is_tombstone` | whether the queued change is a delete |
| `enqueued_at_us` | microseconds since epoch, UTC |
| `envelope_updated_at_us` | the envelope's own `updatedAtUtc`, for supersede comparisons |
| `attempt_count` | failed pushes so far |
| `last_failure_reason` | a short content-free category, never a payload |
| `envelope_json` | the envelope, serialized |

The envelope is stored as its own JSON rather than shredded into columns. It is
transport payload, and re-deriving it from local tables after a later schema
change would risk pushing something the user never actually did.

The retry queue and the quarantine share one table, separated by `status`. A
permanently rejected change is moved out of the way of the ones behind it, never
deleted: retrying it forever would wedge the queue, and deleting it would
discard something the user already saw succeed.

### `sync_cursors`

`owner_key`, the opaque `pull_cursor` (empty means "from the beginning") and
`updated_at_utc`.

### `sync_activations`

`owner_key`, `is_active`, the recorded `choice`, the `backup_id` the merge
preview was shown with, `decided_at_utc` and `last_success_at_utc`.

`keepDeviceLocalOnly` is stored, not forgotten. The account screen has to be
able to say that this device was deliberately left local; a forgotten "no" looks
like a question that was never asked.

## Two invariants that live in the schema

Code that maintains an invariant can be changed by someone who does not know it
exists. These two are enforced by SQLite:

```text
CREATE UNIQUE INDEX idx_sync_outbox_pending_entity
  ON sync_outbox_entries (owner_key, entity_key) WHERE status = 'pending'
```

One pending change per entity per owner — coalescing, so ten offline edits to
one routine template stay one push.

```text
CHECK (is_active = 0 OR choice = 'merge')
```

Sync cannot be active for an owner whose recorded choice was to stay local.
Signing in is identity; activation is a separate, explicit decision.

`idx_sync_outbox_drain` on `(owner_key, status, enqueued_at_us, envelope_id)`
serves the drain order.

## Owner scoping

Every row carries `owner_key`. Signing out of account A and into account B on
one device is cheap to do and catastrophic to get wrong: a shared queue would
push A's recitation history under B's identity. The separation is structural
rather than a `clear()` someone has to remember to call, and it is covered by
its own tests — one account's `acknowledge`, `clear`, cursor and activation are
all invisible to another.

`SyncOwnerKey.local` is the pre-account owner, which keeps "adopt this device's
data into an account" an explicit merge decision.

## Backfill policy

**The migration backfills nothing, and this is the point.** A queue entry
describes a change that has not reached an account yet. Synthesizing one per
historical recitation would push a user's entire journal the first time they
ever sign in — exactly the merge the activation gate exists to make explicit.
Every existing database arrives at v7 with all three tables empty.

Every other table is untouched. Recitation events, learning progress, the recall
journal, prayer routine templates, session-part snapshots and settings all keep
their exact values.

## Timestamps

`enqueued_at_us` and `envelope_updated_at_us` are integers, not Drift
`DateTime` columns. Drift stores those as whole seconds by default, and the
drain order must not depend on two entries happening to land in the same second.
Microseconds since epoch also removes the local/UTC ambiguity of reading a
`DateTime` back out.

## Indexes and integrity

The upgrade finishes with `PRAGMA foreign_key_check`. A violation aborts the
migration instead of leaving a partially trusted database. Both v7 indexes are
created idempotently in `beforeOpen`, like every earlier runtime index.

## Refusing a newer database

`onUpgrade` guards `from < 1 || from > 6 || to != 7`. A database stamped with a
newer `user_version` — one written by a future build — is refused with a
`StateError` rather than silently opened and written by older code. Its own test
covers this.

## Verification

`test/core/data/app_database_migration_test.dart` opens generated schema
fixtures for v1 … v6 and upgrades each to v7, checking preservation of legacy
tables, relationships and event semantics, and that all three new tables arrive
empty. The direct v6→v7 test seeds a complete v6 database — routine scaffold,
session-part snapshot, a recitation bound to that part and slot, a real recall
attempt — proves every row survives byte-for-byte, then exercises the new
tables' own guards: an unknown `status`, an active row whose choice was
`keepDeviceLocalOnly`, a second pending entry for one entity, and the same
entity queued under a different owner (which must be allowed).

`test/core/data/drift_sync_outbox_test.dart` runs the **same**
`runSyncOutboxContract` suite as the in-memory reference, plus owner-isolation
tests and a real restart test that writes to a file, closes the database,
reopens it and finds the queued change with its exact enqueue instant.

`test/core/data/drift_sync_store_test.dart` covers the two transactional
guarantees: a failed local write queues nothing and a refused enqueue rolls the
local write back; a page that fails halfway leaves the cursor where it was and
applies none of it.

The committed schema artifacts are:

- `drift_schemas/drift_schema_v7.json`;
- `test/generated_migrations/schema_v7.dart`;
- the v7 export in `test/generated_migrations/schema.dart`.

**Not yet verified on a real device.** The v6 migration has run on the owner's
own data; v7 has not, because no build carrying it has been installed. Do not
report it as device-verified until it has.
