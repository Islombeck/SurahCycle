# Learning on the lock screen

## Status

Three optional, opt-in ways to see the current Learning stage without
opening the app. All three are read-only projections of the same
`WidgetSnapshot.learning` content the Learning widget already renders; none
of them adds a second resolver, a second source of truth, or any
alarm/wake behavior.

| Surface | Default | Where it lives |
|---|---|---|
| Learning home-screen widget | already shipped | launcher home screen, not the lock screen |
| Quiet Learning notification | off | notification shade, optionally visible on the lock screen per OS setting |
| `MurajaahDreamService` screensaver | off, OS-picked | Settings > Display > Screen saver |

## Honest platform limitation: no lock-screen widget

Modern Android (since API 21) removed the "keyguard widget" API that older
Android versions used to show home-screen-style widgets directly on the
lock screen. There is no supported, non-bypass way for a third-party app to
place `RemoteViews`/Glance content on the lock screen itself on current
Android. This document does not claim otherwise, and Murajaah does not ship
a fake or best-effort implementation of it. The two things that follow —
the notification and the DreamService — are the actual OEM-supported
surfaces for "something visible without unlocking," and both route through
mechanisms the OS itself controls.

## Quiet Learning notification

`LearningNotificationManager.show`/`.cancel` (Kotlin) and
`LearningNotificationController`/`MethodChannelLearningNotifications`
(Dart, `lib/app/app_providers.dart` and
`lib/core/widgets/learning_notification_channel.dart`) implement a single
persistent, silent notification showing the current Learning item's title
and stage/range label.

- **Off by default.** `learningNotificationEnabledProvider` reads a plain
  boolean app setting (`learningNotificationEnabled`, default `false`).
  Nothing shows until the user turns the Settings switch on.
- **Permission requested only at opt-in.** `LearningNotificationController.
  setEnabled(true)` is the only place `POST_NOTIFICATIONS` is ever
  requested, via the same shared `requestNotificationPermission` helper in
  `MainActivity.kt` already used by the media-playback notification. A
  denial leaves the setting off and cancels any pending notification; it is
  never retried silently.
- **Silent by construction.** The `learning_quiet` channel is created with
  `NotificationManager.IMPORTANCE_LOW`, and every post additionally sets
  `.setSilent(true)`, `enableVibration(false)`, `enableLights(false)`, and
  no badge. There is no sound, no vibration, no heads-up interruption.
- **Refreshed, not scheduled.** `_AppWidgetSyncDriver._syncLearningNotification`
  re-shows (or cancels) the notification every time the widget snapshot is
  rebuilt — the same trigger points as the widgets, not a separate timer or
  alarm.
- **Lock-screen visibility is an OS setting, not this app's.** Whether the
  notification's content is visible on the lock screen when the device is
  locked is controlled by the user's system notification privacy setting
  (Settings > Notifications > lock screen), which Murajaah does not
  override, alter, or promise to change from this document — it only
  supplies a normal `NotificationCompat` notification and lets the OS
  decide.

## `MurajaahDreamService` screensaver

`android/app/src/main/kotlin/dev/murajaah/murajaah/widget/MurajaahDreamService.kt`
is a standard Android `DreamService` (the API behind "Screen saver" /
"Daydream"). It is registered in the manifest with
`android:permission="android.permission.BIND_DREAM_SERVICE"` and an
`@xml/dream_info` descriptor, exactly like any other screensaver.

Explicit prohibitions, all verified by
`test/android/widget_native_contract_test.dart`'s
`DreamService is opt-in, read-only, and never bypasses the lock screen`
case:

- no request to appear above the keyguard (no `showWhenLocked`/
  `FLAG_SHOW_WHEN_LOCKED`);
- no full-screen intent (`setFullScreenIntent`);
- no overlay drawn before unlock;
- no Accessibility Service or Device Admin usage anywhere in this class;
- no self-triggered wake (`WAKE_LOCK`/`PowerManager` do not appear here —
  the system alone decides when a dream starts, on charging/docking per the
  user's own Screen saver setting);
- no infinite wakelock;
- no `RecitationRepository`/Drift access — it only reads the same
  `WIDGET_SNAPSHOT_KEY` preference the Learning widget reads.

`isInteractive = false` means any touch lets the system dismiss the dream
through its own normal handling; this app never intercepts or overrides
that dismissal. Content is the current Learning item's first Arabic ayah
line plus its title, or a localized empty state — nothing else.

There is **no in-app toggle** for this screensaver. The only way a user
enables it is the standard OS picker at Settings > Display > Screen saver,
which is intentional: Murajaah does not request or imply any elevated
capability to auto-start or control when a dream shows.

## Non-goals

- No lock-screen bypass of any kind, on any of the three surfaces above.
- No adhan-style alarm or scheduled wake to show any of this content.
- No use of `Accessibility Service`, `Device Admin`, or any permission
  beyond `POST_NOTIFICATIONS` (already requested for the existing media
  notification) and the standard `BIND_DREAM_SERVICE` system permission.

## Contract tests

`test/android/widget_native_contract_test.dart` has two dedicated cases:
`the Learning notification is silent, opt-in, and never posts on its own`
and `DreamService is opt-in, read-only, and never bypasses the lock
screen`. `test/app/learning_notification_controller_test.dart` and
`test/widget/learning_notification_settings_card_test.dart` cover the
Dart-side opt-in/permission-denied/opt-out state machine with a fake
channel, independent of any real Android permission dialog.
