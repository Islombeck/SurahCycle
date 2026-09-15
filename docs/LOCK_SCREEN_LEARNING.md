# Learning on the lock screen

## Status

Three optional, opt-in ways to see the current Learning stage without
opening the app. All three are read-only projections of the same
`WidgetSnapshot.learning` content the Learning widget already renders; none
of them adds a second resolver, a second source of truth, or any
alarm/wake behavior.

Three different surfaces are involved here and they are constantly confused
with one another, so the distinction is the first thing this document states:

| Surface | What it actually is | Default | Where it lives | Can it appear on the lock screen? |
|---|---|---|---|---|
| Learning home-screen widget | an App Widget (`RemoteViews`/Glance) owned by the launcher | already shipped | launcher **home** screen | **No.** Modern Android has no keyguard-widget API — see below |
| Quiet Learning notification | an ordinary silent `NotificationCompat` post | off | notification shade | **Only if the OS is configured to show notifications there**, which is the user's setting, not this app's |
| `MurajaahDreamService` screensaver | an Android `DreamService` | off, OS-picked | Settings > Display > Screen saver | **No.** It is a screensaver, and it ends when the device locks |

A screensaver is not a lock screen. `DreamService` is started by the system
when the device is idle while charging or docked, according to the user's own
Screen saver settings. It is **not** the screen you get when you press the
power button, and nothing in this app can make it be.

## Honest platform limitation: no lock-screen widget

Modern Android (since API 21) removed the "keyguard widget" API that older
Android versions used to show home-screen-style widgets directly on the
lock screen. There is no supported, non-bypass way for a third-party app to
place `RemoteViews`/Glance content on the lock screen itself on current
Android. This document does not claim otherwise, and SurahCycle does not ship
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
  (Settings > Notifications > lock screen), which SurahCycle does not
  override, alter, or promise to change from this document — it only
  supplies a normal `NotificationCompat` notification and lets the OS
  decide.

### What the notification actually contains

This is worth stating exactly, because "показывать аят на экране блокировки"
is easy to read as a promise of Arabic scripture, and that is **not** what
ships. Verified on the device on 2026-09-15:

```text
android.title = "89. Al-Fajr"
android.text  = "Новый аят 8 · Аят 8"
```

It carries the **surah, the learning stage and the ayah coordinates** — what
to review. It does **not** carry the Arabic text of the ayah. The
`MurajaahDreamService` screensaver is the surface that renders the actual
Arabic line; the notification deliberately does not, because a notification is
posted into a shade that may be visible to anyone glancing at the device, and
the coordinates are the useful part anyway.

The posted record, read back from `dumpsys notification`:

```text
id=7001 channel=learning_quiet importance=2 category=reminder groupKey=silent
vibrate=null sound=null defaults=0 flags=ONLY_ALERT_ONCE
vis=PRIVATE  publicNotification=None  fullscreenIntent=null
```

`vis=PRIVATE` with no public version means that on a device configured to hide
sensitive content on the lock screen, the OS shows its own generic placeholder
rather than the title and text. That is the correct behaviour and is not
worked around.

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
which is intentional: SurahCycle does not request or imply any elevated
capability to auto-start or control when a dream shows.

## Non-goals

- No lock-screen bypass of any kind, on any of the three surfaces above.
- No adhan-style alarm or scheduled wake to show any of this content.
- No use of `Accessibility Service`, `Device Admin`, or any permission
  beyond `POST_NOTIFICATIONS` (already requested for the existing media
  notification) and the standard `BIND_DREAM_SERVICE` system permission.

## Device verification (2026-09-15, Unihertz Jelly Max, Android 15)

Run over ADB on the owner's own phone, not inferred from unit tests.

**DreamService — works.** It appears in Settings > Заставка as **SurahCycle**,
selecting it sets

```text
screensaver_components = dev.murajaah.murajaah/dev.murajaah.murajaah.widget.MurajaahDreamService
```

and the preview renders the current learning ayah (89:8 Arabic plus
`89. Al-Fajr`) on a dark background, read-only, with no controls. During the
run `dumpsys dreams` reported `canDoze=false, isDozing=false`. Locking the
device ended it: `mCurrentDream=null`, `mShowingDream=false`,
`isKeyguardShowing=true` — **the screensaver does not cover or bypass the lock
screen**, proved rather than asserted.

**How to verify the DreamService on this device — and how not to.**
`cmd package query-services -a android.service.dreams.DreamService` does **not**
list this service, and that briefly looked like a defect. It is a false
negative: that command filters it out. The authoritative check is the intent
resolver table in `dumpsys package`:

```text
Service Resolver Table:
  android.service.dreams.DreamService:
    dev.murajaah.murajaah/.widget.MurajaahDreamService ... permission android.permission.BIND_DREAM_SERVICE
```

A negative `query-services` result on its own does not prove a service is
absent. Check the resolver table before concluding anything.

**Notification — posts correctly, but cannot reach this lock screen.**
After opting in, the notification posted exactly as described above. It is
nevertheless invisible on this phone's lock screen, because the owner has set,
system-wide:

```text
lock_screen_show_notifications = 0
```

**This is a device-specific limitation, not an application defect.** With that
setting at `0` no notification from *any* app appears on the lock screen. The
related `lock_screen_allow_private_notifications` is `1`, so if the owner ever
enables lock-screen notifications the title and text would be shown.

**This setting was not changed, and must not be changed by an agent.** It is a
privacy decision that belongs to the person holding the phone. Do not flip it to
make a screenshot look better, and do not recommend flipping it as a fix — the
honest answer to "why don't I see the ayah on my lock screen" is "because you
turned lock-screen notifications off, and that is a reasonable thing to want".

**No OEM restriction is applied to this app.** `am get-standby-bucket` returns
`10` (ACTIVE), `appops RUN_ANY_IN_BACKGROUND` is `Default mode: allow`, and the
app is not doze-whitelisted (which it does not need, since nothing here
schedules a background wakeup). The Unihertz/AGUI skin does ship
`com.agui.appblock`, `com.agui.frozen` and `com.agui.systemmanager`, the usual
sources of OEM freezing on this device family, so a future report of "the
notification stopped updating" should check those before suspecting the app.

## Contract tests

`test/android/widget_native_contract_test.dart` has two dedicated cases:
`the Learning notification is silent, opt-in, and never posts on its own`
and `DreamService is opt-in, read-only, and never bypasses the lock
screen`. `test/app/learning_notification_controller_test.dart` and
`test/widget/learning_notification_settings_card_test.dart` cover the
Dart-side opt-in/permission-denied/opt-out state machine with a fake
channel, independent of any real Android permission dialog.
