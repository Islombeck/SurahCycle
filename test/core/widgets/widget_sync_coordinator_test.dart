import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/widgets/widget_snapshot.dart';
import 'package:murajaah/core/widgets/widget_sync_coordinator.dart';

void main() {
  test('debounce coalesces rapid projections to the latest snapshot', () async {
    final bridge = _RecordingBridge();
    final coordinator = WidgetSyncCoordinator(
      bridge: bridge,
      debounce: const Duration(milliseconds: 5),
    );

    coordinator.schedule(_snapshot(locale: 'en'));
    coordinator.schedule(_snapshot(locale: 'ru'));
    coordinator.schedule(_snapshot(locale: 'uz'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await coordinator.flush();

    expect(bridge.savedJson, hasLength(1));
    expect(bridge.savedJson.single, contains('"locale":"uz"'));
    expect(bridge.rotationUpdates, 1);
    expect(bridge.learningUpdates, 1);
    coordinator.dispose();
  });

  test(
    'same projection is deduplicated despite a new generated time',
    () async {
      final bridge = _RecordingBridge();
      final coordinator = WidgetSyncCoordinator(bridge: bridge);

      await coordinator.syncNow(_snapshot());
      await coordinator.syncNow(
        _snapshot(generatedAtUtc: DateTime.utc(2026, 8, 26)),
      );

      expect(bridge.savedJson, hasLength(1));
      coordinator.dispose();
    },
  );

  test(
    'in-flight work is serialized and pending writes are latest-wins',
    () async {
      final gate = Completer<void>();
      final bridge = _RecordingBridge(firstSaveGate: gate.future);
      final coordinator = WidgetSyncCoordinator(bridge: bridge);

      final first = coordinator.syncNow(_snapshot(locale: 'en'));
      await bridge.firstSaveStarted.future;
      final second = coordinator.syncNow(_snapshot(locale: 'ru'));
      final third = coordinator.syncNow(_snapshot(locale: 'uz'));
      gate.complete();
      await Future.wait<void>(<Future<void>>[first, second, third]);

      expect(bridge.savedJson, hasLength(2));
      expect(bridge.savedJson.first, contains('"locale":"en"'));
      expect(bridge.savedJson.last, contains('"locale":"uz"'));
      coordinator.dispose();
    },
  );

  test('bridge failure is reported and can be retried', () async {
    final errors = <Object>[];
    final bridge = _RecordingBridge(failNextSave: true);
    final coordinator = WidgetSyncCoordinator(
      bridge: bridge,
      onError: (error, _) => errors.add(error),
    );

    await expectLater(coordinator.syncNow(_snapshot()), throwsStateError);
    await coordinator.syncNow(_snapshot());

    expect(errors, hasLength(1));
    expect(bridge.savedJson, hasLength(1));
    coordinator.dispose();
  });

  test('dispose cancels pending debounce work', () async {
    final bridge = _RecordingBridge();
    final coordinator = WidgetSyncCoordinator(
      bridge: bridge,
      debounce: const Duration(milliseconds: 5),
    );

    coordinator.schedule(_snapshot());
    coordinator.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await coordinator.syncNow(_snapshot(locale: 'uz'));

    expect(bridge.savedJson, isEmpty);
  });
}

final class _RecordingBridge implements WidgetBridge {
  _RecordingBridge({this.firstSaveGate, this.failNextSave = false});

  final Future<void>? firstSaveGate;
  bool failNextSave;
  final Completer<void> firstSaveStarted = Completer<void>();
  final List<String> savedJson = <String>[];
  int rotationUpdates = 0;
  int learningUpdates = 0;

  @override
  Future<void> saveSnapshotJson(String json) async {
    if (!firstSaveStarted.isCompleted) firstSaveStarted.complete();
    if (firstSaveGate != null && savedJson.isEmpty) await firstSaveGate;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('write failed');
    }
    savedJson.add(json);
  }

  @override
  Future<void> updateLearningWidget() async {
    learningUpdates += 1;
  }

  @override
  Future<void> updateRotationWidget() async {
    rotationUpdates += 1;
  }
}

WidgetSnapshot _snapshot({String locale = 'en', DateTime? generatedAtUtc}) =>
    WidgetSnapshot(
      generatedAtUtc: generatedAtUtc ?? DateTime.utc(2026, 8, 25),
      locale: locale,
      rotation: RotationWidgetProjection(items: const <RotationWidgetItem>[]),
      learning: const LearningWidgetProjection.empty(),
    );
