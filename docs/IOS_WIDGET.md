# Future iOS WidgetKit integration

## Sprint 2 boundary

No WidgetKit extension or Xcode project edit is made on Windows. The platform-neutral Dart snapshot, projection builder, and deep-link contract are ready for a separate Mac/Xcode implementation and validation pass. This avoids hand-editing `.xcodeproj`, signing settings, capabilities, and extension targets that cannot be built here.

`home_widget` 0.9.3 requires iOS 14+, while Murajaah currently declares iOS 13.0. Before running CocoaPods on a Mac, make an explicit product decision to raise the application deployment target to iOS 14, then update the Podfile, Runner target, and future extension target together. Until that verified migration, Android-only code must instantiate the live `HomeWidgetBridge`/coordinator conditionally rather than attempting an iOS widget refresh.

## Proposed architecture

1. In Xcode, create a Widget Extension with SwiftUI/WidgetKit and the same minimum iOS version as Runner.
2. Add one App Group, for example `group.dev.murajaah.murajaah.widgets`, to Runner and the extension. Never reuse standard per-process `UserDefaults`.
3. Configure `HomeWidget.setAppGroupId` in the Flutter iOS startup path after the entitlement exists.
4. Persist the same `murajaah_widget_snapshot` schema 2 JSON into the App Group. Do not create an iOS-specific domain projection.
5. Decode `schemaVersion` strictly in Swift. Missing, malformed, or unknown data renders a localized **Open Murajaah** fallback.
6. Implement separate Rotation and Learning widget kinds. WidgetKit families determine how many due rows or Quran lines fit; the logical snapshot remains complete.
7. After a successful shared write, reload only those widget timelines whose projection changed. Timeline entries may reuse the latest persisted snapshot because domain streams, not periodic prediction, own freshness.
8. Use `.widgetURL`/`Link` only to open the app. Do not add interactive recitation marking.

## Shared deep links

WidgetKit must emit the same allowlisted links as Android:

- `murajaah://app/home`
- `murajaah://app/surah/<surahId>`
- `murajaah://app/surah/<surahId>?part=<partId>`
- `murajaah://app/learning/<surahId>`

Runner should feed cold and warm URLs into the shared `WidgetDeepLink.parse` contract, then validate IDs against repositories before navigating. Do not maintain a looser Swift-only route grammar.

## Quran content rule

Swift must render only `verifiedTextLines` already placed into the snapshot from the fully validated bundled Tanzil repository. Preserve every string exactly: no generation, translation, transliteration, whitespace trimming, or Unicode normalization. If the list is empty, render `rangeLabel` plus `unavailableTextLabel`.

## Mac validation checklist

- Raise and verify the deployment target deliberately; run `pod install` and build Runner plus both extensions.
- Verify App Group entitlements and shared JSON access in Debug and Release signing configurations.
- Test new install, upgrade, missing snapshot, malformed JSON, and unknown schema.
- Test all supported families, Dynamic Type, light/dark appearance, RU/EN/UZ, and right-to-left Quran text layout.
- Test cold/warm links for home, whole surah, split part IDs containing colons, and learning.
- Confirm timeline reload after every Rotation/Learning/cache trigger and after Undo.
- Confirm widget taps never write recitation/history data.

Relevant references: [home_widget iOS setup](https://docs.page/ABausG/home_widget/setup/ios), [home_widget 0.9 migration](https://docs.page/ABausG/home_widget/migrations/0.9.0), [Apple App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), and [Apple WidgetKit](https://developer.apple.com/documentation/widgetkit).
