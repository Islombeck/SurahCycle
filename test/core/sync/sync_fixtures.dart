import 'package:murajaah/core/sync/sync.dart';

/// A fixed UTC instant, so ordering assertions do not depend on the clock.
DateTime at(int minute) => DateTime.utc(2026, 9, 15, 10, minute);

SyncEnvelope envelopeOf({
  required String entityId,
  String id = 'envelope-1',
  String deviceId = 'device-a',
  SyncEntityType entityType = SyncEntityType.appSetting,
  int updatedMinute = 1,
  int schemaVersion = 6,
  String? idempotencyKey,
  String? userId,
  Map<String, Object?> payload = const <String, Object?>{'value': 'x'},

  /// Overrides [updatedMinute] outright, for the one date a minute cannot
  /// express: `kUndatedByThisDevice`, which is the epoch.
  DateTime? updatedAtUtc,
}) => SyncEnvelope(
  id: id,
  userId: userId,
  deviceId: deviceId,
  entityType: entityType,
  entityId: entityId,
  operation: SyncOperation.upsert,
  schemaVersion: schemaVersion,
  createdAtUtc: updatedAtUtc ?? at(0),
  updatedAtUtc: updatedAtUtc ?? at(updatedMinute),
  idempotencyKey: idempotencyKey ?? '$id-key',
  payload: payload,
);

SyncEnvelope tombstoneOf({
  required String entityId,
  String id = 'tombstone-1',
  String deviceId = 'device-a',
  SyncEntityType entityType = SyncEntityType.appSetting,
  int updatedMinute = 1,
  String? idempotencyKey,
}) => SyncEnvelope(
  id: id,
  deviceId: deviceId,
  entityType: entityType,
  entityId: entityId,
  operation: SyncOperation.delete,
  schemaVersion: 6,
  createdAtUtc: at(0),
  updatedAtUtc: at(updatedMinute),
  idempotencyKey: idempotencyKey ?? '$id-key',
);
