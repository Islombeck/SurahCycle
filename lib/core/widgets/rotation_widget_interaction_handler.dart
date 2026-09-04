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
typedef WidgetInteractionLogHandler =
    void Function(String event, Map<String, Object?> fields);

/// Executes an untrusted widget payload and always attempts to restore the
/// launcher from current database state. No optimistic checked state exists.
final class RotationWidgetInteractionHandler {
  const RotationWidgetInteractionHandler({
    required this.recitations,
    required this.refresher,
    this.onError,
    this.onLog,
  });

  final RecitationApplicationService recitations;
  final InteractiveWidgetSnapshotRefresher refresher;
  final WidgetInteractionErrorHandler? onError;
  final WidgetInteractionLogHandler? onLog;

  Future<RotationWidgetInteractionOutcome> handle(Uri? payload) async {
    final receivedAt = DateTime.now().toUtc();
    var status = RotationWidgetInteractionStatus.malformed;
    WidgetRecitationRejection? rejection;
    try {
      final action = WidgetRecitationAction.tryParseUri(payload);
      onLog?.call('action_received', <String, Object?>{
        'receivedAt': receivedAt.toIso8601String(),
        'validation': action == null ? 'malformed' : 'accepted',
        'actionToken': action?.actionToken,
        'surah': action?.surahId,
        'part': action?.partId,
        'prayerSession': action?.prayerSessionId,
        'prayerSessionPart': action?.prayerSessionPartId,
        'slot': action?.slotIndex,
      });
      if (action != null) {
        onLog?.call('transaction_start', <String, Object?>{
          'actionToken': action.actionToken,
          'surah': action.surahId,
          'part': action.partId,
          'prayerSession': action.prayerSessionId,
          'prayerSessionPart': action.prayerSessionPartId,
          'slot': action.slotIndex,
        });
        final result = await recitations.registerFromWidget(action);
        switch (result) {
          case WidgetRecitationRegistered(:final registration):
            status = RotationWidgetInteractionStatus.registered;
            onLog?.call('transaction_commit', <String, Object?>{
              'actionToken': action.actionToken,
              'dbEventId': registration.event.id,
              'prayerContext': registration.event.prayerContext.toString(),
              'prayerSession': registration.event.prayerSessionId,
              'prayerSessionPart': registration.event.prayerSessionPartId,
              'slot': registration.event.slotIndex,
              'parts': registration.event.coveredPartIds.join(','),
              'snapshotRevision': registration.snapshot.revision,
            });
          case WidgetRecitationDuplicate():
            status = RotationWidgetInteractionStatus.duplicate;
            onLog?.call('transaction_duplicate', <String, Object?>{
              'actionToken': action.actionToken,
            });
          case WidgetRecitationRejected(:final reason):
            status = RotationWidgetInteractionStatus.rejected;
            rejection = reason;
            onLog?.call('validation_rejected', <String, Object?>{
              'actionToken': action.actionToken,
              'validation': reason.name,
            });
        }
      }
    } on Object catch (error, stackTrace) {
      status = RotationWidgetInteractionStatus.failed;
      onError?.call(error, stackTrace);
      onLog?.call('transaction_error', <String, Object?>{
        'errorType': error.runtimeType.toString(),
      });
    }

    var refreshed = false;
    try {
      final snapshot = await refresher.refresh(
        actionFailed:
            status == RotationWidgetInteractionStatus.rejected ||
            status == RotationWidgetInteractionStatus.malformed ||
            status == RotationWidgetInteractionStatus.failed,
      );
      refreshed = true;
      onLog?.call('native_update', <String, Object?>{
        'result': 'success',
        'snapshotRevision': snapshot.snapshotRevision,
      });
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      onLog?.call('native_update', <String, Object?>{
        'result': 'error',
        'errorType': error.runtimeType.toString(),
      });
    }
    return RotationWidgetInteractionOutcome(
      status: status,
      snapshotRefreshed: refreshed,
      rejection: rejection,
    );
  }
}
