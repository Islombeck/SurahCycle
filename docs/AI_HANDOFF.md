# Murajaah AI handoff

## Current state

### Reconciled continuation — 2026-09-17 (read this before historical entries)

- Active owner brief: `C:\Users\User\Downloads\SURAHCYCLE_NEXT_HANDOFF_CODEX_CLAUDE2.md`, including the September 16 priority clarification. The owner asked Codex to continue after Claude and reconcile the confusing reports. Verified starting HEAD: `dee3d5a` on `main`; tracked tree clean. Only `.codex/`, the owner's photo and historical video directory were untracked. Preserve those files.
- The repository is newer than the attachment's baseline: regression fixes, the month calendar/historical Home path, schema **v8**, durable owner-scoped outbox, Appwrite account adapter and Settings account screen are committed. `brand/` is committed too. Old statements below saying schema v6/v7, no account screen, no callback activity, or no Appwrite project are historical, not current instructions.
- Independent baseline checks this continuation: the Qada-origin, direct migration, historical-registration UI and calendar-repository suites pass **28/28**. **Correction, 2026-09-17:** "Claude recorded 881/881 at this HEAD" was a misattribution — at `dee3d5a` Claude had recorded nothing, his last own figure being 861/861 at `3fafbf0`, before these three commits existed. Replaced with a fresh run rather than a corrected citation: with this continuation's working tree in place, `flutter analyze` is clean and `flutter test` is **891/891**, run by Claude after fixing the guard below.
- Still open in priority order: freeze registration context across asynchronous work (§D); separate actual Qada fulfilment date from the missed prayer date and entry timestamp (§E), including historical UI/calendar and legacy compatibility; audit remaining §C–F requirements; then finish Stage J provisioning, activation/data transport, and real OAuth/two-device checks. A green test suite or installed APK is not owner acceptance.
- Appwrite state last checked by Claude: project `6aa91956000d1d490a3e`, Frankfurt; Android platform registered; provisioning declaration exists but database/table not applied; Google/Yandex provider applications created but Appwrite providers disabled pending owner-entered values. This continuation has not rechecked cloud state. Do not fetch secret-bearing project/provider objects or ask again for public configuration. An account screen does not mean data backup is active.
- ADB currently sees the authorised Jelly Max. No settings, personal history or installed APK have been changed in this continuation. The old temporary-device-setting notes below were superseded by the September 15 restoration record.
- Active checkpoint: reproduce delayed registration/date switching and duplicate-submit boundaries on test data before fixing. Qada date persistence is being reviewed separately; no new migration has been applied.
- **One defect found while reconciling this work, and fixed rather than reported:** the new registration-context guard replaced `mounted` with `_isRegistrationContextCurrent(token)`, which does check `mounted` — but only inside itself, where the analyzer cannot follow it. Four analyzer findings resulted, three of them `use_build_context_synchronously` on a path that touches `context` after an `await`. The logic was already correct; the check is now spelled out at the call site, because a lint about `BuildContext` across an async gap is not one to silence on a path that shows a SnackBar after a database write. Analysis is clean again.

### Historical current-state entries (superseded by the reconciliation above)

- 2026-09-17: Google and Yandex OAuth applications now exist for end-user sign-in; both Appwrite providers are still `disabled` pending the owner pasting their client ids and secrets. Full detail and the two exact redirect URIs are under **Stage J §6.3**; the Android platform question there is closed. `brand/` holds the app's first real logo.
- 2026-09-17: **§6.3 client wiring is in, parts 1 and 2** — the `appwrite` SDK, a real `AccountGateway`, the OAuth callback filter, and an account screen at `/settings/account` inside the Settings branch. Analyze clean, **881/881**. Identity only: signing in moves no data, and the screen says so rather than implying a backup. `lib/core/sync/` is referenced by the app for the first time. Activation and the data gateway remain blocked on §6.2 provisioning. Nothing has run on a device, and sign-in cannot complete until the owner pastes the four client values into the Console.

- 2026-09-15 Codex resumed after Claude's continuation. Reconciled the real repository at `831c54cbf95df120c954aa85ac34348486d11665`: Stages A-F and their device-verification notes are committed. Claude also left an uncommitted Stage G draft consisting only of `docs/ACCOUNT_SYNC_ARCHITECTURE.md`, `docs/adr/ADR-0001-account-sync-backend.md`, `lib/core/sync/`, and `test/core/sync/`; `docs/DATABASE_MIGRATION_V6.md` is an untracked Stage F document that also needs reconciliation. These files are being reviewed and verified before staging. No tracked source change was present when Codex resumed. The photo and `Скринсейверы до v6/` remain user-owned and excluded.
- ADB currently sees `JELLYMAX00003540` (`Jelly_Max`) as `device`. Prior handoff proves Stage A and Stages D-F foreground scenarios on the device, but widget placement/lifecycle, selected DreamService, and opted-in notification remain physically open. Device settings `stay_on_while_plugged_in=3`, `accelerometer_rotation=0`, and `user_rotation=0` are temporary QA changes that must be restored when device QA ends.

- 2026-09-14 continuation: new user-authorized task is `C:\Users\User\Downloads\MURAJAA_NEXT_HANDOFF_CODEX_CLAUDE.md` (read in full). It supersedes the previous completed A–E scope below. Starting HEAD independently verified as `fb6f8c5e970703ce50a2ed8acb7ca6a18b4eaeb5`, branch `main`; tracked tree and `git diff --check` clean. User-owned untracked media now lives in `Скринсейверы до v6/` (10 videos), plus the existing photo; preserve all.
- Active work: Stages A (routine editor reliability), B (Qada policy), C (sticky manual context), D (Learning navigation), E (stable eight-item recommendation batch) and F (memory-recall mode) are complete, plus a cross-cutting drift watch-stream fix found during device QA. **The single next schema migration is now spent: schema is v6 and it added `recall_attempts`.** Ordered remaining scope: physical Prayer widget/DreamService verification; Stage F device verification; account/sync architecture and local contracts; user-facing SurahCycle rename. Cloud-project setup requires the user's participation. No change to applicationId without ownership/publication evidence.
- Before fixes: `adb devices -l` succeeded and returned an empty device list. User asked to connect/unlock/authorize USB debugging; device verification is pending, not passed. Baseline analyzer/full tests are about to run. This session recreated the missing `M:` alias to the ASCII junction; local Android SDK is `C:\Users\User\AppData\Local\Android\Sdk`.
- Historical entries below describe the prior September 4 session; their pending-commit statements are superseded by the verified September 14 Git history.

- Current HEAD: `ebf090d` (`Docs: update AI handoff after Sprint 5E2 commit`) at the time this paragraph was written; a further docs-only commit for Checkpoint E follows immediately after. Branch `main`.
- Active checkpoint: Checkpoint E (evidence-only Cyrillic transliteration source audit) complete. This was the last checkpoint in the external continuation prompt's ordered list (A–E). **A future session that starts without a new continuation prompt has no more pre-assigned checkpoint work** — ask the user what to work on next rather than inventing scope.
- Tracked tree is clean except for this handoff-doc update itself, about to be committed. The repository still contains one untracked photo and one untracked directory of historical videos (`Скринсейверы до v5/`); these are user-owned QA materials and must not be added, moved, renamed, or deleted implicitly.
- Sprint 5E2 (Checkpoint D) checks are green: analyzer clean, full Flutter test suite 459/459 (run twice — before and after a `dart format` normalization pass, both green), Gradle `:app:testDebugUnitTest :app:compileDebugKotlin` `BUILD SUCCESSFUL`. No debug APK build was run — the user explicitly said to continue without one until the end of the sprint ("apk до конца спринта не обязателен"). Checkpoint E made no code changes (see next bullet), so no Flutter/Gradle re-verification was needed for it.
- Checkpoint E is pure documentation: one new file (`docs/QURAN_CYRILLIC_TRANSLITERATION_AUDIT.md`) plus two link-only edits (`docs/QURAN_TRANSLITERATION.md`, `docs/BACKLOG.md` item 26). No `lib/`, `android/`, or `test/` file changed. The audit used a background multi-agent workflow (4 independent search angles + independent re-verification of the 10 most promising of 20 unique candidates found) rather than a single linear search, specifically because the checklist in `docs/QURAN_DATA_SOURCES.md` demands the kind of adversarial, byte-level double-checking a single pass tends to skip — and it caught real problems a shallower pass would have missed (see Decisions and reasons).

## Next exact action

**Superseded 2026-09-15 by `SURAHCYCLE_NEXT_HANDOFF_CODEX_CLAUDE.md`.** Two statements that used to stand here are now out of date and are corrected rather than deleted, because a stale "next action" is how a session gets sent to redo finished work:

- **The Appwrite project now exists.** The owner created it through GitHub, region Frankfurt, named SurahCycle. Its public client configuration is `APPWRITE_PROJECT_ID=6aa91956000d1d490a3e` and `APPWRITE_ENDPOINT=https://fra.cloud.appwrite.io/v1` — both public, both safe to hold here, and **not to be asked for again**. Secrets remain absent: no API key, no Google/Yandex client secret in chat, Git, the APK or this journal.
- **The brand question is settled.** The owner chose **SurahCycle** after the `Salah Circle` near-miss; the rename is done and verified. A real trademark search in the target countries is still required before publishing, and that is the owner's step.

The new prompt's order is: verify the baseline (done — HEAD `c5df1f6`, analyze clean, 703/703, tree clean except the owner's QA media), then **Stage I** (close three loose ends: lock-screen documentation, real widget tap, normal navigation to surah details), then a checkpoint plus one exact APK for the owner's acceptance smoke test, then **Stage J** (really connect Appwrite: provisioning script with a dry run, client wiring, durable outbox on schema v7, Google/Yandex OAuth checklist, two-device verification).

**All three Stage I loose ends are closed (2026-09-15):**

- ~~a tap on the physically placed widget was attempted and missed~~ **Verified working.** It only fails after an explicit `am force-stop`, which is OS behaviour, not a defect — see Stage I 5.2 below.
- ~~the surah detail screen appears unreachable through normal navigation~~ **Reproduced, and my earlier report was wrong:** the screen was always reachable; I had tapped the overflow menu. A different, real defect was underneath — the screen opened outside the navigation shell — and that is now fixed.
- ~~`docs/LOCK_SCREEN_LEARNING.md` has not yet been updated with the section-14 results.~~ **Done (Stage I step 5.1).**

**Acceptance happened and failed on two points; both are now fixed** (reorder silently discarded; the eight-item block shrinking once repeats appeared — see Verified completed work). Backlog item 27 records the horizontal Prayer Times widget the owner asked to defer.

**A rebuilt APK carrying both fixes is installed (2026-09-16).** `app-debug.apk`, sha256 `9e1f0741b5c7e55c954fcb13e129a1c3d41c81f137a2586d16c62bf7fc1754ce`, 229 216 840 bytes, installed with `adb install -r` at `lastUpdateTime=2026-09-16 08:10:22`. The owner's data survived: a pulled copy of `murajaah_user.sqlite` reports identical row counts before and after (`recitation_events=636`, `recitation_event_parts=638`, `mastered_surahs=27`, `prayer_routine_part_templates=15`, `recall_attempts=4`, `learning_events=32`, `app_settings=10`, `surah_metadata=114`) at `user_version = 6`. **Note that this APK predates schema v7** — it was built before the v7 work below, so v7 has never run on a real device.

**Two things are still owed to the owner, and both need him:**

1. **Re-check acceptance points 1 and 3** on the installed build — the part editor (add/edit/**reorder**/delete) and the eight-item block once entries read `2×`.
2. **Delete the leftover test part in Зухр.** It is the 4th part, `order_index 3`, Фард, 3 рак., 2 слота, id `df2c79e9-c6a7-4db6-955f-adcdabf70f65` — added by me during Stage A QA and never removed. The other four Зухр parts (4 сунна, 4 фард, 2 сунна) are the owner's own. **I could not remove it:** the phone is locked with a credential (`dumpsys trust` → `deviceLocked=1`) and the lock screen renders black to `screencap`, so no UI automation was possible, and removing it by writing to the database directly would mean going behind the app. Deleting it through the part editor *is* smoke-test point 1, so the chore and the re-check are the same action.

## The recommendation cycle ran away — found on the device, reproduced, fixed

Reading the owner's own `app_settings` on 2026-09-16 showed
`recommendationBatch.cycle.cycleNumber = **5392**`. A cycle is one pass over the
eligible pool; with 27 mastered surahs and 8 per batch a pass is about four
batches, so that counter implied tens of thousands of re-plans against 638
recitations.

**Reproduced before anything was changed.**
`test/app/recommendation_cycle_runaway_test.dart` builds the real provider graph
over a real database and listens to `currentRecommendationBatchProvider` for two
prayer contexts at once. With one context the counter reaches a fixed point;
with two the test **hangs**, because the planners never stop.

The cause was a feedback edge visible in the code once you look for it: planning
saves into `app_settings`, and the planner subscribed to `app_settings` through
`repository.watch()`. A save fed its own subscription. With one live key that is
harmless — the stored batch matches, the plan comes back untouched, nothing is
written again. With two live keys against the one stored slot each planner saw
the other's batch, re-planned, saved, and woke the other. Every lap could
advance the cycle.

The file's own comment already warned that "two planners writing to one stored
slot would overwrite each other in a loop" — about the widget driver. It was
true of the app itself, because a context change leaves the previous family
instance alive for a while.

Fix: read the stored state **once** per rebuild instead of subscribing to it.
Nothing is lost — this provider is the only writer, the widget reads the
read-only view, and everything that could change a plan is already watched.

**Verified on the owner's device** with the build carrying the fix (sha256
`0101eea9…`): the counter advanced once on launch, 5392 → 5393, which is one
legitimate re-plan for a changed key, and then stayed at 5393 through 45 seconds
of the app being open **and** through an explicit prayer switch — the two-live-
key scenario that used to be the loop. Row counts and `PRAGMA foreign_key_check`
unchanged. The stored number itself stays at 5393; it is a counter, nothing
depends on its magnitude, and resetting it would mean writing to his data for
cosmetic reasons.

Also verified on the device in the same session: the prayer picker now opens
with **Зухр** ticked while the card reads Зухр, where it used to show a stale
Магриб.

**A correction to an earlier note in this journal:** the `-4x`, `-5x`, `-6x`
badges in the second video are **not** repeat counts. They are the remaining
indicator showing how far *ahead* of the rotation target a surah is. The earlier
reading of them as cycle repeats was wrong.

**A correction to an earlier note in this journal:** the `-4x`, `-5x`, `-6x`
badges in the second video are **not** repeat counts. They are the remaining
indicator showing how far *ahead* of the rotation target a surah is. The earlier
reading of them as cycle repeats was wrong.

## Next exact action (2026-09-16, after the regression fixes)

Fixed and committed this session, each with its own checkpoint:

- `242a02c` — the prayer picker no longer opens on a stale selection; a
  reloading settings provider no longer reads as "no settings"; the stored
  context is read atomically.
- `c296cb6` — the active-surah list no longer re-sorts under the finger.
- `f99c255` — deleting a part offers to remove it from the prayer already open.
- `7bdacd3` — the month calendar.

**APK built and installed 2026-09-16 11:52, and schema v7 ran on real data for
the first time.**

- `app-debug.apk`, sha256
  `750d73331ae5c2004f565e41b24c16a2127c2ff8415cb88da500193826262fee`,
  229 368 904 bytes, from HEAD `7bdacd3`.
- Before installing, a copy of the owner's database was pulled as a backup. It
  had already moved since the previous build — 638 recitation events, 32
  sessions, **14** part templates (he deleted the leftover test part himself)
  — so this is live data, not a fixture.
- After installing and launching, `user_version` reads **7** and **every
  pre-existing count is identical**: `recitation_events=638`,
  `recitation_event_parts=640`, `prayer_sessions=32`,
  `prayer_session_parts=47`, `prayer_routine_part_templates=14`,
  `mastered_surahs=27`, `recall_attempts=4`, `learning_events=32`,
  `app_settings=10`, `surah_metadata=114`. The three sync tables exist and are
  empty, both v7 indexes are present, `PRAGMA foreign_key_check` returns
  nothing and `integrity_check` is `ok`.
- So `docs/DATABASE_MIGRATION_V7.md`'s "not yet verified on a real device" no
  longer holds: it has now run on the owner's own data, with a backup taken
  first. It was **not** interactively smoke-tested, because the phone is locked
  with a credential — see below.

**Still owed and requiring the owner:** every UI-level check. The phone is
locked (`deviceLocked=1`) and its lock screen renders black to `screencap`, so
installing, launching and reading the database are possible from here and
tapping is not. What needs his eyes:

1. that marking a surah no longer moves the row under his finger, and that the
   page stops jumping — the thing that blocked him from entering yesterday's
   prayers;
2. that the prayer picker opens on the prayer actually in effect;
3. the new calendar (icon on Home, next to the history icon);
4. the Иша → Витр observation described below.

**No longer owed:** the leftover test part in Зухр — he removed it himself, and
the template now has 14 parts.

**The Иша → Витр transition is closed.** The owner said not to wait for the
observation, so `_applyIshaToWitrTransition` now applies only to an
automatically resolved context: a prayer he chose himself never moves on its
own. The agreed automatic behaviour is unchanged, and both halves are pinned by
`test/app/isha_to_witr_transition_test.dart`.

## §E and §F are done; what is left

The month calendar ships, and a day chosen in it hands itself to the **one**
registration path: Home then names that day in a banner with one way out, a past
day forces the prayer to be named explicitly, and a future day offers no button
at all. Qada can now say its original day is unknown (schema v8).

**Verified on the device end to end on 2026-09-16** with sha256 `e7789500…`:
14 September opened from the calendar showed «Фаджр / Зухр · частично / Аср /
Магриб / Магриб · Каза» against real history, the button landed on Home with
«Отмечаю за пн, 14 сент.», and «Вернуться к сегодня» cleared it. Row counts and
`PRAGMA foreign_key_check` unchanged; the app was left out of historical mode.

**Not done, and next:**

1. **§E's remaining half — the day a Qada was actually made up**, editable for a
   late entry. Only `qada_origin_is_unknown` went into v8; the fulfilment date is
   a second column and was deliberately left out rather than added with nothing
   writing it. For a Qada entered on the day it was made up, `created_at_utc`
   already carries that moment.
2. **Pre-selecting only the still-unmarked parts** for a chosen day. The
   occurrence sheet shows a session's parts, but the calendar path does not yet
   preselect the unfilled ones.
3. **Stage J** continues: real Appwrite gateway, provisioning, owner
   permissions, opt-in sync. §6.0 is **no longer blocked on the owner** — the
   OAuth grant succeeded on 2026-09-17. It is blocked on **one more authorize
   round trip** carrying `authorization_details`, because the first grant came
   back bound to no project. See "Stage J §6.0 — the Appwrite OAuth grant"
   below for the exact recipe; do not re-run `/mcp` → Authenticate, which
   cannot work.

## Stage J §6.2 — the provisioning declaration exists; nothing was applied

`tool/appwrite_provisioning.dart` declares the cloud shape and diffs it against
observed state. Dry run against an empty project: two operations — create the
`surahcycle` database, then create the `sync_log` table with row-level security,
10 columns and 3 indexes in **one** call, so a failure cannot leave a half-built
table behind.

The planner **cannot reach Appwrite**, deliberately: a script able to apply this
would need an admin API key, and §6.2 forbids one ever entering the repository.
It plans; the agent applies through the authenticated MCP connection, executing
exactly the operations the planner emits.

Owner isolation is in the declaration rather than in a promise: `row_security`
is on, the table grants `create("users")` and nothing else, and the unique
index is `(userId, idempotencyKey)` rather than `idempotencyKey` alone — a key
generated on one device means nothing outside the account that produced it, so a
global unique index would let two accounts collide.

**Deliberately not applied on 2026-09-17.** The only grant available was
account-wide (see below) and expiring within the hour. §H.5 requires the
declarative dry run *before* applying, and creating entities under a deadline
with account-wide write, into a project that has to stay reproducible, is the
"видимый прогресс" the prompt forbids. The grant was left to expire on its own.

**The decision still owed before applying:** the working grant had `all`,
`project:all`, `organization:all` and every write scope, with
`authorizationDetails: []` — account-wide, not SurahCycle-only. A narrow,
project-bound grant was tried earlier and could not read. **Those two attempts
changed two variables at once — scope breadth *and* binding — so the
interesting combination was never tested: broad scopes *with*
`authorization_details` binding to `6aa91956000d1d490a3e`.** That is the next
experiment, and it may give full capability inside one project. Do not conclude
"account-wide or nothing" until it has been run.

**Update 2026-09-17 — the capability half is answered; the apply is blocked
somewhere else entirely.**

- **The current grant can write to the project.** The Android platform was
  created through it today and independently read back, so "will a write even
  work" is settled. What remains is breadth, i.e. risk. Worth stating plainly:
  the account has exactly one organization and one project, so account-wide and
  project-bound presently grant the same access — the difference starts to
  matter the day a second project exists.
- **The owner chose to proceed now and revoke the grant afterwards.**
- **The apply was refused by Claude Code's own permission classifier**, not by
  Appwrite and not by the owner. `tables_db_create` returned `Permission for
  this action was denied by the Claude Code auto mode classifier. Reason:
  [Modify Shared Resources]`. **Nothing was created; the project is unchanged.**
  The refusal was not worked around, and a future session should not work around
  it either: the Appwrite Console ships an authenticated CLI in a terminal pane
  that could run the same operation, and using it would be the same modification
  by another route.
- **What unblocks it:** the owner runs the two operations in the Console
  himself, or allows these MCP writes for the session, or applies them from a
  session whose permission mode permits them.

`tool/appwrite_provisioning.dart` gained `--json`, printing each operation's
exact `tool_name` and `arguments`. Applying a plan by reading a one-line summary
and retyping it is how the thing that ships stops matching the thing that was
reviewed. 15/15 planner tests pass unchanged, analyzer clean.

## Stage J §6.1 — SETTLED against the live project: it is TablesDB (2026-09-17)

The grant works. `appwrite_get_context` with `project_id=6aa91956000d1d490a3e`
returned, read-only and with nothing created:

- project **SurahCycle**, region `fra`, status `active`, created 2026-09-15,
  organization `6aa917cc000c85881d14` ("Personal projects", plan `tier-0`);
- services, all empty: `tablesdb` 0, `users` 0, `storage` 0, `functions` 0,
  `sites` 0, `messaging` 0, `teams` 0;
- connection `mode: oauth_console`, endpoint `https://cloud.appwrite.io/v1` —
  the console API, not the `fra.` regional host the app is compiled against.
  Both are correct for their own purpose; `AppwriteConfig` is unaffected.

**The `Databases`-vs-`TablesDB` question the handoff has been carrying since
Stage G is answered: this project speaks TablesDB.** The context summary has a
`tablesdb` key and no `databases` key at all, and the operator catalog exposes
`tables_db_*` tools — `tables_db_create_index`, `tables_db_create_enum_column`,
`tables_db_create_relationship_column` and so on — every one keyed by
`database_id` + `table_id`, with **columns** and **rows**, not attributes and
documents. A provisioning definition may now be written against that vocabulary.

**What this does NOT establish: whether the grant is limited to SurahCycle.**
Exactly one project and one organization came back, but the account only *has*
one of each, so the result is identical either way. Determining it needs the
Appwrite Console's own record of the grant — which is the owner's housekeeping
pass anyway. Until then, treat the grant as possibly account-wide and say so.

Read-only throughout: the only calls were `appwrite_get_context` and
`appwrite_search_tools`. Nothing in the project was created, modified, or
deleted, and no write tool was invoked.

## Stage J §6.0 — the Appwrite OAuth grant (2026-09-17)

The owner authenticated successfully. `claude mcp list` reported
`appwrite: https://mcp.appwrite.io/ (HTTP) - √ Connected` and the server's real
tools (`appwrite_get_context`, `appwrite_search_tools`, `appwrite_call_tool`,
`appwrite_search_docs`) replaced the two authentication stubs. **That tool swap
is the only trustworthy signal that a grant landed** — `/mcp` panels and browser
redirect pages both lie about it. Two earlier attempts appeared to succeed and
had not.

**Project `6aa91956000d1d490a3e` exists and is reachable.** It came back in the
context listing under the owner's account. Nothing else about it could be read
(see below), so `Databases`-vs-`TablesDB` is **still unsettled** and no
provisioning definition may be written yet. Note the MCP connection reports
endpoint `https://cloud.appwrite.io/v1`, not the `fra.` regional host the app
is compiled against; that is the console API, not a contradiction of
`AppwriteConfig`.

### Three things that are now established, and cost four round trips to learn

**1. Appwrite's authorize endpoint corrupts a long scope list. This is their
bug, not ours.** The MCP client requests 130 scopes (3102 chars raw, 3352
URL-encoded). Appwrite answered `error=invalid_scope`, naming
`project:proxy.invalidations.ject:apps.write` — a token nobody sent. Exactly 27
characters (`write project:apps.read pro`) were deleted from the **middle** of
the parameter at offset 2552 (2766 encoded), welding two scope names together.
Not a tail truncation, not a round buffer boundary. **Consequence: `/mcp` →
`appwrite` → Authenticate can never succeed for this server**, because it builds
that same 130-scope URL. Do not send the owner there again.

**2. The workaround is a hand-built authorize URL with few scopes.** Start a
flow with the `authenticate` tool to obtain a fresh `code_challenge`, `state`
and callback port, then rebuild the URL keeping `client_id`,
`code_challenge`, `code_challenge_method`, `redirect_uri`, `state` and
`resource` **exactly as issued**, replacing only `scope`. The local listener
still accepts the result. 12 scopes came to 233 chars / 639-char URL and passed.

**3. §6.0.4's open question is ANSWERED: the grant can be project-limited, but
not through scopes.** Appwrite's own docs (`docs/products/auth/oauth-server/scopes`):
a scope "cannot identify which projects the permission applies to"; rich
authorization requests (RFC 9396) carry that, and Appwrite reserves the
`project` and `organization` detail types, where each `project` identifier is a
project ID or `*`. The MCP client sends **no** `authorization_details`, which is
why its own URL asks for `all`, `project:all` and `organization:all` — an
account-wide grant across every organization and project on the owner's GitHub
account, including `organization:projects.write`, `project:keys.write` and
`project:users.write`. **A hand-built URL can bind the grant to SurahCycle
alone.** The earlier note that the documentation "does not say whether the grant
can be limited to one project" is superseded.

### Why the grant still does not work, and the exact next action

The successful grant was requested **without** `authorization_details`, so it is
bound to no project. Every read failed identically:

```
project.read   → <owner account> (role: users) missing scopes (["project.read"])
databases.read → ... (code=401, type=general_unauthorized_scope)
```

`role: users` — the token authenticates the owner but carries no project
authority. This is consistent with an unbound grant and is the leading
explanation; it is **not proven**, because the granted scope set could not be
introspected (`project:oauth2.introspect` was not requested).

**Next action, in order.** The `authenticate` tool is gone once the server
connects, and removing/re-adding the server mid-session drops the connection
without restoring it, so:

1. **Restart the session** (or reload the VSCode window) so the MCP client
   reconnects and `mcp__appwrite__authenticate` returns. The registration is
   already reset and reads `! Needs authentication`.
2. Call `authenticate`, take the fresh `code_challenge`/`state`/port.
3. Rebuild the URL with these 10 scopes plus `openid profile email` —
   `project:project.read`, `project:databases.read`, `project:tables.read`,
   `project:columns.read`, `project:indexes.read`, `project:rows.read`,
   `project:documentsdb.read`, `project:documentsdb.collections.read`,
   `organization:organization.read`, `organization:projects.read` — and add
   `&authorization_details=` URL-encoding
   `[{"type":"project","identifiers":["6aa91956000d1d490a3e"]}]`.
   `organization:organization.read` is new: without it the organizations list
   came back empty. Still **zero write scopes** — provisioning needs a second,
   deliberate grant, or the Console by hand.
4. Owner approves in his browser within ~350 s (the code's `exp` is about 350 s
   after `authTime`; one attempt died on that).
5. Verify by the tool swap, then re-run `appwrite_get_context` with
   `project_id`. Only once a real read succeeds may §6.1's
   `Databases`-vs-`TablesDB` question be called settled.

If the bound grant still refuses reads, the remaining suspect is that console
project access needs the broad `all` / `project:all` scopes, i.e. the trade is
account-wide or nothing over MCP. **That is the owner's decision, not the
agent's**, and the Console-by-hand provisioning route stays open either way.

### Operational notes

- The `claude` CLI is **not** on PATH but is bundled with the VSCode extension.
  Three versions are installed; use the newest:
  `C:\Users\User\.vscode\extensions\anthropic.claude-code-2.1.273-win32-x64\resources\native-binary\claude.exe`
- Reset the registration (clears a stuck OAuth state) with, from the project
  folder: `& $claude mcp remove appwrite -s local` then
  `& $claude mcp add --transport http appwrite https://mcp.appwrite.io/ --scope local`.
  This rewrites one entry in `~/.claude.json` under this project. `.mcp.json`
  at the repo root is untouched and still shadowed by local scope.
- **Owner housekeeping:** three or four grants were created on
  `fra.cloud.appwrite.io` during this session (grant ids include
  `6aab639ba5595deff759` and `6aab646488fbe6dd14b9`). The unbound one is live
  and should be revoked in the Appwrite Console once a working grant replaces
  it.
- **No Appwrite resource was created, modified or deleted.** The only calls made
  were `appwrite_get_context` (refused) and `appwrite_search_docs` (public
  documentation). No repository source file changed.

## Stage J §6.4/§6.3 — the transport, and the gate in front of it (2026-09-18)

Two commits, and the order matters: the thing that *moves* data was written
first, then the thing that decides whether it is ever allowed to.

### `ae720e9` — the real `SyncGateway`, against Appwrite TablesDB

Shaped like Codex's account adapter: one narrow file
(`lib/core/sync/appwrite_sync_api.dart`) touches `package:appwrite`, and every
rule lives where a test can reach it without a network, a project or a session.

- **One row per entity, addressed by `entityId`.** That is what makes a retried
  push a replacement rather than a duplicate. `idempotencyKey` still travels
  with the row, because the server's unique index on `(userId, idempotencyKey)`
  is what catches a replay this client has forgotten it sent — so a **409 is
  accepted, not failed**. Treating a successful replay as a failure is how a
  queue wedges on work the server already has.
- **The two refusals are deliberately asymmetric.** 400 is permanent (a row this
  server will never accept; retrying blocks everything behind it). **404 is
  retryable** although it looks worse: a missing table means "not provisioned
  yet", and every queued change succeeds the moment it is. Quarantining there
  would empty the queue into a corner over a temporary gap. Each code is pinned
  by a test.
- **A row this build cannot describe stalls the pull instead of being skipped.**
  Skipping advances the cursor past data that is then never fetched again. An
  empty page leaves the cursor exactly where it was, for the same reason.
- An envelope carrying another account's id is refused before any write.
- `classifyWriteFailure`, `classifyReadFailure` and `pageOf` are **pure statics**
  because constructing Appwrite's `Client` drags in a platform channel and a
  Flutter binding, and a decision this consequential must be examinable without
  either.

### The activation coordinator — signing in is not consent

`lib/core/sync/sync_activation_coordinator.dart` implements
`SyncActivationGateway`. `DriftSyncStore` already held the durable half
(`recordActivationChoice`, `isSyncActive`, `forgetOwner`); what was missing was
the part that refuses. It now `implements SyncActivationStore`, a narrow
interface declared in the sync layer so these rules test without a database —
and named in prose there rather than imported, because `lib/core/data/` depends
on `lib/core/sync/` and not the reverse.

What it refuses, each pinned by a test (15 new, all in
`test/core/sync/sync_activation_coordinator_test.dart`):

- **The backup is created before the data is even counted.** If it throws, no
  preview is ever offered — the offer is only honest while it is reversible. The
  test observes the backup counter *from inside* the inventory rather than
  setting a flag on itself, which would have read true in either order.
- **A superseded token is refused.** A second `prepareFirstSync` invalidates the
  first: agreeing to counts that have since moved authorises a merge the user
  was never shown.
- **A replay is refused, and distinguishably.** A double-tapped dialog gets
  `preview-already-answered`; a call that prepared nothing gets
  `no-preview-was-prepared`. The UI can swallow the first and must surface the
  second. One remembered token, not a growing set.
- **A store belonging to another account is refused, loudly, in both
  `prepareFirstSync` and `isSyncActiveFor`.** Returning `false` was the tempting
  default and is worse: the caller would then set B up against A's store.
- **Conflicts are only entities both sides hold *and disagree about*,** compared
  with `isAtSameMomentAs` so the same instant in two zones is not a
  disagreement. Counting every shared entity as a conflict would frighten a user
  away from a merge that has none.

**One ordering trap, found by reading `forgetOwner` rather than by a test.** It
deletes this owner's **activation row** along with the queue and the cursor. The
obvious sequence — record the choice, then drop the transport state — therefore
erases the very "no" it just stored, and `recordActivationChoice`'s own doc
comment says that "no" must survive so the account screen can tell *declined*
from *never asked*. The coordinator calls `forgetOwner()` **first** and records
the decision **second**. A crash between the two leaves a device that is
inactive and simply has not answered — the question asked again, rather than a
wrong answer kept.

### The backup the gate depends on — `DriftLocalBackupGateway`

`lib/core/data/backup/drift_local_backup_gateway.dart`. The coordinator refuses
to offer a merge without a recovery copy, so this is what makes the question
answerable at all — and it is useful on its own, which is why it lives under
`data/backup` rather than under sync.

Two choices carry the file, and both were arrived at against the real database
rather than chosen for tidiness:

- **`VACUUM INTO`, never a file copy.** The live database runs in WAL mode, so
  the main file on its own can be missing committed transactions. A backup that
  silently omits the last few recitations is worse than none. It also means the
  gateway never has to guess where `driftDatabase(name: 'murajaah_user')` put
  the file.
- **A restore replaces rows through `ATTACH` inside one transaction**, not by
  swapping files under an open connection. All-or-nothing, and no restart.
  `PRAGMA defer_foreign_keys = ON` moves FK checking to commit, so tables can be
  emptied and refilled in any order — otherwise a restore would depend on a
  hand-maintained topological ordering that every new table could silently
  invalidate.

**A SQLite rule learned the hard way here:** `ATTACH`/`DETACH` cannot run inside
a transaction — the attached database stays locked and `DETACH` fails with
`database restore_source is locked`. The first implementation nested them and
two tests caught it. They now sit outside, and a leaked alias from an
interrupted restore is cleared best-effort before the next attach, because one
leak would otherwise make every later restore fail permanently.

Other rules, each pinned by a test (15 new):

- An older snapshot is brought forward by **Drift's own migration run against a
  copy**, never a second implementation of it here, and never in place — a
  failed restore must leave the only copy of the data exactly as it was. The
  scratch copy is deleted afterwards.
- A **newer** snapshot is refused outright: its tables can hold columns this
  build has never heard of, and there is no downgrade path.
- Two backups in the same second both survive. `VACUUM INTO` refuses an existing
  target, so a free name is found rather than one overwritten — making room by
  deleting a recovery copy is never right.
- Pruning keeps the newest `keepAtMost`, never deletes the one just made, and
  never touches a file whose name it cannot parse (it may be the owner's own).
  `keepAtMost: 0` is refused rather than obeyed.
- A backup id is a bare file name; anything with a separator or `..` is refused.
- `exportLocalData` omits `surah_metadata` — the corpus is re-fetched by
  manifest and is not the user's data — while a *backup* still contains it,
  because a restore that dropped the corpus would leave an app that cannot
  render a surah.

### Verified

`flutter analyze` → `No issues found!`; full `flutter test --timeout 90s` →
**975/975** (was 931; +44 across the four commits). `dart format` run on every
touched file, then both re-run green. Tracked tree clean apart from these files;
the owner's photo, `Скринсейверы до v6/` and `.codex/` untouched.

**`build_runner` deleted two committed `.g.dart` files again** — the
`uzbekistan_prayer_locations` and `known_official_quran_enc_translations` ones,
the same pair as last time. Restored with `git checkout --` before committing.
Check `git status` after every generation run.

### The survey, and a schema gap it exposed — `DriftSyncInventory`

`lib/core/data/sync/drift_sync_inventory.dart` fills in the last missing piece
of the preview: what this device holds and what the account holds, keyed by
`SyncEnvelope.entityKey` so the two are comparable. It is a survey, not a sync —
it writes nothing, and it walks the remote from `SyncCursor.beginning` and then
**discards** that cursor, because advancing the durable one would make the first
real pull start after everything the survey had just read.

**Writing it exposed a real schema gap, and it is the most important thing in
this section.** Six of the eleven `SyncEntityType`s have no last-changed column
at all:

| entity type | table | what dates it |
|---|---|---|
| `recitationEvent` | `recitation_events` | `COALESCE(deleted_at_utc, created_at_utc)` |
| `rotationAdjustment` | `rotation_adjustments` | `COALESCE(deleted_at_utc, created_at_utc)` |
| `learningEvent` | `learning_events` | `created_at_utc` |
| `recallAttempt` | `recall_attempts` | `created_at_utc` |
| `appSetting` | `app_settings` | `updated_at_utc` |
| `masteredSurah` | `mastered_surahs` | **nothing** |
| `rotationState` | `rotation_states` | **nothing** |
| `rotationScheme` | `rotation_schemes` | **nothing** |
| `prayerRoutineTemplate` | `prayer_routine_templates` | **nothing** |
| `prayerSession` | `prayer_sessions` | **nothing** |
| `learningState` | `learning_surahs` | **nothing** |

The near-misses are all the wrong quantity and were deliberately **not** used:
`prayer_sessions.started_at_utc` is when a prayer began, not when its parts were
last edited; `mastered_surahs.cached_last_used_at_utc` is when a surah was last
recited, not when the roster entry changed; `learning_surahs.
last_learning_activity_at_utc` is activity, not edit, and is nullable.
Substituting any of them would state agreement or disagreement the schema cannot
support.

**Two consequences, and the second is the one for a future session.**

1. The preview needed a third answer. `SyncMergePreview` gained
   `undeterminedCount` — entities both sides hold whose agreement cannot be
   established — kept separate from `conflictCount` because a conflict is a
   finding and this is an honest "unknown". `needsReview` covers both. The
   factory now also refuses `conflict + undetermined > shared`, arithmetic that
   cannot be true.
2. **Last-writer-wins was not available for those six entity types**, so the
   merge strategy could not simply be "newest timestamp wins" — it would have
   picked one side at random for the roster, the routine and the prayer
   sessions. **Closed by schema v10, below.**

`DriftSyncInventory.coveredTypes` is exposed purely so that adding a
`SyncEntityType` without adding a source fails a test rather than quietly
dropping a whole category out of the preview.

### Schema v10 — the six undatable tables, closed

Full detail in `docs/DATABASE_MIGRATION_V10.md`. In short: each of the six gains
`updated_at_utc`, kept current by **twelve triggers** rather than by twenty-odd
write sites across five repositories that would each have had to remember. The
trigger cannot be forgotten by a future write path, covers writes that never go
through a repository, and changed no line of the code the owner uses daily.

**Nothing is backfilled**, on the same principle as `qada_fulfilled_local_date`:
stamping the migration time onto every existing row looks like an answer while
being arbitrary — two devices upgrading on different days would hand a merge a
winner decided by install order. Rows written before v10 stay null and are
reported honestly as undetermined; the gap closes on its own as the app is used.

**The rebuild trap bit for the fourth time, and a test caught it.** The v3→v4
rebuild of `mastered_surahs` and the v4→v5 rebuild of `prayer_sessions` both
produce the *current* table definition, so both had to declare
`updatedAtUtc` — four chained migration tests failed with `no such column:
updated_at_utc` until they did. The rule holds: **every rebuild lists every
column added after it.**

Three details are load-bearing and each is pinned by a test: the
`CAST(strftime('%s','now') AS INTEGER)` (a string would read back as no date at
all); the `WHEN NEW.updated_at_utc IS OLD.updated_at_utc` guard, which makes the
no-recursion behaviour independent of a pragma this code does not set; and the
consequence of that guard — **a caller supplying its own timestamp keeps it**,
which is what will let an applied remote change carry the originating device's
time instead of being restamped "now" on arrival.

Migration coverage is now `v1→v10` through `v8→v10` plus a dedicated `v9→v10`,
and the newer-`user_version`-is-refused guard moved to 11. **Not yet run on a
real device** — the owner's phone is at v9; pull a copy of `murajaah_user.sqlite`
first, as was done for v7, v8 and v9.

### Not done

Nothing in `lib/app/` or `lib/features/` constructs the coordinator, the backup
gateway or the inventory — in particular no `path_provider` directory is wired
up for backups yet. So the gate exists and is tested, and there is still no path
by which a sign-in moves a recitation, which is the intended state rather than a
gap. Provisioning stays parked until there is something to transport.

**No APK is owed right now.** The device is at schema **v9** from the 2026-09-17
install, and every commit since (`82f6ba3`, `ae720e9`, `3f2e2cc` and this one)
is sync plumbing that nothing constructs plus documentation. A rebuild would
deliver the owner nothing new.

**Analyzer note (new, 2026-09-18):** `flutter analyze` from `M:\` now crashes
with `FormatException: Unexpected character (at character 246)` in
`SessionLoggerSink._normalize` — the LSP init message contains
`"name":"{{workspaceFolder-0}}\"`, an unescaped trailing backslash, because
`M:\` is a **drive root**. Not Cyrillic-related, and not a code defect. Run it
with explicit paths instead: `flutter analyze --no-pub lib test tool`.

## Stage J §6.3 — both providers are ON, verified 2026-09-18

`project_list_o_auth2_providers` reports `google: enabled true` and
`yandex: enabled true`; the other 46 are off. Each carries a client id, and
`clientSecret` comes back empty because the field is write-only — which is why
this read is safe and the project object is not: that one returns secrets
alongside configuration and must not be fetched.

Google is configured for **browser** sign-in (`nativeEnabled: false`), which is
the half the redirect URI belongs to and the right one for this app.

So §6.3's owner steps are done. What remains is his judgement, not a task:
the Google app is still in **Testing**, so only accounts on its test-user list
can sign in. Publishing is public-facing and stays his call.

**Division of work while a second agent operates the browser consoles:** the
repository has exactly one writer — the Claude Code session — and the console
agent touches no file, no commit and not this journal. Every finding it
produces is relayed in chat and written here by the repository session. Two
agents editing `docs/AI_HANDOFF.md` will eventually meet on one line, and a
merge conflict in the shared journal is the worst place to discover the
convention was never agreed.

## Stage J §6.3 — Google and Yandex sign-in for app users (2026-09-17)

**This is not §6.0.** §6.0 is the owner's *console* grant that lets an MCP client
read and write the SurahCycle project. This section is end-user social login: what
a person tapping "Sign in with Google" inside the app goes through. The two share
the word OAuth and nothing else. A working §6.0 grant does not enable sign-in, and
none of this section's work unblocks §6.0.

Baseline at the time of writing: HEAD `3fafbf0` on `main`, tracked tree clean;
untracked are the owner's QA media, an unrelated `.codex/`, and the new `brand/`
below. `git` is not on PATH — use `.\.tools\mingit\cmd\git.exe`.

**Appwrite Console, Auth → Social providers.** The tab is called *Social
providers* in the current Console, not "OAuth2 Providers"; the adjacent *OAuth2
server* tab is Appwrite acting as a provider and is unrelated. Google is split
into two independent switches:

- **Native sign-in** — sessions from ID tokens obtained on device (Google
  Credential Manager). No client secret; a `Native client IDs` list holds extra
  accepted ID-token audiences. The redirect URI plays no part here.
- **Browser sign-in** — the redirect flow. `Client ID` and `Client Secret` are
  both required, and the Redirect URI belongs to this half.

Yandex has a single Enabled switch with the same two required fields.

**Both providers are still `disabled` in Appwrite.** Client ID and Client Secret
are required and the owner enters them himself, so nothing could be saved. Note
that the Update button is *not* disabled while they are empty, so a careless
click would either trip validation or store an enabled-but-empty provider;
neither was attempted. Both dialogs were closed with Cancel and the Appwrite
project is untouched.

**The exact redirect URIs, read out of the Console's own fields rather than
derived from the documented pattern:**

```
https://fra.cloud.appwrite.io/v1/account/sessions/oauth2/callback/google/6aa91956000d1d490a3e
https://fra.cloud.appwrite.io/v1/account/sessions/oauth2/callback/yandex/6aa91956000d1d490a3e
```

The host is the regional `fra.` one, matching `AppwriteConfig`, not
`cloud.appwrite.io`.

### Google side — done

A new Google Cloud project **SurahCycle** (id `surahcycle`, no organization) was
created, and Google Auth Platform configured: app name **SurahCycle**, user
support email and developer contact `<owner's Google account>`, audience
**External**. The owner explicitly authorised ticking the *Google API Services:
User Data Policy* checkbox. An OAuth client of type **Web application** named
`Appwrite SurahCycle (browser)` carries the Google redirect URI above, verified
against the field's DOM value after typing. Google answered `OAuth client
created`.

Type **Web application** is correct even though the target is Android: the
redirect flow terminates on Appwrite's server, not on the device. A separate
**Android** client (package `dev.murajaah.murajaah` plus the signing SHA-1) is
only needed if native sign-in is turned on later, and its id then goes in the
`Native client IDs` field.

**Deliberately not done.** The client id and secret were never read,
screenshotted or recorded; the creation dialog was left open for the owner. The
app sits in **Testing** publishing status, so only accounts on the test-user list
can sign in — publishing is public-facing and was left to the owner. No
consent-screen logo was uploaded, because adding one puts the app into Google's
brand-verification queue while bare `email`/`profile` work without it.

### Yandex side — done

A Yandex ID application **SurahCycle** was created at `oauth.yandex.ru`, platform
**Веб-сервисы**, contact `<owner's Yandex account>`, carrying the Yandex redirect URI
above — verified by reading the stored field back after creation. Requested
rights are exactly the three Appwrite's Yandex adapter asks for — `login:email`,
`login:info`, `login:avatar` — and nothing else; birthday and phone were left
unchecked.

Two things worth knowing before anyone repeats this:

- Yandex **requires an application icon** before it will advance past step 1.
  There was none in the repository (see the brand section below).
- Yandex offers Gosuslugi identity verification in a modal that **re-opens and
  swallows the next click**, which is why the create button appears not to work.
  It was declined and closed twice. Without it the consent screen carries a
  "Сервис не верифицирован" note; clearing that is the owner's own identity step
  and no agent should attempt it.

Creating the application accepts Yandex's «API авторизации через Яндекс ID» terms
implicitly — there is no separate checkbox, the agreement is attached to the
create button.

**Neither client id nor secret was read or recorded, here or anywhere.**

### What is left, and it needs the owner

1. ~~Copy the Google client id and secret into Appwrite → Auth → Social providers
   → Google → Browser sign-in, then Update.~~ **Done by the owner 2026-09-17.**
2. ~~Copy the Yandex client id and secret into the same screen under Yandex, then
   Update.~~ **Done by the owner 2026-09-17.** Both providers now read `enabled`
   in the Console's provider list — verified from that list, which shows status
   without secrets, and deliberately **not** by fetching the project object.

   **Do not check whether they are enabled by fetching the project object.**
   Appwrite returns `oAuthProviders` with each provider's `secret` inline, so a
   casual `project_get` dumps both client secrets into the transcript of whoever
   asked. The owner's standing instruction is that these secrets never reach an
   agent. Ask him, or look at the Console yourself.
3. ~~**Unverified, and outside this task's remit:** Appwrite needs a registered
   Android platform.~~ **Checked and closed on 2026-09-17.** It was not
   "possibly missing" — `project_list_platforms` returned `total: 0`, so the
   project had no platforms at all, and every sign-in would have looked
   successful in the browser and then failed to return to the app. That is the
   worst failure shape available: nothing in the app reports an error, so it
   gets blamed on the provider setup that is actually fine.

   Registered through MCP and read back to confirm: platform `android-surahcycle`,
   type `android`, `applicationId` **`dev.murajaah.murajaah`** — taken from
   `android/app/build.gradle.kts` line 25, not from memory (an earlier revision of
   this entry cited `android/app/src/main/build.gradle.kts`; there is no Gradle
   file under `src/main`, and the wrong path is corrected rather than deleted so
   nobody hunts for it). Appwrite's Android platform needs only the application
   id; no signing SHA-1 is involved.

   Independently re-verified on 2026-09-17 from a separate session:
   `project_list_platforms` now returns `total: 1` — `$id android-surahcycle`,
   name `SurahCycle Android`, type `android`, `applicationId
   dev.murajaah.murajaah`, created `06:47:13Z`. The registration is real, not
   just reported.

   Undo, if it is ever wrong: `project_delete_platform` with
   `platform_id: android-surahcycle`. It is additive and reversible, which is
   why it was done without waiting.

   **The other half is deliberately still absent.** The app has no
   `appwrite-callback-6aa91956000d1d490a3e` intent filter in
   `AndroidManifest.xml`, and it should not get one yet: nothing in the app
   signs in, there is no Appwrite SDK dependency, and a manifest entry nothing
   uses is dead configuration. It belongs with the client wiring, in that
   checkpoint.
4. Optional: publish the Google app out of Testing; add an Android OAuth client if
   native sign-in is wanted.

### One correction to the record

§6.0's finding that `/mcp → appwrite → Authenticate` can never succeed still
stands as written — and the session that opened this conversation was still
telling the owner to go there. That instruction is stale; do not repeat it.

In this session the Appwrite MCP server's real tools (`appwrite_get_context`,
`appwrite_call_tool`, `appwrite_search_tools`, `appwrite_search_docs`) are
present, which §6.0 names as the only trustworthy signal that a grant landed.
**Whether that grant is project-bound was not tested here** — no Appwrite MCP
call was made in this session. Do not read this as §6.0 being closed.

## Stage J §6.3 client wiring, part 1 — identity only (2026-09-17)

Baseline re-verified before touching anything, as CLAUDE.md requires: HEAD
`0cd53cf` on `main`, tracked tree clean, `flutter analyze --no-pub` →
`No issues found!` (119.1 s), full `flutter test` → **861/861**.

**Scope, and why it stops where it does.** Sign-in is implemented; moving data
is not. §6.2's provisioning was never applied, so the project has no database
and no `sync_log` table — there is nothing for a `SyncGateway` to talk to, and
applying the provisioning is still blocked on the owner's grant-breadth
decision recorded in §6.2. So this part lands `AccountGateway` and stops at
`SyncHealth.notActivated`, which is an honest terminal state rather than a
half-built one.

### Two facts read out of the SDK, not remembered

1. **The Android callback scheme is not configurable.** `Client.webAuth`
   (`appwrite-26.2.0/lib/src/client_io.dart:485`) honours the `success`
   parameter's scheme **only on Windows and Linux**; everywhere else it
   hardcodes `appwrite-callback-${project}`. So the manifest filter must carry
   the literal project id, and a build overriding `APPWRITE_PROJECT_ID` silently
   stops receiving the redirect. That coupling is commented at the filter.
2. **`flutter_web_auth_2` declares only its own `AuthenticationManagementActivity`.**
   `CallbackActivity` is left to the app, because only the app knows its scheme.
   Without that declaration sign-in opens, succeeds in the browser and never
   returns, with nothing to show the user — the same silent shape as the missing
   platform.

### What was added

- `pubspec.yaml`: `appwrite: ^26.2.0`, resolving to exactly **26.2.0**, the
  version ADR-0001 was written against. 18 transitive packages came with it,
  including `url_launcher` and `flutter_web_auth_2` 5.1.0.
- `lib/core/sync/appwrite_account_gateway.dart` — the rules, with **no**
  dependency on `package:appwrite`, so they are unit-testable without a network,
  a browser or a project.
- `lib/core/sync/appwrite_account_api.dart` — the only file that imports the
  SDK. It holds no rules; its whole job is turning SDK exceptions into two
  honest outcomes. **401 alone means "signed out"**; every other failure throws,
  because reporting an offline device as signed out would strand its queued work
  and show a reassuring empty screen.
- `android/app/src/main/AndroidManifest.xml` — the `CallbackActivity` filter.
- `test/core/sync/appwrite_account_gateway_test.dart` — 11 tests.

`sync.dart` exports the gateway but deliberately **not** the adapter:
re-exporting it would drag the Appwrite SDK into every unit test that only
wanted an envelope.

### Three things it refuses to pretend, each pinned by a test

- **`deleteCloudAccount` throws.** Appwrite's client-side call is
  `account.updateStatus()`, and the SDK's own documentation says it plainly:
  "the user record is not deleted but permanently blocked from any access. To
  completely delete a user, use the Users API instead." The Users API needs an
  admin key this repository forbids shipping. Blocking is not erasure, and
  offering it under that name would misinform someone exercising a deletion
  right. It needs a server-side path.
- **`exportCloudData` throws.** Nothing of the user's has ever left the device.
  An empty map shaped like a successful export reads as "backed up, nothing to
  restore".
- **A link that changes the user id is refused.** Appwrite attaches a new OAuth
  session to the logged-in account — but if that provider's email already
  belongs to a different user it signs into *that* user instead. The caller
  asked to link, so returning a stranger's account would quietly attach this
  device's history to it. `linkIdentity` also refuses to even open the flow
  while signed out, because an anonymous OAuth login *is* a sign-in.

An identity provider this build does not model is dropped rather than guessed
at; the Console may have others enabled.

### Verified

`flutter analyze --no-pub` → `No issues found!`. Full `flutter test` →
**872/872** (was 861; +11). `dart format lib test` touched 2 files, both new,
and both checks were re-run after it. `gradlew.bat :app:compileDebugKotlin
:app:processDebugManifest` from `M:\android` → `BUILD SUCCESSFUL` in 6m14s.
The merged manifest at
`M:\build\app\intermediates\merged_manifest\debug\outputDebugAppLinkSettings\AndroidManifest.xml`
was read back and contains the activity with
`android:scheme="appwrite-callback-6aa91956000d1d490a3e"` — checked, not assumed.

Note a new Gradle warning, pre-existing in kind: Flutter now warns that
`flutter_web_auth_2` and `home_widget` apply the Kotlin Gradle Plugin, which
future Flutter versions will reject. Not blocking today; worth a backlog item.

### Not done, and next

- **The account screen and its providers.** `SyncStatus` already decides
  everything such a screen may say; nothing renders it yet. No file in
  `lib/app/` or `lib/features/` references `lib/core/sync/` — that count is
  still zero, so this part changed no app behaviour.
- **Nothing was run on a device**, and sign-in cannot succeed end to end until
  the owner pastes the Google and Yandex client ids and secrets into the
  Console. The code path is testable; the round trip is not, yet.
- `SyncGateway`, `SyncActivationGateway`: blocked on §6.2.

## Stage J §6.3 client wiring, part 2 — the account screen (2026-09-17)

`lib/core/sync/` is no longer unreferenced by the app. The count of references
from `lib/app/` and `lib/features/` was zero for three stages; it is now one
screen, one card, one route and one provider file.

### The screen renders `SyncStatus` and nothing else

`SyncStatus.resolve` already decides, in one ordered place, what may be said.
The screen adds no judgement of its own — it maps a health to words. That is
what stops a cheerful summary from appearing over a queue that never drained.

**One state is deliberately not a `SyncStatus` at all: not knowing.** When the
account cannot be reached the provider carries an error, and the screen renders
"could not reach the account", explicitly *not* "signed out". Those two look
identical to an offline device and mean opposite things to the person holding
it — being told you are signed out invites a second OAuth round trip, which is
the last thing a dropped connection needs. Pinned by
`an unreachable account is not reported as signed out`.

`SyncHealth` has nine cases and four are reachable today; the other five all
require `isActivated`, which no code can set yet. They are rendered from the
counts `SyncStatus` already carries rather than from invented copy, so the
screen stays truthful the day activation lands instead of needing to be
remembered.

### A trap that is written down rather than left to be discovered

`syncStatusProvider` passes `queuedCount: 0` and `quarantinedCount: 0`. That is
provably honest today — nothing enqueues, because no repository is sync-aware,
and `SyncStatus.resolve` decides `notActivated` before it ever reads a count.
**It stops being honest the moment activation exists.** The provider says so in
capitals at the exact line that would have to change; a queue full of unsent
work behind a screen that says everything is fine is precisely the failure this
architecture exists to prevent.

### Where it lives, and why there

`/settings/account`, nested inside the Settings branch — the same shape as
`calendar` under Home and `detail/:id` under Surahs. Three screens in this
project have already been declared on the root navigator and opened without the
bottom navigation (`/learning/:id` in Stage D, surah details in Stage I, the
calendar before it was moved). `test/app/account_route_test.dart` is what keeps
this one from becoming the fourth: it asserts the `NavigationBar` is present and
that the Settings tab stays selected at index 4.

The Settings entry is `AccountSettingsCard`, matching the existing
`PrayerTimeSettingsCard` / `PrayerRoutineSettingsCard` /
`LearningNotificationSettingsCard` pattern. Its subtitle reads "Signing in does
not turn on sync" on purpose: "Account" next to a sign-in button reads as "turn
on backup" to most people, and this app backs nothing up.

### Other decisions worth keeping

- **Providers live in `lib/features/account/application/account_providers.dart`,
  not in `app_providers.dart`.** They are the only thing that reaches
  `appwrite_account_api.dart`, and that file imports `package:appwrite`.
  Declaring them in the shared provider file would pull the SDK into every
  widget test that only wanted a database.
- **A failed sign-in shows a fixed message, never the reason.** Provider errors
  quote the user's own email address back at them, and a snackbar is a poor
  place for it. Pinned by a test that asserts the address does not appear.
- **Every action re-reads who is signed in** rather than assuming the call
  worked. The gateway's answer is the only thing that decides what the screen
  shows.
- 25 new l10n keys in all three of `app_en`/`app_ru`/`app_uz`, `flutter gen-l10n`
  re-run.

### Verified

`flutter analyze --no-pub` → `No issues found!`. Full `flutter test` →
**881/881** (was 872; +7 screen, +2 route). `dart format lib test` touched 2
files, both new, and both checks were re-run after it. **No Kotlin or Android
file changed in this part**, so no Gradle run was required — the manifest change
was part 1's and is already verified in a merged manifest.

### Still not done

- **Activation.** `SyncActivationGateway` has no implementation, so the screen
  deliberately offers no way to switch sync on. It stops at "sync is off" and
  says the feature does not exist yet, which is true.
- **Nothing runs on a device**, and sign-in cannot complete end to end until the
  owner pastes the Google and Yandex client ids and secrets into the Console.
  Every path here is covered by fakes; the real round trip is not covered by
  anything.
- Backlog candidate: Flutter now warns that `flutter_web_auth_2` and
  `home_widget` apply the Kotlin Gradle Plugin, which future Flutter versions
  will reject.

## Brand: the app had no logo at all (2026-09-17)

`android/app/src/main/res/mipmap-*/ic_launcher.png` is still the stock Flutter
placeholder — the blue Flutter mark, 0.4–1.4 KB per density — and `assets/` holds
only Quran text and licences. There was no app logo anywhere in the tree, so
Yandex's mandatory icon could not be satisfied from existing material, and the
owner's assumption that "the one the app uses" could be reused was wrong.

A logo was drawn: a rub el hizb (۞, the Quran's own section marker) inside a ring
of eight segments, two of them amber for "due for revision". The green is derived
from `seed = Color(0xFF246B55)` in `lib/app/app_theme.dart`; the amber is a
relative of the qada oranges in `prayer_calendar_screen.dart`. Checked for
legibility down to 64 px.

New, untracked, touching nothing else:

- `brand/surahcycle_logo.svg` — the master, all geometry explicit
- `brand/surahcycle_512.png` — 19 KB, used as the Yandex application icon
- `brand/surahcycle_1024.png` — 41 KB, for stores

Rasterised through .NET `System.Drawing` from PowerShell, because this machine has
no Python (the `python.exe` on PATH is the Microsoft Store stub — it prints
`Python` and exits 49), no ImageMagick, no Inkscape and no Node. The generator
script was kept out of the repository; the SVG is the master and can be
re-rasterised by any means.

**The launcher icons were deliberately not replaced.** That is a change to the
app, and only a logo was asked for. Doing it would mean regenerating every
`mipmap-*` density plus an adaptive icon, and it belongs in its own checkpoint.

## Owner regression report of 2026-09-16 — what the two videos actually show

The owner recorded `video_2026-09-16_09-35-25.mp4` (57.7 s) and
`video_2026-09-16_09-35-42.mp4` (48.3 s), both 606×1280, in the repo root
alongside his other QA media (untracked, never to be committed or renamed).
**They were watched.** No decoder existed on this PC, so a portable ffmpeg was
unpacked into the project's own gitignored `.tools/` (the same place the
portable Flutter/Git toolchain already lives) and frames were extracted at 2 fps
into the session scratchpad, outside the repository.

Below is what the frames *show*. Causes are a separate question and are marked
as open; nothing here is a diagnosis yet.

**Video 1 — the part editor.**

- 0–13 s: context is **Зухр, ручной режим**. The Зухр plan has four parts, the
  fourth being `Фард · 3 рак. · слотов для сур: 2` — the agent's leftover test
  part. **Every part reads `Слоты для сур: 0/N`, so the session has no
  recitations at all.**
- 10–11 s: Настройки → редактор частей Зухра → корзина на четвёртой части →
  dialog «Удалить часть намаза? Удалить «Фард»? Уже созданные сессии намаза не
  изменятся.» → Удалить.
- 12 s: **the editor now lists three parts — the template write succeeded.**
- 13 s: Home still lists **four** parts, including the deleted one.
- **So "удаление не сохраняется" is not what happened.** The template changed;
  the already-created Зухр session kept its own four-part snapshot, exactly as
  the dialog warned. What the owner sees as "не сохранилось" is the plan he is
  actually looking at not changing. Open question: what the right scope choice
  is for a part with no events (prompt §C).

**Video 1 — the prayer picker disagrees with the context.**

- ~18 s: the owner presses «Вернуться к авто» himself; the card becomes
  «Между намазами · Автоматически · Далее: Зухр в 12:18».
- 20 s: he opens «Выбрать намаз». The sheet shows **Магриб** checked — while the
  context is automatic.
- 31–35 s: context is **Иша** (ручной режим); at 35 s he taps the chevron.
- 36 s: the sheet again shows **Магриб** checked while the card reads **Иша**.
  He taps **Витр**.
- 38 s: context is Витр.
- **Correction to the relayed observation:** the Иша → Витр change at ~37 s was
  the owner's own tap in the picker, not an automatic transition. What the
  frames *do* prove is different and was not in the report: **the picker's
  pre-checked prayer is stale** — it stays on Магриб across an auto context and
  two different manual selections. Open question: whether the stored manual
  selection and the displayed context are two different values that diverge.

**Video 2 — marking re-sorts under the finger, then the context is lost.**

- 0–10 s: context is **Магриб, ручной режим**, plan `Магриб · Фард` (Фард 3 рак.
  0/2, Сунна 2 рак. 0/2). The ranked block carries `2×` on ranks 3–8;
  «К повторению: 17».
- 34 s: he taps **Al-Falaq** in «Активные суры».
- 36 s: Al-Falaq is green, snackbar «Сура отмечена / Отменить» — **and Al-Falaq
  and An-Naas have swapped rows.** The row under his finger is now a different
  surah. This is the "прыгает" complaint, captured directly.
- 38 s: after the second mark the viewport has jumped elsewhere in the list.
- 40 → 41 s: the page jumps to the top, and the context becomes
  **«Выбрать намаз · Автоматически»** — with the prayer-time strip **gone
  entirely** (at 20 s in video 1 the automatic state still showed the full strip
  and «Далее: Зухр в 12:18»). The ranked block has lost its `2×` badges and
  «К повторению» reads 15.
- **So the manual Магриб was lost, and the batch identity changed with it.**
  Open question: whether the context collapses because the prayer schedule
  momentarily has no data, and whether a manual choice should depend on the
  schedule at all.

Not yet established, and not to be asserted until it is: why the schedule strip
disappeared, what rebuilt the page, and whether the batch reset is a consequence
of the context change or an independent fault.

### What the frame at 41 s forces to be true

Three signals appear together and only one combination of provider states
produces all three. The card reads «Выбрать намаз», so the resolved context is
null. The first detail line reads «Автоматически», which `_PrayerContextCard`
prints when the status is not `manual` **and** `settings?.contextSelectionMode`
is not `manual` — a null `settings` satisfies it. The strip is absent, which
`_matchingPrayerSchedule` does when `settings == null`. And the
«Вернуться к авто» chip is still there, which requires
`activePrayerContextOverrideProvider != null`.

A live override with null settings is the only consistent reading: the prayer
time **settings** momentarily had no settled value, while the in-memory override
was untouched. It cannot be an app restart, because a restart would take the
in-memory override with it and the chip would be gone.

So the amplifier is proven, and it is one line:

```dart
T? _settledValue<T>(AsyncValue<T> state) =>
    state.isLoading || state.hasError ? null : state.valueOrNull;
```

A reloading Riverpod provider still carries the value it last emitted. This
threw it away. Home derives the resolved context, the routine card, the
recommendation batch and the whole prayer-time strip from these, so one loading
tick empties all of them at once — and because the page then becomes much
shorter, the scroll offset is clamped and the user is thrown back to the top.
That single mechanism accounts for the lost context, the vanished strip, the
`2×` badges disappearing and the jump, in one frame.

### What is NOT yet proven

**Which upstream event produced that loading/error tick.** A reproduction was
built against the real database and the real provider graph
(`test/app/prayer_context_stability_test.dart`) and it does **not** reproduce:
an unrelated `app_settings` write — which is what storing the recommendation
batch does on every mark — leaves both a sticky override and a persisted manual
selection intact. That hypothesis is therefore recorded as **refuted for now**,
not quietly dropped.

One real defect did surface while building it, from a genuine exception rather
than a guess: `PrayerRepository.getSelectedContext()` read its two keys with two
independent awaits, so a reader could straddle the transaction that writes them
and see the type without the flag — throwing `Stored prayer context is
incomplete.`. That exception is reachable from the prayer-time settings stream,
and an errored settings stream is exactly the null-settings state the frame
requires. It is **a** path to the observed frame; whether it is *the* path the
owner hit is still unproven. It is fixed regardless, by reading both keys in one
transaction.

**Stage J is under way. §6.4 (durable outbox, schema v7) is done. §6.0's "blocked on one owner action" below is SUPERSEDED — the owner authenticated on 2026-09-17; see "Stage J §6.0 — the Appwrite OAuth grant" above for what actually happened and what is owed now.**

- MCP: `claude` is not on PATH in this environment (it runs as the VSCode extension), so instead of `claude mcp add --transport http appwrite https://mcp.appwrite.io/` the server is declared in a project-scoped **`.mcp.json`** at the repo root — the same "only this local project" scope the prompt asked for, expressed as the file the command writes. No existing configuration was touched (there was none: no global `mcpServers`, no project entry). **Owner action: `/mcp` → `appwrite` → Authenticate**, then sign in to Appwrite through GitHub in his own browser and read the scope Appwrite actually requests before approving. A session restart may be needed for the extension to pick up a new `.mcp.json`. Nothing beyond §6.0 was attempted — no read of the project, no provisioning.
- Schema **v7** adds `sync_outbox_entries`, `sync_cursors`, `sync_activations`, and nothing else. `DriftSyncOutbox` passes the existing `runSyncOutboxContract` unchanged; `DriftSyncStore` owns the two transactional guarantees and the owner scoping. Migration tests cover v1→v7 … **v6→v7**. Full details in `docs/DATABASE_MIGRATION_V7.md`. **Still not wired into the app** — no file in `lib/app/` or `lib/features/` references any of it, because the wiring belongs with a real gateway (§6.3), which is behind the MCP step.

**Device settings were restored at the end of QA on 2026-09-15** — `stay_on_while_plugged_in` to `0`, screensaver back to the deskclock default and disabled, the quiet-notification toggle back off. `accelerometer_rotation`/`user_rotation` were left untouched because no original value was ever recorded; do not "restore" them to a guess.

Stage F's original brief, for reference. Constraints from the prompt: do not decompile or copy Murajaa's code, design, interface text, algorithm or closed content, and do not claim their API is open — write an original minimal mode. Use only the project's already-audited Quran text and coordinates; never generate Arabic. Flow: pick a surah or target range; a step shows the surah/ayah number with the Arabic hidden (no word-count leak in strict mode); a "Показать аят" button reveals the exact text; after revealing, offer `Вспомнил`, `С ошибкой`, `Не вспомнил` and `Дальше`; persist an append-only `RecallAttempt` (UUID, surahId, ayahStart/end, learningCycle, result, createdAtUtc, localDate, source surface); a mistake may influence future review priority only in a documented, transparent way and must never create or cancel a recitation-in-prayer event; after revealing, audio may play through the existing audio architecture; no speech recognition and no claim of automatic correctness checking in this stage. Integrate into Learning without slowing the existing fast path. **If `RecallAttempt` needs persistence, that is the ONE next schema migration (section 16) — the recommendation batch deliberately did not take it, so v6 is still free.** Tests: reveal order, inability to grade before revealing, attempt persistence, ranges, and coordinate exactness. The block is currently recalculated and shrinks after every mark — if one unmarked surah is left, only it is shown instead of the stable eight. Introduce a persisted `RecommendationBatch` (or a pure equivalent) keyed at minimum by localDate + PrayerContext + a stable prayer part/session identifier + algorithm version; exactly eight entries when at least eight eligible candidates exist; never recomputed or reordered after a mark; all eight stay visible in both app and widget; a completed entry turns green instead of disappearing; Home and the Rotation widget read one snapshot rather than each computing a list; checked state updates atomically with the recitation event; the batch and its green marks survive a restart and process death. Cycle rules: prefer not-yet-offered eligible surahs, randomise only the new unmarked tail with a persisted seed so the UI does not jump, and when fewer than eight remain in the cycle show those first then top up from a new round, marking a repeated entry honestly as `2×` (which never doubles one recitation event or distorts statistics). **If this needs new persistence it must share ONE next schema migration together with any recall/outbox tables (section 16), so check section 11 before designing the migration.** Tests required: 1/7/8/9/24 candidates, marking 1 of 8, a full batch, the cycle rollover with `2×`, restart and process death, different prayers and parts, widget/app snapshot equality, and undo.

Stage D is done. Its original brief, for reference: navigation from the Learning widget. The `/learning/:id` route sits outside `StatefulShellRoute`, so a deep link can open the selected surah without the bottom navigation and without a normal back path — the user saw this once. Move the selected-surah route under the learning branch of the existing shell, or use a safe `/learning?surah=<id>`. Every entry from the Learning widget must land on the Learning screen **with** bottom navigation, the system Back button must return somewhere expected and must never trap the user, and no second `MaterialApp`/Navigator may be introduced for that screen. Tests required: cold deep link, warm deep link, repeated tap, invalid surah id, Android back, switching to other tabs.

Stages A–C are done (see Verified completed work). The physical-device step (new prompt section 5) is still open: `adb devices -l` returned an empty list again on 2026-09-14, so ask the user to connect the phone and confirm USB debugging before claiming anything about the Prayer widget, DreamService or notification on a real device.

After Stage D the remaining prompt order is: physical Prayer widget/DreamService verification (needs the phone), persisted eight-item recommendation batches (section 10), the original memory-recall mode (section 11), account/sync architecture and local contracts only (section 12, cloud project needs the user), and finally the user-facing SurahCycle rename (section 13). Any new batch/recall/outbox persistence must share ONE next schema migration.

## Environment and tooling (read before running any command)

- Git and Flutter are **not** on PATH in a plain PowerShell session here, even unsandboxed. A prior Codex session set up a portable toolchain in `D:\MurajaahWorkspace\.tools\` (`mingit`, `flutter`, `gradle-home`, `pub-cache`). `D:\MurajaahWorkspace` is a **directory junction pointing at this exact repo** (`D:\Приложении\Repeat Qur`an`) — not a separate copy. Verify with `Get-Item 'D:\MurajaahWorkspace' -Force` (LinkType Junction, Target = this repo).
- Git: `D:\MurajaahWorkspace\.tools\mingit\cmd\git.exe`. The repo's `.git` is owned by a different Windows account (`CodexSandboxOffline`), so git refuses to run as `User` until `git config --global --add safe.directory <path>` has been called for that account. This was already added to the `User` account's global gitconfig in this session; a future session running as a different OS account will need to repeat it (message is self-explanatory if it happens again). **Never write the Cyrillic path as a double-quoted PowerShell literal** — `` `an `` inside `"...Qur`an"` is parsed as the alert-escape sequence and corrupts the string; use single quotes, or better, capture it once via `(Get-Location).Path`.
- Flutter: `D:\MurajaahWorkspace\.tools\flutter\bin\flutter.bat`. Set `$env:PUB_CACHE = 'D:\MurajaahWorkspace\.tools\pub-cache'` first.
- **`flutter analyze` crashes if invoked while the working directory is the real Cyrillic path** (`D:\Приложении\Repeat Qur`an`): the Dart analysis server's LSP channel throws `FormatException: Unterminated string` while parsing the `rootUri` JSON and exits 255. This looks like a Windows-path/JSON-framing bug in this Dart/analysis-server build, not anything in our code. Workaround: run `flutter`/`dart` from the ASCII junction path `D:\MurajaahWorkspace` instead (`Push-Location 'D:\MurajaahWorkspace'` first) — same files, same git history, analyzer runs clean from there.
- **It also crashes from `M:\`, and the real cause is broader than "Cyrillic".** 2026-09-16: `Push-Location M:\` then `flutter analyze` exits 255 with `FormatException: Unexpected character (at character 246) …"name":"{{workspaceFolder-0}}\","uri":…` inside `SessionLoggerSink._normalize`. The working directory was the **root** of the subst'd drive, so the folder path ends in `\`, which escapes the closing quote when the analysis server's session logger re-serializes its own JSON. Any path ending in a separator will do it. Run `flutter analyze`/`flutter test` from `D:\MurajaahWorkspace` (no trailing separator); `M:\` stays correct for Gradle, which needs that exact root.
- **`gradlew testDebugUnitTest` for this project runs nothing of ours.** `android/app/src` contains only `debug/`, `main/` and `profile/` — there is no test source set, so `:app:testDebugUnitTest` reports `NO-SOURCE`. That is an honest "nothing to run", not a pass; do not report it as green Kotlin tests. The **unscoped** `testDebugUnitTest` additionally fails at configuration with `this and base files have different roots: M:\build\audio_session and C:\…\Pub\Cache\…\audio_session-0.2.4\android` when the pub cache sits on another drive, so scope it to `:app:` regardless.
- **The device has no `sqlite3` binary** (`which sqlite3` → exit 127 on the Jelly Max, Android 15). To inspect the app database, pull a copy and read it on the PC: `cmd /c "<adb> exec-out run-as dev.murajaah.murajaah cat /data/data/dev.murajaah.murajaah/app_flutter/murajaah_user.sqlite > <out>.sqlite"` — via `cmd /c`, because PowerShell's `>` corrupts binary output — then `flutter.bat pub run tool/dump_user_db.dart <out>.sqlite ["<sql>" …]`. That tool is read-only and opens the copy, never the device file.
- **PowerShell 5.1 cannot pass a native argument containing a double quote.** `git commit -m @'…"переставить не сохраняется"…'@` reached git as several arguments (`error: pathspec 'не' did not match any file(s)`), because 5.1 wraps native arguments in `"` without escaping inner ones. Write the message to a file and use `git commit -F <file>` whenever it contains quotes; the Write tool round-trips UTF-8 correctly.
- Gradle: there is also a `M:` subst'd drive already mapped to `D:\MurajaahWorkspace` (`subst M: D:\MurajaahWorkspace`; recreate with that command if a fresh session doesn't have it). **Always invoke `gradlew.bat` from `M:\android`, not from `D:\MurajaahWorkspace\android` or the Cyrillic path.** Flutter's generated Gradle wiring bakes in `M:\...` pub-cache paths; invoking from a different root for the same files throws `this and base files have different roots` and fails configuration. Set `$env:GRADLE_USER_HOME = 'D:\MurajaahWorkspace\.tools\gradle-home'` to reuse the warm cache.
- `gradlew.bat testDebugUnitTest` (no module scope) also runs the bundled `geolocator_android` plugin's own unit test, which failed once in this session with `Could not find or load main class worker.org.gradle.process.internal.worker.GradleWorkerMain` (a Gradle worker JVM spawn crash) — unrelated to any app code. Re-running scoped to `:app:testDebugUnitTest :app:compileDebugKotlin` succeeded immediately after. If the unscoped command fails only on a third-party plugin's test task, re-run scoped to `:app:...` rather than treating it as a regression.
- **Never edit a source file with PowerShell `Get-Content`/`Set-Content` (even with `-Encoding utf8`).** In this session, `(Get-Content -Raw) -replace ... | Set-Content -Encoding utf8` silently mis-decoded the file's existing non-ASCII characters on read (PowerShell 5.1's `Get-Content` without an explicit read-side `-Encoding` used the wrong codepage) and wrote back corrupted bytes (`Fajr · Fard` became `Fajr В· Fard`) plus an unwanted UTF-8 BOM — `flutter analyze`/`dart` didn't catch either, only a failing test did. Always use the Edit tool for source changes; it round-trips UTF-8 correctly. If a PowerShell text rewrite of a repo file is ever truly unavoidable, verify with `[System.IO.File]::ReadAllBytes(path)[0..3]` for a stray `239,187,191` BOM and grep the file for any non-ASCII character afterward.
- `dart format` is not `flutter pub run dart format` (that fails with "Could not find package dart") and the `dart.bat` wrapper shells out to `git` internally (fails unless MinGit's `cmd` dir is prepended to `$env:PATH` first). Call the real executable directly: `D:\MurajaahWorkspace\.tools\flutter\bin\cache\dart-sdk\bin\dart.exe format lib test`, after `$env:PATH = 'D:\MurajaahWorkspace\.tools\mingit\cmd;' + $env:PATH`.
- `flutter gen-l10n` must be re-run (from the ASCII junction, like everything else here) after editing any `lib/l10n/*.arb` file — it respects `l10n.yaml` and regenerates `app_localizations*.dart` automatically; there is no separate flag needed.
- **`build_runner build` deletes two committed generated files it does not own**: `lib/features/quran/data/providers/known_official_quran_enc_translations.g.dart` and `lib/features/prayer_times/data/uzbekistan_prayer_locations.g.dart`. They are produced by the project's own `tool/` scripts, not by `build_runner`, but it treats them as stale outputs and removes them; the build then *succeeds* and only a later `flutter test` fails with "Error when reading '…​.g.dart'". This happened in the 2026-09-15 session. After every `build_runner` run, check `git status` and restore them with `git checkout -- <both paths>` if they show as deleted. (The `--delete-conflicting-outputs` flag is irrelevant — this build_runner version ignores it and deletes them anyway.)
- Run `build_runner`, `drift_dev schema dump` and `drift_dev schema generate` from the ASCII junction (`Push-Location D:\MurajaahWorkspace`). From the real Cyrillic path the AOT build script fails with `Unable to write file: …\.dart_tool\build\entrypoint\build.dart.aot`. Invoke them as `flutter.bat pub run …`, not via `dart.bat`, which shells out to `git` and then trips over the repo's `dubious ownership`.
- **`flutter analyze` with no path argument now crashes** with `FormatException: Unexpected character (at character 246)` inside `SessionLoggerSink._normalize`. The LSP init message contains `"name":"{{workspaceFolder-0}}\"` — an unescaped trailing backslash, because `M:\` is a **drive root**. Nothing to do with Cyrillic, and not a code defect. Run it with explicit paths instead: `flutter analyze --no-pub lib test tool`.
- **Never rewrite a source file with `Get-Content` + `Set-Content`.** PowerShell 5.1's `Get-Content` decodes with the system ANSI codepage unless told otherwise, so a round-trip silently mangles every non-ASCII character: an em dash came back as `вЂ”` in two test files, and `Set-Content -Encoding utf8` then added a UTF-8 BOM on top. Both were caught by a failing string comparison, not by review. Use the Edit tool for source edits; if a scripted rewrite is unavoidable, pass `-Encoding utf8` to **both** ends and strip the BOM byte-wise afterwards.

## Scope and non-goals

Current ordered scope: continuity protocol; stabilize interactive Rotation Widget and Learning Widget deep links; configurable prayer routines/schema v5; contextual prayer recommendations; remaining Sprint 5E Android surfaces; evidence-only Cyrillic transliteration audit.

Non-goals: cloud sync/accounts/server, gamification, Qibla, adhan alarms, full Quran reader, iOS WidgetKit, generated/converted Quran text or transliteration, invented prayer rules or times, and lock-screen bypasses.

## Verified completed work

- **Stage J §6.4 — durable, owner-scoped sync outbox on schema v7 (2026-09-16).** Three transport tables only: `sync_outbox_entries` (retry queue and quarantine in one table, separated by `status`), `sync_cursors`, `sync_activations`. `DriftSyncOutbox` passes the **existing** `runSyncOutboxContract` with no weakening — the same suite the in-memory reference passes — plus owner-isolation tests and a real restart test that writes to a file, closes the database, reopens it and finds the queued change with its exact enqueue instant. `DriftSyncStore` owns both transactional guarantees (a failed local write queues nothing; a refused enqueue rolls the local write back; a page that fails halfway leaves the cursor exactly where it was). Migration tests cover **v1→v7, v2→v7, v3→v7, v4→v7, v5→v7 and v6→v7**; the direct v6→v7 test proves a seeded recall attempt, recitation, session-part snapshot, part template and setting all survive byte-for-byte, then exercises the new tables' own guards. Two invariants are enforced by SQLite rather than only by the code that maintains them: a partial unique index on `(owner_key, entity_key) WHERE status = 'pending'` (coalescing) and `CHECK (is_active = 0 OR choice = 'merge')` (signing in is not activation). Analyzer clean, **763/763** tests pass (was 719). Full write-up: `docs/DATABASE_MIGRATION_V7.md`. **Not wired into the app and not yet run on a device.**
- **Stage J §6.4, the one port that changed.** `SyncAwareLocalStore.commitLocalChangeAndEnqueue` now takes the caller's own domain write as `applyLocalChange`. The original signature took only the envelope, which would have forced the durable store to reconstruct the local row from transport payload — a second, competing writer for every table, and a way to persist something the user never did. Nothing implemented the interface yet, so widening it broke nothing; `docs/ACCOUNT_SYNC_ARCHITECTURE.md` was updated to say why.
- **Stage J §6.0 — Appwrite MCP registered; the OAuth step is the owner's (2026-09-16).** First attempt: `claude` is not on PATH, so the prompt's `claude mcp add --transport http appwrite https://mcp.appwrite.io/` was expressed as the file that command writes — a project-scoped `.mcp.json` at the repo root, holding only the public URL. **That was not enough, and the owner's `/mcp` proved it: "No MCP servers are configured."** A project-scoped server needs a trust approval that the VSCode extension's `/mcp` panel does not surface; `claude mcp list` showed it as `⏸ Pending approval (run 'claude' to approve)`.
  The real CLI does exist, bundled with the extension at
  `~/.vscode/extensions/anthropic.claude-code-<version>-win32-x64/resources/native-binary/claude.exe`
  — worth knowing, because "not on PATH" is not "not installed". The official
  command was then run from the project folder at **local** scope, which is
  still this project only and needs no approval:
  `claude mcp add --transport http appwrite https://mcp.appwrite.io/ --scope local`.
  It wrote one entry — `{"type":"http","url":"https://mcp.appwrite.io/"}` — under
  this project in `~/.claude.json`, and `claude mcp list` now reports
  `! Needs authentication` instead of pending approval.
  `.mcp.json` is kept: it is the reproducible artifact for another machine or
  for Codex, and local scope simply shadows it.
  **No Appwrite call has been made**: not a read of project
  `6aa91956000d1d490a3e`, not a provisioning dry run. The owner's action is
  `/mcp` → `appwrite` → Authenticate — reloading the VSCode window first if the
  panel still shows nothing — and then approving, in his own browser, whatever
  scope Appwrite actually requests.
  **[Superseded 2026-09-17: `/mcp` → Authenticate CANNOT succeed for this
  server. It builds a 130-scope URL that Appwrite's own authorize endpoint
  corrupts, answering `invalid_scope` for a scope name nobody sent. A
  hand-built short-scope URL is required. Do not send the owner to `/mcp`.]**
- **Stage J §6.0/§6.1 — documentation re-verified against the primary source on 2026-09-16, and one claim must NOT be made.** Appwrite's own pages confirm the remote HTTP MCP at `https://mcp.appwrite.io/`, that it authenticates by OAuth with no API key to create, and the exact Claude Code flow (`claude mcp add --transport http appwrite https://mcp.appwrite.io/`, then `/mcp` → `appwrite` → Authenticate; `claude mcp login appwrite --no-browser` is the remote-host variant). **What the documentation does not say is whether the OAuth grant can be limited to one project — it documents no scopes at all.** §6.0.4 forbids calling it project-limited on an assumption, so the owner must read the consent screen Appwrite actually shows him before approving, and if it grants account-wide access that is what it is. **[Superseded 2026-09-17: it CAN be limited, via RFC 9396 `authorization_details` with type `project`, and the scope vocabulary is documented after all under `docs/products/auth/oauth-server/scopes`. The MCP client's own request is account-wide because it sends no authorization details. See "Stage J §6.0 — the Appwrite OAuth grant".]** The Flutter SDK re-check also came back unchanged from Stage G: `appwrite` 26.2.0 on pub.dev, published ~2026-09-08, so the ADR needs no revision. `Databases`-vs-`TablesDB` naming is **not** settled from the public package page and must be confirmed against the live project before any provisioning definition is written.
- **Acceptance-fix APK built and installed (2026-09-16), data verified rather than assumed.** sha256 `9e1f0741b5c7e55c954fcb13e129a1c3d41c81f137a2586d16c62bf7fc1754ce`. The prompt (§5) explicitly says not to infer survival from the database file size, so the check was row counts from a pulled copy before and after `adb install -r`: identical across all sixteen tables, `user_version = 6` unchanged. The leftover Зухр test part could **not** be removed — the phone is locked with a credential and its lock screen renders black to `screencap`, so no UI automation was possible, and writing to the database directly would have gone behind the app's own guarantees. It is listed under Next exact action as an owner action, which doubles as smoke-test point 1.
- **Stage H final name is SurahCycle, not SalahCycle** (2026-09-15, same day). After the `Salah Circle` near-miss below was reported, the owner chose **SurahCycle**, which removes the collision outright — both words differ rather than one vowel — and describes the product more exactly, since the app cycles surahs. Clearance for the new name: no app on Google Play or the App Store, no product in web search, and `github.com/surahcycle` returns 404 so the namespace is free (**nothing was registered — claiming it is the owner's action**). Renamed the same surfaces a second time, plus the deep-link scheme constant `surahcycle`, and re-verified on the device: the system App-info screen and Home both read **SurahCycle**, storage still 330 MB with the owner's data intact, and a cold `surahcycle://app/home` deep link lands on Home. `docs/RENAME_TO_SURAHCYCLE.md` is now `docs/RENAME_TO_SURAHCYCLE.md` and records both steps. **Lesson recorded in that file: the first attempt to switch the prose used a regex and flattened the historical mentions too, briefly claiming the name moved "from SurahCycle to SurahCycle" — the exact mechanical find-and-replace the document warns against, applied to itself.** The entries below describing the SalahCycle step are left as written: they are the record of what happened.
- Stage H (2026-09-15, new prompt section 13): user-facing rename to **SalahCycle**, **verified on the device**. The clearance ran first and found no direct conflict — no app, project, organization or trademark surfaced for "SalahCycle" on Google Play, the App Store, GitHub or in web search — so the reversible rename proceeded as the brief instructs. **One near-miss is recorded rather than swallowed: `Salah Circle` (`com.salahcircle.app`) is live on Google Play** with prayer times, a tracker, a Qada calculator, Quran and tasbih — an overlapping audience. "SalahCycle" and "Salah Circle" share the consonant skeleton *s-k-l*, syllable count and stress; only the vowel differs, which is thin for a largely non-native-English audience. That is exactly the "конфликт по звучанию и транслитерации" check the brief asks for, so it went to the owner as a branding judgement rather than being treated as an engineering blocker. **Caveat that must not be dropped: these were web searches, not a legal clearance — no trademark register (USPTO, EUIPO, UZ, RU) was queried directly, and a real search is still required before publishing.** Full plan and the kept/changed table: `docs/RENAME_TO_SURAHCYCLE.md`.
- Stage H, the line that was drawn: renamed everything the user reads — Flutter `appName` and the two strings naming the app, the Android launcher label, all three widget names and their empty/error copy in `values`/`values-ru`/`values-uz`, the screensaver label, and the iOS display name and location-permission string. **Deliberately kept: `applicationId`/`namespace` `dev.murajaah.murajaah`, the iOS bundle id, the Kotlin package, `MurajaahDreamService` and other class names, the method-channel and widget-receiver names, and the Drift database filenames.** Changing the applicationId makes Android treat the result as a different app — fresh install, owner's real reading history gone — and the brief forbids adopting a new reverse-domain namespace without evidence the owner controls that domain. Renaming the DreamService class silently deselects a screensaver the user had chosen. Renaming the database files abandons the data outright. A mechanical find-and-replace across the 133 files that mention the old name would have done all three.
- Stage H, deep links with transitional compatibility: the scheme is private to the app↔widget handoff (no `<data android:scheme>` intent filter exists), but a widget already on the launcher holds a `PendingIntent` built with the old URI, and that intent survives an app update. So step 1 only **widens** the parser to accept `salahcycle://` *and* `murajaah://`, while the builders and the Kotlin side keep emitting the legacy scheme — nothing placed can break. Step 2 (emit the new scheme) and step 3 (drop the old one) are separate and can wait. Verified on the device: both `murajaah://app/learning` and `salahcycle://app/learning/89` cold-start into Learning inside the shell.
- Stage H, device evidence (APK from the rename commit, `adb install -r`): the system App-info screen shows **SalahCycle**, Home's title shows **SalahCycle**, and storage still reports 330 MB with the owner's prayer routine, prayer times and recall summary intact — which is the point of not touching `applicationId`. All three widget providers remain registered and at least one placed widget instance survived the update.
- Stage G steps 1–2 (2026-09-15, new prompt section 12): account/sync design and local contracts. **The preliminary preference for Appwrite was checked rather than assumed, and it survived — but for a reason worth knowing.** Yandex ID is plain OAuth 2.0 with a Yandex-specific user-info endpoint (`GET https://login.yandex.ru/info`): `/.well-known/openid-configuration` 404s on both `oauth.yandex.ru` and `login.yandex.ru`, and no `id_token` is documented. Supabase custom providers and Firebase/Identity Platform both reach non-native providers *only* through OIDC discovery — Firebase says so outright ("if your OIDC provider doesn't comply with the OIDC specification for discovery, it won't work"). So with either of those, Yandex sign-in would require running our own bridge server holding a Yandex client secret and a token-minting key, for an app whose whole premise is working without a server. Appwrite lists `yandex` among its built-in OAuth2 providers. That single fact decided it; everything else (Flutter SDK `appwrite` 26.2.0 published ~2026-09-08, 75K MAU free tier, Frankfurt EU residency, self-hostable, project export) merely confirmed it. Recorded in `docs/adr/ADR-0001-account-sync-backend.md` with sources; `docs/SERVER_PLAN.md` got a pointer so its "framework not chosen / possibly Spring Boot" paragraph no longer silently contradicts the ADR.
- Stage G, the code: `lib/core/sync/` holds the envelope model, the ports, an in-memory outbox, the drain/pull engine, a closed app-setting allowlist and a local fake backend — **and nothing in `lib/app/`, `lib/features/` or the Android code references any of it.** That is deliberate: there is no backend, so there is nothing to half-wire, and a stub that reported a successful sync would be worse than an absent feature. 89 new tests. The guarantees worth remembering: a permanent server rejection is **quarantined** (not retried forever, which wedges the queue, and not deleted, which discards a change the user already saw succeed); a retryable failure keeps the entry with its attempt count raised; the pull cursor advances only with the local commit, so an interrupted pull is retried rather than skipped; `SyncEngine.drain` validates that the server's accepted/rejected id sets are disjoint and cover exactly what was sent, and treats a malformed answer as a retryable failure rather than trusting it. `runSyncOutboxContract` is a reusable suite so the future durable Drift-backed outbox runs the same tests unchanged.
- Stage G, two design points that came out of writing it down: `app_settings` cannot be synced wholesale because it mixes real preferences with device-local state, so `SyncAppSettingPolicy` is a **closed allowlist** (theme, prayer-time settings, transliteration profile, translation selection/language, display preferences) and everything else — selected learning surah, selected prayer context, the recommendation batch, one-time migration markers — stays local. And authentication is separated from activation: `SyncActivationGateway` requires a local backup, a merge preview and one explicit choice (including the honest `keepDeviceLocalOnly` option) before an account may touch existing local data, with an opaque preview token so a stale dialog cannot authorize a merge it never described.
- Stage G, **not done and deliberately so**: no durable outbox table. The one migration slot was spent on `recall_attempts` (v6), and adding a table nothing writes to, for a server that does not exist, is migration risk with no benefit. It ships with the migration that carries real sync, and the contract suite is what it will have to pass.
- Stage F (2026-09-15, new prompt section 11): the original memory-recall mode. **Written from the prompt's description only — Murajaa was not decompiled, and none of their code, design, interface text or algorithm was consulted or copied; no claim is made about their API.** Only the project's already-audited Tanzil text and existing coordinates are used, nothing generates Arabic, and there is no speech recognition or any claim of automatic correctness checking: every grade is the user's own self-assessment, and the UI says so. Structure: `lib/core/domain/recall.dart` holds the pure rules — `RecallSession.grade()` **throws unless the ayah was revealed**, `advance()` always re-hides, and a finished range refuses further grades; `RecallAttempt` is immutable and validates its own coordinates. `RecallRepository` is append-only by construction — it exposes no update and no delete, because editing a record of what someone remembered would turn an honest history into a flattering one. `RecallController` (a `StateNotifier`) never advances past a grade whose write failed, so a lost result cannot silently overstate progress. The hidden state renders a **fixed placeholder**, never a blurred or greyed copy of the real text: a blur still leaks word count and shape, which is most of the answer for a short ayah. Entry points: the Learning card («Проверить по памяти», defaulting to the current stage's range) and a mastered surah's detail screen (defaulting to the whole surah). Audio is offered **only after the reveal, and only when the checked range exactly equals the learning stage** the existing `LearningAudioControls` would play — a narrower check gets no audio rather than audio for the wrong ayahs. 47 new tests: 18 domain, 12 repository, 9 controller, 5 screen (the reveal gate asserted at the widget level too), plus the migration work below.
- Stage F, the one documented effect on review priority: a surah whose **most recent** check was imperfect sorts ahead of its equals, as the weakest contextual tie-break tier — below urgency and below both recency tiers, so it can never make a surah eligible or outrank a more overdue one, and a single clean check removes it. Only the latest attempt counts, deliberately, so one bad day cannot pin a surah to the front forever. It is surfaced in words, not as a hidden score: the recall screen states it, and the surah detail screen repeats it whenever the flag is actually set. A recall attempt never creates, cancels or substitutes a recitation-in-prayer event and never touches rotation credit or statistics.
- Stage E part 3b (2026-09-15): the Rotation widget now ranks from the same stored batch, so Home and the widget read one snapshot. The feared snapshot-schema bump turned out to be unnecessary and the earlier note claiming otherwise was wrong: `maxRotationWidgetItems` is 64, `RotationWidgetItem` already allows `remaining == 0`, and nothing in the projection path filters to due-only rows, so a completed entry already survives into the widget — it only needed the batch's ranks instead of a recomputed list. **Second loop found and fixed here**: Home and the widget driver both *planned and persisted* a batch into one stored slot, so whenever their resolved prayer contexts differed they overwrote each other endlessly (`flutter analyze` 234s, suite over 10 minutes). Only Home plans now; the widget reads `storedRecommendationBatchProvider`, which is read-only by construction. Analyzer back to 11s, suite to 62s. Lesson: two writers to one stored slot is a loop waiting to happen — give exactly one component the right to write.
- Stage E parts 1–3a (2026-09-14/15, new prompt section 10): a stable eight-item recommendation batch, **Home side complete**. Root cause of the shrinking block: recommendations were recomputed from the rotation snapshot on every rebuild, so a marked surah stopped being due and dropped out. Now `RecommendationBatchService` returns a stored batch untouched while its key matches (localDate + prayer + routine part + algorithm version); only a new key builds a new one. The offered set in `RecommendationCycleState` is **global rather than per prayer**, which is what stops Fajr and Asr from being handed the same surahs by the shared `remaining` ordering, and when the cycle runs out mid-batch a new round starts with the topped-up tail honestly marked as occurrence two (`2×`, which never doubles a recitation event). Stored as versioned JSON in `AppSettings`, deliberately **not** a Drift table: a batch is a replaceable presentation decision, not history, so it does not justify a schema migration, and anything unreadable is rebuilt rather than guessed at. `SurahSuggestionService.rankedCandidateIds` was extracted (not duplicated) from the existing ranking because `suggest()` is capped at the product ceiling while a batch needs the whole pool. Home renders the batch: all entries keep their position, a completed one turns green instead of vanishing, and a repeat shows `2×`. Commits `a70c32d`, `480356e`, plus the Home rendering commit.
- **Performance regression found and fixed while wiring this**: the full test suite went from ~50s to over 10 minutes. Cause: `ContextualRecommendationInputs` had no value equality, so every unrelated stream emission produced a non-equal instance, which made every dependent — including the new batch provider — rebuild and resubscribe. Adding `==`/`hashCode` restored the suite to ~60s. Worth remembering: a value object watched by Riverpod needs equality, or it silently becomes a rebuild amplifier.

- Stage D (2026-09-14, new prompt section 9): navigation from the Learning widget. `/learning/:id` was declared with `parentNavigatorKey: _rootNavigatorKey`, so it was pushed **above** the `StatefulShellRoute` and rendered Learning without the bottom navigation and without a normal back path. The selected surah is now a query parameter of the one shell route (`/learning?surah=<id>`), so every entry point lands on the same screen inside the shell; `/learning/:id` is kept purely as a redirect into that form, which keeps deep links already cached inside a launcher widget valid. `openWidgetLink` emits the query form directly. `LearningScreen` gained `didUpdateWidget`, because a warm deep link now reuses the mounted screen instead of running `initState` again — without it a second widget tap would have changed the URL but not the selected surah. No second `MaterialApp`/`Navigator` was introduced. 7 new tests in `test/app/learning_deep_link_route_test.dart` covering cold deep link, warm deep link, repeated tap, unknown surah id, empty id, system Back (asserting `router.canPop()` is false, so nothing is stacked to unwind), and switching tabs afterwards; each also asserts the `NavigationBar` is present.

- Watch-stream key collision (2026-09-14, found during the first real-device QA pass, not by a test): **the routine editor list never refreshed after a successful write — changes only appeared after restarting the app.** This is the second half of the user's original report ("иногда запись появляется позднее") and is a distinct defect from Stage A. Found on the device: adding a part produced no error and no visible change, but the part *was* present after a restart; deleting behaved the same. Root cause proved from drift's own source (`drift-2.34.3/lib/src/runtime/executor/stream_queries.dart`): `StreamKey` is built from **`sql` and `variables` only** — `readsFrom` is deliberately not part of it — and `StreamQueryStore` caches active streams in a `Map<StreamKey, QueryStream>`. Eight different watch queries in this repo all used the identical text `'SELECT 1'` with different `readsFrom` sets, so they collapsed onto one shared subscription whose table set was whichever registered first. On a real device `SurahRepository.watchCatalog` (surah tables only) subscribes early from Home, so later writes to `prayer_routine_part_templates` woke nobody. Isolated widget tests passed because only one such stream exists there — which is exactly why this survived a green suite. Fix: every watch query now has its own SQL text (`'SELECT 1 AS surah_catalog_watch'`, `'SELECT 1 AS prayer_routine_template_watch'`, and so on for all eight). Regression test: `test/core/data/watch_stream_key_collision_test.dart` subscribes an unrelated stream first and asserts the template stream still emits; it fails on the old code and passes now. **Lesson for future work: a bare `'SELECT 1'` watch query is now a bug in this repo — give each one a unique alias.**

- Stage C (2026-09-14, new prompt section 8): a manually chosen context is now sticky. `home_screen.dart` used to clear `prayerContextOverrideProvider` immediately after every recitation **and** after followed-imam, which is why Witr/Nafl had to be re-picked for each surah. Both unconditional clears are gone; the only remaining clear is the new explicit user action. `prayerContextOverrideProvider` now holds a `PrayerContextOverride` (context **plus** the local date it was chosen for) instead of a bare `PrayerContext`, and the new derived `activePrayerContextOverrideProvider` yields it only while that date is still today. That is the midnight guard: a sticky override simply stops applying after the local-date boundary and the app falls back to automatic resolution, so it can never silently attribute events to the next day. Home shows a `return-to-automatic-prayer` chip ("Вернуться к авто") whenever an override is actually in force, so there is always one visible way back. The ordinary-mark and followed-imam paths now behave identically because neither touches the override at all. The override remains in-memory only, so an app restart resolves automatically by default. 6 new provider tests plus a rewritten Home widget test.
- Stage B (2026-09-14, new prompt section 7): Qada is limited to the obligation itself. `PrayerType.supportsQada` already resolved correctly at the prayer level (the five daily prayers plus Witr; never Jumuah or Nafl) — the missing dimension was the **part kind**, so the rule now lives in one domain predicate, `PrayerQadaPolicy` in `lib/core/domain/prayer_routine.dart`. `obligatoryPartKind` maps the five daily prayers to `fard` and Witr to its own `witr` kind (Witr is deliberately **not** remodelled as Fard just to reuse the type), and returns null for Jumuah/Nafl. Enforced in three places so no caller can bypass it: the routine snapshot filters ineligible parts when building a Qada session (`_qadaEligibleParts` in `prayer_routine_repository.dart`, applied in both `startSession` and `ensureCurrentSession`), the recitation write boundary re-checks it and throws the new `PrayerSessionSlotUnavailableReason.qadaPartNotEligible`, and an ordinary context is untouched so a normal prayer keeps every configured part. A Qada context whose routine has no obligatory part creates no session at all, so the plain slotless mark stays available instead of forcing the user into a Qada slot. The policy takes `prayerType`/`isQada` separately rather than a rebuilt `PrayerContext`, because that constructor rejects combinations legacy history may legitimately contain. **Legacy is read-only compatible**: existing sessions and rows — including any pre-existing Nafl/Jumuah/Sunnah Qada — are still returned unchanged; only *new* writes are refused. 21 new tests (13 policy, 8 session/write-boundary).
- Stage A (2026-09-14, new prompt section 6): prayer routine editor reliability. **Root cause proved, not guessed.** `test/core/data/prayer_routine_stale_revision_repro_test.dart` reproduces it deterministically: the editor UI captured `template.revision` in the widget-build closure, `_guard` re-enabled the buttons the instant the write future resolved, and `watchTemplate` had not yet delivered the new revision at that moment (third test in that file asserts exactly this lag). So the next add/delete was sent with a superseded revision and the repository correctly raised `PrayerRoutineRevisionConflict` — which the card swallowed into a generic "Не удалось выполнить действие". The first write had already committed, which is why the user saw the record "appear later". The FK hypothesis (session parts pinning template part rows) was checked first and **disproved**: `PrayerSessionParts.sourceTemplatePartId` has no foreign key. Fix: new `lib/features/settings/application/prayer_routine_editor.dart`. It serializes every mutation through one queue, reads the revision inside that queue immediately before the write (so a UI-held revision is never used), retries at most once on a genuine concurrent-writer conflict, and returns a typed outcome — `Applied` / `Unchanged` / `Conflict` / `Failed` — instead of throwing. Duplicate submits and deleting an already-deleted part resolve to `Unchanged`, so one tap can never duplicate a part. The card now shows a precise message plus a "Повторить" action for `Failed`, a refreshed-state message for `Conflict`, and logs the real exception type/message/stack via `developer.log(name: 'MurajaahRoutine')` under `kDebugMode`. The repository's in-transaction revision check is untouched, so a real concurrent writer is still rejected. 20 new tests (16 editor, 3 reproduction, 1 widget-level regression covering a stale shown revision).

- (pending commit): Checkpoint E, Cyrillic transliteration source audit. New `docs/QURAN_CYRILLIC_TRANSLITERATION_AUDIT.md` records a multi-agent search (open datasets, official Quran APIs/institutions, Central Asian/Russian religious authorities, community transcription sites) that found 20 unique candidates and independently re-verified the 10 most promising against the project's 9-item source checklist. None passed. Notable findings: `maqsats/Quran-Transliteration-` on GitHub is the only candidate anywhere with a genuinely complete (byte-verified 6,236/6,236 lines), real Cyrillic transliteration, but has no license of any kind and no stated original source — and its own `translit_ru.xml` internally disagrees with its `translit_ru.txt` by 113 extra "ayahs," including an erroneous Bismillah prepended to Surah 9 (which canonically has none), showing no QA process exists for it. Several candidates that appeared to offer "Russian"/"Cyrillic" content turned out on direct inspection to be ordinary meaning translations, not phonetic transliterations (`MakhmudovBekhruz/quran_db`, all `rus-*` editions in `fawazahmed0/quran-api`). The one candidate delivered through a documented, keyless, freely-licensed official API (Al Quran Cloud's `ru.transliteration`) was independently confirmed to contain systematically corrupted text (words broken by stray spaces) at both ends of the corpus, which would fail the project's own byte-for-byte/no-normalization rule even if licensing were otherwise resolved. A Dagestan-muftiyat-linked portal was found citing an actual fatwa (a Saudi Permanent Committee ruling) against reading the Quran from Cyrillic/Latin transcription at all, on pronunciation-corruption grounds — a plausible reason no official Central Asian or Russian religious authority checked in the audit (Kazakhstan's DUMK, Russia's Council of Muftis, Dagestan's muftiyat) publishes its own transliteration dataset. `docs/QURAN_TRANSLITERATION.md` and `docs/BACKLOG.md` item 26 now link to the audit; neither's underlying decision changed. No code, test, or non-doc file was touched.
- `e90690b`: Sprint 5E2 remaining Android surfaces (Checkpoint D). Home gets a compact "Today" prayer-schedule strip inside the existing Prayer Context card (`_PrayerScheduleStrip`, keyed `prayer-schedule-entry-$label`), built from the same `PrayerScheduleContextResolutionProvider` schedule/timing data Home already displays — no second resolver. A third Android widget (`PrayerWidget.kt`) renders the same six daily boundaries at compact/medium/large Glance `SizeMode.Responsive` sizes; `PrayerWidgetProjectionFactory` (`lib/core/widgets/prayer_widget_projection_factory.dart`) is a pure formatting layer that does not decide current/next/staleness itself, matching the "Kotlin never owns a resolver" rule already established for Rotation/Learning. `WidgetSnapshot` schema bumped 5→6 to carry the new required `prayer: PrayerWidgetProjection` field; native Kotlin decoding (`WidgetSnapshot.kt`) validates it with the same strict-schema/exact-invariant style as the rest of the snapshot (exactly 6 entries, at most 1 current, at most 1 next, boundary-only entries — Sunrise — can never be current/next). A silent, opt-in Learning notification (`LearningNotificationManager.kt`, `learning_quiet` channel, `IMPORTANCE_LOW`) is off by default; `LearningNotificationController.setEnabled(true)` is the only place `POST_NOTIFICATIONS` is requested, reusing `MainActivity.kt`'s existing shared permission helper, and a denial leaves it off without retrying. `LearningNotificationChannel` was refactored from a concrete class into an interface plus a `MethodChannelLearningNotifications` implementation specifically so `LearningNotificationController` could be unit-tested against a fake. An optional `MurajaahDreamService` screensaver (system-picked only via Settings > Display > Screen saver, no in-app toggle) shows the current Learning item read-only; it explicitly never requests `showWhenLocked`, a full-screen intent, an overlay before unlock, Accessibility/Device Admin, or a self-triggered wake — all independently asserted by `test/android/widget_native_contract_test.dart`. `docs/LOCK_SCREEN_LEARNING.md` documents, rather than works around, that modern Android has no supported keyguard-widget API — there is no real lock-screen widget, and this is stated as a platform fact, not implemented as a fake. The Settings learning-notification card was extracted into its own `LearningNotificationSettingsCard` widget (matching the existing `PrayerRoutineSettingsCard`/`PrayerTimeSettingsCard` pattern) specifically so it could be pumped and tested in isolation with a fake channel override. New docs: `docs/PRAYER_WIDGET.md`, `docs/LOCK_SCREEN_LEARNING.md`; `docs/ANDROID_WIDGETS.md`/`ARCHITECTURE.md`/`PRODUCT_SPEC.md`/`BACKLOG.md` updated for schema 6 and Sprint 5E2 scope.
- `1fa90d0`: Sprint 6B contextual prayer recommendations. `ContextualSurahSuggestionService` layers two new tie-break tiers (exact-routine-part recency via a new `RecitationRepository.getLastUsedByRoutinePart`/`watchLastUsedByRoutinePart`, then prayer-type recency reusing existing `getStats(prayerType:, isQada:)`) strictly between the unchanged global `remaining` urgency ordering and the unchanged existing tie-break tail, implemented as a minimal, backward-compatible extension to `SurahSuggestionService.suggest` (`excludedSurahIds`, `contextualTiebreak` params) rather than a parallel reimplementation — all pre-existing `SurahSuggestionService`/`SurahOperationalOrderService` tests pass unmodified. Home's separate "Recommended" chip block is gone; `_SurahRotationTile` now shows the `RecommendationRankBadge` and a "recited in this part" check icon inline, and Home/`RotationWidgetProjectionFactory` both consume the same `contextualRecommendationInputsProvider` so ranks/exclusions are identical. Isha→Witr auto-transition is a pure `_applyIshaToWitrTransition` function applied by two new thin wrapper points (`homePrayerContextResolutionProvider` for Home, inline in `widgetSyncLifecycleProvider` for the widget) — deliberately *not* folded into the shared `prayerContextResolutionProvider` itself (see Decisions and reasons for why that first attempt broke three existing tests). Kotlin needed zero changes: `RotationWidget.kt` already renders `recommendationRank` since Sprint 5E1/6A.
- `260cf93`: Sprint 6A configurable prayer routines (schema v5, routine templates/editor, immutable session-part snapshots, followed-imam, Jumuah). Independently re-verified in this session (not just re-reading the prior agent's notes): `flutter analyze` clean, full `flutter test` 424/424, `:app:compileDebugKotlin`/`:app:testDebugUnitTest` green, and the followed-imam completion path in `prayer_routine_repository.dart` was read directly to confirm it only updates `PrayerSessionParts` (completion mode + timestamp) and never inserts a `RecitationEvent` or touches rotation state.
- `6ad2772`: Sprint 5E1 stabilize interactive widgets (Checkpoint A), previously verified.
- `a640f50`: Sprint 5D Quran audio, previously verified with Flutter tests, Android compilation, and APK build.
- `2888de3`: Sprint 5C multilingual Quran layers.
- `68780aa`: Sprint 5B prayer context and history UX.
- `761f339`: Sprint 5A mastery lifecycle and learning plans.
- `bacacec`: Sprint 4 interactive widgets, Quran layers, and prayer times.
- Baseline inspection on 2026-09-03 confirmed HEAD/branch and the code facts described in the continuation scope: DB schema v4; Rotation Widget projection filters `remaining > 0`; Learning Widget fallback uses the Home URI; no Prayer Widget or DreamService exists.

## In progress

- Continuity files were committed in isolated checkpoint `4528fce`.
- Sprint 5E1 is committed as `6ad2772`: DB-backed revision ordering, atomic stale-write rejection, explicit checked state, foreground reconciliation, stable rows, debug-gated diagnostics, early callback registration, and corrected Learning links.
- Sprint 6A is committed as `260cf93`: schema/domain v5, all migration fixtures, Jumuah, revision-safe routine editor/repository, immutable sessions, exact-slot Home/widget flow, completed-routine guard and followed-imam/Undo, all covered by targeted and full checks.
- Sprint 5E1's foreground/headless ordering risk is addressed by DB-backed journal revisions and stale-snapshot rejection; physical-device lifecycle verification remains pending.
- Checkpoint C (contextual prayer recommendations) is committed as `1fa90d0`.
- Checkpoint D (remaining Sprint 5E Android surfaces: Home prayer schedule strip, Prayer Times Widget, Learning notification/DreamService) is committed as `e90690b`.
- Checkpoint E (evidence-only Cyrillic transliteration source audit) is complete; the audit doc is about to be committed. This was the last checkpoint in the continuation prompt's list.

## Decisions and reasons

- The manual context override carries the local date it was chosen for rather than relying on a timer to expire it. Comparing the stored date against the current one at the point of use is stateless and cannot miss a midnight tick, a suspended process, or a timezone change; a timer-based reset could. The override is also kept in memory only, so the safe default after an app restart is automatic resolution rather than a silently resurrected choice.
- An existing Home test asserted the old "override clears after one mark" behaviour and its name said "one-event". It was **updated, not deleted**: the requirement deliberately changed, so the test now encodes the new contract (two marks in a row keep the chosen context, then the explicit action returns to automatic) and covers more than it did before.
- Witr keeps its own `PrayerRoutinePartKind.witr` in the Qada rule instead of being modelled as Fard. Collapsing it into Fard would have made the policy a one-liner but would misrepresent a Wajib-level prayer as an obligatory Fard in stored history, which is a religious claim the app must not invent.
- The Qada part rule is enforced at three layers on purpose. Filtering only when the snapshot is built would still let a stale widget payload or a deep link write into an ineligible part of a session created earlier, so the recitation write boundary re-checks the same predicate. Both call one shared function; there is no second copy of the rule.
- A Qada context with no obligatory part yields *no* routine session rather than an empty one. That keeps the ordinary slotless mark available, which is what stops a configuration gap from pushing the user toward Qada as a workaround — the behaviour the user actually reported doing.
- Legacy Qada rows stay readable and are never rewritten. A previously stored Witr Qada is now simply valid; any older Nafl/Jumuah/Sunnah Qada row remains in history for honesty, but no new one can be created. Known edge case, documented rather than silently patched: a *legacy* Qada session whose current part is voluntary will refuse new recitations into that part. Sessions are date-scoped, so this resolves itself the next day; it is not worth rewriting stored history to avoid.
- Optimistic concurrency for routine edits stays in the repository, but the *editor UI no longer supplies the revision*. A revision is only meaningful at the moment of the write, and a widget necessarily holds a stale one (its stream lags the commit). The new `PrayerRoutineEditor` reads it inside its own serialization queue, immediately before writing. This preserves the guarantee the revision exists for — rejecting a genuinely concurrent writer inside the transaction — while removing a window that produced pure false failures for the single human editing their own routine.
- Routine edits are expressed by part identity (id / id list), never by positional index alone, which is what makes "apply to the freshest state" safe: a delete of a vanished part is a no-op, an edit of a vanished part is a real conflict, and a reorder whose id set no longer matches is a real conflict. Each is reported distinctly rather than collapsing into one generic error.
- The editor returns typed outcomes instead of throwing. A screen must distinguish "someone else changed this" (show refreshed state, ask to repeat) from "this actually failed" (offer a bounded, user-driven retry). Retry is capped at one automatic attempt inside the editor plus an explicit user tap; there is no silent retry loop.

- The application database remains authoritative. SharedPreferences remains a replaceable widget projection, never a second source of truth.
- Existing untracked media remains outside commits because it was present before this checkpoint and belongs to the user.
- Normal Android Back/Activity destruction will not be overridden. Reliability must come from idempotent background actions, committed revision ordering, and resume reconciliation.
- Schema v5 is introduced once for prayer routines, preserving all legacy events with nullable part/slot links rather than inventing historical prayer parts.
- Routine templates start empty with `enabled=true`; without parts they have no runtime effect and infer no madhhab preset. A template can be disabled and an individual part can be confirmed-deleted (schema v5 has no per-part enabled flag).
- A current routine makes the complete session/part/next-slot tuple mandatory at the repository transaction boundary. Cached schema-1/slotless widget actions remain compatible only when no routine exists and otherwise fail closed.
- Followed-imam is a part completion, never a recitation; it creates no event, rotation credit or surah statistics. Undo is accepted only before later dependent history.
- Jumuah is manual, distinct from Dhuhr, has no invented solar time and does not support Qada. Friday automatic resolution stays Dhuhr; Home offers an explicit one-event override in its current interval.
- The Isha→Witr transition was first written as two extra `ref.watch` calls added directly inside `prayerContextResolutionProvider`. That broke three existing tests (`prayer_startup_provider_test.dart` ×2, plus `home_screen_test.dart`'s Fajr routine test) that construct a bare `ProviderContainer`/override set with no reason to expect the base resolver to now also depend on routine/template providers. Fix: `prayerContextResolutionProvider` was reverted to byte-identical original behavior; the transition lives in a pure `_applyIshaToWitrTransition(base, {ishaRoutine, witrTemplate})` function, applied only by `homePrayerContextResolutionProvider` (which Home now watches instead of the base provider) and inline inside `widgetSyncLifecycleProvider`. Lesson: a provider with many existing bare-`ProviderContainer` tests is a poor place to add new cross-cutting `ref.watch` dependencies — wrap it from outside instead.
- "Prayer type stats" tie-break (continuation-prompt 8.3 rule 5) is implemented as least-recently-used-anywhere-in-this-prayer-type, reusing existing `getStats(prayerType:, isQada:)`'s `bySurah[i].lastUsedAtUtc` — not a frequency/count metric. This was a judgment call where the prompt didn't pin an exact metric; recency was chosen to form one consistent three-level recency cascade (exact-part → prayer-type → global) with the existing global tie-break tail.
- "Already filled in the current part" exclusion (rule 2) is scoped by surah id, not by individual rotation-scheme part id. A split surah could in principle still be recommended by a different internal chunk after one chunk fills a slot; this was judged a reasonable, simple, testable reading of "не рекомендуются повторно."
- The Prayer Times widget has no periodic self-refresh (no WorkManager job), matching Rotation and Learning widgets' existing lack of one. All three rebuild only when `WidgetSyncCoordinator` publishes after an app-triggered recalculation. Since the schedule itself only changes at day boundaries or on explicit location/method changes, this was judged sufficient for now rather than adding a new periodic-refresh mechanism no other widget has; documented as an option to revisit if physical-device QA shows real launcher staleness, not a silently dropped requirement.
- No true lock-screen widget was implemented, and none was faked. Modern Android (since API 21) removed the keyguard-widget API third-party apps used to use for lock-screen `RemoteViews`/Glance content; there is currently no supported, non-bypass way to place one there. `docs/LOCK_SCREEN_LEARNING.md` states this platform fact directly instead of shipping something that only resembles a lock-screen widget (e.g., an overlay or `showWhenLocked` trick), which the continuation prompt explicitly prohibits.
- `LearningNotificationChannel` was refactored from a single concrete class into `abstract interface class LearningNotificationChannel` plus `MethodChannelLearningNotifications implements LearningNotificationChannel`, matching the codebase's established bridge-interface pattern (e.g. `WidgetSnapshotBridge`/`HomeWidgetBridge`). This was done specifically so `LearningNotificationController.setEnabled` could be unit-tested against a fake channel without a real `MethodChannel`/native embedding.
- The Settings learning-notification card was pulled out of `SettingsScreen`'s private `_buildLearningNotificationCard` method into its own `LearningNotificationSettingsCard` `ConsumerStatefulWidget` file. `PrayerRoutineSettingsCard` and `PrayerTimeSettingsCard` on the same screen already follow this pattern for the same reason: a private method on a screen with many other heavy provider dependencies (translation catalogs, display preferences, transliteration profile registry, rotation snapshot) cannot be pumped in a widget test in isolation, but a standalone widget can with a single `learningNotificationChannelProvider` override.
- `MurajaahDreamService.kt`'s own doc comment explained, in prose, that it deliberately never requests "`showWhenLocked`" — but `widget_native_contract_test.dart`'s check for that exact substring matched the comment itself, not real code, and failed the test it was meant to prove passes. Reworded the comment to describe the same guarantee ("never asks to appear above the keyguard") without the literal trigger string, rather than weakening the test's blunt substring check, which is intentionally blunt so it also catches a future accidental real usage.
- The Cyrillic transliteration audit (Checkpoint E) was run as a background multi-agent Workflow (4 parallel search agents by distinct angle, then 10 parallel independent-re-verification agents against the same 9-item checklist) rather than as a single linear search-and-read pass. This matched the task: the project's own integrity rules (`docs/QURAN_DATA_SOURCES.md`) demand exactly the kind of adversarial, byte-level double-checking that caught real problems here — a search-stage agent's fabricated pair of edition names for `fawazahmed0/quran-api` was caught and corrected by its verifier, and `MakhmudovBekhruz/quran_db`'s README claim of "Cyrillic" support was overturn by directly inspecting the bundled SQLite content, not the README prose. A single-pass search would very plausibly have accepted one of these two at face value.
- No new candidate Cyrillic source was connected, and none will be, based on this audit alone. The audit's own "what could change this" section names concrete next actions (contact the `maqsats` repo author or find the original source of that text; ask the Taraz mosque portal or DUMK directly for a distributable dataset; ask Quran Foundation about adding an authored Cyrillic edition) — those require outreach a coding session cannot perform, so Cyrillic stays disabled until a human takes one of those steps and a future session re-verifies whatever comes back against the same checklist.

## Database and migrations

- Application schema version: **6** (`lib/core/data/database/app_database.dart`), raised from 5 by Stage F on 2026-09-15.
- Current core tables include Surahs/mastery, RotationStates/Schemes/Parts/Adjustments, PrayerSessions, RecitationEvents/EventParts, LearningSurahs/Events, RecallAttempts, and AppSettings.
- Migrations are verified by direct v1→v6, v2→v6, v3→v6, v4→v6 and v5→v6 tests, including exact legacy-row/relationship preservation, plus a test that a database stamped with a *newer* `user_version` is refused rather than silently downgraded.
- Schema v5 adds routine templates, immutable prayer-session part snapshots, and optional recitation-event part/slot links. It preserves legacy history with null part/slot links and seeds only empty manual templates (no madhhab preset).
- **Schema v6 adds `recall_attempts`** — the append-only memory-check journal (`id`, autoincrement `sequence`, `surah_id` FK, `ayah_start`/`ayah_end`, `learning_cycle`, `result`, `created_at_utc`, `local_date`, `source`) with CHECK constraints on result/source/range and two indexes. **It backfills nothing on purpose**: a recall attempt is a statement about what the user remembered, and inventing historical ones would misreport their memory. This was the one migration slot section 16 reserved; the recommendation batch deliberately stayed in AppSettings JSON to leave it free, and it is now spent — any further persistence needs a new, separately justified v7.
- The `drift_schemas/drift_schema_v6.json` fixture and `test/generated_migrations/schema_v6.dart` were generated with `flutter pub run drift_dev schema dump …` / `… schema generate …` from the ASCII junction; regenerating the whole `test/generated_migrations/` directory also rewrote the v1–v5 helper files (formatting/codegen version only, no schema change).

## Known bugs and reproduction

- No currently reproduced code-level Sprint 5E1 or Sprint 6A defect remains after automated verification; the original launcher lifecycle report and new routine labels/actions still need physical-device confirmation.
- Android force-stop may prevent broadcast delivery by OS design and must not be represented as supported delivery.
- `flutter analyze`/`dart` crash with a JSON `FormatException` when run with the working directory set to the real Cyrillic project path; see Environment and tooling above for the ASCII-junction workaround. Not a code defect.
- Unscoped `gradlew.bat testDebugUnitTest` can fail on the bundled `geolocator_android` plugin's own test task with a Gradle worker JVM spawn error, unrelated to app code; see Environment and tooling above.

## Tests and commands

- 2026-09-15 (Stage H, full): `flutter analyze` -> `No issues found!`; full `flutter test --timeout 90s` -> **`699/699`** (same count; one existing expectation updated from "Murajaah" to "SalahCycle" and four new deep-link transition tests added). `flutter gen-l10n` re-run after the three `.arb` files. `flutter build apk --debug` from `M:\` -> built; installed with `adb install -r`. Android resources changed, so this stage did need the Gradle build, unlike G.
- 2026-09-15 (Stage G, full): `flutter analyze` -> `No issues found!`; full `flutter test --timeout 90s` -> **`699/699` passed** (was 610; +89 sync tests). No Kotlin/Android file changed and no new package dependency was added, so no Gradle run and no `pub get` were required. Suites: `test/core/sync/sync_envelope_test.dart` (boundary invariants, including that a tombstone may not carry a payload and that derived snapshots are absent from `SyncEntityType`), `in_memory_sync_outbox_test.dart` (runs the shared `runSyncOutboxContract`), `fake_sync_backend_test.dart` (the rules a real server must enforce), `sync_engine_test.dart` (drain/pull failure paths and the account/identity rules).
- 2026-09-15 (Stage F, full): `flutter analyze` from the ASCII junction -> `No issues found!`; full `flutter test --timeout 90s` -> **`610/610` passed** (was 600 before the review-priority tier, 558 before Stage F; +52 in total for this stage). No Kotlin/Android file changed, so no Gradle run was required. `flutter gen-l10n` was re-run after adding 25 recall keys to all three of `app_en.arb`/`app_ru.arb`/`app_uz.arb`.
- 2026-09-15 (Stage F, migrations): `flutter test test/core/data/app_database_migration_test.dart` -> 6/6 passed — v1→v6, v2→v6, v3→v6, v4→v6, a new direct v5→v6 test that seeds the full v5 routine scaffold (edited template revision, part template, session-part snapshot, a recitation bound to that part and slot) and proves all of it survives, and a new test that a database stamped `user_version = 7` is refused with a `StateError` instead of being silently downgraded. The v5→v6 test also exercises the new table's own guards: an unknown `result`, a reversed ayah range, an unknown `source`, an unknown surah id and a duplicate attempt id are each rejected.
- 2026-09-15 (Stage F, units): `test/core/domain/recall_test.dart` 18/18 (reveal gate, grading refused before the reveal, re-hiding on advance, the range walk and its completion, single-ayah and resumed sessions, reversed/out-of-bounds/outside-surah coordinates, exact coordinates on the produced attempt, UTC and non-empty-id validation, value equality). `test/core/data/recall_repository_test.dart` 12/12 (exact round-trip, newest-first ordering, per-surah scoping, a duplicate id rejected without overwriting the original, an unknown surah rejected, per-result counts, the review flag following the *latest* attempt in both directions, per-surah independence, and the watch stream emitting on every append). `test/features/learning/recall_controller_test.dart` 9/9 (including: a grade attempted before the reveal stores nothing and changes no state, and a failed write leaves the step exactly where it was so the user can retry). `test/core/domain/recall_review_priority_test.dart` 7/7 (the tie-break fires, ties among equals keep the previous order, a missed surah still cannot overtake a more overdue one, no checks means a byte-identical ranking, a clean check clears the nudge). `test/widget/recall_screen_test.dart` 5/5.
- 2026-09-15 (Stage F, test-writing note): the recall widget tests first appeared to hang. Two separate causes, both worth remembering. **(1)** Piping `flutter test` through `Out-String`/`Select-Object` buffers the entire stream, so no interim output reaches the log and a slow run is indistinguishable from a hang — use `Tee-Object` to a file, and pass `--timeout` so a genuinely stuck test fails instead of blocking. **(2)** The real failure was drift's zero-duration `StreamQueryStore.markAsClosed` timer, scheduled while the `ProviderScope` is disposed. Draining it from an `addTearDown` is too late — `flutter_test` checks for pending timers before tear-downs run. The drain (`pumpWidget(SizedBox.shrink())` plus a few 1 ms pumps) must be the last statement **inside the test body**, which is what the existing `home_recommendations_without_context_test.dart` already did.
- 2026-09-14 (Stage C): `flutter test --no-pub test/app/prayer_context_override_test.dart` -> 6/6 passed (no override resolves to nothing; an override chosen today keeps applying across repeated reads; an explicit clear works; it stops applying once the local date moved on; a Qada override is preserved exactly; value equality). `flutter test --no-pub --plain-name "manual override survives" test/widget/home_screen_test.dart` -> 1/1 passed: two marks in a row both persist with the chosen context and Home still shows it, then the `return-to-automatic-prayer` chip restores automatic resolution and disappears. The two `prayer_startup_provider_test.dart` call sites were updated for the new override type; the manual-mode test now deliberately uses a still-applicable date so it still proves persisted manual mode wins over a live override.
- 2026-09-14 (Stage C, full): `flutter analyze --no-pub` -> `No issues found!`; full `flutter test --no-pub --reporter compact` -> `506/506` passed (was 500; +6). `dart format lib test` touched 3 files; analyzer and the affected suites re-run green afterwards. No Kotlin/Android file changed, so no Gradle run was required.
- 2026-09-14 (Stage B): `flutter test --no-pub test/core/domain/prayer_qada_policy_test.dart` -> 13/13 passed (all five Fard prayers, Witr as its own Wajib part, rejection of Sunnah/Nafl/custom/Witr kinds inside a Qada Dhuhr, Jumuah and Nafl having no make-up obligation, a missed Jumuah not being registrable as Jumuah Qada, and every kind staying available in an ordinary context). `flutter test --no-pub test/core/data/prayer_qada_routine_test.dart` -> 8/8 passed (Qada Fard session keeps only Fard, the same routine keeps everything when ordinary, Qada Witr keeps only Witr, a Qada context with no obligatory part creates no session, a past date alone is not Qada, a legacy Qada session with a voluntary part stays readable, and the write boundary both rejects a forged Qada recitation on a voluntary part and accepts the same one on the Fard part).
- 2026-09-14 (Stage B, full): `flutter analyze --no-pub` -> `No issues found!`; full `flutter test --no-pub --reporter compact` -> `500/500` passed (was 479; +21). `dart format lib test` touched 1 file; analyzer and the Stage B suites re-run green afterwards. No Kotlin/Android file changed, so no Gradle run was required.
- 2026-09-14 (Stage A): `flutter test --no-pub test/core/data/prayer_routine_stale_revision_repro_test.dart` -> 3/3 passed, documenting the root cause before any fix (stale captured revision conflicts on the second mutation; the first write is already persisted; `watchTemplate` has not caught up when the write returns).
- 2026-09-14 (Stage A): `flutter test --no-pub test/features/settings/prayer_routine_editor_test.dart` -> 16/16 passed. Covers the first part in an empty template, three queued rapid additions, an external revision change before the user's action, add→edit→delete in one sequence, deleting the last part, reorder-then-delete with contiguous order, duplicate submit, deleting an already-deleted part, editing/reordering against a vanished part, a rejected edit leaving the database untouched, enable/disable idempotency, Fard+Sunnah together, every seeded prayer type, and the two "an unconfigured routine never forces Qada" cases (empty and disabled templates create no session, so the slotless flow stays).
- 2026-09-14 (Stage A): `flutter test --no-pub test/widget/prayer_routine_settings_card_test.dart` -> 4/4 passed, including the new widget-level regression where the card is showing a superseded revision and the user's add must still apply.
- 2026-09-14 (Stage A, full): `flutter analyze --no-pub` -> `No issues found!`; full `flutter test --no-pub --reporter compact` -> `479/479` passed (was 459; +20 new). `dart format lib test` reformatted 4 touched files; analyzer and the affected suites re-run green afterwards. No Kotlin/Android file changed in this stage, so no Gradle run was required.

- 2026-09-03T09:38-09:45Z: `flutter --version` -> Flutter 3.44.7, Dart 3.12.2.
- 2026-09-03T09:38-09:45Z: `flutter analyze --no-pub` -> no issues (74.6 s).
- 2026-09-03T09:45Z: `flutter test --no-pub --reporter compact` -> 389/389 passed.
- 2026-09-03T09:45Z: `git diff --check` -> clean.
- 2026-09-03T09:54Z: `cd /d M:\android && gradlew.bat testDebugUnitTest` -> `BUILD SUCCESSFUL` in 1m 19s; 190 actionable tasks (4 executed, 186 up-to-date). `:app:testDebugUnitTest` reported `NO-SOURCE`.
- 2026-09-03: Sprint 5E1 interim `flutter analyze --no-pub` -> no issues; targeted widget/action/native-contract suite -> 47/47 passed.
- 2026-09-03T10:12Z: final `flutter analyze --no-pub` -> no issues; full `flutter test --no-pub --reporter compact` -> 395/395 passed.
- 2026-09-03T10:13Z: `gradlew.bat :app:compileDebugKotlin` -> `BUILD SUCCESSFUL` (14s).
- 2026-09-03T10:13Z: `gradlew.bat testDebugUnitTest assembleDebug` -> `BUILD SUCCESSFUL` (45s; 352 tasks). App Android unit task remains `NO-SOURCE`; debug APK built at `build/app/outputs/flutter-apk/app-debug.apk` (228,894,889 bytes).
- 2026-09-03T11:55Z: `flutter test --no-pub --reporter expanded test/core/data/app_database_migration_test.dart` -> 4/4 direct v1/v2/v3/v4 to v5 migration paths passed; `dart analyze lib/core/data/database/app_database.dart test/core/data/app_database_migration_test.dart` -> no issues.
- 2026-09-03: `flutter test --no-pub --reporter expanded test/core/data/prayer_routine_repository_test.dart` -> 11/11 passed; targeted repository/test `dart analyze` -> no issues. Covered revision-safe CRUD/reorder, immutable session snapshots, zero-slot completion, deterministic current-session reuse/progress, and followed-imam completion/guarded Undo without recitation or rotation credit.
- 2026-09-04T02:45Z: `flutter test --no-pub --reporter expanded test/widget/home_screen_test.dart` -> 31/31 passed. Covered ordered part advance, exact stored tuple, completed-routine stale callback rejection, followed-imam UI/no credit/Undo and Friday Jumuah override.
- 2026-09-04T02:46Z: combined Sprint 6A migration/repository/domain/application/Home/Settings/widget/native/Jumuah matrix -> 144/144 passed.
- 2026-09-04T02:50Z: full `flutter analyze --no-pub` completed with one `unnecessary_non_null_assertion` in a new test; the assertion was removed. Final analyzer rerun is pending after documentation.
- 2026-09-04T02:53Z: final `flutter analyze --no-pub` -> `No issues found` (13.5s).
- 2026-09-04T02:54Z: full `flutter test --no-pub --reporter compact` -> 423/423 passed.
- 2026-09-04T03:01Z: `gradlew.bat testDebugUnitTest :app:compileDebugKotlin` -> `BUILD SUCCESSFUL` in 2m31s; 190 actionable tasks (11 executed, 179 up-to-date). App unit task remains `NO-SOURCE`; Kotlin compiled successfully. Existing AGP/Kotlin deprecation warnings remain non-blocking.
- 2026-09-04T03:02Z: `flutter build apk --debug --no-pub` -> success. `build/app/outputs/flutter-apk/app-debug.apk`, 229,081,565 bytes, SHA-256 `1A1DEDF4D0D7FD5066DE3A12F2E6AF81604FFA2599CF0501CABFF5CA088FA7F5`.
- 2026-09-04 (independent re-verification before committing, run from the `D:\MurajaahWorkspace` ASCII junction): `flutter analyze --no-pub` -> `No issues found!` (146.6s). `flutter test --no-pub --reporter compact` -> `424/424` passed (one more test than the prior count; still fully green). `gradlew.bat testDebugUnitTest :app:compileDebugKotlin` from `M:\android` (unscoped) failed only on `:geolocator_android:testDebugUnitTest` (`GradleWorkerMain` class-not-found, a worker JVM spawn crash in a bundled plugin's own tests). Re-run scoped to `gradlew.bat ':app:testDebugUnitTest' ':app:compileDebugKotlin'` -> `BUILD SUCCESSFUL` in 6s, confirming the app module's Kotlin (including the modified `RotationWidget.kt`/`WidgetSnapshot.kt`) compiles and has no failing tests. Staged and committed as `260cf93` after confirming `git diff` for `lib/features/prayer_times/data/uzbekistan_prayer_locations.g.dart` and `lib/features/quran/data/providers/known_official_quran_enc_translations.g.dart` was empty (EOL-only) and excluding both files plus the two pre-existing user media items from the commit.
- 2026-09-04 (Sprint 6B, data/domain layer): `flutter test --no-pub --reporter expanded test/core/data/recitation_repository_contextual_stats_test.dart` -> 5/5 passed (exact-part stableKey correlation across sessions, stableKey isolation, Qada isolation, unused key, newest-time-wins). `flutter test --no-pub --reporter expanded test/core/domain/contextual_suggestion_service_test.dart test/core/domain/suggestion_service_test.dart` -> 17/17 passed, confirming the `SurahSuggestionService` extension is fully backward-compatible.
- 2026-09-04 (Sprint 6B, Home/widget wiring): `flutter analyze` clean after each incremental change. Two `home_screen_test.dart` tests broke when the "Recommended" `Chip` block was removed (`active surahs are displayed`, `ahead badges and due presentation follow the global target`) — fixed by asserting `RecommendationRankBadge` presence inside each `active-surah-*` tile instead. `test/widget/recommendation_rank_badge_test.dart` updated the same way after `RecommendationChip` (now unused) was deleted.
- 2026-09-04 (Sprint 6B, Isha→Witr, first attempt — reverted): embedding the transition directly in `prayerContextResolutionProvider` broke `prayer_startup_provider_test.dart`'s two minute-boundary/expiry tests plus `home_screen_test.dart`'s Fajr routine test. Reverted; see Decisions and reasons for the fix (`homePrayerContextResolutionProvider` wrapper).
- 2026-09-04 (Sprint 6B, Isha→Witr, final): `flutter test --no-pub --reporter expanded --plain-name "Witr" test/widget/home_screen_test.dart` -> 4/4 passed (completed Isha transitions exactly once and reuses the same Witr session on re-derivation; incomplete Isha does not transition; disabled/unconfigured Witr keeps a completed Isha on Isha).
- 2026-09-04 (Sprint 6B, full re-verification after `dart format lib test` normalized 6 files): `flutter analyze --no-pub` -> `No issues found!` (45.8s). `flutter test --no-pub --reporter compact` -> `439/439` passed. No Android/Kotlin file changed in this checkpoint, so no Gradle rebuild was run for it (Checkpoint B's `:app:compileDebugKotlin`/`:app:testDebugUnitTest` green run stands; nothing native to re-verify).
- 2026-09-04 (Sprint 5E2 / Checkpoint D, mid-session Kotlin fix): `gradlew.bat :app:compileDebugKotlin` -> `BUILD SUCCESSFUL` (9s) confirming the `MurajaahDreamService.kt` fix (wrapping the entire `HomeWidgetGlanceStateDefinition().getDataStore(...).data.first().preferences` chain, not just `.first()`, inside `runBlocking {}`) compiles; the original attempt only wrapping `.first()` failed with "Suspend function ... can only be called from a coroutine."
- 2026-09-04 (Sprint 5E2, `LearningNotificationChannel` interface refactor): `flutter analyze --no-pub` -> `No issues found!` (14.6s) after splitting the class into an interface plus `MethodChannelLearningNotifications`, and fixing the two now-stale constructor references in `app_providers.dart`.
- 2026-09-04: `flutter test --no-pub test/app/learning_notification_controller_test.dart test/android/widget_native_contract_test.dart test/core/widgets/prayer_widget_projection_test.dart` -> first run 20/21 passed, one failure (`DreamService is opt-in, read-only, and never bypasses the lock screen` — the doc comment's own use of the word "showWhenLocked" tripped the contract test's substring check; see Decisions and reasons). Reworded the comment; re-run -> `21/21` passed.
- 2026-09-04: created `test/widget/learning_notification_settings_card_test.dart` after extracting `LearningNotificationSettingsCard`; first run of the "turning the switch back off" case failed on a wrong assumption (`cancelCalls == 2`; actual behavior only cancels once, since enabling with a granted permission never calls `cancel()`). Fixed the expectation to `1`; re-run -> `3/3` passed.
- 2026-09-04: `flutter analyze --no-pub` -> `No issues found!` (9.9s) after the card extraction.
- 2026-09-04: full `flutter test --no-pub --reporter compact` (first pass, before `dart format`) -> `459/459` passed.
- 2026-09-04: `dart.exe format lib test` -> reformatted 6 files (`app_providers.dart`, `home_screen.dart`, and 4 of the new/changed test files); no logic changes, whitespace only.
- 2026-09-04: post-format re-verification: `flutter analyze --no-pub` -> `No issues found!` (10.0s). Full `flutter test --no-pub --reporter compact` -> `459/459` passed again. `gradlew.bat ':app:testDebugUnitTest' ':app:compileDebugKotlin'` (scoped, from `M:\android`) -> `BUILD SUCCESSFUL` in 1m; `:app:testDebugUnitTest` remains `NO-SOURCE` (same as every prior checkpoint — the app module has no JVM-level unit tests, only Kotlin compiled/asserted via the contract tests above), `:app:compileDebugKotlin` executed and succeeded, covering `PrayerWidget.kt`, `MurajaahDreamService.kt`, `LearningNotificationManager.kt`, the updated `WidgetSnapshot.kt`/`MainActivity.kt`/`AndroidManifest.xml` together. No debug APK build was run this session; the user explicitly said the APK is not required until the end of the sprint.
- 2026-09-04: staged and committed exactly the Checkpoint D file set (45 files) as `e90690b`, deliberately excluding this handoff doc (updated in a following commit) and the two pre-existing untracked user media items.

## Manual/device QA

- 2026-09-14, first real ADB session of this whole continuation. ADB is at `C:\u\adb.exe` (not the Android SDK path); the device initially did not appear because the phone was in USB-tethering mode — Windows enumerated it only as a `Net` device (`USB\VID_0E8D&PID_2005`, MediaTek RNDIS) with no ADB interface at all. After the user switched USB mode and enabled USB debugging it attached normally.
- Device under test: **Unihertz Jelly Max, Android 15 (SDK 35), arm64-v8a**, launcher **Square Home 2** (`com.ss.squarehome2`).
- The build that was on the phone before this session (installed 2026-09-07) declared only `RotationWidgetReceiver` and `LearningWidgetReceiver`. **It contained no `PrayerWidgetReceiver` and no `MurajaahDreamService` at all**, so "the prayer times widget never appeared" was an old-APK problem, not a manifest or launcher-cache problem. Recorded because the prompt explicitly warns not to blame a real manifest bug on launcher caching — here the opposite was true and it is now proven either way.
- After installing the APK built from `809c25d`: `dumpsys package` shows all three widget receivers plus `MurajaahDreamService` (with `BIND_DREAM_SERVICE`), and `dumpsys appwidget` lists the Prayer provider as `[122] ... PrayerWidgetReceiver ... widgetCategory=1 resizeMode=3`, i.e. it is registered with the system and will be offered in the widget picker.
- Confirmed working on the device: the Home "today" prayer schedule strip (Фаджр/Восход/**Зухр** current/**Аср** next/Магриб) renders with correct current/next emphasis, and the Settings "Тихое напоминание о заучивании" switch exists and is **off by default**.
- Confirmed **broken** on the device and then fixed in this session: the routine editor list did not refresh after add or delete (see the watch-stream key collision entry).
- **Re-verified on the device after the fix** (APK built from `28181c5`, installed with `adb install -r`): adding a part updates the list immediately with no restart and no error; two rapid additions in a row both land (five parts, no snackbar, nothing in logcat matching `MurajaahRoutine`/`E/flutter`/`RevisionConflict`); three deletions in a row each reflect immediately. The three test parts were then deleted so the user's own Fajr routine (Сунна + Фард) is exactly as it was before the session.
- The phone locks itself during long Gradle builds and a locked screen returns an all-black `screencap`. With the user's explicit permission this session set `settings put global stay_on_while_plugged_in 3`. **This is a temporary test setting on the user's own device — offer to restore it to `0` when device QA is finished.** The user's screen-lock PIN was supplied verbally for this session only and is deliberately not recorded here or anywhere in the repository.
- **Stage D verified on the device** (APK from `57f61e7`). A widget click can be replayed faithfully over ADB because `home_widget`'s `actionStartActivity` sets both the data URI *and* the action `es.antonborri.home_widget.action.LAUNCH`, and the plugin only returns the launch URI when that action matches: `adb shell am start -a es.antonborri.home_widget.action.LAUNCH -d 'murajaah://app/learning/112' -n dev.murajaah.murajaah/.MainActivity`. Sending only `-d` without that action does nothing, which is why a first attempt looked like a failure. Both the cold start (after `am force-stop`) and the warm start open the Learning screen **with the bottom navigation bar present and the Обучение tab highlighted**. A surah id that is not a known learning surah leaves the current selection untouched instead of crashing.
- **Stage E verified on the device (2026-09-15)**, and the check earned its keep twice. First, opening the app during the sunrise gap showed the batch-driven list rendering **no recommendations at all**, because with no resolved prayer context there is no batch — a regression no test covered. Fixed (`0529958`) by falling back to the computed ranking when there is no batch, plus a widget test that pumps a `betweenPrayers` resolution. Second, the main scenario now passes on the phone: with a manually chosen Nafl context, marking the rank-1 surah (Al-Falaq) left it **in place at position 1 with a green badge and a check**, the due count went 9 → 8, and rank 2 was untouched — previously it would have vanished. The same pass also confirmed Stage C end to end: choosing a prayer showed the "Вернуться к авто" chip, and tapping it restored automatic resolution and removed the chip.
- Device-QA hygiene: the verification created one real recitation event (Al-Falaq · Nafl · 10:06). The in-app Undo tap missed, so it was removed afterwards through History → delete; the user's genuine readings that morning (Fajr 04:52–04:59, Witr 04:41) were left untouched. With the user's permission this session also set `accelerometer_rotation 0` / `user_rotation 0` to keep the screen in portrait for reproducible coordinates — **restore both, and `stay_on_while_plugged_in`, when device QA is finished.**
- **Stage F verified on the device (2026-09-15, APK from `2655f2d`).** Real device DB re-read afterwards: `user_version = 6`, so the v5→v6 migration ran on the user's actual data, not just on fixtures. Learning card → «Проверить по памяти» → the range sheet opens pre-filled with the current stage's range (8–8 for Al-Fajr «Новый аят 8») and was widened to 6–8. The hidden step shows only «Аят 6», a fixed crossed-eye icon and the hint — **no text, no length hint, and no grade buttons exist at all**; only «Показать аят» and «Дальше». After the reveal the correct Quran coordinates appear (89:6 `Alam tara kayfa faAAala rabbuka biAAadin`) and «Показать аят» is replaced by the three grades. «С ошибкой» advanced to ayah 7 re-hidden with the counter at «1 из 3»; «Дальше» on ayah 7 advanced without storing anything; ayah 8 revealed 89:8 correctly. The summary read «Вспомнил: 1 · С ошибкой: 1 · Не вспомнил: 0» — the skipped ayah correctly contributed nothing. Audio was absent throughout, which is correct: the checked range 6–8 does not match the learning stage 8–8.
- **Stage F, the things that must NOT have happened, checked explicitly on the device**: the learning card still reads «Новый аят 8», so the check did not advance learning progress; the History screen after the check still shows only the user's genuine morning readings (Fajr 04:52/04:59, Witr 04:41) and **no event from the 11:34–11:35 check**, so a recall attempt really does not create a recitation-in-prayer event; Home still shows «К повторению: 9» with the same ranks 1–3.
- **Stage F, the mastered-surah entry point** (`/surah/surah-113`, Al-Falaq): «Проверить по памяти» is present, the range sheet defaults to the whole surah (1–5), a narrowed 1–1 check revealed 113:1 correctly (translation not cached for that surah yet, handled by the existing fallback text), and after a clean «Вспомнил» the detail screen shows «1 вспомнил · 0 повторить» **without** the review-priority note — correct, because the last check was clean. Note that this screen is reached from `/surah/:id`; neither the Суры list row nor its overflow menu navigates there, and Home's tune icon opens the prayer-context picker instead, so it was reached by deep link. **Whether that screen is discoverable at all in normal use is a separate open question, not a Stage F defect.**
- **Device-QA data note (Stage F): three real recall attempts remain in the user's data** — Al-Fajr ayah 6 «С ошибкой» and ayah 8 «Вспомнил», and Al-Falaq ayah 1 «Вспомнил». Unlike the Stage E recitation event, these were **not** cleaned up afterwards, and deliberately so: the recall journal is append-only by design and exposes no delete path, so removing them would have meant going behind the app's own guarantee. The Al-Fajr mistake leaves that surah flagged as "last check was imperfect", but Al-Fajr is still being learned and is not in the rotation, so it does not currently affect any ranking; Al-Falaq's clean check leaves no flag. The user was told.
- **Owner acceptance of the Stage I build (`e458f53`, sha256 `4554707c…`), 2026-09-15.** This is the first real user acceptance in the project, and it found two defects that every automated check had passed. Results as reported: (1) part editor — **не сохраняется**; (2) sticky Witr/Nafl context — works; (3) the eight-item block — works, **"но когда уже по 2× количество уменьшается"**; (4) widgets — opened; (5) recall mode — works. The owner also asked for a second, horizontal Prayer Times widget variant and explicitly said to defer it — recorded as backlog item 27, not built.
- **Acceptance defect 1 — reorder silently discarded. Fixed.** `ReorderableListView.onReorderItem` (which replaced the deprecated `onReorder` after Flutter v3.41.0-0.0.pre) delivers `newIndex` **already adjusted** for the removal at `oldIndex`, and only calls back when the index actually changed — `_handleReorderItem` in `widgets/reorderable_list.dart` does `if (newIndex > oldIndex) newIndex -= 1;` itself. `PrayerRoutineSettingsCard._reorder` repeated that adjustment. Consequence: dragging a part **down by one** collapsed onto `insertionIndex == oldIndex` and hit an early `return` — nothing written, no error, no diagnostic. Dragging down further landed one slot short; dragging **up** was unaffected, which is why it looked intermittent rather than broken. Fix: drop the manual adjustment. 3 new tests drive the callback the way Flutter does rather than synthesizing a drag. **The existing reorder test was updated, not deleted:** it passed `(0, 2)` on a two-item list, which is the deprecated pre-removal convention and was exactly what the card was compensating for.
- **Acceptance defect 2 — the block shrank once repeats appeared. Fixed.** The batch pool came from `rankedCandidateIds`, which drops every candidate with `remaining <= 0`. That is correct for `suggest()` — the product ranking means "what is due" — but wrong for a batch pool: as the owner recited, surahs reached the rotation target and left the pool, so a newly planned batch could no longer find eight candidates. By the time entries are marked `2×` the user has recited most of the rotation, which is precisely when the pool is smallest — hence "при 2× количество уменьшается". Fix: `rankedCandidateIds` gained an opt-in `includeSatisfied`, used **only** by `rankedCandidateIdsWith` (the batch pool). Satisfied surahs sort after every still-due one, so nothing visible reorders; they only become available once the due ones run out. `suggest()` is untouched and a test pins that it still returns due-only.
- **Method note from this acceptance:** neither defect was reachable by the automated suite as written, and one of them could not be reproduced by ADB either — a synthetic `input draganddrop` does not trigger `ReorderableListView`'s long-press-then-drag gesture, so the device reproduction attempt scrolled the page instead. The defect was found by reading the Flutter SDK source for the callback contract. When a gesture cannot be synthesized, read the framework's own dispatch code rather than concluding the feature works.
- **Stage I (2026-09-15, new prompt `SURAHCYCLE_NEXT_HANDOFF_CODEX_CLAUDE.md` section 5). Baseline re-verified first**, as section 3 requires: HEAD `c5df1f655c5241dea1eb03f5a902ecf7cbdd88bc` (`c5df1f6`), `6658882` present, `git diff --check` clean, tree clean except the owner's untracked QA media, `flutter analyze --no-pub` clean, `flutter test --no-pub` **703/703** — every claimed figure matched.
- **Stage I 5.3 — my earlier "surah details are unreachable" claim was WRONG, and the prompt was right to demand a reproduction.** Tapping the row title in Суры → Выученные opens the detail screen and always did; `_MasteredTile.onTap` routes to it. What I had actually hit in the Stage F session was the overflow menu at the right edge of the row. **The lesson: "I could not find it" is not "it does not exist", and a mis-tap reported as a defect costs the next session real time.** There *was* a genuine defect underneath, but a different one: the route was declared with `parentNavigatorKey: _rootNavigatorKey`, so the screen opened **above** the shell with no bottom navigation — the same defect Stage D fixed for `/learning/:id`. Fixed by nesting it in the Surahs branch as `/surahs/detail/:id`; `/surah/:id` stays as a redirect that carries the `part` query parameter, because a Rotation widget already on the launcher holds a `PendingIntent` with the old path. Added `/surah` → `/surahs` too: `/surah/` normalizes to `/surah`, matches nothing and would land on the router error page. 8 new tests in `test/app/surah_detail_route_test.dart`; verified on the device — the detail screen now shows with the bottom navigation and «Суры» highlighted, and Back returns to the list.
- **Stage I 5.2 — the real widget tap, and a correction to my own method.** Device: `JELLYMAX00003540` (Unihertz Jelly Max), Android 15 / SDK 35, launcher `com.ss.squarehome2`. Placed instances from `dumpsys appwidget`: Rotation id=71, Learning id=72, Prayer id=75, all hosted by Square Home 2. **First result looked like a serious defect: taps on our Prayer and Learning widgets did nothing.** `logcat` showed `E RemoteViews: Cannot send pending intent: android.content.IntentSender$SendIntentException` at `ContextImpl.startIntentSender`. A control test discriminated it — tapping the Google Tasks widget on the same launcher started its trampoline activity normally, so the launcher was fine and the fault looked like ours.
- **The actual cause was my test procedure: I ran `am force-stop` before every tap.** A force-stopped package's `PendingIntent` cannot start an activity until the user launches the app again — the OS delivery boundary this journal already warns about, met from the other direction. Repeating the tap **without** force-stopping works: `ActivityTaskManager: START u0 {act=es.antonborri.home_widget.action.LAUNCH dat=murajaah://app/... cmp=dev.murajaah.murajaah/.MainActivity} with LAUNCH_SINGLE_TOP ... (BAL_ALLOW_VISIBLE_WINDOW)`, and the Learning screen opens **inside the shell** with the bottom navigation and «Обучение» highlighted. **So the widget tap is verified working, and the `SendIntentException` after a force-stop is expected OS behaviour, not a defect.** Reinstalling the APK does not cause it; refreshing the widget does not clear it; only launching the app does. A future session seeing that exception should check whether it force-stopped first before reporting a bug.
- **Prompt section 15 (Prayer Times widget) — VERIFIED on the device, 2026-09-15.** The widget was already placed on the Square Home 2 launcher (`dumpsys appwidget` shows widget id=75 bound to `PrayerWidgetReceiver` with non-null RemoteViews, alongside the Rotation and Learning instances). It renders "Время намаза" with exactly six entries — Фаджр 04:28, **Зухр 12:18 highlighted as current**, **Аср 16:42 bold as next**, Магриб 18:32, Иша 20:06, and Восход 06:02 in smaller type as a boundary that is neither current nor next. That is the projection contract satisfied on a real screen. The merged manifest (`M:\build\app\intermediates\merged_manifests\debug\processDebugManifest\AndroidManifest.xml`) confirms all three receivers carry their `android.appwidget.provider` metadata and that the app label is now `SalahCycle`. **The earlier "user never sees the prayer widget" report was the old-APK problem already diagnosed; there is no manifest or launcher-cache defect.**
- **Prompt section 15, lifecycle:** after `am force-stop` (verified zero app processes) all three widgets still render unchanged, because a widget is a RemoteViews snapshot the launcher owns — correct for a read-only projection surface. **Not re-confirmed this session: a tap on the physically placed widget.** One attempt missed the partially clipped "Открыть приложение" row and left focus on the launcher. Deep links themselves were verified cold for both schemes by `am start` with the plugin's `es.antonborri.home_widget.action.LAUNCH` action, which is the same path a widget tap uses, and on-widget taps were confirmed in the earlier 2026-09-14 session.
- **Prompt section 14 (DreamService) — VERIFIED on the device, 2026-09-15.** It is enumerated in the system resolver table (`dumpsys package` → `android.service.dreams.DreamService: dev.murajaah.murajaah/.widget.MurajaahDreamService ... permission android.permission.BIND_DREAM_SERVICE`). Note for future sessions: `cmd package query-services -a android.service.dreams.DreamService` does **not** list it — that command filtered it out and briefly looked like a defect; the resolver table in `dumpsys package` is the authoritative check. In Settings → Заставка it appears as **SalahCycle**, selecting it set `screensaver_components=dev.murajaah.murajaah/dev.murajaah.murajaah.widget.MurajaahDreamService`, and the preview renders the current learning ayah (89:8 Arabic plus "89. Al-Fajr") on a dark background, read-only, with no controls.
- **Prompt section 14, the negative claims proved rather than asserted.** `dumpsys dreams` during the run reported `canDoze=false, isDozing=false`. Locking the device ended the dream: `mCurrentDream=null`, `mShowingDream=false`, `isKeyguardShowing=true` — **the screensaver does not cover or bypass the lock screen.** The merged manifest carries no `SYSTEM_ALERT_WINDOW`, no Accessibility service, no Device Admin, and the posted notification has `fullscreenIntent=null`.
- **Prompt section 14 (quiet notification) — VERIFIED, with one decisive device-specific limitation.** After opting in, `POST_NOTIFICATIONS` was already `granted=true` (USER_SET) so no dialog appeared, and the notification posted as `id=7001 channel=learning_quiet importance=2 vibrate=null sound=null defaults=0 flags=ONLY_ALERT_ONCE category=reminder groupKey=silent vis=PRIVATE`, title `89. Al-Fajr`, text `Новый аят 8 · Аят 8`. **It carries the coordinates and stage, not the ayah text itself** — worth stating precisely, because the brief's wording ("может показывать аят на lock screen") could be read as promising the Arabic.
- **The limitation: on this device the notification cannot appear on the lock screen at all, because the owner has `lock_screen_show_notifications = 0`** — lock-screen notifications are switched off system-wide. `lock_screen_allow_private_notifications` is `1`, so if the owner ever enables lock-screen notifications the title and text would show; with `vis=PRIVATE` and `publicNotification=None`, a device that hides sensitive content would show the generic placeholder instead. **This setting was deliberately NOT changed**: it is a privacy choice the owner made, and the session was authorized to restore `stay_on_while_plugged_in`, not to flip it. The lock screen was captured and confirmed to show no notifications from any app.
- **OEM restrictions checked:** `am get-standby-bucket` returns `10` (ACTIVE), the app is not doze-whitelisted (normal, and not needed — nothing schedules background wakeups), and `appops RUN_ANY_IN_BACKGROUND` is "No operations / Default mode: allow". The Unihertz/AGUI skin ships `com.agui.appblock`, `com.agui.frozen` and `com.agui.systemmanager`, which are the usual source of OEM freezing on this device family, but **no restriction is currently applied to this app at the AOSP level.**
- **Device settings restored 2026-09-15 at the end of QA:** `stay_on_while_plugged_in` back to `0`; `screensaver_enabled` back to `0` and `screensaver_components` back to `com.android.deskclock/com.android.deskclock.Screensaver` (both recorded before being changed); the in-app quiet-notification toggle switched back off and the posted notification confirmed cancelled (zero active `NotificationRecord`). **`accelerometer_rotation` was left at `1` and deliberately not touched — the journal records only that a prior session set it to `0`, never what it was before, so there is no original value to restore to.** `user_rotation` likewise untouched.
- ~~Still not physically verified: widget placement and rendering from the picker, cold/background/swiped-away/killed behaviour of the widgets themselves, the DreamService as an actually selected screen saver, and the notification after opt-in.~~ **All of these were run over ADB on 2026-09-15 — see the section-14/15 entries above.** The one item still open is a tap on the physically placed widget, which was attempted and missed rather than failed.

- No Android device or ADB session has been used in this continuation session.
- User photo `photo_2026-09-03_10-59-07.jpg` was visually reviewed: it shows the foreground Home recommendations/context screen, not the launcher widget or the reported click/rollback sequence.
- The specifically requested `video_2026-09-03_10-58-46.mp4` and `video_2026-09-03_10-59-16.mp4` were not found. Eight older MP4 files remain available but no video decoder is installed on PATH in this session.
- The required foreground/background/Back/swipe-away/double-tap/immediate-open/offline/stale-context matrix remains pending. Do not claim physical verification from unit tests or APK compilation.

## Sources and licensing

- Arabic text and metadata: pinned Tanzil assets with integrity validation and attribution.
- Latin transliteration: exact Tanzil corpus; Cyrillic remains unavailable pending full-corpus provenance and redistribution evidence.
- RU/UZ translations: audited QuranEnc versions with pinned corpus hashes and unchanged provider text.
- Prayer schedules: Namoz-vaqti.uz published data; adhan_dart is a separately labelled local fallback.
- Quran audio: documented MP3Quran API v3 and unchanged remote recordings; Hafs-only default catalog, timing only when validated.
- Detailed evidence remains in `docs/QURAN_DATA_SOURCES.md`, `docs/QURAN_TRANSLATION_LICENSE_AUDIT.md`, `docs/PRAYER_TIME_SOURCE_AUDIT.md`, and `docs/QURAN_AUDIO_SOURCE_AUDIT.md`.

## Uncommitted changes

- 2026-09-15: Stage G steps 1–2 are about to be committed (the ADR, `ACCOUNT_SYNC_ARCHITECTURE.md`, the missing `DATABASE_MIGRATION_V6.md`, the `SERVER_PLAN.md` pointer, `lib/core/sync/`, `test/core/sync/` and this handoff update).
- 2026-09-15: Stage F was committed as `2655f2d` (domain, schema v6 + generated fixtures, repository, controller, screen, range sheet, both entry points, l10n for en/ru/uz, the review-priority tie-break, and all new tests). Only this handoff update, recording the device verification, remains to be committed.
- Pre-existing user-owned files, excluded from commits: `photo_2026-09-03_10-59-07.jpg` and the videos under `Скринсейверы до v6/`. Never add, move, rename or delete them.
- 2026-09-17: `brand/` is new and untracked — `surahcycle_logo.svg`, `surahcycle_512.png`, `surahcycle_1024.png` — plus this handoff update. No `lib/`, `android/`, `test/` or `assets/` file was touched. `.codex/` is also untracked and is not mine.

## Decision log

- 2026-09-17: Registered the Google and Yandex OAuth applications for end-user sign-in, but left both Appwrite providers `disabled`, because Client ID and Client Secret are required fields the owner fills in himself. Chose not to press Update with empty required fields even though the button is enabled: the two possible outcomes are a validation error or an enabled-but-broken provider, and neither is worth guessing at on a live project. Read both redirect URIs out of the Console's own fields rather than deriving them from the documented pattern, because the regional `fra.` host makes a derived guess a plausible `redirect_uri_mismatch`.
- 2026-09-17: Picked **Web application** for the Google client although the target is Android, since the redirect flow terminates on Appwrite's server; an Android client is only needed if native sign-in is enabled later. Left the Google app in **Testing** and uploaded no consent-screen logo — publishing is public-facing and a logo triggers brand verification, so both are the owner's calls, not an agent's.
- 2026-09-17: Granted Yandex exactly `login:email`, `login:info`, `login:avatar` — the three Appwrite's Yandex adapter requests — and refused Gosuslugi identity verification outright. The "Сервис не верифицирован" note is the accepted cost; an agent must never drive a government identity flow on the owner's behalf.
- 2026-09-17: Discovered the app has no logo at all (stock Flutter placeholder) when Yandex demanded a mandatory icon, so drew one rather than shipping someone else's mark to a consent screen. Kept it in a new `brand/` folder and did **not** replace the launcher icons: only a logo was asked for, and swapping every `mipmap-*` density plus an adaptive icon is its own checkpoint.
- 2026-09-03: Adopted one shared handoff file for Codex and Claude; no parallel divergent journal.
- 2026-09-03: Reconciled baseline `a640f50`; recorded user-owned untracked QA media instead of cleaning or committing it.
- 2026-09-03: Confirmed checkpoint order: widget reliability precedes schema v5 prayer routines and all later feature work.
- 2026-09-03: Committed shared continuity protocol as `4528fce`; started Sprint 5E1 with tests-first diagnosis.
- 2026-09-03: Chose existing DB journal sequence as the monotonic widget revision; no schema migration or second source of truth is needed for Sprint 5E1.
- 2026-09-03: Schema 4 explicitly separates rotation debt, recommendation, and current-prayer marking. Learning root surfaces use `/learning`; selected content retains `/learning/:surahId`. Rotation footer remains Home.
- 2026-09-03: Android force-stop remains an OS delivery boundary; no broadcast delivery after true force-stop is promised or claimed.
- 2026-09-03: Committed verified Sprint 5E1 as `6ad2772`; advanced to Sprint 6A without changing the established checkpoint order.
- 2026-09-03: A chained v1 to v5 upgrade must create the empty `prayer_session_parts` table before copying rows into the current `recitation_events` shape, because SQLite resolves its optional foreign key during the earlier v1 to v2 step. The final v5 step now uses table introspection so this prerequisite remains idempotent; legacy event part/slot links stay null.
- 2026-09-04: Exact-slot validation was placed in `RecitationRepository`, not only UI/action decoding, so stale callbacks and cached widget payloads cannot bypass the current ordered part or next slot.
- 2026-09-04: A completed routine disables Home/widget actions and remains the current immutable session; it never falls back to slotless registration. Followed-imam completion explicitly invalidates the foreground routine provider so its UI and Undo state refresh immediately.
- 2026-09-04: Added `docs/PRAYER_ROUTINES.md` and `docs/DATABASE_MIGRATION_V5.md`; updated product, architecture, prayer-time and Android-widget contracts to schema/action versions 5/2.
- 2026-09-04 (Claude Code continuation): Independently re-verified Sprint 6A (analyzer, full test suite, scoped Gradle build, direct code read of the followed-imam completion path) rather than trusting the prior agent's report alone, then staged exactly the documented file set and committed `260cf93`. Discovered and documented the portable toolchain (`D:\MurajaahWorkspace` junction, `M:` subst drive, MinGit/Flutter/Gradle under `.tools/`), the Cyrillic-path Dart-analyzer crash and its ASCII-junction workaround, and the unrelated `geolocator_android` Gradle worker flakiness — recorded under Environment and tooling so no future session has to rediscover them.
- 2026-09-04: Implemented Sprint 6B (contextual prayer recommendations) as a minimal, backward-compatible extension of `SurahSuggestionService` rather than a parallel service, so all pre-existing suggestion/operational-order tests kept passing unmodified. Removed Home's separate "Recommended" chip block in favor of an inline per-tile rank badge, sharing one `contextualRecommendationInputsProvider` between Home and the widget projection factory so both always rank identically.
- 2026-09-04: First attempt at the Isha→Witr transition added `ref.watch` calls directly inside the widely-depended-on `prayerContextResolutionProvider` and broke three existing tests that construct minimal bare `ProviderContainer`s. Reverted that provider to its exact original form and instead applied a pure transformation function from two new, narrowly-scoped wrapper points (`homePrayerContextResolutionProvider` for Home, inline in `widgetSyncLifecycleProvider` for the widget) — both conditionally watch the extra routine/template providers only when the resolved context is actually Isha, minimizing new side effects for every other prayer type.
- 2026-09-04: A PowerShell `Get-Content -Raw | ... | Set-Content -Encoding utf8` one-liner (used to bulk-rename `clock.now()` to `clock.nowUtc()` in a test file) silently corrupted the file's two non-ASCII middle-dot strings and added a UTF-8 BOM; caught only by a failing test, not by `flutter analyze`. Fixed and documented under Environment and tooling: use the Edit tool for all source-file text changes, never PowerShell `Get-Content`/`Set-Content`.
- 2026-09-04 (Claude Code continuation, Checkpoint D / Sprint 5E2): implemented the Home prayer-schedule strip, third Prayer Times widget, opt-in Learning notification and opt-in `MurajaahDreamService` screensaver per continuation-prompt section 9. Chose to extract the Settings learning-notification card and refactor `LearningNotificationChannel` into an interface specifically to make the new opt-in/permission-denied/opt-out logic unit- and widget-testable, matching the existing `PrayerRoutineSettingsCard`/`PrayerTimeSettingsCard`/bridge-interface patterns rather than inventing a new one. Documented, rather than worked around, that no true lock-screen widget is possible on modern Android. Committed as `e90690b` after two full green passes of the entire Flutter test suite (459/459, before and after `dart format`) and a scoped Gradle Kotlin build; no APK build this session per explicit user instruction to continue without one until the end of the sprint.
- 2026-09-04 (Claude Code continuation, Checkpoint E): ran the Cyrillic transliteration source audit as a background multi-agent Workflow rather than a manual search, specifically to get the adversarial double-checking the project's integrity checklist calls for. It paid off immediately: caught a search-stage agent's fabricated pair of edition names for `fawazahmed0/quran-api`, and overturned `MakhmudovBekhruz/quran_db`'s README "Cyrillic" claim by reading the actual bundled database rather than trusting the description. Found exactly one candidate with genuinely complete, real Cyrillic transliteration text (`maqsats/Quran-Transliteration-`) but with zero license and zero stated provenance, so it cannot be connected. Documented a plausible religious-policy reason (a cited fatwa against Cyrillic/Latin Quran transcription) no official Central Asian or Russian religious authority publishes its own transliteration dataset — recorded because it changes the shape of "waiting for a source to appear" into "may never appear by design," which is worth knowing for how much future effort to spend searching. Made no code changes; this was the last checkpoint in the session's continuation prompt.
- 2026-09-15 (Stage F): spent the single reserved schema migration on `recall_attempts` (v5 -> v6) rather than storing recall attempts as JSON in AppSettings like the recommendation batch. The distinction is deliberate and is the rule to apply to any future storage decision here: a recommendation batch is a replaceable presentation decision whose loss costs one rebuilt list, so it does not deserve a migration; a recall attempt is user history — an auditable record of what they could remember on a given day — and history belongs in a real table with foreign keys, CHECK constraints and no update or delete path. The migration backfills nothing, because there is no honest value to backfill.
- 2026-09-15 (Stage F): made recall affect review priority as the weakest tie-break tier only, keyed on the latest attempt rather than an accumulated mistake count. A running count would let one bad session hold a surah at the front indefinitely and would quietly become the hidden score the prompt forbids; "your last check on this surah did not go cleanly" is a single fact the user can verify, undo with one clean check, and see stated in words on screen. The tier was added below both recency tiers specifically so the Stage E batch stays stable: it can reorder candidates that were already equal, and nothing else.
- 2026-09-15 (Stage F): offered audio after the reveal only when the checked range exactly matches the learning stage. `LearningAudioControls` plays the stage range, so wiring it to a narrowed recall range would play the wrong ayahs while looking correct. Silently playing the wrong audio is worse than offering none, so a narrowed check simply has no audio. A recall-specific audio range is a reasonable future improvement; it was not invented here.
- 2026-09-15 (Stage G): chose Appwrite on evidence rather than on the brief's stated preference, and the evidence turned on one fact that is easy to get wrong — Yandex ID is not an OpenID Connect provider. Both obvious alternatives reach non-native providers only through OIDC discovery, so "add Yandex to Supabase/Firebase" quietly means "run and secure your own bridge server". Recording the negative result matters more than the choice: if someone later revisits this because Appwrite is less familiar than Firebase, the question to re-check is not "which BaaS is better" but "does Yandex publish a discovery document yet".
- 2026-09-15 (Stage G): kept the sync library completely unreferenced by the app. The temptation with ports-and-adapters work is to wire a provider "so it is ready", but a `SyncGateway` with no backend can only be a stub, and a stub that returns success is a lie the UI will eventually render as a green checkmark. Absent is safer than fake, and the contract tests are what make the absence productive rather than idle.
- 2026-09-15 (Stage G): did not add a durable outbox table despite the outbox being the stage's headline deliverable. The one reserved migration went to `recall_attempts` in v6, and a table that nothing writes to, draining to a server that does not exist, is pure migration risk. The contract suite is the durable implementation's specification; it can be written the day there is something to drain into.
- 2026-09-15 (Stage G): separated authentication from sync activation after writing the first-sign-in section and noticing the design had no place to refuse. Signing in now only establishes identity; a local backup, a merge preview and one explicit choice stand between an account and existing local data, and the preview carries a token so a stale dialog cannot authorize a merge it never described. The third option — keep this device local-only — is offered deliberately: a user who signs in to try the feature must be able to decline the merge without losing either side.
- 2026-09-15 (Stage H): renamed only what the user reads and kept every technical identifier, rather than doing the find-and-replace the task superficially looks like. The 133 files that mention the old name include the applicationId, the Kotlin package, the method-channel name, the widget receiver class names and the Drift database filenames; replacing those would have given the owner a fresh install with an empty history on the next update. The rule applied: a name the operating system or SQLite uses to find something is an address, not a brand, and addresses only change when somebody is ready to move.
- 2026-09-15 (Stage H): reported the `Salah Circle` phonetic near-miss instead of either blocking on it or quietly ignoring it. It is not the same class of finding that forced Murajaah out — that was a near-identical name — so per the brief the reversible rename proceeded. But the brief also explicitly lists a sound/transliteration check, and "SalahCycle"/"Salah Circle" differ by one vowel in the same store category, which is thin for a Russian- and Uzbek-speaking audience. That is a branding call the owner has to make with full information, and it is cheap to change now and expensive after publication.
- 2026-09-15 (Stage H): widened the deep-link parser before changing what emits links. A placed launcher widget holds a PendingIntent built with the old URI and keeps it across an app update, so flipping the scheme in one step would break exactly the users who already trusted the widget enough to place it. Accept-both first, emit-new later, drop-old much later; only the first step is taken, and a test pins that the builders still emit the legacy scheme so step 2 is a deliberate change rather than an accident.
- 2026-09-15 (Stage I): reproduced the "surah details are unreachable" report instead of acting on it, and it turned out to be my own mis-tap from the Stage F session — I had hit the overflow menu at the right edge of the row rather than the row itself. The prompt explicitly demanded reproduction before a fix, and that instruction paid for itself: acting on the original report would have meant adding a duplicate entry point to a screen that already had a working one. The rule worth keeping: a navigation report from a session that could not find something is evidence about that session, not about the code, until it is reproduced.
- 2026-09-15 (Stage I): the real defect hiding under that false report was the one Stage D had already fixed elsewhere — a detail route declared on the root navigator, opening above the shell without the bottom navigation. Two instances of the same mistake in one codebase means the shape is easy to reach for, so the fix nests the route in its own branch rather than patching the symptom, and `/surah/:id` survives as a redirect because launcher widgets hold the old path in a PendingIntent that outlives an app update.
- 2026-09-15 (Stage I): nearly reported the widget tap as broken. `E RemoteViews: Cannot send pending intent: SendIntentException` looked damning, and a control test on another app's widget on the same launcher ruled out the launcher. The cause was my own procedure: I ran `am force-stop` before every tap, and a force-stopped package's PendingIntent cannot start an activity until the app is launched again. Without the force-stop the tap works and lands inside the shell. The project already documents force-stop as an OS delivery boundary for broadcasts; this is the same boundary met from the PendingIntent side, and it is now written down so the next session does not re-diagnose it as a bug.
- 2026-09-15 (acceptance): both defects the owner found had passed every automated check, and the reason is the same in both cases — the tests encoded the implementation's own assumption rather than the contract it depends on. The reorder test called the callback with the deprecated pre-removal index, so it agreed with the card's double adjustment; the batch tests supplied a pool directly, so they never exercised the due-only filter that produced it. A test that mirrors the code cannot catch the code being wrong about something outside itself. Both replacement tests now assert against the external contract: Flutter's documented callback semantics, and the pool actually returned by the ranking service.
- 2026-09-15 (acceptance): kept `suggest()` due-only and widened only the batch pool, instead of the simpler change of dropping the `remaining <= 0` filter everywhere. "What is due" and "what may appear in a batch" are different questions that happened to share one function; collapsing them would have made the app start recommending surahs that are not due, which is a rotation-algorithm change smuggled in as a bug fix.
- 2026-09-15 (acceptance): could not reproduce the reorder defect over ADB — `input draganddrop` does not trigger ReorderableListView's long-press-then-drag, so the attempt scrolled the page. Rather than report the feature as working, read the Flutter SDK's `_handleReorderItem` and found the contract mismatch there. A gesture that cannot be synthesized is a limit of the harness, not evidence about the app.
- 2026-09-16 (Stage J §6.4): made the durable outbox pass the *existing* contract suite rather than writing tests for it. This was the whole point of Stage G leaving `runSyncOutboxContract` behind, and it is worth naming because the temptation ran the other way: several contract tests are awkward against SQL (coalescing, the id-collision refusal, quarantine keeping the attempt count), and each one was a small invitation to "adapt" the contract. Adapting it would have moved the guarantees to wherever they were cheapest to keep. The only test that is genuinely new is the one the in-memory implementation *cannot* satisfy — writing to a file, closing the database, reopening it and finding the change still queued.
- 2026-09-16 (Stage J §6.4): scoped every durable sync row by owner instead of storing one queue per device. Sign out of A, sign in as B is a two-tap sequence on a shared or re-sold phone, and a device-global queue would push A's recitation history under B's account — not a data-loss bug but a privacy one, and silent. Scoping makes it structurally impossible rather than dependent on some sign-out path remembering to call `clear()`, and `clear()` is deliberately *not* what sign-out calls: unsent changes have to resume when the same account comes back.
- 2026-09-16 (Stage J §6.4): put two invariants in the schema rather than only in the code that maintains them — a partial unique index for one pending entry per entity, and `CHECK (is_active = 0 OR choice = 'merge')`. Both are already enforced by `DriftSyncOutbox` and `DriftSyncStore`, so the constraints are redundant today. They are there for the version where somebody adds a second write path without reading either class; a database that refuses is cheaper than a support case about history appearing under the wrong account.
- 2026-09-16 (Stage J §6.4): stored enqueue timestamps as integer microseconds, not Drift `DateTime` columns, after noticing Drift's default is whole seconds. Two changes queued in the same second would have had an undefined drain order, and ordering is what makes a delete that follows an edit actually win. The envelope itself keeps full ISO precision inside its JSON, so nothing else lost resolution.
- 2026-09-16 (Stage J §6.4): widened `SyncAwareLocalStore` rather than implementing it as written. Its signature took only the envelope, which reads as "apply the payload" — meaning the sync store would rebuild domain rows from transport payload, competing with the repositories that already own those tables. Taking the caller's own write as a callback keeps one writer per table and still gives the guarantee the port exists for. Changing a documented port needs a reason; this is the reason, and it is in the architecture doc too.
- 2026-09-16 (Stage J §6.0): did not treat "the `claude` CLI is missing" as a blocker to report back. The prompt's command exists to register an HTTP MCP server at project scope, and a project-scoped `.mcp.json` is exactly the artifact it writes; the file holds a public URL and no secret. What was *not* substituted is the part that genuinely needs the owner — the OAuth consent. That stays a single explicit action in his own browser, with the scope Appwrite actually requests visible to him before he approves it.
- 2026-09-16: left a test part in the owner's Зухр routine rather than deleting the row directly when the phone turned out to be locked. Reaching into `prayer_routine_part_templates` would have worked — delete one row, bump the template revision — but it means writing to a user's live data behind the app that owns it, with no revision check and no journal entry, to tidy up my own mess. It is also, exactly, the delete path the owner has to re-test. Asking costs him one tap he was going to make anyway.
