# SurahCycle on iOS — state, gaps and standing rules

Written for: whoever takes the iOS build, including a future session of this
agent. It is the iOS counterpart of `AI_HANDOFF.md`, and it is kept the same
way — **read it completely before touching anything under `ios/`, reconcile it
with `git status`, `git log` and the tests, and update it before and after
every checkpoint and before ending a session.** Never mark anything here
verified that has not actually run on an Apple device or a simulator.

Nothing in this file has been built or run on Apple hardware. Every claim below
is read off the repository, and each one says how it was established.

**Two older iOS documents exist and are still worth reading, with one
correction each.** `IOS_TESTING.md` is the Mac setup and verification
procedure and is current. `IOS_WIDGET.md` is the WidgetKit plan; its
architecture section still holds, but it says the snapshot is **schema 2** and
it is schema **6** today (`WidgetSnapshot.schemaVersion`), and the prayer
projection it does not mention is now part of it. Its deployment-target point
is still live: `IPHONEOS_DEPLOYMENT_TARGET` is **13.0** in all three build
configurations, and `home_widget` 0.9.3 needs iOS 14 — so §2.3 below starts
with a product decision, not with Xcode.

---

## 1. Where iOS actually stands, 2026-10-09

`ios/` is the stock Flutter scaffold plus exactly one deliberate edit. 49 files,
40 of them tracked. `Runner.xcodeproj` and `Runner.xcworkspace` exist;
`AppDelegate.swift` is the generated one and registers the generated plugin
registrant and nothing else; `SceneDelegate.swift` is generated. There is **no
Swift of ours in the project at all** and no second target.

The one edit: `Info.plist` carries `NSLocationWhenInUseUsageDescription`,
`CFBundleDisplayName`/`CFBundleName` are `SurahCycle`, and the scene manifest is
the modern generated form.

**The app has never been built for iOS from this repository.** There is no
`Podfile`, no `Podfile.lock`, no `ios/Flutter/Flutter.podspec` beyond the
generated ephemerals, and no CI that compiles it. Treat the first
`flutter build ios` as an unknown, not as a formality.

### What already works on iOS by construction

The Dart side is platform-safe and was written that way on purpose, not by
luck. Verified by reading every platform branch in `lib/`:

| Area | Why it is safe |
| --- | --- |
| Database, rotation, recitations, learning, recall, statistics | Pure Dart and Drift. `drift_flutter` opens a file in the documents directory on both platforms. |
| Prayer times | `adhan_dart` is pure Dart; the Uzbek provider is HTTP; the cache is `dart:io` files. |
| Location | `geolocator` supports iOS and the usage description is already in `Info.plist`. |
| Account and sync | `appwrite` supports iOS — **but see §2.1, it cannot complete a sign-in yet.** |
| Learning notification channel | `MethodChannelLearningNotifications` returns early unless `defaultTargetPlatform == android`, and catches `MissingPluginException` besides. A no-op on iOS, never a crash. |
| Media-permission channel | Same two guards in `just_audio_playback.dart`. |
| Home-screen widgets | Every call is behind an Android check and uses `qualifiedAndroidName`. They simply do not exist on iOS. |
| Screensaver (DreamService) | Android-only by nature; there is no iOS equivalent and none is pretended. |

So the **first** iOS run should reach Home with real data. What it will not do
is sign in, play audio in the background, or show anything on the home screen.

---

## 2. Gaps, each with what it breaks and what it needs

Ordered by what stops a user, not by effort.

### 2.1 OAuth sign-in cannot return to the app — **blocker**

`Info.plist` has no `CFBundleURLTypes`. Appwrite's OAuth2 flow opens a browser
and comes back through a custom scheme; on Android that is handled by
`com.linusu.flutter_web_auth_2.CallbackActivity`, which **is** declared in
`AndroidManifest.xml`. The iOS half is missing, so the browser completes the
login and has nowhere to hand the session back to.

Needs: a URL type whose scheme is `appwrite-callback-<projectId>`. The project
id is public configuration and already lives in the build defines — do not
invent a second copy of it in the plist by hand without checking it against
`AppwriteConfig`.

Until this is done, every account feature on iOS ends at
«Не удалось связаться с аккаунтом», and the new paused-project card added on
2026-10-08 will not help, because the failure is local.

### 2.2 Background audio is declared on one platform only

`pubspec.yaml` depends on `just_audio_background`. Android has
`FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`. `Info.plist` has
no `UIBackgroundModes`, so recitation audio stops the moment the app leaves the
foreground and the lock-screen controls never appear.

Needs: `UIBackgroundModes` with `audio`, plus an `AVAudioSession` category set
at startup. Note that adding the background mode is an App Store review
question — the app must genuinely play audio in the background, which it does.

### 2.3 There are no iOS widgets, and that is three pieces of work, not one

Android has three Glance widgets (Rotation, Learning, Prayer) plus a
`DreamService`. iOS has none. `home_widget` supports iOS through a **WidgetKit
extension target plus an App Group**, which means (see `IOS_WIDGET.md` for the
fuller plan, corrected as above):

- the deployment target raised from **13.0** to 14, deliberately, in all three
  build configurations and the Podfile together, because `home_widget` 0.9.3
  requires iOS 14;
- a new target in `Runner.xcodeproj`, which does not exist yet;
- an App Group id shared by app and extension, and `HomeWidget.setAppGroupId`
  called before any `saveWidgetData` — **today nothing calls it**, so even with
  an extension present the snapshot would be written where the extension
  cannot read it;
- SwiftUI views that decode the same `WidgetSnapshot` JSON the Kotlin side
  decodes in `WidgetSnapshot.kt` (556 lines of strict validation). That
  validation is a contract, not an implementation detail: it rejects a snapshot
  with the wrong number of prayer entries, more than one current entry, or a
  boundary-only entry marked current. **An iOS decoder that is more forgiving
  than the Kotlin one is a bug**, because it will render states the app
  considers impossible.
- interactivity (marking a surah from the widget) is an Android-only mechanism
  here; on iOS it would be App Intents, and the headless path does not exist.

Do not start this before §2.1 and §2.2. A widget on a phone that cannot sign in
is the least useful thing to build first.

### 2.4 The silent Learning notification has no iOS half

`LearningNotificationManager.kt` posts a silent, opt-in notification on a
low-importance channel. On iOS this is `UNUserNotificationCenter` and a
permission request. The Dart interface (`LearningNotificationChannel`) is
already the right shape — implement it in Swift against the same three methods
and the opt-in rule holds without changing Dart.

**The owner's privacy choice travels with this**: `lock_screen_show_notifications
= 0` on his device is deliberate. An iOS implementation must not show the body
on a locked screen by default.

### 2.5 Nothing is known about iPad, Dynamic Type or VoiceOver

`UISupportedInterfaceOrientations~ipad` allows all four orientations and no
layout has ever been seen on an iPad. The app's one narrow-layout suite
(`test/widget/layout_at_phone_width_test.dart`) pins 411×914 — an Android
phone. Before claiming iPad support, add a case at iPad width to that suite;
it costs almost nothing because the suite asserts by overflow rather than by
hand.

---

## 3. Standing rules for iOS work

These are not style preferences. Each one has a reason in the Android history
of this repository.

1. **Do not change the bundle identifier, the Dart package name, the
   method-channel names, the Drift filenames or the widget snapshot schema**
   without a migration plan and the owner's confirmation. The channel names
   (`dev.murajaah.murajaah/learning_notifications`,
   `dev.murajaah.murajaah/media_permissions`) are a contract already honoured
   by Android.
2. **Swift never owns a resolver.** Which prayer is current, which day a mark
   belongs to, what the rotation owes — all of that is decided in Dart and
   travels in the snapshot. Kotlin follows this rule; Swift must too. See §4.1
   for what it costs and why it is still right.
3. **No secret in `Info.plist`, in an xcconfig or in Git.** The Appwrite project
   id and endpoint are public configuration; passwords, tokens and client
   secrets are not, and nothing of that kind may be committed, logged or
   printed.
4. **Never weaken the snapshot validation to make a Swift decoder pass.** If the
   two platforms disagree about a snapshot, the snapshot is wrong.
5. **A test that fails first, or it did not fix anything.** Every defect in this
   project is repaired by watching a test go red against the old code. A Swift
   change without an iOS test is at least accompanied by a Dart test of the
   contract it depends on.
6. **Never claim "verified on a device"** unless it ran on one, and say which.

---

## 4. Cross-platform findings that an iOS reader needs

### 4.1 The prayer widget's highlight cannot be correct without a scheduled refresh

Found and half-fixed on 2026-10-09. The snapshot has carried a prayer
projection since schema 6, and `WidgetSyncCoordinator` nudged the rotation and
learning receivers only — the prayer receiver was never told, and
`prayer_widget_info.xml` sets `updatePeriodMillis="0"`, so Android had no
schedule either. The widget rendered once and kept that frame: whichever prayer
was current when the launcher built it stayed highlighted. The owner reported
exactly that.

The nudge is now sent (`updatePrayerWidget`, with a test that was watched
failing). **That only fixes the case where the app runs.** `isCurrent` and
`isNext` are flags in the snapshot, by rule 2 above, so with the app closed the
highlight still cannot move on its own.

This is the one place where "the platform never owns a resolver" costs
correctness, and iOS will meet it in exactly the same form — a WidgetKit
timeline is built from data the app supplied. The honest options are a
scheduled rebuild (AlarmManager / WorkManager on Android, a WidgetKit timeline
with entries at each boundary on iOS) or letting the platform pick the current
entry from boundary times the snapshot already carries. **Not yet decided.**
Whoever decides it should decide it for both platforms at once.

### 4.2 What the app already enforces that a port must not lose

- Qada exists only for the five Fard prayers and for Witr/Wajib.
- "Followed the imam" completes a part and creates **no** recitation event.
- A recall attempt never creates or cancels a recitation.
- Al-Fatiha never enters rotation.
- Global rotation debt and the fullness of a prayer's slots are different
  questions and must not be shown as one. (Two green indicators on one row
  already caused one report.)
- A mark between midnight and Fajr belongs to the night that is ending, not to
  the calendar day.

---

## 5. Suggested order

1. §2.1 sign-in, because nothing else about the account can be tested without it.
2. A first `flutter build ios` and a simulator run of the local-only app, with
   whatever that turns up written down here.
3. §2.2 background audio.
4. §2.5 an iPad case in the narrow-layout suite.
5. §4.1 decided for both platforms.
6. §2.3 widgets, last and largest.
7. §2.4 the notification.

---

## 6. Log

Append here. Newest first, one entry per checkpoint, each saying what was
verified and how.

- **2026-10-09** — file created. Nothing built, nothing run on Apple hardware.
  Findings above are from the repository: `ios/` inventory, `Info.plist` keys,
  every `defaultTargetPlatform` branch in `lib/`, the Android manifest and the
  three `appwidget-provider` XML files.
