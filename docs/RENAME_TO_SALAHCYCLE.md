# Rename plan — Murajaah → SalahCycle

## Why

**Murajaah/Murajaa can no longer be used as a public brand.** Google Play
already carries an app named Murajaa with overlapping purpose. `Tartib` was
also ruled out: taken, and too generic. The owner chose **SalahCycle**.

The rename is therefore mandatory for anything a user reads, and optional-to-
harmful for anything that identifies the app to the operating system or to the
database. This document draws that line explicitly, because a mechanical
find-and-replace across 133 files would break an installed app and lose the
owner's real reading history.

## Availability clearance (2026-09-15)

Performed before touching anything, as the brief requires.

| Check | Result |
| --- | --- |
| Google Play, exact name | No app named "SalahCycle" |
| Apple App Store, exact name | No app named "SalahCycle" |
| Web search, exact match and spellings | No product, project or company |
| GitHub | No project or organization by that name |
| Domain | No `salahcycle.*` site found in search results |
| Trademark | No mark surfaced by web search |
| Phonetic / transliteration | **One near-miss — see below** |

**No direct conflict was found, so the reversible rename proceeded.**

### The near-miss, recorded rather than swallowed

**`Salah Circle`** (`com.salahcircle.app`) is live on Google Play: prayer times,
prayer tracker with a Qada calculator, Quran with translation and audio, tasbih,
qibla. That is an overlapping audience and a partly overlapping feature set.

"SalahCycle" and "Salah Circle" share the consonant skeleton *s-k-l*, the same
syllable count and the same stress; only the vowel differs (/ˈsaɪkəl/ vs
/ˈsɜːrkəl/). For a largely non-native-English audience — Uzbekistan, Russia,
Central Asia — that difference is thin. The brief's own list asks specifically
for a "конфликт по звучанию и транслитерации" check, and this is that category.

It is **not** the same kind of finding that forced Murajaah out: that was a
near-identical name. This is a similar-sounding name in the same category. It is
recorded here and reported to the owner rather than treated as a blocker,
because the decision is a branding judgement, not an engineering one.

The App Store is also crowded with `Salah…` prayer trackers (SalahStreak, Salah
Tracker App, My Salah App, Salah – Prayer Times & Qibla). "Salah" as a prefix is
heavily used. That is a discoverability concern for the owner, not a legal one.

**Caveat stated plainly:** these are web searches, not a legal clearance. No
trademark register was queried directly — not USPTO, not EUIPO, not the
Uzbekistan or Russian registers. Before publishing, a real trademark search in
the target countries is still required, and nothing here is a legal guarantee.

## What is renamed (reversible, user-facing)

| Surface | Where |
| --- | --- |
| App display name | `lib/l10n/app_*.arb` → `appName` |
| In-app copy naming the app | `widgetOpenAppToLoadText`, `widgetSelectPrayerInApp` |
| Android launcher label | `android/app/src/main/AndroidManifest.xml` → `android:label` |
| Android widget names | `res/values{,-ru,-uz}/strings.xml` → `rotation_widget_name`, `learning_widget_name`, `prayer_widget_name` |
| Android widget empty/error copy | `rotation_widget_empty`, `widget_open_murajaah` *value*, `widget_error_title` |
| Screensaver label and copy | `dream_service_name`, `dream_service_empty` |
| iOS display name | `ios/Runner/Info.plist` → `CFBundleDisplayName`, `CFBundleName` |
| iOS permission copy | `NSLocationWhenInUseUsageDescription` |

## What is deliberately NOT renamed

Each of these is a stable identifier, and changing it costs the user something
real while gaining nothing they can see.

| Kept | Reason |
| --- | --- |
| `applicationId` / `namespace` `dev.murajaah.murajaah` | Changing it makes Android treat the result as a **different app**: a fresh install, and the owner's real reading history gone. The brief also forbids adopting a new reverse-domain namespace without evidence the owner controls that domain, and no such evidence exists. |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | Same identity argument. |
| Kotlin package `dev.murajaah.murajaah.widget` | Follows `applicationId`. |
| `MurajaahDreamService` and other class names | A screensaver the user selected is remembered by component name; renaming the class silently deselects it. The brief explicitly says not to rename historical class names mechanically when it risks data or state. |
| Method-channel name, widget receiver names, the snapshot lock filename | Wire identifiers between Dart and Kotlin. Renaming them is pure churn with a real chance of a mismatch. |
| Drift database files `murajaah_user.sqlite`, `murajaah_quran_cache.sqlite` | Renaming abandons the user's data. Never. |
| Dart package name `murajaah` in `pubspec.yaml` | It is the `package:murajaah/...` import prefix. Touching it rewrites every file in the repo for zero user-visible benefit. |
| Android string resource **keys** such as `widget_open_murajaah` | Keys are identifiers; only their values are read by anyone. |
| `developer.log(name: 'MurajaahRoutine')` | Debug-only diagnostic tag. |

None of these appears in the user interface. The app is called SalahCycle
everywhere it speaks, and keeps its old technical identity where it only speaks
to Android, to SQLite or to itself.

## Deep links: transitional compatibility

Widget deep links use the private scheme `murajaah://app/...`. It is **not** a
registered external scheme — there is no `<data android:scheme>` intent filter;
the URI travels inside `home_widget`'s own launch action. So no other app and no
web link depends on it.

It still cannot be swapped in one step: a widget already placed on the launcher
holds a `PendingIntent` built with the old URI, and that intent survives an app
update. Flipping the scheme would leave every existing widget opening nothing.

Transitional approach, in this order:

1. **Now:** the parser accepts **both** `murajaah://` and `salahcycle://`. Kotlin
   keeps emitting `murajaah://`, so every placed widget keeps working exactly as
   before.
2. **Later, safely:** Kotlin switches to emitting `salahcycle://`. Old widgets
   still work because the parser still accepts the old scheme.
3. **Much later, if ever:** drop `murajaah://` once no widget can plausibly still
   hold one. There is no reason to hurry this step.

Only step 1 is done here. OAuth redirects are unaffected: none exist yet, and
Appwrite's callback scheme is derived from the Appwrite project id
(`appwrite-callback-<PROJECT_ID>`), not from the app name.

## What still has to happen before publishing

- A real trademark search in the target countries.
- The owner's decision on "SalahCycle" vs "Salah Circle" similarity.
- A domain, if one is wanted, registered by the owner.
- The store listing name, which is chosen at publication and does not have to
  equal `applicationId`.

Documentation and code comments still say "Murajaah" in historical contexts —
commit messages, migration notes, the handoff journal. Those are a record of
what happened and are not rewritten.
