import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/widgets/widgets.dart';

void main() {
  late AppDatabase database;
  late AppSettingsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = AppSettingsRepository(database);
  });

  tearDown(() => database.close());

  test(
    'enabling persists true and shows nothing when permission is granted',
    () async {
      final channel = _FakeLearningNotificationChannel(permissionGranted: true);
      final controller = LearningNotificationController(
        repository: repository,
        channel: channel,
        timeProvider: _FixedTimeProvider(DateTime.utc(2026, 9, 4)),
      );

      final result = await controller.setEnabled(true);

      expect(result, isTrue);
      expect(await repository.getBool('learningNotificationEnabled'), isTrue);
      expect(channel.requestPermissionCalls, 1);
      expect(channel.cancelCalls, 0);
    },
  );

  test(
    'a denied permission leaves the setting off and cancels any notification',
    () async {
      final channel = _FakeLearningNotificationChannel(
        permissionGranted: false,
      );
      final controller = LearningNotificationController(
        repository: repository,
        channel: channel,
        timeProvider: _FixedTimeProvider(DateTime.utc(2026, 9, 4)),
      );

      final result = await controller.setEnabled(true);

      expect(result, isFalse);
      expect(await repository.getBool('learningNotificationEnabled'), isFalse);
      expect(channel.cancelCalls, 1);
    },
  );

  test(
    'disabling persists false and cancels without asking permission',
    () async {
      final channel = _FakeLearningNotificationChannel(permissionGranted: true);
      final controller = LearningNotificationController(
        repository: repository,
        channel: channel,
        timeProvider: _FixedTimeProvider(DateTime.utc(2026, 9, 4)),
      );
      await controller.setEnabled(true);

      final result = await controller.setEnabled(false);

      expect(result, isFalse);
      expect(await repository.getBool('learningNotificationEnabled'), isFalse);
      expect(channel.cancelCalls, 1);
      expect(channel.requestPermissionCalls, 1);
    },
  );
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _FakeLearningNotificationChannel
    implements LearningNotificationChannel {
  _FakeLearningNotificationChannel({required this.permissionGranted});

  final bool permissionGranted;
  int requestPermissionCalls = 0;
  int cancelCalls = 0;
  int showCalls = 0;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return permissionGranted;
  }

  @override
  Future<void> show({required String title, required String text}) async {
    showCalls += 1;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
  }
}
