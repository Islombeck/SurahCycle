import '../application/application.dart';
import 'interactive_widget_snapshot_refresher.dart';

enum RotationWidgetInteractionStatus {
  registered,
  duplicate,
  rejected,
  malformed,
  failed,
}

final class RotationWidgetInteractionOutcome {
  const RotationWidgetInteractionOutcome({
    required this.status,
    required this.snapshotRefreshed,
    this.rejection,
  });

  final RotationWidgetInteractionStatus status;
  final bool snapshotRefreshed;
  final WidgetRecitationRejection? rejection;
}

typedef WidgetInteractionErrorHandler =
    void Function(Object error, StackTrace stackTrace);

/// Executes an untrusted widget payload and always attempts to restore the
/// launcher from current database state. No optimistic checked state exists.
final class RotationWidgetInteractionHandler {
  const RotationWidgetInteractionHandler({
    required this.recitations,
    required this.refresher,
    this.onError,
  });

  final RecitationApplicationService recitations;
  final InteractiveWidgetSnapshotRefresher refresher;
  final WidgetInteractionErrorHandler? onError;

  Future<RotationWidgetInteractionOutcome> handle(Uri? payload) async {
    var status = RotationWidgetInteractionStatus.malformed;
    WidgetRecitationRejection? rejection;
    try {
      final action = WidgetRecitationAction.tryParseUri(payload);
      if (action != null) {
        final result = await recitations.registerFromWidget(action);
        switch (result) {
          case WidgetRecitationRegistered():
            status = RotationWidgetInteractionStatus.registered;
          case WidgetRecitationDuplicate():
            status = RotationWidgetInteractionStatus.duplicate;
          case WidgetRecitationRejected(:final reason):
            status = RotationWidgetInteractionStatus.rejected;
            rejection = reason;
        }
      }
    } on Object catch (error, stackTrace) {
      status = RotationWidgetInteractionStatus.failed;
      onError?.call(error, stackTrace);
    }

    var refreshed = false;
    try {
      await refresher.refresh(
        actionFailed:
            status == RotationWidgetInteractionStatus.rejected ||
            status == RotationWidgetInteractionStatus.malformed ||
            status == RotationWidgetInteractionStatus.failed,
      );
      refreshed = true;
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
    return RotationWidgetInteractionOutcome(
      status: status,
      snapshotRefreshed: refreshed,
      rejection: rejection,
    );
  }
}
