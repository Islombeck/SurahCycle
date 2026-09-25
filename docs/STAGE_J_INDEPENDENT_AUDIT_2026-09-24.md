# Independent Stage J audit — 2026-09-24

## Verified baseline

HEAD: `7903099b22fa1b5fe227b6f862a89f51bab0415f`. All sixteen reported commits are present. Initial tracked tree and git diff --check were clean; owner media and .codex/ remain untouched.
APK: 230272532 bytes, 2026-09-24 14:42:47 local, SHA256 `DC564698F120D928C4B9B1CA0F11A552418700616AA3B91D6828D2DED88794BF`; matches the report.
Read the linked conversation's full final report, AGENTS.md, CLAUDE.md, current-state handoff sections, ADR-0002 and relevant source/tests. Historical AI_HANDOFF.md sections still require a complete read before source changes.

## Findings supported by source inspection

1. **P1: Persistent incoming cursor stalls.** `lib/core/data/sync/drift_sync_store.dart:182` advances it only when deferred records are empty. The cycle carries failures across pages in memory, then retries the suffix next cycle. Later valid records can apply, but fetching/reapplying repeats indefinitely. Durable owner-scoped inbox storage must commit atomically with cursor progress, survive restart, retry prerequisites and expose unresolved records without dropping them.
2. **P1: Equivalent schemes lose the incoming identifier.** `rotation_scheme_sync_applier.dart:146` accepts the same split without storing the incoming ID. `recitation_sync_applier.dart:141` requires that exact ID later; coverage also requires incoming part IDs. Persist mappings for both scheme and parts. The existing same-split test does not follow the absorption with a recitation referring to the absorbed ID.
3. **P1: An OLD offline withdrawal can defeat a NEWER restore.** The report reverses this direction. Recitations bypass the router's version comparison; the applier sets deletion without comparing a restore timestamp, and line 239 clears deletion without saving a state version. Test both delivery orders, repeated envelopes, restart and tombstones arriving before their original records. Store state versions with deterministic ties across all local and incoming paths.

Durable inbox, alias and state-version information is justified. Consolidating this into migration v11 is reasonable, but the audit does not prove exactly one column alone solves convergence or that each fix inherently needs a new table. Specify precision, tie handling, owner scope and migration of unknown historical times first.

## Report corrections

The supplied acceptance table supports **4 complete (1,2,4,7), 1 partial (6), 3 incomplete (3,5,8)**, not five complete. These are the report's physical-device claims, not newly repeated checks.

85 sessions were reported on Honor after merge; 84 on the main phone. These are different devices, not a measured before/after pair. No matching .sqlite/.db snapshots were found in the searched workspace. Compare timestamped snapshot ID sets, then differing session parts and linked recitations. Neither loss nor the claim that nothing was lost is established by the counts. Today's live state cannot resolve historical counts by itself.

## Fresh tests and limits

59 tests passed, exit 0, across:
- test/core/data/sync/sync_cycle_runner_test.dart
- test/core/data/sync/rotation_scheme_sync_applier_test.dart
- test/core/data/sync/recitation_sync_applier_test.dart
- test/app/two_device_sync_test.dart

Synthetic databases only. Drift printed multiple-database warnings in the multi-device tests. Full 1296-test run, analyzer, Gradle, installations and real-data suites were not repeated. No source code, personal databases, backups, phones or cloud were changed. Standard command startup and apply_patch failed with sandbox helper_unknown_error; approved elevated reads/tests worked. Flutter needed process-local safe.directory for its SDK, without global Git changes.

## Concrete emulator acceptance sequence

1. Prepare isolated Android emulators A and B and a separate test account. The inspected SDK lacks emulator/system-images and the default AVD directory is absent. Do not use owner phones/account for destructive tests.
2. Install the same APK on both and record hash/commit. Seed A through the app: ordinary/Qada entries, split surah, history, learning plan. Record IDs and activate via backup/preview.
3. B starts with empty app data. Sign in and restore through the app; compare IDs, date/Qada fields, parts and rotation scores, then actual Home/history/calendar screens. This closes item 3 only after emulator execution.
4. Disconnect both. Make distinct and conflicting edits, including withdrawal at t1 and restore at t2. Reconnect B then A; repeat in reverse order. Include equivalent scheme IDs and prerequisites on later pages.
5. Interrupt a pull, restart and repeat sync. Verify persisted pending inbox/outbox, cursor progress, idempotence and convergence. In isolated test data, include an unsupported record and missing prerequisite; valid subsequent records must progress. This covers items 5/6.
6. Sign out and compare retained local data. Delete cloud history ONLY on the separate test account and verify deletion/retention scope, satisfying item 8.
7. Save APK hash, device IDs, network order, record ID differences, queue/cursor/inbox state, screenshots and pass/fail. Label emulator evidence honestly; do not call it a physical-phone check.

Next implementation checkpoint: finish mandatory handoff reading, add isolated failing reproductions, repair durable state, verify migrations, then run this acceptance sequence. Stage J remains open.
