# Prayer Times widget

## Status

Murajaah's third native Android home-screen widget shows today's six daily
boundaries — Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha — with the current and
next boundary visually distinct. It reuses the same `PrayerTime`/schedule
architecture as Home and the manual Prayer Context: there is no second
resolver, no second schedule source, and no widget-only time calculation.

The widget is read-only. It never marks a recitation, never writes to the
database, and its only interaction is a whole-surface tap that opens Home.

## Ownership boundary

```text
prayerTodayScheduleProvider / prayerScheduleContextResolutionProvider
                 |
                 v
       PrayerWidgetProjectionFactory (Dart, pure formatting)
                 |
                 v
       PrayerWidgetProjection (part of WidgetSnapshot schema 6)
                 |
                 v
 home_widget SharedPreferences bridge
                 |
                 v
        PrayerWidget Glance rendering (Kotlin)
```

`PrayerWidgetProjectionFactory` (`lib/core/widgets/prayer_widget_projection_factory.dart`)
does not decide which boundary is current or next, and does not decide
staleness. Those are the existing schedule/context resolvers' job; the
factory only formats the six already-resolved boundaries
(`PrayerWidgetBoundary`) into display entries and asserts the invariants the
schema requires (exactly six entries, at most one current, at most one
next, a boundary-only entry — Sunrise — can never be current/next). Kotlin
renders `NativePrayerProjection`/`NativePrayerEntry` and owns no schedule
logic, no Drift access, and no `RecitationRepository` reference.

## Sizes

`PrayerWidget.kt` uses Glance `SizeMode.Responsive` over three fixed sizes:

| Size | Dimensions | Content |
|---|---|---|
| Compact | 150×100dp | title, current boundary, "next at HH:mm", region |
| Medium | 250×180dp | all five prayer rows plus Sunrise as a secondary row, region |
| Large | 250×320dp | date, all six rows (Sunrise included at full weight), region + provider |

An unavailable projection (`PrayerWidgetProjection.unavailable`, no
confirmed location or no reliable schedule yet) renders only the title and a
localized message — never an invented time. A stale projection renders an
extra warning line above the normal content; `allowsRotationAutoMark` is
`false` whenever the projection is stale or unavailable, matching Rotation
Widget's existing stale-schedule fail-closed rule.

## Tap target

The entire widget surface is one `actionStartActivity<MainActivity>` deep
link to `murajaah://app/home`, using the same `errorUiLayout`/
`onCompositionError` fallback pattern as Rotation and Learning. There is no
`actionRunCallback` and no background action: unlike Rotation's mark
circle, nothing here writes to the database, so there is nothing to
transport headlessly.

## Refresh

The widget has no periodic self-refresh (no WorkManager job), matching
Rotation and Learning widgets today: all three are rebuilt only when
`WidgetSyncCoordinator` publishes a new snapshot after an app-triggered
recalculation (startup, locale/content/display-setting changes, and any
mutation affecting rotation, prayer routines or learning). Since the
schedule itself only changes at day boundaries and on explicit
location/method changes, this is judged sufficient for now; a periodic
refresh can be added later without changing the schema if launcher staleness
turns out to be a real problem in physical-device QA.

## Contract tests

`test/core/widgets/prayer_widget_projection_test.dart` covers the
`PrayerWidgetProjection`/`PrayerWidgetTimeEntry` invariants, the factory's
formatting and current/next flagging, and a schema round-trip through the
snapshot codec. `test/android/widget_native_contract_test.dart` asserts the
Kotlin widget is size-responsive, contains no `RecitationRepository`/
`ActionCallback`/`actionRunCallback` reference, and opens only
`murajaah://app/home`.

## Primary references

Same as [ANDROID_WIDGETS.md](ANDROID_WIDGETS.md); this widget adds no new
external dependency.
