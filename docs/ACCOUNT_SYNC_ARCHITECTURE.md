# Account and progress sync architecture

## Status

Design and local contracts only. **No cloud project exists, no backend SDK is a
dependency of the app, and nothing in the running app touches this code yet.**
The backend choice is recorded in `docs/adr/ADR-0001-account-sync-backend.md`
(Appwrite, Frankfurt). `docs/SERVER_PLAN.md` remains the longer-range plan; this
document is the concrete design for accounts and sync, and replaces that
document's "possible Spring Boot" placeholder.

## The invariant everything else serves

**The app works completely without an account and without a network.** Sync is
voluntary, and the local Drift database is the working copy — not a cache of a
remote truth. A user who never signs in must never experience a degraded app, a
nag, or a feature that silently needs the network.

This is why the sync layer is a set of ports with no implementation wired into
the app: there is nothing to half-work. Until a real backend exists,
`SyncGateway` and `AccountGateway` simply have no production implementation,
rather than a stub that pretends a sync succeeded.

## What syncs and what does not

**Syncs** — everything the user created or chose:

- recitation events and their coverage;
- learning progress and learning events;
- recall attempts;
- rotation schemes, parts and manual adjustments;
- prayer routine templates and part templates;
- prayer sessions and their immutable part snapshots;
- user aliases, and the settings on the allowlist below.

`app_settings` is a generic key/value table that holds both real preferences and
device-local implementation state, so it cannot be synced wholesale.
`SyncAppSettingPolicy` is a **closed allowlist** of the keys that are genuinely
the user's choice: theme, prayer-time settings, transliteration profile,
translation selection, translation language and Quran display preferences.
Everything else stays on the device — the selected learning surah, the selected
prayer context, the recommendation batch and one-time local migration markers
are all "what this device is doing right now", not "what this person decided".
A newly added setting stays local until someone has thought about what it means
on a second device.

**Never syncs:**

- the bundled Quran corpus, translations and transliteration — they are
  redistributable content pinned by provenance and checksum, not user data, and
  re-downloading them by manifest is both cheaper and safer than copying them
  between devices;
- the audio cache, for the same reason;
- derived snapshots and projections — the widget snapshot, the rotation
  projection, the recommendation batch. These are rebuildable from the journal
  by definition, so syncing them would create a second source of truth that can
  disagree with the events.

If a value can be recomputed from synced facts, it is not synced. That rule is
what keeps merge from having to reconcile two different answers to the same
question.

## Record identity

Every synced record carries:

| Field | Purpose |
| --- | --- |
| `id` | stable UUID, assigned locally at creation, never reassigned |
| `userId` | owner; absent while the user is anonymous |
| `deviceId` | which device produced this version |
| `entityType` / `entityId` | what this record is about |
| `schemaVersion` | the local schema that produced the payload |
| `createdAtUtc` | when the fact happened, client clock, never rewritten by the server |
| `updatedAtUtc` | last local mutation |
| `operation` | `upsert` or `delete` |
| `idempotencyKey` | makes a retried push a no-op instead of a duplicate |

A delete is a **tombstone**, not a removal: the record stays in the sync log with
`operation: delete` so that a device which has been offline learns about the
deletion instead of resurrecting the row. `SERVER_PLAN.md`'s rule holds — a
tombstone wins over the record it refers to and is not itself deleted.

Recitation, learning and recall events are append-only in the local schema
already, which is what makes them safe to merge by id: two devices can never
produce conflicting versions of the same event, only different events.

## The outbox

Local writes commit to Drift first and are never blocked on the network. A
successful local commit also enqueues a `SyncEnvelope` in an outbox. A separate
drain step pushes queued envelopes when a session exists and the network allows.

Properties the outbox must have, and which the contract tests pin:

- **Durable and ordered per entity.** A crash between the local commit and the
  push must not lose the change. Entries for the same entity drain in the order
  they were enqueued.
- **Idempotent.** Re-pushing an envelope after an ambiguous failure must not
  create a duplicate; that is what `idempotencyKey` is for.
- **Coalescing by entity.** Ten edits to one routine template while offline
  should not become ten pushes. The latest pending upsert for an entity replaces
  the earlier one; a pending delete supersedes pending upserts entirely.
- **Failure is not loss.** A retryable failure leaves the entry queued with its
  attempt count raised, never silently dropped.
- **A permanent rejection is quarantined, not deleted and not retried forever.**
  A server refusal that will never succeed — a schema the server is too old to
  read, a reused idempotency key with different content — moves the entry out of
  the retry queue into an inspectable quarantine. Retrying it forever would wedge
  every later change behind it; deleting it would discard something the user
  already saw succeed locally. Quarantine is the only honest third option, and it
  needs a user-visible resolution path before sync ships.
- **One envelope id means one record.** Reusing an envelope id for a different
  entity is a programming error and is refused loudly, rather than silently
  overwriting an unrelated queued change.
- **The cursor advances only after a local commit.** A pulled page is applied in
  one transaction and the cursor is saved with it, so an interrupted pull is
  retried rather than skipped.
- **Enqueuing is part of the local write's transaction.** `SyncAwareLocalStore`
  exists to make that explicit: a plain `write(); await outbox.enqueue()` pair
  loses the change if the process dies between the two calls, so the durable
  implementation must commit both together. The port takes the caller's own
  domain write as `applyLocalChange` rather than replaying the envelope's
  payload: the repository that already knows how to write a record does so, and
  a store that re-derived the row from transport payload would be a second,
  competing writer for every table.
- **Queue, cursor and activation belong to an owner, not to the device.** Every
  durable sync row carries a `SyncOwnerKey`. Signing out of account A and into
  account B is cheap to do and catastrophic to get wrong — B would push A's
  recitation history under B's identity — so the separation is structural
  rather than a `clear()` somebody has to remember to call. `SyncOwnerKey.local`
  is the pre-account owner, which keeps "adopt this device's data into an
  account" an explicit merge decision instead of two lifetimes sharing rows.

`SyncEngine.drain` also validates the server's own answer before acting on it:
the accepted and rejected id sets must be disjoint and must together cover
exactly what was sent. A malformed response is treated as a retryable failure
rather than trusted, because acknowledging an envelope that was never stored is
indistinguishable from data loss.

Stage G shipped the ports, an in-memory reference implementation and the
contract suite, and deliberately stopped there: the v6 migration slot was spent
on `recall_attempts`, and a table nothing writes to, for a server that did not
exist, would have been migration risk with no benefit.

**Stage J adds the durable side (schema v7).** Three tables, transport only:

| Table | Holds |
| --- | --- |
| `sync_outbox_entries` | the retry queue **and** the quarantine, separated by `status`, one row per queued envelope, scoped by `owner_key` |
| `sync_cursors` | where each owner's pull left off |
| `sync_activations` | each owner's answer to the first-sync preview, the backup id it was shown with, and the last successful sync |

`DriftSyncOutbox` passes the *same* `runSyncOutboxContract` as the in-memory
reference — a weaker suite for the implementation that actually ships would move
the guarantees to wherever they were easiest to keep. `DriftSyncStore` owns the
two transactional guarantees (local change + enqueue; pulled page + cursor) and
the owner scoping.

Two invariants live in the schema rather than only in the code that maintains
them: a partial unique index on `(owner_key, entity_key) WHERE status =
'pending'` enforces coalescing, and
`CHECK (is_active = 0 OR choice = 'merge')` makes it impossible to activate sync
for a user who chose to keep the device local.

The migration backfills nothing. Synthesizing one queue entry per historical
recitation would push a user's entire journal the first time they ever sign in —
exactly the merge the activation gate exists to make explicit. Nothing in
`lib/app/` or `lib/features/` references any of it yet: the tables ship with the
migration, the wiring ships with a real gateway.

## First sign-in must not overwrite local progress

This is the single most dangerous moment in the whole feature, because the user
already has real history on the device and may already have history in the
cloud.

The rule: **signing in never destroys local data, and never silently merges.**
Authentication establishes identity and nothing else; `SyncActivationGateway` is
the gate between having an account and that account being allowed to touch
existing local data.

1. Take a local backup first — `LocalBackupGateway.createBackup` — and keep it
   until the user confirms the result. The returned `backupId` travels inside the
   preview, so a preview can prove its recovery copy exists.
2. Fetch the remote state and compute a **merge preview**: how many records exist
   only locally, only remotely, and on both sides, plus how many the
   deterministic rules could not settle.
3. Show that preview and require an explicit confirmation. Offer the honest third
   option — `keepDeviceLocalOnly`: keep this device's data and do not link it to
   the existing cloud account — rather than forcing a merge.
4. Apply the merge in one transaction, then rebuild projections from the journal.

The preview carries an opaque `token` that the confirmation must quote back. A
dialog left open while the data underneath changed cannot authorize a merge it
never described; a stale token is refused rather than applied to whatever the
state happens to be now.

`LocalBackupGateway` deliberately works **without an account and without a
network**: export and recovery belong to the person, not to the sync feature.

Deterministic merge rules, inherited from `SERVER_PLAN.md`:

- append-only events merge by id; a duplicate id is the same event, not two.
  Recitation events, learning events, recall attempts and rotation adjustments
  are marked append-only on the envelope itself, and the server refuses an
  *update* to one that already exists — two devices can produce different
  events, never two versions of the same one, so an "update" to a recorded fact
  means something is wrong and should surface rather than overwrite history;
- a tombstone beats the record it refers to;
- versioned values (aliases, ordering, settings, routine templates) resolve by
  `updatedAtUtc`, ties broken by `deviceId` so both devices reach the same
  answer; the losing version stays available for audit rather than vanishing;
- materialized counters are never summed across devices — `totalRecitations` and
  `rotationScore` are recomputed from the merged journal;
- the global rotation target never decreases as a result of a merge.

These rules need their own ADR and property-based tests before multi-device sync
ships. They are written down here so the tests have something to check against,
not because they are final.

## Accounts and identity linking

Google and Yandex sign-in both map to Appwrite identities on one account.

**Linking is only ever initiated by an already-authenticated user.** The flow is:
the user is signed in, chooses "link Yandex", completes that OAuth flow, and the
new identity attaches to the current account. An unauthenticated OAuth login is
a *sign-in*, never a link — otherwise anyone who controls an email address
could attach themselves to an existing account.

Appwrite enforces email uniqueness across all users and identities, so the case
where Google and Yandex return the same address resolves to "already claimed"
rather than to a silent account merge. Merging two separate accounts that turn
out to be the same person is **out of scope** and should stay that way: it is a
data-destroying operation with no safe automatic answer.

## Export and deletion

There are two of each, and conflating them is how people lose data:

- **`LocalBackupGateway.exportLocalData`** produces a portable JSON document of
  this device's events, mastery state, learning progress, recall attempts,
  routines, settings and aliases, stamped with the schema version. The Quran
  corpus and audio cache are excluded and re-fetched by manifest. It needs no
  account and no network — a user who never signs in can still take their data
  with them.
- **`AccountGateway.exportCloudData`** produces the same shape for what the
  account holds, which is what a data-portability request actually asks for.
- **`AccountGateway.deleteCloudAccount`** erases the account and its cloud copy,
  then ends the session. Appwrite's client `Account` API blocks access but does
  not delete the user record; complete erasure goes through the server `Users`
  API, which needs an API key and therefore a deployed Appwrite Function. That
  Function is part of the work, not an afterthought — a "delete my account"
  button that only signs the user out would be a lie.
- **Deleting local data is a separate, explicit choice.** Erasing the cloud copy
  must not silently wipe the device, and signing out must not either: ordinary
  sign-out leaves the outbox intact so queued changes resume when the same
  account returns. `SyncOutbox.clear` is reserved for confirmed erasure or for a
  deliberate "keep this device local-only" decision.

## Access rules

Server-side rules must permit a user to read and write only their own documents.
This is enforced on the server, never only in the client: a client-side filter is
a display choice, not a security boundary.

## Secrets

**Client secrets never enter this repository, the APK, application logs or the
handoff journal.** In Appwrite's model the OAuth client secret is entered in the
Appwrite console and stored server-side. The app needs only:

- the public Appwrite endpoint;
- the public project id;
- an `appwrite-callback-<PROJECT_ID>` intent filter in `AndroidManifest.xml`.

None of those are secrets, but the project id will still be supplied through
build configuration rather than hard-coded, so a fork does not inherit someone
else's project. Nobody should send a client secret into a chat or a commit, and
any secret that is ever pasted somewhere it should not be must be rotated rather
than deleted and forgotten.

## Implementation stages

1. **Ports and outbox, no server.** ← *this stage*
2. **Contract tests and a local fake backend.** ← *this stage*
3. **Create the real cloud project.** ← **stops and asks the owner**
4. Configure Google/Yandex redirect URIs and public identifiers through secure
   configuration.
5. Closed migration/merge test on two devices.

## What is needed from the owner to continue past stage 2

Work stops before stage 3 by instruction. To continue, the owner needs to create
the project and provide only **public** values:

- an Appwrite Cloud account, and a project created in the **Frankfurt** region
  if EU residency matters (region choice is a Pro-plan feature);
- the **project id** and the **endpoint URL** — both public;
- a Google Cloud OAuth client and a Yandex OAuth application, with their
  redirect URIs set to the callback URLs that the Appwrite console displays;
- the client id **and** client secret for each provider entered **into the
  Appwrite console directly** — not sent to this chat, not committed, not
  written into the handoff journal.

## Current code

`lib/core/sync/` contains the ports, the envelope model, the app-setting
allowlist, an in-memory outbox, the drain/pull engine and a local fake backend.
Nothing in `lib/app/`, `lib/features/` or the Android code references it: it is a
tested library waiting for a backend, not a feature that is half-on.

`test/core/sync/` holds the contract suites any real implementation has to pass.
`runSyncOutboxContract` is written once and run against the in-memory outbox
today; the durable Drift-backed outbox will run the same suite unchanged. The
fake-backend suite is where the rules a *server* must enforce — per-user
isolation, idempotency, monotonic cursors, surviving tombstones, append-only
refusal, deterministic conflict resolution — are written as executable
behaviour rather than prose, so the eventual Appwrite adapter has a definition
to satisfy instead of an intention.
