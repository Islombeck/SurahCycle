/// Records a deletion that leaves nothing behind for a scan to find.
///
/// Almost nothing needs this. The four append-only journals withdraw by writing
/// `deleted_at_utc` rather than by removing the row, so a scan sees the
/// withdrawal exactly as it sees an edit; a routine's parts travel inside their
/// template; a rotation scheme is superseded rather than dropped. The one place
/// the app really removes a row is a learning plan, and its deletion is a thing
/// the owner meant.
///
/// So this is not a return to "call a recorder from every write" — that design
/// was rejected because twenty call sites each get one chance to be remembered.
/// This exists for the handful of cases a scan *structurally* cannot see, and
/// it is used once.
///
/// **It finds its own owners.** A repository has no business knowing which
/// account is signed in, and threading one down to it would have meant an async
/// lookup in a provider graph that must not import the account feature. The
/// activation table already records every owner this device has said yes to,
/// and a tombstone is a fact about the data rather than about a session, so it
/// goes to each of them.
///
/// A device that has never activated has no active owner and nothing is
/// queued — which is the same "no rows, no growth, not one extra write" that
/// the recorder promises a device that never signs in.
library;

import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'drift_sync_outbox.dart';

abstract final class SyncTombstones {
  /// Queues a deletion of [entityId] for every account this device syncs with.
  ///
  /// Call inside the same transaction as the delete itself. A tombstone that
  /// committed separately could be lost to a crash in the gap, leaving a row
  /// gone here and present in the account forever — the exact failure
  /// `SyncAwareLocalStore` exists to rule out.
  static Future<void> recordDelete(
    AppDatabase database, {
    required SyncEntityType entityType,
    required String entityId,
    required DateTime deletedAtUtc,
    required String Function() newId,
    required Future<String> Function() deviceId,
    int schemaVersion = kSyncPayloadSchemaVersion,
  }) async {
    if (!deletedAtUtc.isUtc) {
      throw ArgumentError.value(deletedAtUtc, 'deletedAtUtc', 'Must be UTC.');
    }
    final owners = await (database.select(
      database.syncActivations,
    )..where((row) => row.isActive.equals(true))).get();
    if (owners.isEmpty) return;

    final device = await deviceId();
    if (device.isEmpty) {
      throw StateError('Refusing to record a tombstone without a device id.');
    }
    for (final owner in owners) {
      await DriftSyncOutbox(
        database,
        owner: SyncOwnerKey.stored(owner.ownerKey),
      ).enqueue(
        SyncEnvelope(
          id: newId(),
          deviceId: device,
          entityType: entityType,
          entityId: entityId,
          operation: SyncOperation.delete,
          schemaVersion: schemaVersion,
          createdAtUtc: deletedAtUtc,
          updatedAtUtc: deletedAtUtc,
          idempotencyKey: newId(),
        ),
        nowUtc: deletedAtUtc,
      );
    }
  }
}
