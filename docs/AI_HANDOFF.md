# Murajaah AI handoff

## Current state

- Current HEAD: `6ad2772` (`Sprint 5E1: stabilize interactive widgets`), branch `main`.
- Active checkpoint: Checkpoint B / Sprint 6A final verification and commit.
- Tracked tree was clean at baseline. The repository already contained one untracked photo and eight untracked historical videos; these are user-owned QA materials and must not be added, moved, renamed, or deleted implicitly.
- Baseline Flutter and Android checks are green.

## Next exact action

Run `git diff --check`, inspect/stage only the documented Sprint 6A files (exclude user media and the two semantic-empty generated-source EOL changes), then commit exactly `Sprint 6A: configurable prayer routines`.

## Scope and non-goals

Current ordered scope: continuity protocol; stabilize interactive Rotation Widget and Learning Widget deep links; configurable prayer routines/schema v5; contextual prayer recommendations; remaining Sprint 5E Android surfaces; evidence-only Cyrillic transliteration audit.

Non-goals: cloud sync/accounts/server, gamification, Qibla, adhan alarms, full Quran reader, iOS WidgetKit, generated/converted Quran text or transliteration, invented prayer rules or times, and lock-screen bypasses.

## Verified completed work

- `a640f50`: Sprint 5D Quran audio, previously verified with Flutter tests, Android compilation, and APK build.
- `2888de3`: Sprint 5C multilingual Quran layers.
- `68780aa`: Sprint 5B prayer context and history UX.
- `761f339`: Sprint 5A mastery lifecycle and learning plans.
- `bacacec`: Sprint 4 interactive widgets, Quran layers, and prayer times.
- Baseline inspection on 2026-09-03 confirmed HEAD/branch and the code facts described in the continuation scope: DB schema v4; Rotation Widget projection filters `remaining > 0`; Learning Widget fallback uses the Home URI; no Prayer Widget or DreamService exists.

## In progress

- Continuity files were committed in isolated checkpoint `4528fce`.
- Sprint 5E1 is committed as `6ad2772`: DB-backed revision ordering, atomic stale-write rejection, explicit checked state, foreground reconciliation, stable rows, debug-gated diagnostics, early callback registration, and corrected Learning links.
- Sprint 6A implementation/documentation is complete but uncommitted: schema/domain v5, all migration fixtures, Jumuah, revision-safe routine editor/repository, immutable sessions, exact-slot Home/widget flow, completed-routine guard and followed-imam/Undo are covered by targeted and full checks. Only final diff/staging review and commit remain.
- Sprint 5E1's foreground/headless ordering risk is addressed by DB-backed journal revisions and stale-snapshot rejection; physical-device lifecycle verification remains pending.

## Decisions and reasons

- The application database remains authoritative. SharedPreferences remains a replaceable widget projection, never a second source of truth.
- Existing untracked media remains outside commits because it was present before this checkpoint and belongs to the user.
- Normal Android Back/Activity destruction will not be overridden. Reliability must come from idempotent background actions, committed revision ordering, and resume reconciliation.
- Schema v5 is introduced once for prayer routines, preserving all legacy events with nullable part/slot links rather than inventing historical prayer parts.
- Routine templates start empty with `enabled=true`; without parts they have no runtime effect and infer no madhhab preset. A template can be disabled and an individual part can be confirmed-deleted (schema v5 has no per-part enabled flag).
- A current routine makes the complete session/part/next-slot tuple mandatory at the repository transaction boundary. Cached schema-1/slotless widget actions remain compatible only when no routine exists and otherwise fail closed.
- Followed-imam is a part completion, never a recitation; it creates no event, rotation credit or surah statistics. Undo is accepted only before later dependent history.
- Jumuah is manual, distinct from Dhuhr, has no invented solar time and does not support Qada. Friday automatic resolution stays Dhuhr; Home offers an explicit one-event override in its current interval.

## Database and migrations

- Working-tree application schema version: 5 (`lib/core/data/database/app_database.dart`); committed HEAD remains schema v4 until the final Sprint 6A commit.
- Current core tables include Surahs/mastery, RotationStates/Schemes/Parts/Adjustments, PrayerSessions, RecitationEvents/EventParts, LearningSurahs/Events, and AppSettings.
- Existing v1/v2/v3 fixtures plus the newly generated v4/v5 fixtures are verified through direct v1/v2/v3/v4 to v5 migration tests, including exact legacy-row/relationship preservation.
- Schema v5 adds routine templates, immutable prayer-session part snapshots, and optional recitation-event part/slot links. It preserves legacy history with null part/slot links and seeds only empty manual templates (no madhhab preset).

## Known bugs and reproduction

- No currently reproduced code-level Sprint 5E1 or Sprint 6A defect remains after automated verification; the original launcher lifecycle report and new routine labels/actions still need physical-device confirmation.
- Android force-stop may prevent broadcast delivery by OS design and must not be represented as supported delivery.
- Sprint 6A automated checks and APK build are green. It is not committed yet, so do not advance to Checkpoint C until staging review and the required checkpoint commit exist.

## Tests and commands

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

## Manual/device QA

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

- Sprint 6A schema-v5/domain/repository/UI/widget integration and tests; generated Drift schema/database and Flutter l10n files belong to that checkpoint.
- Documentation changes: `docs/ARCHITECTURE.md`, `docs/PRODUCT_SPEC.md`, `docs/BACKLOG.md`, `docs/PRAYER_TIME_ARCHITECTURE.md`, `docs/ANDROID_WIDGETS.md`, `docs/INTERACTIVE_ANDROID_WIDGET.md`, new `docs/PRAYER_ROUTINES.md`, new `docs/DATABASE_MIGRATION_V5.md`, and this live handoff.
- Pre-existing user-owned files, excluded from commits: `photo_2026-09-03_10-59-07.jpg` and eight MP4 files under `Скринсейверы до v5/`.

## Decision log

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
