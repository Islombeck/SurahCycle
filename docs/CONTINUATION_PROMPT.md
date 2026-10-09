# Continuation prompt — SurahCycle, from 2026-10-09

Paste this whole file as the first message of a new session. It is the standing
brief: what the project is, what may not be broken, what is next and in what
order. Update it when the order changes; it is meant to be edited, not
rewritten each time.

---

## Who you are working with

The owner is referred to as **Ака**. Answer in Russian, naturally, without
addressing him in every paragraph. He runs Windows, builds for his own Android
phones, and uses the app daily — most defects in this repository were found by
him using it, not by a test.

**«Всё, что можешь сделать сам, делай; от меня — минимум действий.»** Take that
literally: do the backups, the builds, the installs, the verification. Ask only
when a decision is genuinely his or when something cannot be done without a
credential.

---

## What the project is

SurahCycle — a local-first Flutter / Drift / Riverpod Android companion for
revising memorised Qur'an inside the five daily prayers. 171 source files,
~44k lines, 1,329 tests. Schema v11. The device database is authoritative;
the Appwrite account is an append-only sync log, not a backup.

Read first, every session, completely:

- `docs/AI_HANDOFF.md` — the running log. Reconcile it against `git status`,
  `git log` and the tests before changing anything, and update it before and
  after every checkpoint.
- `docs/ARCHITECTURE_REVIEW_2026-10.md` — what is right, what is debt, in what
  order.
- `docs/IOS_HANDOFF.md` — the iOS counterpart of the handoff. **Fill it in on
  every session that touches anything a port would care about**, the same way
  as `AI_HANDOFF.md`.
- `CLAUDE.md`, `AGENTS.md`, and the feature document for whatever you touch.

---

## Rules that are not negotiable

**Secrets.** Never write a password, OAuth client secret, API key, access or
refresh token, authorization code or cookie into Git, a document, a log or the
chat. Never ask him for an authorization code or a callback URL. Never type his
account password. Public configuration that is fine to use:
`APPWRITE_PROJECT_ID=6aa91956000d1d490a3e`,
`APPWRITE_ENDPOINT=https://fra.cloud.appwrite.io/v1`.

**Honesty.** Never claim "verified on the phone" unless it ran over ADB, and
say which device. Never write "the owner confirmed" until he actually has.
Report what failed, with the output.

**Tests.** Never delete a test to get a green result; rewrite it if the
contract genuinely changed, and say so. **Falsify every fix**: break the code
again and watch the new test go red before you believe it.

**His data.** Back up before anything touches the device database. Never write
directly into it. Never use his cloud account for destructive tests. Never
touch his untracked files — `.codex/`, `photo_2026-09-03_10-59-07.jpg`,
`Скринсейверы до v6/`. `lock_screen_show_notifications = 0` is his privacy
choice and stays.

**Identifiers.** Do not change `applicationId`/namespace
`dev.murajaah.murajaah`, the Kotlin package, the iOS bundle id, the
method-channel or widget identifiers, the Drift/SQLite filenames, or the Dart
package name `murajaah`, without a migration plan and his confirmation.

**Religious invariants.** Qada only for the five Fard prayers and Witr/Wajib.
"Followed the imam" creates no recitation event. A recall attempt never
creates or cancels a recitation. Al-Fatiha never enters rotation. Global
rotation debt and the fullness of a prayer's slots are different questions and
must never be shown as one thing. A mark between midnight and Fajr belongs to
the night that is ending.

**Git.** No destructive operations. No single giant commit — one subject per
commit, suite green between them.

---

## The environment, so you do not rediscover it

- `flutter test` / `flutter analyze` from `D:\MurajaahWorkspace`. The SDK is at
  `D:\MurajaahWorkspace\.tools\flutter\bin` and is **not** on `PATH`; prepend
  it, and prepend `D:\MurajaahWorkspace\.tools\mingit\cmd` too or Flutter's own
  version script fails.
- `flutter build apk` **only from `M:\`**, a `subst` alias that does not
  survive a reboot. Without it Gradle fails with `Cannot invoke
  "java.io.File.exists()" because "parent" is null`. Recreate:
  `subst M: D:\MurajaahWorkspace`.
- Git needs `$env:GIT_CONFIG_COUNT='1'; $env:GIT_CONFIG_KEY_0='safe.directory';
  $env:GIT_CONFIG_VALUE_0='*'`. Use `git commit -F <file>`; a here-string with
  quotes in it breaks the PowerShell parser.
- `adb` at `C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe`.
  Binary redirects go through `cmd /c` — PowerShell corrupts PNGs.
- Never run `flutter test` while a Gradle build runs in the same tree.
- Never edit source with `Get-Content`/`Set-Content`.
- Screenshots, not `uiautomator dump`, and a fresh one before every tap. One
  action, then look.

**The install ritual, every time:** pull a backup → `integrity_check`,
foreign-key check, row counts → check the APK's Dart kernel for acceptance
credentials → `adb install -r` → launch → pull again → id-level comparison with
`tool/compare_databases.dart` → `sha256sum` of `base.apk` **on the phone**.
Phone passcodes he authorised: Jelly Max `7207`, Honor 50 `773376`.

---

## Where things stand, 2026-10-09

Done in the last two days, all on his phone: the green tick now means "recited
in this prayer" rather than "in this part" (`ef85e13`); no empty Isha/Witr
session is opened on a day that has not started (`8f1b4e4`); a paused Appwrite
project is no longer reported as an expired session (`041818f`); the analyzer
is strict and clean (`66e79b7`); the prayer widget is finally told when the
snapshot changes (`4af7451`).

Open and known: the account holds 1,244 recitation rows against the phone's
1,202 and the 42 are unexplained (`AI_HANDOFF.md`, 2026-10-08); the theme
segmented button breaks words at his real width.

---

## The work, in order

### 1. Extract the Home registration controller

`home_screen.dart` is 2,567 lines and one `State` with 76 methods, and it is
where every defect of the last two weeks lived. Pull the mark pipeline —
resolving the prayer for an action, the registration-context token, the
Isha→Witr transition, the busy set, Undo — into
`features/home/application/home_registration_controller.dart`, with its own
tests. No behaviour change; the suite must pass untouched.

Do this first. It is the prerequisite that makes everything below testable
without pumping a whole screen.

### 2. Move the prayer-time providers out of the global registry

`app_providers.dart` is 2,017 lines and ~95 providers from every feature.
Create `lib/app/core_providers.dart` for the genuinely global ones (database,
clock, local date, settings, HTTP, uuid) and move the 20 prayer providers to
`features/prayer_times/application/`. Leave `app_providers.dart` re-exporting
them so **no other import changes**. `features/account/application/
account_providers.dart` is the existing example and its header says why.

### 3. Decide how a widget stays fresh — both platforms at once

`isCurrent`/`isNext` are frozen into the snapshot, so a widget is only as fresh
as the last time the app wrote one. Nudging the receiver (done) fixes the case
where the app runs and nothing else. Three options are written up in
`ARCHITECTURE_REVIEW_2026-10.md` §3; the third — carry the **boundary instants**
instead of the verdict, so the platform compares rather than judges — is
probably right and is a schema 7 change. **Ask him before implementing.**

This blocks items 4 and 5.

### 4. Horizontal prayer-times widget

A wide widget showing all six daily boundaries in a row, with the current one
marked. The Glance provider already exists (`PrayerWidget.kt`, responsive
sizes); this is a new size class and layout, plus `prayer_widget_info.xml`
targeting a wide cell. The projection (`PrayerWidgetProjectionFactory`) is pure
formatting and already carries everything it needs.

### 5. A widget that shows only the current prayer

Small, one prayer, large type. Same projection, a different Glance layout and
a second provider XML. **Confirm with him which he meant**: a compact
current-prayer widget, or the complaint that the existing one was stuck on
Asr — item 3 of "where things stand" says the stuck behaviour was real and is
half-fixed.

### 6. Scheduler

The largest piece, and new. Sketch of the contract, to be agreed before coding:

- The day is divided by the real prayer schedule into intervals.
- Each prayer gets a **duration the owner sets himself** — "about 20 minutes
  for Maghrib". It is his estimate and the UI must say so; the app must never
  present a prayer as taking a fixed, authoritative length of time.
- A task has a title and an estimated duration, and may be **split** into
  chunks that land in different free intervals.
- A visual timeline shows the day: prayer blocks, free gaps, where each task
  chunk sits.
- Storage is a new Drift table — schema **v12**, with a migration test from
  every earlier version, the same as every other bump here.
- It must be useful with no network and no account, like everything else.

Open questions for him before any code: does a task repeat daily? what happens
to a chunk that was not done — does it move, or does it stay as a record of a
day? does the scheduler ever notify, given that notifications are opt-in and
silent by rule?

### 7. Launcher icon from `brand/surahcycle_logo.svg`

Mipmaps and the adaptive icon. Small, long overdue.

### 8. Widen the narrow-layout suite

`test/widget/layout_at_phone_width_test.dart` walks five tabs at 411×914. Add
the sheets — learning plan editor, coverage sheet, calendar day detail — and an
iPad width while you are there (`IOS_HANDOFF.md` §2.5). Fix the theme
segmented button that breaks words at his real width.

---

## How to work

Read the handoff. Pick the next item. Write the failing test first and watch
it red. Make it pass. Run `flutter analyze` and the full suite. Commit one
subject with a message that explains the defect, not the diff. Update
`AI_HANDOFF.md` — and `IOS_HANDOFF.md` when the change touches anything a port
would care about. Then build, back up, install and verify on his phone, and
say plainly what you did and did not see with your own eyes.
