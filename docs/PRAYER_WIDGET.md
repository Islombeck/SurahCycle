# Prayer Times widgets

## Status

SurahCycle has two native Android home-screen widgets for the prayer
schedule, both rendering the same projection:

- **Prayer times** (`PrayerWidget`) — a vertical list, size-responsive across
  compact / medium / large.
- **Prayer times — strip** (`PrayerStripWidget`, since 2026-10-09) — one
  launcher row: six names over six times, the current prayer on a filled
  pill, and above them a live countdown to the next boundary and the region.
  The shape of the strip under the prayer card on Home, made to fit a
  launcher row; backlog item 27.

Both show today's six boundaries — Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha.
There is no second resolver, no second schedule source and no widget-only
time calculation. Both are read-only: they never mark a recitation, never
write to the database, and the whole surface opens Home.

## Ownership boundary

```text
prayerTodayScheduleProvider / prayerScheduleContextResolutionProvider
                 |
                 v
       PrayerWidgetProjectionFactory (Dart)
                 |
                 v
       PrayerWidgetProjection (part of WidgetSnapshot schema 7):
       six display entries + the day as PrayerWidgetWindows
                 |
                 v
 home_widget SharedPreferences bridge
          |                         |
          v                         v
   PrayerWidget (Glance)     PrayerStripWidget (Glance)
```

Since schema 7 the snapshot carries **the day as windows of real time, not a
verdict**. A `PrayerWidgetWindow` is two instants and a row index: seven of
them, contiguous and ordered — the hours before Fajr point at last night's
Isha, Sunrise→Dhuhr points at no row (`-1`), because no prayer is current
then. Everything that requires knowing something about prayer is decided in
Dart, in the factory. Kotlin compares its own clock with those windows:

| Kotlin (`NativePrayerProjection`) | answers |
|---|---|
| `currentIndexAt(now)` | which row is on the pill, or none |
| `nextIndexAt(now)` | the next row that is a prayer |
| `windowEndsAt(now)` | when the drawing next changes |
| `nextBoundaryAt(now)` / `nextBoundaryIndexAt(now)` | what the strip's countdown counts to |

`nextBoundaryAt` is the start of the next window, which is not always
`windowEndsAt`: once Isha begins, the window ends at midnight only because the
snapshot covers one calendar day. The real next boundary is tomorrow's Fajr,
which the snapshot does not carry, so after Isha begins the strip shows the
date instead of a countdown. During Fajr the countdown runs to Sunrise — the
end of Fajr's time — and Sunrise's time is bold, so the line and the row
agree.

The Kotlin decoder re-checks the invariants Dart enforces (ordered,
contiguous, never naming Sunrise) and refuses anything else: a decoder more
forgiving than the writer renders states the app considers impossible.

## Sizes

`PrayerWidget` (`prayer_widget_info.xml`, default 3×2):

| Size | Dimensions | Content |
|---|---|---|
| Compact | 150×100dp | current boundary, "next at HH:mm", region |
| Medium | 250×180dp | the five prayers plus Sunrise as a secondary row, region |
| Large | 250×320dp | date, all six rows, region + provider |

`PrayerStripWidget` (`prayer_strip_widget_info.xml`, default 4×1, min
240×40dp):

| Size | Dimensions | Content |
|---|---|---|
| Slim | 240×40dp | six names over six times |
| Headed | 240×50dp | plus a line above: countdown (or stale warning, or the date after Isha) and the region |

From 320dp wide the times grow from 13sp to 15sp. 240dp is the narrowest at
which "12:10" still fits its column. A stale schedule in the slim size shows
only the warning: six confident times under no warning is worse than the
warning alone.

An unavailable projection (no confirmed location or no reliable schedule)
renders only a localized message — never an invented time.

## Refresh

A Glance widget only compares the clock when something makes it draw. Three
things do:

1. **The app.** `WidgetSyncCoordinator` writes a snapshot and calls
   `updatePrayerWidget()`; `HomeWidgetBridge` sends that to **both** prayer
   receivers. (The vertical one was once left out of this nudge entirely and
   sat on Asr for days — `4af7451`. A test now names both receivers.)
2. **A boundary alarm** (`PrayerWidgetRefresh`). Every update books one alarm
   per receiver at `windowEndsAt(now)`. It is `setWindow` with plain `RTC`:
   inexact, so it needs no `SCHEDULE_EXACT_ALARM` permission, and non-waking,
   so it never wakes a sleeping phone — it is delivered when the screen next
   comes on. Android grants such an alarm a window of at least ten minutes
   (API 31+), so a redraw lands **within ten minutes after** a boundary, never
   before. Cancelled when the last widget of that kind is removed.
3. **`updatePeriodMillis` = 30 minutes**, Android's floor, as a backstop.

The strip's countdown is a platform `Chronometer` in count-down mode, the only
widget text that changes by itself. It does not stop at zero; until the
boundary alarm is delivered it can show a few minutes of negative time. That
is the known cost of not asking for the exact-alarm permission.

## Tap target

The entire surface of either widget is one `actionStartActivity<MainActivity>`
deep link to `murajaah://app/home`, with the shared `errorUiLayout` /
`onCompositionError` fallback. No `actionRunCallback`, no background action.

## Contract tests

- `test/core/widgets/prayer_widget_projection_test.dart` — the projection,
  the factory's windows, and the snapshot round trip.
- `test/core/widgets/home_widget_bridge_test.dart` — `updatePrayerWidget()`
  wakes both receivers.
- `test/android/widget_native_contract_test.dart` — both widgets are
  read-only and responsive, open only Home, decide nothing but compare the
  clock; both receivers book the boundary redraw; no exact alarm and no
  exact-alarm permission anywhere.
- `android/app/src/test/kotlin/.../PrayerBoundaryTest.kt` — JVM tests (run by
  `:app:testDebugUnitTest`) of the Kotlin comparisons on his own day: the
  countdown before Fajr, during Fajr (to Sunrise), between Sunrise and Dhuhr
  (nothing current, counting to Dhuhr), after Isha (no countdown, not to
  midnight), and the redraw instants.

## Primary references

Same as [ANDROID_WIDGETS.md](ANDROID_WIDGETS.md); no new external dependency
(JUnit 4 is test-only).
