import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/widgets/widgets.dart';
import 'package:murajaah/features/settings/presentation/learning_notification_settings_card.dart';
import 'package:murajaah/l10n/app_localizations.dart';

void main() {
  testWidgets('turning the switch on requests permission and persists it', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final channel = _FakeLearningNotificationChannel(permissionGranted: true);

    await _pumpCard(tester, database, channel);
    var toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    expect(toggle.value, isFalse);

    await tester.tap(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    await tester.pumpAndSettle();

    expect(channel.requestPermissionCalls, 1);
    toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    expect(toggle.value, isTrue);
    expect(
      await AppSettingsRepository(
        database,
      ).getBool('learningNotificationEnabled'),
      isTrue,
    );
    expect(find.byType(SnackBar), findsNothing);

    await _disposeWidgetTree(tester);
  });

  testWidgets('a denied permission leaves the switch off with a warning', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final channel = _FakeLearningNotificationChannel(permissionGranted: false);

    await _pumpCard(tester, database, channel);
    await tester.tap(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    await tester.pumpAndSettle();

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    expect(toggle.value, isFalse);
    expect(
      await AppSettingsRepository(
        database,
      ).getBool('learningNotificationEnabled'),
      isFalse,
    );
    expect(find.byType(SnackBar), findsOneWidget);

    await _disposeWidgetTree(tester);
  });

  testWidgets('turning the switch back off cancels without asking again', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final channel = _FakeLearningNotificationChannel(permissionGranted: true);

    await _pumpCard(tester, database, channel);
    await tester.tap(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    await tester.pumpAndSettle();

    expect(channel.requestPermissionCalls, 1);
    expect(channel.cancelCalls, 1);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey<String>('learning-notification-switch')),
    );
    expect(toggle.value, isFalse);
    expect(
      await AppSettingsRepository(
        database,
      ).getBool('learningNotificationEnabled'),
      isFalse,
    );

    await _disposeWidgetTree(tester);
  });
}

final class _FakeLearningNotificationChannel
    implements LearningNotificationChannel {
  _FakeLearningNotificationChannel({required this.permissionGranted});

  final bool permissionGranted;
  int requestPermissionCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return permissionGranted;
  }

  @override
  Future<void> show({required String title, required String text}) async {}

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
  }
}

Future<void> _pumpCard(
  WidgetTester tester,
  AppDatabase database,
  LearningNotificationChannel channel,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        learningNotificationChannelProvider.overrideWithValue(channel),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: LearningNotificationSettingsCard(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}
