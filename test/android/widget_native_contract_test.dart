import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rotation circle uses Dart callback while row text opens the app', () {
    final source = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'RotationWidget.kt',
    );
    final row = _between(
      source,
      'private fun RotationRow',
      'private fun FallbackRow',
    );
    final callback = _between(
      source,
      'class RotationWidgetMarkAction',
      source.length,
    );

    expect(row, contains('val rowAction = actionStartActivity<MainActivity>'));
    expect(row, contains('actionRunCallback<RotationWidgetMarkAction>'));
    expect(row, contains('.size(30.dp).clickable(markAction)'));
    expect(
      row,
      contains('GlanceModifier.defaultWeight().clickable(rowAction)'),
    );
    expect(
      callback,
      contains(
        'HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(actionUri)).send()',
      ),
    );
    expect(callback, isNot(contains('actionStartActivity')));
    expect(callback, isNot(contains('MainActivity')));
  });

  test('native widget is projection-only and registers official receiver', () {
    final rotation = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'RotationWidget.kt',
    );
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final drawable = _read(
      'android/app/src/main/res/drawable/ic_widget_mark.xml',
    );

    expect(rotation, isNot(contains('.core.')));
    expect(rotation, isNot(contains('RecitationRepository')));
    expect(rotation, isNot(contains('PrayerContext')));
    expect(
      manifest,
      contains('es.antonborri.home_widget.HomeWidgetBackgroundReceiver'),
    );
    expect(manifest, contains('es.antonborri.home_widget.action.BACKGROUND'));
    expect(drawable, contains('A11.5,11.5'));
    expect(drawable, contains('@android:color/transparent'));
  });

  test('Learning widget root surfaces and fallback open Learning', () {
    final learning = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'LearningWidget.kt',
    );
    final fallback = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'WidgetErrorFallback.kt',
    );

    expect(learning, contains('Uri.parse("murajaah://app/learning")'));
    expect(learning, contains('.clickable(learningAction)'));
    expect(learning, contains('learningItem.deepLink'));
    expect(learning, isNot(contains('Uri.parse("murajaah://app/home")')));
    expect(fallback, contains('appWidgetId: Int, deepLink: Uri'));
  });

  test('schema 6 routine state is strict and preserves older fallback', () {
    final snapshot = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'WidgetSnapshot.kt',
    );
    final learning = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'LearningWidget.kt',
    );
    final rotation = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'RotationWidget.kt',
    );

    expect(snapshot, contains('private const val LEGACY_SCHEMA_VERSION = 2'));
    expect(snapshot, contains('private const val PREVIOUS_SCHEMA_VERSION = 3'));
    expect(
      snapshot,
      contains('private const val INTERACTIVE_SCHEMA_VERSION = 4'),
    );
    expect(snapshot, contains('private const val SCHEMA_VERSION = 7'));
    expect(snapshot, contains('private const val PRAYER_SCHEMA_VERSION = 7'));
    expect(
      snapshot,
      contains('internal const val LEGACY_ACTION_SCHEMA_VERSION = 1'),
    );
    expect(snapshot, contains('internal const val ACTION_SCHEMA_VERSION = 2'));
    expect(snapshot, contains('root.getLong("snapshotRevision")'));
    expect(snapshot, contains('requireOnlyKeys(root, rootKeys)'));
    expect(snapshot, contains('require(remaining >= 0)'));
    expect(snapshot, contains('debtLabel == if (remaining > 1)'));
    expect(snapshot, contains('item.getBoolean("isMarkedInCurrentPart")'));
    expect(snapshot, contains('item.getBoolean("canMark")'));
    expect(snapshot, contains('json.optionalString("currentPartLabel")'));
    expect(snapshot, contains('json.optionalString("slotProgressLabel")'));
    expect(snapshot, contains('json.optionalString("prayerSessionId")'));
    expect(snapshot, contains('json.optionalString("prayerSessionPartId")'));
    expect(snapshot, contains('json.getInt("slotIndex")'));
    expect(
      snapshot,
      contains('require(hasAnySlotTarget == hasCompleteSlotTarget)'),
    );
    expect(snapshot, contains('val ayahLines: List<NativeLearningAyahLine>'));
    expect(snapshot, contains('val surahNumber: Int?'));
    expect(snapshot, contains('val ayahNumber: Int?'));
    expect(snapshot, contains('lineAyah > previousAyah'));
    expect(learning, contains('LearningAyahBlock'));
    expect(
      learning,
      contains('line.transliteration.withoutTanzilPresentationTags()'),
    );
    expect(rotation, contains('snapshot?.rotation?.currentPartLabel'));
    expect(rotation, contains('snapshot?.rotation?.slotProgressLabel'));
    expect(
      snapshot,
      contains('require(entriesJson.length() == PRAYER_ENTRY_COUNT)'),
    );
    // Schema 7: the row no longer carries a verdict, so there is no
    // "at most one current" to check. What replaced it is the window list,
    // and these are the invariants that make a comparison on the far side
    // safe — ordered, contiguous, in range, and never naming Sunrise.
    expect(snapshot, contains('require(index == 0 || windows[index - 1]'));
    expect(
      snapshot,
      contains('require(entryIndex >= -1 && entryIndex < PRAYER_ENTRY_COUNT)'),
    );
    expect(
      snapshot,
      contains(
        'require(entryIndex < 0 || !entries[entryIndex].isBoundaryOnly)',
      ),
    );
    expect(snapshot, contains('require(end > start)'));
    expect(
      snapshot,
      isNot(contains('isCurrent')),
      reason:
          'a frozen verdict is what made the widget sit on Asr for days; it '
          'must not come back on the native side either',
    );
    expect(
      snapshot,
      contains('require(!json.has("staleLabel") || json.isNull("staleLabel"))'),
    );
  });

  test(
    'Prayer widget is a read-only, size-responsive, projection-only surface',
    () {
      final prayer = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
        'PrayerWidget.kt',
      );
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final info = _read('android/app/src/main/res/xml/prayer_widget_info.xml');

      expect(prayer, isNot(contains('.core.')));
      expect(prayer, isNot(contains('RecitationRepository')));
      expect(prayer, isNot(contains('ActionCallback')));
      expect(prayer, isNot(contains('actionRunCallback')));
      expect(prayer, contains('SizeMode.Responsive'));
      expect(prayer, contains('Uri.parse("murajaah://app/home")'));
      expect(prayer, contains('.clickable(homeAction)'));
      expect(manifest, contains('android:name=".widget.PrayerWidgetReceiver"'));
      expect(manifest, contains('@xml/prayer_widget_info'));
      expect(info, contains('android:resizeMode="horizontal|vertical"'));
    },
  );

  test(
    'the prayer strip is a second read-only surface of the same projection',
    () {
      final strip = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
        'PrayerStripWidget.kt',
      );
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final info = _read(
        'android/app/src/main/res/xml/prayer_strip_widget_info.xml',
      );
      final countdown = _read(
        'android/app/src/main/res/layout/prayer_strip_countdown.xml',
      );

      expect(strip, isNot(contains('.core.')));
      expect(strip, isNot(contains('RecitationRepository')));
      expect(strip, isNot(contains('ActionCallback')));
      expect(strip, isNot(contains('actionRunCallback')));
      expect(strip, contains('SizeMode.Responsive'));
      expect(strip, contains('Uri.parse("murajaah://app/home")'));
      expect(strip, contains('.clickable(homeAction)'));
      // It compares the clock with Dart's windows and decides nothing else:
      // the pill is currentIndexAt, the countdown is nextBoundaryAt.
      expect(strip, contains('prayer.currentIndexAt(nowUtcMs)'));
      expect(strip, contains('prayer.nextBoundaryAt(nowUtcMs)'));
      expect(strip, contains('setChronometerCountDown('));
      expect(
        manifest,
        contains('android:name=".widget.PrayerStripWidgetReceiver"'),
      );
      expect(manifest, contains('@xml/prayer_strip_widget_info'));
      // One launcher row, like the reference on his home screen.
      expect(info, contains('android:targetCellHeight="1"'));
      expect(info, contains('android:minHeight="40dp"'));
      expect(info, contains('android:resizeMode="horizontal|vertical"'));
      expect(countdown, contains('<Chronometer'));
      expect(countdown, contains('android:id="@+id/prayer_strip_countdown"'));
    },
  );

  test(
    'both prayer surfaces book a boundary redraw, and never an exact alarm',
    () {
      final refresh = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
        'PrayerWidgetRefresh.kt',
      );
      final prayer = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
        'PrayerWidget.kt',
      );
      final strip = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
        'PrayerStripWidget.kt',
      );
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      expect(
        prayer,
        contains(
          'PrayerWidgetRefresh.reschedule(context, '
          'PrayerWidgetReceiver::class.java)',
        ),
      );
      expect(
        strip,
        contains(
          'PrayerWidgetRefresh.reschedule(context, '
          'PrayerStripWidgetReceiver::class.java)',
        ),
      );
      expect(prayer, contains('PrayerWidgetRefresh.cancel('));
      expect(strip, contains('PrayerWidgetRefresh.cancel('));
      // Inexact and non-waking, so no permission and no battery question.
      expect(refresh, contains('alarms.setWindow(AlarmManager.RTC, '));
      expect(refresh, isNot(contains('RTC_WAKEUP')));
      expect(refresh, isNot(contains('setExact')));
      expect(refresh, isNot(contains('setAlarmClock')));
      expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
      expect(manifest, isNot(contains('USE_EXACT_ALARM')));
      // The redraw instant is the end of the window, not a verdict.
      expect(refresh, contains('?.windowEndsAt(nowUtcMs)'));
    },
  );

  test(
    'DreamService is opt-in, read-only, and never bypasses the lock screen',
    () {
      final dream = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
        'MurajaahDreamService.kt',
      );
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      expect(dream, contains('class MurajaahDreamService : DreamService()'));
      expect(dream, contains('isInteractive = false'));
      expect(dream, isNot(contains('showWhenLocked')));
      expect(dream, isNot(contains('FLAG_SHOW_WHEN_LOCKED')));
      expect(dream, isNot(contains('setFullScreenIntent')));
      expect(dream, isNot(contains('WAKE_LOCK')));
      expect(dream, isNot(contains('PowerManager')));
      expect(dream, isNot(contains('RecitationRepository')));
      expect(dream, contains('WIDGET_SNAPSHOT_KEY'));
      expect(manifest, contains('android:name=".widget.MurajaahDreamService"'));
      expect(
        manifest,
        contains('android:permission="android.permission.BIND_DREAM_SERVICE"'),
      );
      expect(manifest, contains('android.service.dreams.DreamService'));
      expect(manifest, contains('@xml/dream_info'));
    },
  );

  test(
    'the Learning notification is silent, opt-in, and never posts on its own',
    () {
      final manager = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
        'LearningNotificationManager.kt',
      );
      final activity = _read(
        'android/app/src/main/kotlin/dev/murajaah/murajaah/MainActivity.kt',
      );
      final channelDart = _read(
        'lib/core/widgets/learning_notification_channel.dart',
      );

      expect(manager, contains('NotificationManager.IMPORTANCE_LOW'));
      expect(manager, contains('.setSilent(true)'));
      expect(manager, contains('enableVibration(false)'));
      expect(manager, contains('enableLights(false)'));
      expect(manager, isNot(contains('FLAG_SHOW_WHEN_LOCKED')));
      expect(manager, isNot(contains('setFullScreenIntent')));
      expect(
        activity,
        contains('"dev.murajaah.murajaah/learning_notifications"'),
      );
      expect(activity, contains('"requestPermission" ->'));
      expect(
        channelDart,
        contains("'dev.murajaah.murajaah/learning_notifications'"),
      );
      expect(channelDart, contains('requestPermission'));
    },
  );

  test('Quran audio owns a separate Android media service contract', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final activity = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/MainActivity.kt',
    );

    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
    );
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(
      manifest,
      contains('com.ryanheise.audioservice.MediaButtonReceiver'),
    );
    expect(activity, contains('class MainActivity : AudioServiceActivity()'));
    expect(activity, contains('requestMediaNotifications'));
    expect(activity, contains('Manifest.permission.POST_NOTIFICATIONS'));
  });
}

String _read(String relativePath) {
  final file = File(relativePath);
  expect(file.existsSync(), isTrue, reason: 'Missing $relativePath');
  return file.readAsStringSync();
}

String _between(String value, String start, Object end) {
  final startIndex = value.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing $start');
  final endIndex = end is int ? end : value.indexOf(end as String, startIndex);
  expect(endIndex, greaterThan(startIndex), reason: 'Missing $end');
  return value.substring(startIndex, endIndex);
}
