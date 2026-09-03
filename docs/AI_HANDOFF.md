# Murajaah AI handoff

## Current state

- Current HEAD: `4528fce` (`Project: add Codex and Claude handoff protocol`), branch `main`.
- Active checkpoint: Sprint 5E1 is fully implemented and verified in code; required checkpoint commit is pending.
- Tracked tree was clean at baseline. The repository already contained one untracked photo and eight untracked historical videos; these are user-owned QA materials and must not be added, moved, renamed, or deleted implicitly.
- Baseline Flutter and Android checks are green.

## Next exact action

Review and stage only the Sprint 5E1 tracked changes/new source files, excluding user-owned media. Commit as `Sprint 5E1: stabilize interactive widgets`, record its hash, then begin Checkpoint B with schema-v5 characterization and migration tests.

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
- Sprint 5E1 implementation uses DB `lastJournalSequence` as snapshot revision, an inter-isolate file lock for atomic stale-write rejection, explicit marked/canMark state, resume/foreground reconciliation, stable headless row order, debug-gated structured logs, early callback registration, and Learning-root links.
- Full Dart and Android regression is green. No physical-device matrix was run because ADB is unavailable on PATH in this session.
- Relevant risk: foreground Drift streams may not observe a headless-isolate database write immediately; SharedPreferences snapshots currently have no DB-backed ordering revision.

## Decisions and reasons

- The application database remains authoritative. SharedPreferences remains a replaceable widget projection, never a second source of truth.
- Existing untracked media remains outside commits because it was present before this checkpoint and belongs to the user.
- Normal Android Back/Activity destruction will not be overridden. Reliability must come from idempotent background actions, committed revision ordering, and resume reconciliation.
- A later schema v5 must be introduced once for prayer routines, preserving all legacy events with nullable part links rather than inventing historical prayer parts.

## Database and migrations

- Current application schema version: 4 (`lib/core/data/database/app_database.dart`).
- Current core tables include Surahs/mastery, RotationStates/Schemes/Parts/Adjustments, PrayerSessions, RecitationEvents/EventParts, LearningSurahs/Events, and AppSettings.
- Existing migration paths v1/v2/v3 to v4 are covered by generated schema fixtures and migration tests.
- Planned schema v5: routine templates, immutable prayer-session part snapshots, optional recitation-event part/slot links. It must preserve mastery, rotation, learning, settings, cache boundaries, schedules, and all legacy history; old recitations receive no fabricated part.

## Known bugs and reproduction

- Rotation Widget mark can become delayed, flicker/roll back, or fail after leaving the root Activity with Back and later invoking a headless widget action.
- The foreground app may not immediately reflect a widget-originated database commit.
- Rotation Widget hides active items once `remaining == 0`, conflating global debt with current-session marking.
- Learning Widget title/empty/fallback/footer opens Home instead of Learning; selected content needs the safe `/learning/:surahId` route.
- Android force-stop may prevent broadcast delivery by OS design and must not be represented as supported delivery.

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

- Sprint 5E1 Dart/Kotlin widget implementation and tests are uncommitted; inspect `git status --short` for the exact tracked-file list.
- `docs/AI_HANDOFF.md`: current checkpoint state.
- Pre-existing user-owned files, excluded from commits: `photo_2026-09-03_10-59-07.jpg` and eight MP4 files under `Скринсейверы до v5/`.

## Decision log

- 2026-09-03: Adopted one shared handoff file for Codex and Claude; no parallel divergent journal.
- 2026-09-03: Reconciled baseline `a640f50`; recorded user-owned untracked QA media instead of cleaning or committing it.
- 2026-09-03: Confirmed checkpoint order: widget reliability precedes schema v5 prayer routines and all later feature work.
- 2026-09-03: Committed shared continuity protocol as `4528fce`; started Sprint 5E1 with tests-first diagnosis.
- 2026-09-03: Chose existing DB journal sequence as the monotonic widget revision; no schema migration or second source of truth is needed for Sprint 5E1.
- 2026-09-03: Schema 4 explicitly separates rotation debt, recommendation, and current-prayer marking. Learning root surfaces use `/learning`; selected content retains `/learning/:surahId`. Rotation footer remains Home.
- 2026-09-03: Android force-stop remains an OS delivery boundary; no broadcast delivery after true force-stop is promised or claimed.
