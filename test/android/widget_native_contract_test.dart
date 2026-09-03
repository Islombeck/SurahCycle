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

  test('schema 4 state is strict and preserves schema 2/3 fallback', () {
    final snapshot = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'WidgetSnapshot.kt',
    );
    final learning = _read(
      'android/app/src/main/kotlin/dev/murajaah/murajaah/widget/'
      'LearningWidget.kt',
    );

    expect(snapshot, contains('private const val LEGACY_SCHEMA_VERSION = 2'));
    expect(snapshot, contains('private const val PREVIOUS_SCHEMA_VERSION = 3'));
    expect(snapshot, contains('private const val SCHEMA_VERSION = 4'));
    expect(snapshot, contains('root.getLong("snapshotRevision")'));
    expect(snapshot, contains('requireOnlyKeys(root, rootKeys)'));
    expect(snapshot, contains('require(remaining >= 0)'));
    expect(snapshot, contains('debtLabel == if (remaining > 1)'));
    expect(snapshot, contains('item.getBoolean("isMarkedInCurrentPart")'));
    expect(snapshot, contains('item.getBoolean("canMark")'));
    expect(snapshot, contains('val ayahLines: List<NativeLearningAyahLine>'));
    expect(snapshot, contains('val surahNumber: Int?'));
    expect(snapshot, contains('val ayahNumber: Int?'));
    expect(snapshot, contains('lineAyah > previousAyah'));
    expect(learning, contains('LearningAyahBlock'));
    expect(
      learning,
      contains('line.transliteration.withoutTanzilPresentationTags()'),
    );
  });

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
