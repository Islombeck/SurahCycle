# Android home-screen widgets

## Status

Murajaah ships two native Android home-screen widgets:

- **Rotation** — a scrollable due-only list. Up to eight ranked
  recommendations appear first, followed by other due rows and an
  `Ещё N` footer.
- **Learning** — selected surah, stage, cumulative range and up to three
  coordinate-bound ayah blocks with Arabic, transliteration and translation
  according to the same three display settings as the app.

Rotation has a direct mark control. The circular control marks in a headless
Dart callback without opening the app; the row text still opens the appropriate
surah/part. Learning remains navigation-only.

The project pins `home_widget 0.9.3` and
`androidx.glance:glance-appwidget:1.1.1`. Kotlin 2.3.20 uses the
Compose compiler plugin. Current Android configuration keeps the Flutter
min/target/compile SDK values and JVM 17.

## Ownership boundary

`text
Drift/domain/Quran/prayer streams
                 |
                 v
       Dart projection builders
                 |
                 v
       WidgetSnapshot schema 3
                 |
                 v
 home_widget SharedPreferences bridge
          |                    |
          v                    v
 Rotation Glance        Learning Glance
 display + transport      display only
          |
          v
 official home_widget background callback
          |
          v
 RecitationApplicationService + Drift transaction
`

Dart owns sorting, rank, debt, eligible actions, localized labels, Quran layer
selection, Prayer Context and all mutation rules. Kotlin validates a
denormalized snapshot, renders it and transports a prebuilt action. It never
opens Drift or reimplements `RotationEngine`.

The shared snapshot key is `murajaah_widget_snapshot`. Malformed JSON,
unknown schema, unsafe deep links, duplicate IDs/tokens, unreasonable payloads
or native composition errors fail closed to localized fallback UI.

## Snapshot schema 3

The current contract adds:

- optional structured action per Rotation row;
- structured Learning ayah lines bound by surah/ayah coordinates;
- independent `showArabic`, `showTransliteration` and
  `showTranslation` flags;
- exact transliteration/translation fields without generated substitutes.

Abbreviated example:

`json
{
  "schemaVersion": 3,
  "generatedAtUtc": "2026-08-26T10:00:00.000Z",
  "locale": "ru",
  "rotation": {
    "items": [{
      "id": "scheme-id:part:2",
      "surahId": "2",
      "partId": "part-id",
      "title": "2. Бакара",
      "subtitle": "Часть 2/4 · аяты 72–141",
      "remaining": 2,
      "debtLabel": "2×",
      "recommendationRank": 0,
      "deepLink": "murajaah://app/surah/2?part=part-id",
      "action": {
        "schemaVersion": 1,
        "actionToken": "00000000-0000-4000-8000-000000000001",
        "surahId": "2",
        "rotationSchemeId": "scheme-id",
        "partId": "part-id"
      }
    }],
    "omittedCount": 0
  },
  "learning": {
    "item": {
      "surahId": "112",
      "surahNumber": 112,
      "startAyah": 1,
      "endAyah": 3,
      "title": "112. Ихляс",
      "stageLabel": "Накопительно",
      "rangeLabel": "Аяты 1–3",
      "showArabic": true,
      "showTransliteration": true,
      "showTranslation": true,
      "ayahLines": [{
        "surah": 112,
        "ayah": 1,
        "arabic": "exact verified source text",
        "transliteration": "exact verified source text",
        "translation": "exact verified cached source text"
      }],
      "deepLink": "murajaah://app/learning/112"
    }
  }
}
`

Actual Quran strings are never examples hardcoded in production. Arabic comes
from the pinned Tanzil Uthmani corpus, transliteration from the pinned Tanzil
English Transliteration asset, and translation only from the selected verified
QuranEnc cache. Missing layers remain absent.

Native decoder accepts schema 2 only as a display-only migration input and
schema 3 as current. Dart reads/writes schema 3. Dynamic Glance IDs are masked
outside the reserved range and checked for collisions.

## Synchronization

`WidgetSyncCoordinator` debounces foreground stream emissions for
150 ms, serializes writes, collapses pending work to the newest projection and
skips unchanged content even if generation time changed. Recalculation occurs
after app startup, locale/content/display-setting changes and every mutation
affecting rotation or learning.

An interactive outcome performs an immediate zero-debounce rebuild from the
database. A widget bridge error never rolls back a valid domain transaction.
Learning content already present in the snapshot is preserved when a lightweight
interactive refresh cannot initialize Quran repositories.

## Interaction

The Rotation circle uses Glance `actionRunCallback` and
`HomeWidgetBackgroundIntent`. The body uses explicit
`actionStartActivity<MainActivity>` deep links. Headers, footer and
Learning content also open the app. `flutter_deeplinking_enabled=false`
prevents duplicate Flutter routing.

Exact-once semantics, stale validation and the no-network execution path are
specified in
[INTERACTIVE_ANDROID_WIDGET.md](INTERACTIVE_ANDROID_WIDGET.md).

Both provider receivers are exported only for `APPWIDGET_UPDATE`.
The background receiver is supplied by home_widget. No browsable custom-scheme
intent filter exposes MainActivity.

## Composition fallback

Both widgets override Glance `onCompositionError`, log the widget type,
appWidgetId and throwable under `MurajaahWidget`, and render the local
`widget_error.xml` fallback. The fallback opens Murajaah but does not
mutate data.

## Build

Focused commands:

`powershell
flutter test --no-pub test/core/widgets test/android
android\gradlew.bat -p android testDebugUnitTest
flutter build apk --debug --no-pub
`

On this checkout the physical path contains Cyrillic and a backtick. Android
CMake/AGP tooling requires the existing ASCII junction and, for APK builds, a
temporary ASCII drive mapping:

`powershell
subst M: D:\MurajaahWorkspace
Set-Location M:\
$env:PUB_CACHE = 'M:\.tools\pub-cache'
flutter pub get
flutter build apk --debug --no-pub
`

Leave `M:\` before running `subst M: /D`. This workaround
does not change sources and is unnecessary in a normal ASCII checkout.

## Physical-device QA

When ADB exposes a device, verify:

1. localized picker names/previews and resize behavior;
2. scrolling to the final due/Learning item;
3. rank order and absence of closed/ahead rows;
4. circle mark without Activity in foreground, background, swiped-away and
   killed states;
5. double tap creates one event and a later newly published token works;
6. text tap opens the correct row without marking;
7. History contains the widget-created event; Delete refreshes the widget;
8. manual and reliable automatic Prayer Context attribution;
9. malformed/unknown snapshot and forced composition fallbacks;
10. RU/EN/UZ native strings;
11. tap → database → launcher refresh latency.

If no physical device appears in `adb devices`, these items remain
unverified; desktop tests and APK compilation are not reported as device QA.

## Primary references

- [home_widget package](https://pub.dev/packages/home_widget)
- [home_widget Android setup](https://docs.page/ABausG/home_widget/setup/android)
- [home_widget interactive widgets](https://docs.page/ABausG/home_widget/features/interactive-widgets)
- [AndroidX Glance release notes](https://developer.android.com/jetpack/androidx/releases/glance)
- [Glance UI](https://developer.android.com/develop/ui/compose/glance/build-ui)
- [Glance interactions](https://developer.android.com/develop/ui/compose/glance/user-interaction)
- [Android unsafe deep-link guidance](https://developer.android.com/privacy-and-security/risks/unsafe-use-of-deeplinks)
