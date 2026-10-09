import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/widgets/widgets.dart';

void main() {
  test(
    'resume invalidates providers when headless revision is newer',
    () async {
      var invalidations = 0;
      final reconciler = WidgetResumeReconciler(
        bridge: _Bridge(_snapshot(5)),
        loadDatabaseRevision: () async => 5,
        currentProjectionRevision: () => 4,
        invalidateProviders: () => invalidations += 1,
      );

      expect(await reconciler.reconcile(), isTrue);
      expect(invalidations, 1);
    },
  );

  test('resume does nothing when DB, widget and provider agree', () async {
    var invalidations = 0;
    final reconciler = WidgetResumeReconciler(
      bridge: _Bridge(_snapshot(5)),
      loadDatabaseRevision: () async => 5,
      currentProjectionRevision: () => 5,
      invalidateProviders: () => invalidations += 1,
    );

    expect(await reconciler.reconcile(), isFalse);
    expect(invalidations, 0);
  });
}

WidgetSnapshot _snapshot(int revision) => WidgetSnapshot(
  generatedAtUtc: DateTime.utc(2026, 9, 3),
  snapshotRevision: revision,
  locale: 'ru',
  rotation: RotationWidgetProjection(items: const <RotationWidgetItem>[]),
  learning: const LearningWidgetProjection.empty(),
  prayer: PrayerWidgetProjection.unavailable(messageLabel: 'Open app'),
);

final class _Bridge implements WidgetSnapshotBridge {
  _Bridge(WidgetSnapshot snapshot)
    : json = const WidgetSnapshotCodec().encode(snapshot);

  String json;

  @override
  Future<String?> loadSnapshotJson() async => json;

  @override
  Future<bool> saveSnapshotIfCurrent(
    WidgetSnapshot snapshot,
    String source,
  ) async {
    json = source;
    return true;
  }

  @override
  Future<void> updateLearningWidget() async {}

  @override
  Future<void> updateRotationWidget() async {}

  @override
  Future<void> updatePrayerWidget() async {}
}
