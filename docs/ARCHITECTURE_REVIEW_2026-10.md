# Architecture and clean-code review — 2026-10-09

Written for: whoever works on this codebase next, the owner included. It is a
review, not a plan of record; `ARCHITECTURE.md` describes the intended design
and stays authoritative for what the layers *mean*.

Every number here was measured on the tree at commit `66e79b7`, and every
claim says how. Where a measurement contradicted a suspicion, the measurement
is what is written down.

---

## The short version

**The architecture is sound and it is not where the problems are.** The layer
boundaries hold mechanically, not just by intention, and the type discipline
turned out to be stronger than the tooling that was checking it. Two files
have grown past the point where they can be read, and that — not the
structure — is the real debt.

| Measured | Result |
| --- | --- |
| Source files (excluding generated and l10n) | 171, 44,035 lines |
| Test files / tests | 170 files, **1,328 passing**, 11 skipped |
| `lib/core/domain` importing Flutter, Drift or Riverpod | **0** |
| `lib/core/domain` importing anything under `data/` | **0** |
| `lib/core` importing `lib/features` | **0** |
| Presentation importing `package:drift` or the database directly | **0** |
| Cross-feature imports | 14, all through feature barrels |
| `strict-casts` + `strict-raw-types` + `strict-inference` | **0 errors, 0 warnings** |
| `print(` in `lib/` | 0 |
| `// ignore:` in hand-written code | 36, all documented, all a Dart language limitation |

---

## 1. What is right, and worth not breaking

### 1.1 The dependency rule is actually enforced by the code

A clean architecture that is only described in a document drifts. This one
does not: the domain layer has no framework import of any kind, the core layer
never reaches up into a feature, and no screen has ever been given a database
handle. Those four greps are the whole of the layering claim and all four come
back empty.

Cross-feature coupling is 14 imports in total — `surahs → learning`,
`learning → quran`, `home → prayer_times` and a few more — and each goes
through the target feature's barrel rather than into its internals.

### 1.2 Ports and adapters are used where they pay

The pattern is applied exactly where the decisions are expensive and nowhere
for its own sake: `AppwriteAccountApi`, `AppwriteSyncApi`, `SyncGateway`,
`WidgetBridge`, `LearningNotificationChannel`, `QuranAudioPlayback`. Each one
exists because a rule on this side of it has to be testable without a network,
a platform channel or a Mac — and each classifier is a pure static function
for the same reason.

### 1.3 The type discipline was already there

Turning on all three strict language modes found **nothing** in 44k lines.
That is unusual and it is the single strongest signal in this review. The
analyzer configuration was the untouched `flutter create` scaffold, so none of
it was being enforced; it is enforced now (`66e79b7`).

### 1.4 The tests are the design's load-bearing part

A 1:1 file ratio between `lib/` and `test/`, and the repository's own rule —
every defect repaired by first watching a test go red against the old code —
has held through this session. Three defects were fixed that way in two days.

---

## 2. The two files that are the real debt

### 2.1 `lib/features/home/presentation/home_screen.dart` — 2,567 lines

22 classes in one file, and one `State` with **76 methods**. It holds, in a
single compilation unit:

- the screen and its tab plumbing;
- the whole mark pipeline — resolving the prayer for an action, the
  registration-context token, the Isha→Witr transition, the busy set, Undo;
- three modal sheets (coverage, occurrence, prayer picker);
- nine presentational widgets, from the routine card to the rotation tile.

This is where every defect of the last two weeks lived, and that is not a
coincidence: the file is too large to hold in one reading, so a change to the
mark pipeline and a change to a badge look equally local when they are not.

**Target.** Three files and a folder, no behaviour change:

```
features/home/
  application/
    home_registration_controller.dart   // the mark pipeline + the token
  presentation/
    home_screen.dart                    // the screen, ~300 lines
    widgets/
      prayer_context_card.dart
      prayer_routine_card.dart
      rotation_list.dart                // _RotationContent + tile + indicator
      current_learning_card.dart
    sheets/
      recitation_coverage_sheet.dart
      prayer_occurrence_sheet.dart
```

The split that matters most is the first one: the registration pipeline is
*logic*, it has been the source of three user-visible defects, and today it can
only be tested by pumping a whole screen. Pull it into a controller and it can
be tested directly, which is what the two midnight defects actually needed.

**Do it in that order, one commit each, suite green between them.** A
presentational widget moving files is a zero-risk diff; the controller
extraction is not, and it should not be buried under nine file moves.

### 2.2 `lib/app/app_providers.dart` — 2,017 lines, ~95 providers

One global registry holding the providers of every feature: 24 Quran, 20
prayer, 9 learning, 7 recitation, 6 rotation, 5 sync/widget, plus the genuinely
global ones (database, clock, settings, HTTP).

The cost is not the line count. It is that `lib/app` — the composition root —
now knows the internals of every feature, so adding a provider to one feature
edits a file that every other feature imports, and nothing can be moved
without touching it.

**The codebase already contains the answer.**
`lib/features/account/application/account_providers.dart` keeps its own
providers next to its feature, and the reason is written at the top of the
file: declaring them centrally would drag `package:appwrite` into every widget
test that only wanted a database. That reason generalises.

**Target.** `lib/app/core_providers.dart` keeps what is genuinely global — the
database, the clock, the local-date provider, settings, the HTTP client, the
uuid source. Every other provider moves to `features/<name>/application/`.
`app_providers.dart` becomes a barrel that re-exports them, so **no import
anywhere else has to change** and the move can be done one feature at a time
with the suite green after each.

Start with `prayer_times`: it is the largest coherent group, it is the subject
of the next three features on the roadmap, and it has the most tests to catch
a mistake.

### 2.3 Honourable mention

`recitation_repository.dart` (1,291 lines) and `app_database.dart` (1,618) are
large but cohesive — one is the write boundary for the app's central entity,
the other is the schema. Neither is urgent. `widget_snapshot.dart` (1,018) is
a codec with strict validation and is the right size for what it guarantees.

---

## 3. The one architectural rule that currently costs correctness

**"The platform never owns a resolver."** Which prayer is current, which day a
mark belongs to, what the rotation owes — Dart decides, and Kotlin renders
flags carried in the snapshot. The rule is right: it is why there is exactly
one answer to "which prayer is this" and why a widget cannot invent a
religious decision.

It has one consequence nobody wrote down until now. `isCurrent` and `isNext`
are **frozen into the snapshot**, so a widget can only be as fresh as the last
time the app wrote one. The prayer widget made that visible: nothing nudged its
receiver at all (fixed on 2026-10-09, with a test watched failing) and its
provider XML sets `updatePeriodMillis="0"`, so it kept the frame drawn when the
launcher created it — whichever prayer was current at that moment, highlighted
until something else rebuilt it. Reported by the owner as "the widget only
highlights Asr".

Nudging the receiver fixes the case where the app runs. **It does not fix a
phone whose owner has not opened the app since Dhuhr**, and it will reappear
in exactly this form on iOS, where a WidgetKit timeline is likewise built from
data the app supplied.

**Decided on 2026-10-09, by the owner: option three below.** Schema 7 carries
the day as windows of real time and the platform compares its clock against
them. The rest of this section is kept as the reasoning, not as an open
question.

Two honest options, and this review deliberately does not pick one:

1. **Schedule the rebuild.** An alarm at each prayer boundary wakes a headless
   Dart entry point, which writes a new snapshot. Keeps the rule intact; costs
   a background mechanism on both platforms and the battery conversation that
   comes with it.
2. **Let the platform choose the current entry** from the boundary times the
   snapshot already carries — the same arithmetic Dart does, against the device
   clock. Cheap and offline; weakens the rule, and the before-Fajr case (where
   the current prayer belongs to the *previous* day's schedule) is exactly the
   kind of thing that made the rule worth having.

A third shape exists and is probably the right one: keep the decision in Dart
but make the snapshot carry **the boundaries rather than the verdict** — the
instants at which each entry becomes current — so the platform performs a
comparison, not a judgement. That is a schema change (7) and a decision for the
owner.

**That is what shipped.** `PrayerWidgetWindow` is two instants and a row
index; the day comes out as seven of them, including the one before Fajr that
points at the Isha row and the Sunrise-to-Dhuhr one that points at no prayer
at all. Dart still decides everything that requires knowing something about
prayer. Kotlin validates the same invariants it is given — ordered,
contiguous, never naming Sunrise — because a decoder more forgiving than the
writer renders states the app considers impossible.

The one thing the shape alone does not buy is a redraw: a Glance widget
recomposes when something tells it to. `updatePeriodMillis` is 30 minutes now
(Android's floor) rather than zero, which bounds the lag with no alarm and no
permission. An exact wake-up at each boundary is the remaining step, and both
sides already expose `windowEndsAt` for it.

**The silent catches are worth their own line.** The widget write path had
`onError: (_, _) {}` and `.catchError((Object _) {})`, one after the other. A
launcher failure must never break the app, which is right and is unchanged —
but saying nothing at all means a widget can stop updating and leave no trace
on the device or in a log. Both now call `developer.log` under `kDebugMode`.

---

## 4. Clean code: what was found and what was done

| Finding | Action |
| --- | --- |
| `analysis_options.yaml` was the untouched scaffold | Strict modes + a curated lint set, `66e79b7` |
| `prayer_schedule_cache.read` asked `exists()` then read — two syscalls, stale between them | Reads and lets a missing file take the same path as a corrupt one |
| `prayer_schedule_cache.write` deleted the destination before renaming over it | Renames straight over; the delete bought nothing and opened a window where the cache did not exist |
| A test used `const <dynamic>[]` as an empty fallback | Typed |
| 26 misordered import blocks, 4 stray parens, 4 non-final locals | `dart fix --apply` |
| `no_adjacent_strings_in_list` fires 20 times, every one a wrapped SQL `CHECK` | Rule left off, with the reason in the config: its suggested fix would split one correct constraint into two broken ones |
| `avoid_dynamic_calls` fires 63 times in the migration test, 0 in `lib/` | Rule on; the one test carries a documented file-level ignore, because reading an old schema through an untyped executor is its subject |

What was **not** found, having been looked for: god objects outside the two
files above, duplicated business rules across layers, a second source of truth
for any entity, silent `catch {}` blocks, `print` debugging, dead providers.

---

## 5. Order of work

1. ~~Extract `home_registration_controller.dart`~~ — **done 2026-10-09.**
   `HomeRegistrationController` holds the token, the day and prayer of a
   mark, Isha→Witr, the slot write, Undo, the picked prayer, following the
   imam and the busy sets; it reads providers through an injected `read`
   and has 16 tests of its own. `home_screen.dart` is 2,325 lines now —
   the presentational widgets and sheets (step 5) are what is left in it.
2. ~~Move the `prayer_times` providers out of `app_providers.dart`~~ — **done
   2026-10-09.** `lib/app/core_providers.dart` holds the database, HTTP,
   clock, uuid, the settings repository and the stored-prayer repository
   (the prayer-time settings read it) plus the `LocalDateProvider` classes.
   `features/prayer_times/application/prayer_time_providers.dart` holds the
   twelve schedule providers and the settings controller — and
   `localDateProvider`, because the app's "today" is the prayer region's
   date and depends on its settings, so it cannot sit in the core without
   the core importing a feature. `app_providers.dart` re-exports both; no
   import changed; `test/app/provider_layout_test.dart` keeps it that way.
   **Not moved yet:** the prayer-*context* group (selected prayer, override,
   context resolution, Home's resolution) — it depends on the routine and
   recitation providers, which have to leave first.
3. Decide §3 for both platforms; it blocks three roadmap items.
4. Move the remaining provider groups, one feature per commit.
5. Split the Home widgets and sheets into files.

Steps 1 and 2 are prerequisites for the Scheduler feature: it needs prayer
boundaries as a first-class input and a place to put its own providers, and
adding either to the current `app_providers.dart` would make the file worse.
