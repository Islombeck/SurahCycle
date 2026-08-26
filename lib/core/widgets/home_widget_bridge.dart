import 'package:home_widget/home_widget.dart';

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

  @override
  Future<String?> loadSnapshotJson() =>
      HomeWidget.getWidgetData<String>(widgetSnapshotStorageKey);

  @override
  Future<void> saveSnapshotJson(String json) async {
    final saved = await HomeWidget.saveWidgetData<String>(
      widgetSnapshotStorageKey,
      json,
    );
    if (saved == false) {
      throw StateError('The platform rejected the widget snapshot write.');
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

  Future<WidgetDeepLink?> initiallyLaunchedFromWidget() async =>
      WidgetDeepLink.parse(await HomeWidget.initiallyLaunchedFromHomeWidget());

  Stream<WidgetDeepLink> get clicks => HomeWidget.widgetClicked
      .map(WidgetDeepLink.parse)
      .where((link) => link != null)
      .cast<WidgetDeepLink>();
}
