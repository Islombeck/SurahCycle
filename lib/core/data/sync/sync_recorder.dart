/// Turns a local change into a queued envelope, inside the caller's
/// transaction.
///
/// Two decisions shape this file, and both were the owner's to make.
///
/// **It is called inside the write, never after it.** A recorder that ran
/// afterwards could lose a change to a crash in the gap between the row landing
/// and the queue entry being made — the exact failure `SyncAwareLocalStore`
/// exists to rule out. So every method here assumes it is already inside a
/// transaction and does no transaction management of its own.
///
/// **A repository holds `null` until an account has been activated.** Nothing
/// is queued before that, and nothing changes for a device that never signs
/// in: no rows, no growth, not one extra write. The whole of the existing
/// history reaches an account through a backfill at activation instead, which
/// is the only mechanism that can carry records written before sync existed —
/// so a queue kept running "just in case" would duplicate that work rather than
/// replace it.
library;

import '../../domain/domain.dart';
import '../../sync/recitation_sync_payload.dart';
import '../../sync/sync.dart';
import '../repositories/settings_repository.dart';

/// Records one local change for the account this device has activated.
abstract interface class SyncRecorder {
  Future<void> recordRecitationUpsert(
    SurahRecitationEvent event, {
    required DateTime atUtc,
  });

  Future<void> recordRecitationDelete({
    required String entityId,
    required DateTime originalCreatedAtUtc,
    required DateTime deletedAtUtc,
  });
}

final class OutboxSyncRecorder implements SyncRecorder {
  OutboxSyncRecorder({
    required SyncOutbox outbox,
    required String deviceId,
    required int schemaVersion,
    required String Function() newId,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _outbox = outbox,
       // ignore: prefer_initializing_formals
       _deviceId = deviceId,
       // ignore: prefer_initializing_formals
       _schemaVersion = schemaVersion,
       // ignore: prefer_initializing_formals
       _newId = newId {
    if (deviceId.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Must not be empty.');
    }
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
  }

  final SyncOutbox _outbox;
  final String _deviceId;
  final int _schemaVersion;

  /// Generates both the envelope id and the idempotency key.
  ///
  /// Two separate values from it, not one used twice: the envelope id
  /// identifies this attempt to the local queue, while the idempotency key is
  /// what the server's unique index recognises on a replay. They happen to be
  /// generated together and must not be assumed equal.
  final String Function() _newId;

  @override
  Future<void> recordRecitationUpsert(
    SurahRecitationEvent event, {
    required DateTime atUtc,
  }) => _enqueue(
    RecitationSyncPayload.upsert(
      event,
      envelopeId: _newId(),
      deviceId: _deviceId,
      idempotencyKey: _newId(),
      schemaVersion: _schemaVersion,
      updatedAtUtc: atUtc,
    ),
    atUtc,
  );

  @override
  Future<void> recordRecitationDelete({
    required String entityId,
    required DateTime originalCreatedAtUtc,
    required DateTime deletedAtUtc,
  }) => _enqueue(
    RecitationSyncPayload.tombstone(
      entityId: entityId,
      envelopeId: _newId(),
      deviceId: _deviceId,
      idempotencyKey: _newId(),
      schemaVersion: _schemaVersion,
      originalCreatedAtUtc: originalCreatedAtUtc,
      deletedAtUtc: deletedAtUtc,
    ),
    deletedAtUtc,
  );

  Future<void> _enqueue(SyncEnvelope envelope, DateTime atUtc) =>
      _outbox.enqueue(envelope, nowUtc: atUtc.toUtc());
}

/// The id this device is known by inside an account.
///
/// Random and stored, never derived from the hardware. A hardware identifier
/// would follow the owner across uninstalls and across apps, and it is not what
/// this is for: the only question it answers is "which of my devices wrote
/// this", which a random value answers just as well and tells no one anything
/// else.
abstract final class SyncDeviceId {
  static const String settingKey = 'sync.deviceId';

  /// Reads the id, generating and storing one the first time.
  static Future<String> ensure(
    AppSettingsRepository settings, {
    required String Function() newId,
    required DateTime nowUtc,
  }) async {
    final existing = await settings.getString(settingKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = newId();
    await settings.setString(settingKey, created, updatedAtUtc: nowUtc);
    return created;
  }
}
