import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import 'widget_deep_link.dart';
import 'widget_snapshot.dart';
import 'widget_sync_coordinator.dart';

abstract interface class WidgetSnapshotBridge implements WidgetBridge {
  Future<String?> loadSnapshotJson();
}

final class HomeWidgetBridge implements WidgetSnapshotBridge {
  const HomeWidgetBridge();

  static const String rotationReceiver =
      'dev.murajaah.murajaah.widget.RotationWidgetReceiver';
  static const String learningReceiver =
      'dev.murajaah.murajaah.widget.LearningWidgetReceiver';
  static const String prayerReceiver =
      'dev.murajaah.murajaah.widget.PrayerWidgetReceiver';
  static const String prayerStripReceiver =
      'dev.murajaah.murajaah.widget.PrayerStripWidgetReceiver';

  @override
  Future<String?> loadSnapshotJson() =>
      HomeWidget.getWidgetData<String>(widgetSnapshotStorageKey);

  @override
  Future<bool> saveSnapshotIfCurrent(
    WidgetSnapshot snapshot,
    String json,
  ) async {
    final support = await getApplicationSupportDirectory();
    final lockFile = File(
      '${support.path}${Platform.pathSeparator}murajaah_widget_snapshot.lock',
    );
    final lock = await lockFile.open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    try {
      final current = const WidgetSnapshotCodec().decode(
        await loadSnapshotJson(),
      );
      if (current is WidgetSnapshotDecoded &&
          current.snapshot.snapshotRevision > snapshot.snapshotRevision) {
        return false;
      }
      final saved = await HomeWidget.saveWidgetData<String>(
        widgetSnapshotStorageKey,
        json,
      );
      if (saved == false) {
        throw StateError('The platform rejected the widget snapshot write.');
      }
      return true;
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }

  @override
  Future<void> updateRotationWidget() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: rotationReceiver);
  }

  @override
  Future<void> updateLearningWidget() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: learningReceiver);
  }

  /// Both launcher surfaces of the prayer projection — the vertical list and
  /// the horizontal strip. They render the same data, so the coordinator asks
  /// for "the prayer widget" once and this is the one place that knows there
  /// are two; the vertical one was left out of this nudge once and sat on Asr
  /// for days.
  @override
  Future<void> updatePrayerWidget() async {
    await Future.wait<void>(<Future<void>>[
      HomeWidget.updateWidget(qualifiedAndroidName: prayerReceiver),
      HomeWidget.updateWidget(qualifiedAndroidName: prayerStripReceiver),
    ]);
  }

  Future<WidgetDeepLink?> initiallyLaunchedFromWidget() async =>
      WidgetDeepLink.parse(await HomeWidget.initiallyLaunchedFromHomeWidget());

  Stream<WidgetDeepLink> get clicks => HomeWidget.widgetClicked
      .map(WidgetDeepLink.parse)
      .where((link) => link != null)
      .cast<WidgetDeepLink>();
}
