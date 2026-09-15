# Rename plan — Murajaah → SurahCycle

## Why

**Murajaah/Murajaa can no longer be used as a public brand.** Google Play
already carries an app named Murajaa with overlapping purpose. `Tartib` was
also ruled out: taken, and too generic.

The owner first chose **SalahCycle**, and the app was renamed to it and verified
on the device on 2026-09-15. The clearance then surfaced a phonetic near-miss
(`Salah Circle`, below), and on that evidence the owner chose **SurahCycle**
instead, the same day. SurahCycle is the final name; the SalahCycle step is kept
in this document because the reasoning is what makes the final choice legible.

The rename is mandatory for anything a user reads, and optional-to-harmful for
anything that identifies the app to the operating system or to the database.
This document draws that line explicitly, because a mechanical find-and-replace
across the 133 files mentioning the old name would break an installed app and
lose the owner's real reading history.

## Availability clearance (2026-09-15)

Performed before touching anything, as the brief requires. Both candidates were
run through the same list.

| Check | SurahCycle (final) | SalahCycle (superseded) |
| --- | --- | --- |
| Google Play, exact name | No app | No app |
| Apple App Store, exact name | No app | No app |
| Web search, exact match and spellings | No product, project or company | No product, project or company |
| GitHub | `github.com/surahcycle` → 404, namespace free | No project or organization |
| Domain | No `surahcycle.*` site in search results | No `salahcycle.*` site |
| Trademark | No mark surfaced by web search | No mark surfaced by web search |
| Phonetic / transliteration | No close neighbour found | **Near-miss — see below** |

**No direct conflict was found for either, so the reversible rename proceeded.**

### Why the name moved from SalahCycle to SurahCycle

**`Salah Circle`** (`com.salahcircle.app`) is live on Google Play: prayer times,
prayer tracker with a Qada calculator, Quran with translation and audio, tasbih,
qibla. That is an overlapping audience and a partly overlapping feature set.

"SalahCycle" and "Salah Circle" share the consonant skeleton *s-k-l*, the same
syllable count and the same stress; only the vowel differs (/ˈsaɪkəl/ vs
/ˈsɜːrkəl/). For a largely non-native-English audience — Uzbekistan, Russia,
Central Asia — that difference is thin. The brief's own list asks specifically
for a "конфликт по звучанию и транслитерации" check, and this is that category.

It was **not** the same kind of finding that forced Murajaah out — that was a
near-identical name — so it was reported to the owner as a branding judgement
rather than treated as an engineering blocker. The owner chose to move.

**SurahCycle removes the collision**: both words differ from `Salah Circle`, not
one vowel. It also describes the product more exactly, since the app cycles
*surahs* through a rotation. The remaining caution is that "Surah" and "Salah"
are themselves one vowel apart for non-Arabic speakers — but that is a
similarity to a common noun, not to a competing product in the same store.

The App Store is crowded with `Salah…` prayer trackers (SalahStreak, Salah
Tracker App, My Salah App, Salah – Prayer Times & Qibla) and with `Surah…`
readers (Surah: Noble Quran with Tafsir). Both prefixes are heavily used; that
is a discoverability concern for the owner, not a legal one.

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

None of these appears in the user interface. The app is called SurahCycle
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

1. **Now:** the parser accepts **both** `murajaah://` and `surahcycle://`. Kotlin
   keeps emitting `murajaah://`, so every placed widget keeps working exactly as
   before.
2. **Later, safely:** Kotlin switches to emitting `surahcycle://`. Old widgets
   still work because the parser still accepts the old scheme.
3. **Much later, if ever:** drop `murajaah://` once no widget can plausibly still
   hold one. There is no reason to hurry this step.

Only step 1 is done here. OAuth redirects are unaffected: none exist yet, and
Appwrite's callback scheme is derived from the Appwrite project id
(`appwrite-callback-<PROJECT_ID>`), not from the app name.

## What still has to happen before publishing

- A real trademark search in the target countries.
- A domain, if one is wanted, registered by the owner. `github.com/surahcycle`
  was free on 2026-09-15 but is **not** reserved — nothing was registered, and
  claiming a namespace is the owner's action, not this session's.
- The store listing name, which is chosen at publication and does not have to
  equal `applicationId`.

Documentation and code comments still say "Murajaah" in historical contexts —
commit messages, migration notes, the handoff journal — and the SalahCycle step
is likewise left in the record above. Those are an account of what happened and
are not rewritten.

**A note earned the hard way while editing this very file:** the first pass at
switching SalahCycle → SurahCycle used a regular expression over the prose, and
it flattened the historical mentions too — the document briefly claimed the name
moved "from SurahCycle to SurahCycle". That is precisely the mechanical
find-and-replace this document warns against, applied to itself. Prose about a
rename has to be edited by hand, for the same reason identifiers do: the tool
cannot tell which occurrences are the brand and which are the history.
