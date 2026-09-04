# Murajaah AI handoff

## Current state

- Current HEAD: `260cf93` (`Sprint 6A: configurable prayer routines`), branch `main`.
- Active checkpoint: Checkpoint C (contextual prayer recommendations) not yet started. The checkpoint order (A: widget reliability, B: configurable prayer routines, C: contextual recommendations, D: remaining Sprint 5E surfaces, E: Cyrillic transliteration audit) comes from the external continuation prompt the user supplies each session; it is not itself checked into this repo, so re-request it from the user if a future session starts without it.
- Tracked tree is clean. The repository still contains one untracked photo and one untracked directory of historical videos (`Скринсейверы до v5/`); these are user-owned QA materials and must not be added, moved, renamed, or deleted implicitly.
- Sprint 6A checks are green (analyzer, full Flutter test suite, Android `:app` Kotlin compile). See Tests and commands for the verification run that preceded the commit.

## Next exact action

Start Checkpoint C: implement contextual prayer recommendations (a `ContextualSurahSuggestionService` consuming `RotationSnapshot` + `PrayerContext` + `PrayerSessionPart?` + contextual stats + current-session marks, ranked: mastered/active only, exclude already-filled current-part slots by default while keeping history visible, then eligibility/urgency, then least-recently-read-in-this-exact-part, then prayer-type stats, then existing global tie-breaks; falling back cleanly to today's global order when there is no contextual history yet), wired into Home and Rotation Widget so both render identical ranks/badges from one Dart-built snapshot, plus the Isha-to-Witr auto-transition (fard+sunnah complete or followed-imam in today's session moves the active context to Witr without inventing a Witr time or recitation event, and is idempotent on repeat screen opens). Start with characterization tests around the existing `SurahSuggestionService`/`RecitationRepository.getStats` before changing their public API.

## Environment and tooling (read before running any command)

- Git and Flutter are **not** on PATH in a plain PowerShell session here, even unsandboxed. A prior Codex session set up a portable toolchain in `D:\MurajaahWorkspace\.tools\` (`mingit`, `flutter`, `gradle-home`, `pub-cache`). `D:\MurajaahWorkspace` is a **directory junction pointing at this exact repo** (`D:\Приложении\Repeat Qur`an`) — not a separate copy. Verify with `Get-Item 'D:\MurajaahWorkspace' -Force` (LinkType Junction, Target = this repo).
- Git: `D:\MurajaahWorkspace\.tools\mingit\cmd\git.exe`. The repo's `.git` is owned by a different Windows account (`CodexSandboxOffline`), so git refuses to run as `User` until `git config --global --add safe.directory <path>` has been called for that account. This was already added to the `User` account's global gitconfig in this session; a future session running as a different OS account will need to repeat it (message is self-explanatory if it happens again). **Never write the Cyrillic path as a double-quoted PowerShell literal** — `` `an `` inside `"...Qur`an"` is parsed as the alert-escape sequence and corrupts the string; use single quotes, or better, capture it once via `(Get-Location).Path`.
- Flutter: `D:\MurajaahWorkspace\.tools\flutter\bin\flutter.bat`. Set `$env:PUB_CACHE = 'D:\MurajaahWorkspace\.tools\pub-cache'` first.
- **`flutter analyze` crashes if invoked while the working directory is the real Cyrillic path** (`D:\Приложении\Repeat Qur`an`): the Dart analysis server's LSP channel throws `FormatException: Unterminated string` while parsing the `rootUri` JSON and exits 255. This looks like a Windows-path/JSON-framing bug in this Dart/analysis-server build, not anything in our code. Workaround: run `flutter`/`dart` from the ASCII junction path `D:\MurajaahWorkspace` instead (`Push-Location 'D:\MurajaahWorkspace'` first) — same files, same git history, analyzer runs clean from there.
- Gradle: there is also a `M:` subst'd drive already mapped to `D:\MurajaahWorkspace` (`subst M: D:\MurajaahWorkspace`; recreate with that command if a fresh session doesn't have it). **Always invoke `gradlew.bat` from `M:\android`, not from `D:\MurajaahWorkspace\android` or the Cyrillic path.** Flutter's generated Gradle wiring bakes in `M:\...` pub-cache paths; invoking from a different root for the same files throws `this and base files have different roots` and fails configuration. Set `$env:GRADLE_USER_HOME = 'D:\MurajaahWorkspace\.tools\gradle-home'` to reuse the warm cache.
- `gradlew.bat testDebugUnitTest` (no module scope) also runs the bundled `geolocator_android` plugin's own unit test, which failed once in this session with `Could not find or load main class worker.org.gradle.process.internal.worker.GradleWorkerMain` (a Gradle worker JVM spawn crash) — unrelated to any app code. Re-running scoped to `:app:testDebugUnitTest :app:compileDebugKotlin` succeeded immediately after. If the unscoped command fails only on a third-party plugin's test task, re-run scoped to `:app:...` rather than treating it as a regression.

## Scope and non-goals

Current ordered scope: continuity protocol; stabilize interactive Rotation Widget and Learning Widget deep links; configurable prayer routines/schema v5; contextual prayer recommendations; remaining Sprint 5E Android surfaces; evidence-only Cyrillic transliteration audit.

Non-goals: cloud sync/accounts/server, gamification, Qibla, adhan alarms, full Quran reader, iOS WidgetKit, generated/converted Quran text or transliteration, invented prayer rules or times, and lock-screen bypasses.

## Verified completed work

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
- Checkpoint C (contextual prayer recommendations) has not been started: `SurahSuggestionService.suggest` still takes only a `RotationSnapshot`, `RecitationRepository.getStats` groups by `PrayerType + isQada` but nothing consumes it for per-prayer/per-part ranking yet, and Home still separates a "Recommended" block from the active-surah list rather than the single ranked list the continuation prompt specifies.

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

- Committed HEAD application schema version: 5 (`lib/core/data/database/app_database.dart`), as of `260cf93`.
- Current core tables include Surahs/mastery, RotationStates/Schemes/Parts/Adjustments, PrayerSessions, RecitationEvents/EventParts, LearningSurahs/Events, and AppSettings.
- Existing v1/v2/v3 fixtures plus the newly generated v4/v5 fixtures are verified through direct v1/v2/v3/v4 to v5 migration tests, including exact legacy-row/relationship preservation.
- Schema v5 adds routine templates, immutable prayer-session part snapshots, and optional recitation-event part/slot links. It preserves legacy history with null part/slot links and seeds only empty manual templates (no madhhab preset).

## Known bugs and reproduction

- No currently reproduced code-level Sprint 5E1 or Sprint 6A defect remains after automated verification; the original launcher lifecycle report and new routine labels/actions still need physical-device confirmation.
- Android force-stop may prevent broadcast delivery by OS design and must not be represented as supported delivery.
- `flutter analyze`/`dart` crash with a JSON `FormatException` when run with the working directory set to the real Cyrillic project path; see Environment and tooling above for the ASCII-junction workaround. Not a code defect.
- Unscoped `gradlew.bat testDebugUnitTest` can fail on the bundled `geolocator_android` plugin's own test task with a Gradle worker JVM spawn error, unrelated to app code; see Environment and tooling above.

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
- 2026-09-04 (independent re-verification before committing, run from the `D:\MurajaahWorkspace` ASCII junction): `flutter analyze --no-pub` -> `No issues found!` (146.6s). `flutter test --no-pub --reporter compact` -> `424/424` passed (one more test than the prior count; still fully green). `gradlew.bat testDebugUnitTest :app:compileDebugKotlin` from `M:\android` (unscoped) failed only on `:geolocator_android:testDebugUnitTest` (`GradleWorkerMain` class-not-found, a worker JVM spawn crash in a bundled plugin's own tests). Re-run scoped to `gradlew.bat ':app:testDebugUnitTest' ':app:compileDebugKotlin'` -> `BUILD SUCCESSFUL` in 6s, confirming the app module's Kotlin (including the modified `RotationWidget.kt`/`WidgetSnapshot.kt`) compiles and has no failing tests. Staged and committed as `260cf93` after confirming `git diff` for `lib/features/prayer_times/data/uzbekistan_prayer_locations.g.dart` and `lib/features/quran/data/providers/known_official_quran_enc_translations.g.dart` was empty (EOL-only) and excluding both files plus the two pre-existing user media items from the commit.

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

- None from any checkpoint. Working tree is clean as of `260cf93`.
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
- 2026-09-04 (Claude Code continuation): Independently re-verified Sprint 6A (analyzer, full test suite, scoped Gradle build, direct code read of the followed-imam completion path) rather than trusting the prior agent's report alone, then staged exactly the documented file set and committed `260cf93`. Discovered and documented the portable toolchain (`D:\MurajaahWorkspace` junction, `M:` subst drive, MinGit/Flutter/Gradle under `.tools/`), the Cyrillic-path Dart-analyzer crash and its ASCII-junction workaround, and the unrelated `geolocator_android` Gradle worker flakiness — recorded under Environment and tooling so no future session has to rediscover them.
