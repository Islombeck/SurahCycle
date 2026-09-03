import 'home_widget_bridge.dart';
import 'widget_snapshot.dart';

typedef WidgetRevisionLoader = Future<int> Function();
typedef CurrentWidgetRevision = int? Function();
typedef WidgetProviderInvalidator = void Function();

/// Detects writes committed by a headless Flutter engine and asks the
/// foreground provider graph to reopen its authoritative database streams.
final class WidgetResumeReconciler {
  const WidgetResumeReconciler({
    required this.bridge,
    required this.loadDatabaseRevision,
    required this.currentProjectionRevision,
    required this.invalidateProviders,
    this.codec = const WidgetSnapshotCodec(),
  });

  final WidgetSnapshotBridge bridge;
  final WidgetRevisionLoader loadDatabaseRevision;
  final CurrentWidgetRevision currentProjectionRevision;
  final WidgetProviderInvalidator invalidateProviders;
  final WidgetSnapshotCodec codec;

  Future<bool> reconcile() async {
    final databaseRevision = await loadDatabaseRevision();
    final currentRevision = currentProjectionRevision();
    final decoded = codec.decode(await bridge.loadSnapshotJson());
    final widgetRevision = decoded is WidgetSnapshotDecoded
        ? decoded.snapshot.snapshotRevision
        : null;
    if (currentRevision == databaseRevision &&
        widgetRevision == databaseRevision) {
      return false;
    }
    invalidateProviders();
    return true;
  }
}
