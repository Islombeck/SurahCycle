/// Writes a pulled app setting into this device.
///
/// The allow-list is checked again here, not only when sending. A device on an
/// older build — or one whose list has drifted — must not be able to put its
/// own identity or its own location into this device's settings.
library;

import '../../sync/app_setting_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'sync_versioned_rows.dart';

final class AppSettingSyncApplier {
  const AppSettingSyncApplier(this._database);

  final AppDatabase _database;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == AppSettingSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a setting envelope: ${envelope.entityKey}');
    }
    // ADR-0002's rule, run here because the server does not run it. A setting
    // is the one entity whose payload already carries its own timestamp, but
    // the envelope's is the one every other entity is compared by, and one
    // rule in one place is worth more than a special case here.
    if (!SyncMergeDecision.incomingWins(
      incomingUpdatedAtUtc: envelope.updatedAtUtc,
      localUpdatedAtUtc: await SyncVersionedRows(
        _database,
      ).updatedAtUtc(table: 'app_settings', key: envelope.entityId),
    )) {
      return;
    }
    if (envelope.isTombstone) {
      if (!AppSettingSyncPayload.isSyncable(envelope.entityId)) {
        throw const SyncTransportException('remote-setting-is-not-syncable');
      }
      // Clearing a preference is a real thing: it returns to the app's default
      // rather than to some other device's choice.
      await (_database.delete(
        _database.appSettings,
      )..where((AppSettings row) => row.key.equals(envelope.entityId))).go();
      return;
    }

    final record = AppSettingSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: record.key,
            value: record.value,
            valueType: record.valueType,
            updatedAtUtc: record.updatedAtUtc,
          ),
        );
  }
}
