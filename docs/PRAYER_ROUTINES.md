# Prayer routines — Sprint 6A

## Product boundary

A prayer routine is a user-authored ordered list of parts for one
`PrayerType`. Murajaah does not install or infer a madhhab preset. Schema v5
creates one empty template for each supported type and leaves every part,
rakaat count and surah-slot count to the user. The scaffold's enabled flag is
true, but an empty template has no runtime effect; the user can disable it at
any time.

Supported prayer contexts are Fajr, Dhuhr, Jumuah, Asr, Maghrib, Isha, Witr
and Nafl. Jumuah is a distinct manual context, not another label for Dhuhr.

## Domain model

`PrayerRoutineTemplate` is the editable definition. It has a unique prayer
type, an enabled flag, a positive revision and a contiguous ordered list of
`PrayerRoutinePartTemplate` values. Each part stores:

- a stable key and order index;
- kind: `fard`, `sunnah`, `witr`, `nafl` or `custom`;
- a required custom label for `custom` parts;
- a positive rakaat count;
- a non-negative number of required surah slots;
- whether completion by following the imam is allowed;
- a default completion mode.

The rakaat count describes the prayer part. A recitation event still stores
one `rakaatSpanCount`; Murajaah does not invent an ayah-to-rakaat mapping.
Zero-slot parts are valid and complete automatically when a session snapshot
is created. They create no recitation event and no rotation credit.

## Revision-safe editing

Settings exposes the templates directly. The user can enable or disable the
whole routine, add a part, edit every field, reorder parts, and delete a part
after confirmation. The repository uses optimistic revision checks: every
successful mutation advances the template revision exactly once, while an
editor based on an older revision receives `PrayerRoutineRevisionConflict`.

There is intentionally no independent `enabled` flag on an individual part in
schema v5. A part is either present in the ordered template or explicitly
deleted; the whole template can be disabled without losing its parts.

## Immutable session snapshots

At the first registration for a prayer context and local date,
`ensureCurrentSession` snapshots the current enabled template into
`PrayerSessionPart` rows. The snapshot copies label, kind, order, rakaats,
required slots, imam capability, completion mode, source part id and template
revision. Later template edits never rewrite an existing session.

The latest session with parts for the exact `PrayerType + isQada + localDate`
is reused, including after completion. Deterministic ids make foreground and
headless widget callers converge on the same session. A disabled or empty
template creates no empty session and retains the legacy registration flow.

`currentPart` is the first incomplete part in snapshot order. Its
`nextSlotIndex` is the first unoccupied index in `0..<requiredSurahSlots`.
Completing the last slot marks the part complete. The next ordered part then
becomes current; after the last part the session is complete and new marks are
rejected.

## Exact-slot write boundary

The database and repository, not the presentation layer, are authoritative.
When an exact routine exists for the event's prayer/date, a write must carry
the complete tuple:

```text
prayerSessionId + prayerSessionPartId + slotIndex
```

The repository validates the tuple again inside the registration transaction:

- session exists and matches prayer type, Qada flag and local date;
- part exists, belongs to the session and is the first incomplete part;
- part is not already complete;
- slot is in range, unoccupied and exactly the next free slot.

A partial tuple, skipped slot, later part, completed session, or stale
slotless action fails closed and creates neither an event nor rotation credit.
The partial unique index on active `(prayer_session_part_id, slot_index)` is a
second concurrency guard. Deleted history no longer occupies a slot; Undo and
projection rebuild reopen the exact resulting state.

Legacy events remain valid with null session-part and slot links. A slotless
registration remains valid only when no configured/current routine exists for
that exact context and date.

## Following the imam

`Followed the imam` is an explicit, confirmed completion action available only
for the current eligible Fard part when no recitation slot has been used. It:

- sets the part completion mode and completion timestamp;
- creates no `RecitationEvent`;
- changes no global rotation score, debt or statistics;
- is rendered as `Completed by following the imam`, not as `0/N` missed slots;
- returns a repository-owned short-lived Undo capability.

Undo reopens only that exact completion and is rejected if the part changed or
later part history/completion now depends on it. A later part cannot be marked
as followed while an earlier part is incomplete.

## Jumuah

Jumuah is manually selected. The solar prayer-time resolver continues to
return Dhuhr on Friday and never manufactures a Jumuah time. During the current
Friday Dhuhr context Home offers an explicit one-event Jumuah override; it is
not persisted as a change of automatic mode.

Jumuah does not support Qada in this product model. Its history and statistics
remain separate from Dhuhr. A newly added Jumuah Fard part defaults to allowing
followed-imam completion, but the user can change that field before saving.

## Home and Android Rotation Widget

Home shows the current part, ordered part progress and explicit imam action.
Surah controls are disabled when the resolved routine is complete; the write
boundary still revalidates stale callbacks. A completed routine never falls
back to a fake prayer or an arbitrary slot.

Widget snapshot schema 5 carries display-ready current-part/progress labels.
Action schema 2 adds the exact session tuple. Kotlin validates and transports
the payload but does not select parts or slots. Dart re-resolves the current
prayer and routine at execution time and rejects stale actions. Schema-1
actions remain parseable for launcher-cache compatibility, but are rejected
if a routine now requires an exact slot.

## Related documents

- [DATABASE_MIGRATION_V5.md](DATABASE_MIGRATION_V5.md)
- [INTERACTIVE_ANDROID_WIDGET.md](INTERACTIVE_ANDROID_WIDGET.md)
- [PRAYER_TIME_ARCHITECTURE.md](PRAYER_TIME_ARCHITECTURE.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
