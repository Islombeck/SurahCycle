# Stage J emulator acceptance — prepared 2026-09-25

The audit of 2026-09-24 ends with a seven-step acceptance sequence and the note
that the SDK had no emulator in it. This is what was prepared for that sequence,
what ran, and the two things that stop the rest of it — named precisely, because
"blocked" without a cause is the kind of sentence that hides a skipped check.

## What is ready

| Piece | State |
| --- | --- |
| `emulator` package | installed, 37.1.11.0 |
| `system-images;android-35;google_apis;x86_64` | installed |
| AVD A — `murajaah_a` | created, pixel_6 profile |
| AVD B — `murajaah_b` | created, pixel_6 profile |
| Two isolated user datasets | yes: separate AVDs, separate `userdata-qemu.img` |
| Test Appwrite project | created and provisioned — see blocker 2 |
| Test account | created, one tap to sign in on a build that carries the defines |
| Acceptance APK | built from the defines file, pointed at the test project |

Both AVDs are throwaway. `avdmanager delete avd -n murajaah_a` removes one; they
are in `%USERPROFILE%\.android\avd` and touch nothing else.

## Blocker 1 — no hardware acceleration

`emulator -accel-check` reports exit 6, "Android Emulator hypervisor driver is
not installed". The machine can run one: an i7-7700HQ with
`VirtualizationFirmwareEnabled` and SLAT both true, on Windows 10 Pro, with
`HypervisorPresent` false.

`extras;google;Android_Emulator_Hypervisor_Driver` 2.2.0 is downloaded and
sitting in the SDK. Installing it runs `silent_install.bat`, which loads a
kernel driver and therefore needs an elevated prompt; the elevation request was
cancelled, so it is not installed. **One approval on that prompt is the whole
of it**, and `silent_install.bat -u` undoes it.

Software emulation was tried rather than assumed, and it does not work here.
With `-accel off -gpu off -no-window` the emulator starts, QEMU reaches its main
loop and `adb` lists `emulator-5554 offline` — and then nothing. After eight
minutes the QEMU process had used **0.7 seconds of CPU**: it is not booting
slowly, it is not executing the guest at all. Killed, and no processes left
behind. `-accel off` with the GPU left on exits with code 5 before that point.

So the driver is not an optimisation here. It is the difference between an
emulator and no emulator.

## Blocker 2 — resolved, 2026-09-25, without registering an identity

The owner chose the route that needs no Google account. A **separate Appwrite
project** now exists for acceptance runs and holds nothing of his:

| | |
| --- | --- |
| Project id | `surahcycle-acceptance` |
| Name | SurahCycle Acceptance (test only) |
| Region | `fra`, same endpoint as production |
| Database / table | `surahcycle` / `sync_log` — 10 columns, 3 indexes, row security on |
| Test user | `acceptance-tester`, `acceptance@surahcycle.test` |

The table was created from `tool/appwrite_provisioning.dart`'s own emitted plan,
not typed by hand, and planning again against the result prints "Nothing to do:
the project already matches the declaration" — so the test project is the
declared shape, and any drift between it and production is visible rather than
guessed.

The app reaches it because `APPWRITE_PROJECT_ID` and `APPWRITE_ENDPOINT` were
already compile-time values; no code changed for that. What did change is a
password sign-in behind `DebugPasswordSignIn`, refused outside a debug build —
see that commit for why it exists and what keeps it off the product surface.

**The password is not in this repository and will not be.** It lives in the
session scratchpad and in the build's compiled defines. Deleting the project
disposes of the account and everything in it in one action, which is the
intended end of the acceptance run.

**Checked before the emulator, not after.** A full round trip was run against
the test project over plain HTTPS, so a typo or a disabled auth method would be
found here rather than halfway through an acceptance run: the credentials the
APK was built with create a session, that session writes a row into `sync_log`
with per-row permissions, the owner reads it back, and the delete removes it.
The table was left empty — `total: 0`.

**What this still does not cover:** §6.6 item 2, the real OAuth sign-in. It
cannot — it is a different path. That item is closed by the owner's own phones.

## Comparing the two devices

`tool/compare_databases.dart` compares two databases **by identifier** and then
by field, which is what item 3 asks for and what the audit said the 85/84 claim
lacked. It reads; it opens both files read-only.

It has already earned itself on the real pair from 2026-09-24 —
`honor_merged.sqlite` against `jelly_final2.sqlite`:

| Table | Honor \| main | What differs |
| --- | --- | --- |
| `rotation_schemes` | 28 \| 28 | same ids, same fields |
| `rotation_parts` | 31 \| 31 | same ids, same fields |
| `mastered_surahs` | 27 \| 27 | same ids, same fields |
| `rotation_adjustments` | 1 \| 1 | same ids, same fields |
| `recall_attempts` | 4 \| 4 | same ids, same fields |
| `recitation_events` | 741 \| 847 | 106 only on the main phone — **exactly** its 106 withdrawn rows; the Honor holds none |
| `prayer_sessions` | 85 \| 84 | one only on the Honor: the session it opened for itself |
| `learning_surahs` | 5 \| 1 | four only on the Honor: the plans it already had |
| `learning_events` | 66 \| 32 | 34 only on the Honor: those plans' events |
| `app_settings` | 10 \| 13 | three only on the main phone, all device-local |

Nothing appears on the Honor that the main phone is missing, except what the
Honor made itself. The recitation gap is entirely rows that do not show.

## Blocker 2, as it stood before that

The app signs in with Google or Yandex OAuth and nothing else
(`appwrite_account_api.dart` maps exactly those two; there is no email/password
path and no debug sign-in). So "a separate test account" means a Google or
Yandex account that is not the owner's, and creating one on his behalf is not
something to do unasked — it wants a phone number and it would be an identity in
his name.

Steps 3 through 6 of the sequence are sign-in, restore, conflict and cloud
deletion. All four need that account. Using his own instead is refused by the
brief and rightly: step 6 deletes cloud history.

**The smallest unblock:** a throwaway Google account — any address he is willing
to burn — signed in once on emulator A. Nothing else about it matters; it never
needs to receive mail.

That was the ask. He answered it differently and better: build the test account
inside Appwrite instead, which is what the section above records. This paragraph
stays because the reasoning is still the reason the other route was taken.

## What can run once only blocker 1 is gone

One item does not need an account, and it is the one the harness cannot reach:
**the v11 migration under a real Android runtime, over data an installed build
wrote.** Install the 2026-09-24 build on A, seed it through the app, install the
new build over it, and watch the migration run against a database Android wrote
rather than one a test seeded.

It is evidence about the migration only — not about sync, which is what Stage J
is. But it is the one emulator check that needs no identity, so it is the first
thing to run after the driver goes in.

The closest thing done so far without an emulator: the migration was run over 52
copies of databases real phones wrote, including one still at v4, and every
table the owner filled himself came out with the same row count. That is the
same code path; what it does not exercise is Android's own sqlite build and the
app opening the file for the first time after an upgrade.

## The sequence, as commands

Written down so it can be run in one sitting once the two blockers are gone.
`$E` is `%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe`, `$A` is
`platform-tools\adb.exe`.

1. **Start both.** `$E -avd murajaah_a -port 5554` and `$E -avd murajaah_b -port
   5556`, each `-no-snapshot -wipe-data` so the run starts from nothing. Wait on
   `$A -s emulator-5554 shell getprop sys.boot_completed`.
2. **Install and record.** `$A -s emulator-5554 install -r <apk>`, the same file
   on both, and record its SHA-256 and the commit it was built from.
3. **Seed A through the app.** Ordinary and Qada entries, a split surah, a
   learning plan, some history. Record the ids from
   `/data/data/dev.murajaah.murajaah/app_flutter/*.sqlite` pulled to the host —
   read, never written.
4. **Restore on B.** Sign in, preview, merge. Compare id sets, not counts, for
   `recitation_events`, `prayer_sessions`, `rotation_schemes` and coverage; then
   open Home, history and the calendar and look at them.
5. **Conflict, both orders.** Disconnect both (`$A -s <id> emu network delay
   none` is not enough — use airplane mode via `svc wifi disable`/`svc data
   disable`). Withdraw a recitation on A at t1, restore it on B at t2 > t1.
   Reconnect B first, then A; then repeat with the order reversed and t1/t2
   swapped. Both runs must end with the same standing on both devices.
6. **Interrupt a pull.** Kill the app mid-cycle (`$A shell am force-stop`), start
   it again, and check that `sync_inbox_entries` still holds what was waiting,
   that the cursor did not go backwards, and that a second run converges.
7. **Sign out and delete.** Local data must stay; then delete the cloud history
   **on the test account only** and check what goes and what stays.

Every line of evidence is labelled emulator, not phone.
