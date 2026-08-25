# Android home-screen widgets

## Status and compatibility

Sprint 2 ships two real Android widgets:

- **Rotation**: the complete scrollable list of due whole surahs and parts. Recommended rows are first; completed and ahead rows are absent.
- **Learning**: the selected surah, stage, cumulative ayah range, and exact verified cached Quran text when the application explicitly supplies it.

The bridge is pinned to `home_widget: 0.9.3`. That release supports AGP 9 and requires Flutter 3.38.1+/Dart 3.10+; Murajaah uses Flutter 3.44.7/Dart 3.12. Android UI uses the current stable Glance line, `androidx.glance:glance-appwidget:1.1.1`, pinned directly in the app. Glance 1.2 is only a release-candidate line, while the 1.3 alpha line raises the SDK/tooling closure, so neither is appropriate for the current compileSdk 36/AGP 9.0.1 build.

The project keeps minSdk 24 and targetSdk 36. `home_widget` 0.9.3 also brings WorkManager 2.11.2, whose minimum is API 23, so the dependency closure does not require a minSdk increase.

Kotlin 2.3.20 applies `org.jetbrains.kotlin.plugin.compose` rather than the removed legacy Compose compiler configuration. The project still opts out of AGP built-in Kotlin in `android/gradle.properties`; `home_widget` 0.9.3 detects that migration mode and applies Kotlin correctly. Gradle warns that the opt-out is deprecated for AGP 10, but the current AGP 9 build compiles.

## Ownership boundary

```text
Drift/domain streams
        |
        v
WidgetProjectionBuilder (Dart: all calculations and display labels)
        |
        v
WidgetSnapshot schemaVersion 1 JSON
        |
        v
home_widget SharedPreferences bridge
        |
        +--> RotationWidget (Kotlin/Glance: display only)
        `--> LearningWidget (Kotlin/Glance: display only)
```

Kotlin never opens Drift, reimplements `RotationEngine`, evaluates `LearningStateMachine`, sorts recommendations, calculates debt, invents Quran content, or marks a recitation. It only validates and displays a denormalized snapshot.

The shared key is `murajaah_widget_snapshot`. Missing JSON, malformed JSON, duplicate IDs, unsafe links, an unreasonable payload, or an unknown `schemaVersion` fails closed to a localized **Open Murajaah** state. RU, EN, and UZ native strings live in `values-ru`, default `values`, and `values-uz`.

## Dart API and integration

Import `package:murajaah/core/widgets/widgets.dart`.

1. Adapt the latest repository projections into `RotationWidgetCandidate.whole(...)` and `.part(...)`. `remaining` may be negative, but `WidgetProjectionBuilder` emits only `remaining > 0`.
2. Mark the recommendation set with `isRecommended`. The builder orders recommendation first, then greater debt, never/oldest use, `displayOrder`, surah number, and part index.
3. Adapt the selected learning state into `LearningWidgetCandidate`. Pass the already localized `stageLabel` and cumulative `startAyah`/`endAyah`.
4. Pass Quran strings through `verifiedTextLines` only after the Quran cache repository has verified the source. An empty list displays `openAppToLoadText`; no layer generates substitute Arabic.
5. Create one root-lifetime `WidgetSyncCoordinator(bridge: const HomeWidgetBridge())`. Feed it recomputed snapshots with `schedule`; use `syncNow` for an explicit startup flush. Call `dispose` from the owner.

`WidgetSyncCoordinator` debounces rapid stream emissions for 150 ms, serializes native writes, collapses pending work to the newest projection, and skips an unchanged projection even if `generatedAtUtc` changed. A bridge error is reported through `onError` and does not participate in a domain transaction.

The application owner must recompute after startup and after every mutation affecting either projection:

- recitation, Undo, history deletion, balance adjustment;
- mastered-surah add, activation/deactivation, alias, reorder;
- split scheme or part progress changes;
- learning selection, repeat/learn action, inactivity rollback, Undo rollback, completion;
- verified Quran cache load/update;
- locale change.

The coordinator deliberately accepts application-layer DTOs rather than importing provider or Drift types. This keeps the snapshot stable while DB/domain models evolve.

## Snapshot contract

Schema 1 contains display-ready data:

```json
{
  "schemaVersion": 1,
  "generatedAtUtc": "2026-08-25T10:00:00.000Z",
  "locale": "ru",
  "rotation": {
    "items": [{
      "id": "scheme-uuid:part:2",
      "surahId": "2",
      "partId": "scheme-uuid:part:2",
      "title": "2. Бакара",
      "subtitle": "Часть 2/4 · аяты 72–141",
      "remaining": 2,
      "debtLabel": "2×",
      "isRecommended": true,
      "deepLink": "murajaah://app/surah/2?part=scheme-uuid%3Apart%3A2"
    }]
  },
  "learning": {
    "item": {
      "surahId": "112",
      "title": "112. Ихляс",
      "stageLabel": "Накопительно",
      "rangeLabel": "Аяты 1–3",
      "unavailableTextLabel": "Отройте приложение для загрузки текста",
      "verifiedTextLines": [],
      "deepLink": "murajaah://app/learning/112"
    }
  }
}
```

An empty learning projection is `{}`. `verifiedTextLines` is serialized and rendered without trimming or Unicode normalization. The native parser caps the overall payload and collection sizes above the Quran domain maximum to guard the launcher process; it does not arbitrarily truncate a valid due list.

## Widgets and interaction

Both receivers extend `HomeWidgetGlanceWidgetReceiver` and use `HomeWidgetGlanceStateDefinition`. Both widget-provider XML files set `updatePeriodMillis=0`, horizontal/vertical resize, home-screen category, preview layouts, and practical min/target cell sizes. Flutter stream changes drive refreshes; periodic polling does not.

Both bodies are Glance `LazyColumn`s. Rotation passes every due row into the collection instead of taking the first three. Learning scrolls verified text lines when the launcher viewport is small. Launcher support ultimately controls collection scrolling and exact resize increments.

Every tap is an `actionStartActivity<MainActivity>`:

- `murajaah://app/home`
- `murajaah://app/surah/<surahId>`
- `murajaah://app/surah/<surahId>?part=<partId>`
- `murajaah://app/learning/<surahId>`

There is no callback, background isolate, checkbox, or native mutation action. `flutter_deeplinking_enabled=false` ensures the Flutter engine does not also route the same URI. The application consumes the single source through `HomeWidgetBridge.initiallyLaunchedFromWidget()` (cold start) and `HomeWidgetBridge.clicks` (already running). Both pass through the strict Dart allowlist. Before routing, the integration layer must still verify that the referenced surah/part exists and is currently valid.

The `MainActivity` widget action is explicit and is not exposed as a browsable web/custom-scheme intent filter. Receivers must be exported so Android launchers can update them, but they declare only `APPWIDGET_UPDATE` and perform no writes.

## Build and QA

Focused verification:

```powershell
flutter test --no-pub test/core/widgets
./android/gradlew.bat -p android :app:compileDebugKotlin
flutter build apk --debug --no-pub
```

On this Windows checkout, AGP resolves a directory junction back to the physical Cyrillic path and its CMake command formatter rejects the backtick in that path. Use a temporary ASCII drive mapping for Android builds; it changes no source files:

```powershell
subst M: D:\MurajaahWorkspace
Set-Location M:\
$env:PUB_CACHE = 'M:\.tools\pub-cache'
flutter pub get
flutter build apk --debug --no-pub
```

`flutter pub get` is required once on the mapped drive so generated plugin paths use the same drive root. `android.overridePathCheck=true` permits this checkout layout, and `kotlin.compiler.execution.strategy=in-process` prevents Kotlin incremental-cache alias collisions between the physical and mapped paths. On a normal ASCII checkout, no `subst` workaround is needed. Remove the temporary mapping later with `subst M: /D` only after leaving that drive.

Required physical-device QA:

1. Add both picker entries and confirm localized names/previews.
2. Resize each horizontally and vertically on the target launcher.
3. Populate more rows than fit; scroll to the final due item.
4. Confirm recommended rows precede other due rows and closed/ahead items never appear.
5. Tap headers, whole rows, part rows, learning metadata, verified text, and footer during cold and warm app states.
6. Confirm a tap only navigates and never creates a recitation.
7. Trigger each refresh event above, including recitation and Undo, and confirm immediate widget updates.
8. Test absent, deliberately malformed, and unknown-version snapshot fallbacks.
9. Switch Android among RU, EN, and UZ and check native fallback/picker text.

## RemoteViews contingency

Glance 1.1.1 and the Compose compiler plugin compile successfully in the current project, so Glance is the selected implementation. If a future AGP/Kotlin upgrade makes its dependency closure untenable, native `RemoteViews` plus a `RemoteViewsService` collection is the conservative Android fallback: it avoids Compose compiler integration and has a longer compatibility history.

However, merely changing the two UI receivers to `RemoteViews` does **not** remove Glance from the graph because `home_widget` itself currently declares `glance-appwidget:1.1.1`. Removing the closure completely would require a verified newer bridge release, a narrowly maintained bridge fork, or a small project-owned MethodChannel/SharedPreferences bridge. Do not make that migration pre-emptively while the pinned stable stack builds.

## Primary sources checked 2026-08-25

- [home_widget package and requirements](https://pub.dev/packages/home_widget)
- [home_widget changelog](https://pub.dev/packages/home_widget/changelog)
- [home_widget 0.9.3 Android dependency file](https://raw.githubusercontent.com/ABausG/home_widget/home_widget-v0.9.3/packages/home_widget/android/build.gradle)
- [home_widget Android setup](https://docs.page/ABausG/home_widget/setup/android)
- [home_widget click detection](https://docs.page/ABausG/home_widget/features/detect-clicks)
- [AndroidX Glance release notes](https://developer.android.com/jetpack/androidx/releases/glance)
- [Official Glance setup](https://developer.android.com/develop/ui/compose/glance/setup)
- [Official Glance UI and lazy collections](https://developer.android.com/develop/ui/compose/glance/build-ui)
- [Official Glance interactions](https://developer.android.com/develop/ui/compose/glance/user-interaction)
- [Android widget collection guidance](https://developer.android.com/develop/ui/views/appwidgets/collections)
- [Kotlin Compose compiler migration](https://kotlinlang.org/docs/compose-compiler-migration-guide.html)
- [Android unsafe deep-link guidance](https://developer.android.com/privacy-and-security/risks/unsafe-use-of-deeplinks)
