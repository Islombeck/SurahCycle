import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/widgets/home_widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String?> updatedReceivers() => <String?>[
    for (final call in calls)
      if (call.method == 'updateWidget')
        (call.arguments as Map<Object?, Object?>)['qualifiedAndroidName']
            as String?,
  ];

  group('the prayer projection has two launcher surfaces', () {
    // The vertical widget was once left out of the nudge and sat on Asr for
    // days (4af7451). A second surface rendering the same projection is the
    // same defect waiting to happen, so the bridge names both, and the
    // coordinator keeps asking for "the prayer widget" without having to
    // know how many there are.
    test(
      'updatePrayerWidget wakes the vertical and the strip receivers',
      () async {
        await const HomeWidgetBridge().updatePrayerWidget();

        expect(
          updatedReceivers(),
          unorderedEquals(<String>[
            'dev.murajaah.murajaah.widget.PrayerWidgetReceiver',
            'dev.murajaah.murajaah.widget.PrayerStripWidgetReceiver',
          ]),
        );
      },
    );

    test(
      'the other two updates still wake exactly their own receiver',
      () async {
        await const HomeWidgetBridge().updateRotationWidget();
        await const HomeWidgetBridge().updateLearningWidget();

        expect(updatedReceivers(), <String>[
          'dev.murajaah.murajaah.widget.RotationWidgetReceiver',
          'dev.murajaah.murajaah.widget.LearningWidgetReceiver',
        ]);
      },
    );
  });
}
