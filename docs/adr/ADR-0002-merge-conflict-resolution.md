# ADR-0002 — How two devices disagreeing is settled

Status: accepted, 2026-09-21
Supersedes nothing. Extends ADR-0001, which chose the backend.

## The question

Two devices hold the same entity and say different things about it. Something
has to decide, and whatever decides has to reach the *same* answer on both, or
they disagree permanently and neither can correct the other.

`docs/ACCOUNT_SYNC_ARCHITECTURE.md` has carried the rules as prose since the
design was written, with a line saying they need an ADR and property tests
before multi-device sync ships. This is that ADR. The tests are in
`test/core/sync/merge_rules_property_test.dart`.

## What was decided

**1. A conflict is settled by `updatedAtUtc`, then by whether it is a deletion,
then by `deviceId`.**

```
newer updatedAtUtc wins
  → on an exact tie, a tombstone wins
    → on a tie between two of the same kind, the larger deviceId wins
```

Every step is a total order over values both devices already have, so both
compute the same winner without talking to each other. The last step exists only
to make the rule total: it is arbitrary, and it is arbitrary *consistently*,
which is the whole requirement.

**2. Time comes first on the server; a deletion comes first in the local queue.**

This asymmetry is deliberate and was paid for once already. The outbox holds
envelopes from **one** device, where "deleted after editing" is a sequence and
needs no clock, so a deletion supersedes a queued edit outright. The server sees
envelopes from **different** devices, where time is the only ordering that
exists at all.

The rule used to put a tombstone ahead of *any* upsert in both places. That made
a restore unsendable: History's undo pushes an upsert, the server discarded it,
and every other device went on believing the record deleted while the device
that restored it showed it present — with nothing able to correct either. Both
halves were fixed together. **They must agree, or a device and its account
disagree permanently.**

A tombstone still wins an exact tie, because the two sides must converge on
*something* and "withdrawn" is the recoverable answer: History can undo a
deletion, while a resurrection cannot be told apart from the user entering the
record again.

**3. An append-only record is never updated, only added or withdrawn.**

Recitations, rotation adjustments, learning events and recall attempts are facts
about a moment. Two devices can produce different facts; they cannot produce two
versions of the same one. An *update* to an append-only record that already
exists is therefore a symptom — of a reused id, or of a client that has
misunderstood the type — and the server refuses it rather than overwriting
history. A tombstone against one is still accepted, because withdrawing a fact
is a thing the owner really does.

**4. A version that loses is kept, not discarded.**

The server writes every accepted mutation to an audit log, including the ones
that lose. A conflict resolved wrongly is then recoverable; a conflict resolved
silently and destructively is not.

**5. Counters are recomputed, never merged.**

`rotationScore`, `totalRecitations` and the rotation projection are derived from
the journal. Adding two devices' counters would double-count shared history, and
taking the larger would lose one device's work. They are rebuilt from the merged
journal after applying, which is why `SyncEntityType.rotationState` is refused by
the router and skipped by the backfill: a projection with a second source of
truth is a projection that can disagree with what it projects.

**6. The rotation target never decreases because of a merge.**

`rebuildFromJournal(targetFloor:)` takes the current target as a floor. A merge
may raise it; nothing about receiving another device's history is a reason to
ask the owner for less than he had already committed to.

**7. An undatable local row loses.**

Schema v10 added `updated_at_utc` and backfilled nothing, so a row untouched
since that upgrade has no date. It travels stamped at the epoch
(`kUndatedByThisDevice`) rather than at "now". The reasoning is in that
constant, and the short form is: the only way the account holds a *dated* copy
of a row this device cannot date is that another device edited it more recently,
so the account is right. The opposite rule would let a phone untouched for a
year overwrite a newer edit merely by signing in.

## What was rejected

**Last-write-wins on arrival order.** Not a rule, a race. Two devices pushing in
different orders would reach different states and neither would be wrong.

**Asking the user per conflict.** The preview asks once, before anything moves,
with counts. A per-entity prompt during a sync of several hundred records is not
consent, it is an obstacle course, and the answer it collects is "yes" repeated
until the dialog stops.

**Merging field by field.** A recitation with one device's prayer and another's
date is a record neither device ever held. Whole records win or lose.

## Consequences

- Every device needs a clock that is roughly right. A device far in the past
  loses every conflict; one far in the future wins every one. Nothing here
  detects that, and nothing should pretend to — see "still open".
- `deviceId` is random and stored, so the tie-break is stable for a device's
  lifetime and says nothing about the hardware.
- The rules are testable without a backend, which is why the property tests run
  against `FakeSyncBackend`: it is the written-down form of what the server must
  do, and a real backend that disagrees with it is a bug in the backend.

## Amendment, 2026-09-22 — the rules run on the device, because the server cannot

The paragraph above was wrong in a way that mattered, and it was wrong from the
day it was written. **The chosen backend cannot be a party to any of this.**
Appwrite's TablesDB is a row store: `upsertRow` writes what it is handed, and
the project deploys no function, so there is no hook a comparison could live in.
"A real backend that disagrees is a bug in the backend" describes a backend this
project is not using and cannot obtain by fixing.

Meanwhile every applier wrote whatever arrived. So the effective rule in the
shipped path was **the last push wins** — the very thing "What was rejected"
calls a race rather than a rule — and it held for exactly as long as there was
one device, which is why nothing noticed.

**The decision is unchanged; where it runs is.** `SyncMergeDecision` is asked by
every applier for a mutable entity, before writing:

```
the account's copy is applied
  unless this device holds a strictly newer one
```

That is step 1 exactly. Steps 2 and 3 are folded into "the account wins a tie",
because a local row records *when* it last changed and not *which device* wrote
it, so `deviceId` is not available on this side. The fold gives the same answer
step 2 would — a withdrawal at the same instant wins, and History can undo it —
and matches what `FakeSyncBackend` already does on a complete tie.

**Three consequences worth stating, because each was a defect until it was.**

1. **An applied record keeps the time it was authored, not the time it landed.**
   Otherwise each device re-dates a record as it passes it on, and the copy
   grows newer with every hop until it outranks the edit it came from. The v10
   update trigger steps aside when the writer sets the column itself, which is
   what makes this expressible at all; the insert trigger does not, so the stamp
   is a separate statement after the write.

2. **A row this app invents is undated.** The eight empty routine templates each
   install seeds, and the placeholder scheme created when a roster entry arrives
   ahead of its real one. Dated `now` by the insert trigger they outranked the
   owner's real records: a routine authored last week refused by a blank one
   created during setup. Null is "nobody has an opinion here", which is §7's
   reasoning applied to a placeholder instead of to a pre-v10 row.

3. **The account can still hold an older copy than a device has.** When the
   local copy wins, this device keeps it and the account keeps the older one;
   a third device that pulls before anything touches that entity again takes
   the older one. Correcting it means re-queuing the local record when it wins,
   which needs the outbox to be addressable by entity and is **not built** —
   see "still open".

## Still open

- **Clock skew is unhandled.** A server-assigned receive time, used only to
  detect an implausible client clock, is the obvious next step and is not built.
- ~~A hard-deleted row has no tombstone.~~ **Closed.** `SyncTombstones` records
  one inside the same transaction as the delete, for every account this device
  has activated. It is used exactly once — `LearningRepository.delete` — and is
  not a return to "call a recorder from every write": it exists for the cases a
  scan *structurally* cannot see, and there is one.
- **Nothing has run against two real devices.** These rules are verified against
  a local double. That is not the same thing, and it is the check that has to
  happen before this ships. The 2026-09-22 amendment is the strongest argument
  for it there has been: the double was doing the deciding, and nobody noticed
  until the real project was read.
- **A winning local copy is not pushed back.** The device keeps it and the
  account keeps the older one, so a device joining later takes the older one.
  The fix is to re-queue the entity when the local copy wins, which needs a way
  to enqueue one named entity — the outbox is addressable by entity, the
  backfill is not.
