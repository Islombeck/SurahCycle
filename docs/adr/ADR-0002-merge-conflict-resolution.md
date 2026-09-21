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

## Still open

- **Clock skew is unhandled.** A server-assigned receive time, used only to
  detect an implausible client clock, is the obvious next step and is not built.
- **A hard-deleted row has no tombstone** unless something records one. The
  journals withdraw by writing a date; a learning plan is deleted outright and
  its deletion does not travel.
- **Nothing has run against two real devices.** These rules are verified against
  a local double. That is not the same thing, and it is the check that has to
  happen before this ships.
