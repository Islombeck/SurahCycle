/// The real [SyncGateway], backed by Appwrite's TablesDB.
///
/// Shaped like [AppwriteAccountGateway] on purpose: a narrow [AppwriteSyncApi]
/// is the only thing that would touch the SDK, and every rule — how an envelope
/// becomes a row, what counts as already-applied, what may be retried and what
/// must never be — lives here, where it can be tested without a network, a
/// project or a session.
///
/// One row per entity, addressed by `entityId`. That is what makes a retried
/// push a no-op rather than a duplicate: the second write replaces the first
/// with identical content. `idempotencyKey` still travels with the row, because
/// the server's unique index on `(userId, idempotencyKey)` is what catches a
/// replay that this client has forgotten it already sent.
library;

import 'dart:convert';

import 'sync_envelope.dart';
import 'sync_ports.dart';

/// One page of raw rows, exactly as storage returned them.
final class AppwriteSyncPage {
  AppwriteSyncPage({
    required Iterable<Map<String, Object?>> rows,
    required this.lastRowId,
    required this.hasMore,
  }) : rows = List<Map<String, Object?>>.unmodifiable(rows);

  final List<Map<String, Object?>> rows;

  /// The cursor to resume after, or null when the page is empty.
  final String? lastRowId;
  final bool hasMore;
}

/// Why a single row could not be written.
enum AppwriteSyncWriteOutcome {
  written,

  /// The server already holds this exact change. Not a failure: the unique
  /// index on `(userId, idempotencyKey)` did its job during a replay.
  alreadyApplied,

  /// The server refused permanently — a malformed row, or a schema it cannot
  /// accept. Retrying would wedge the queue behind it forever.
  rejected,
}

/// The slice of TablesDB this gateway needs.
///
/// Implementations hold no rules. They translate one call into one request and
/// map the server's answer onto [AppwriteSyncWriteOutcome], or throw
/// [SyncTransportException] when the outcome is simply unknown.
abstract interface class AppwriteSyncApi {
  Future<AppwriteSyncWriteOutcome> upsertRow({
    required String rowId,
    required Map<String, Object?> data,
    required List<String> permissions,
  });

  /// Rows the owner may read, oldest change first, starting after [cursor].
  Future<AppwriteSyncPage> listRowsAfter({
    required String cursor,
    required int limit,
  });
}

final class AppwriteSyncGateway implements SyncGateway {
  const AppwriteSyncGateway({required this.api, required this.userId});

  final AppwriteSyncApi api;

  /// The owner every row is written for and permitted to. Passed in rather
  /// than read per call: a gateway must never straddle two accounts, and
  /// re-reading the session mid-batch is exactly how it would.
  final String userId;

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) async {
    final accepted = <String>[];
    final rejected = <String>[];
    String? rejectionReason;

    for (final envelope in envelopes) {
      // An envelope belonging to someone else is a programming error, not a
      // server problem, and must never be written under this owner's
      // permissions.
      if (envelope.userId != null && envelope.userId != userId) {
        throw StateError(
          'Refusing to push an envelope owned by a different account.',
        );
      }
      final outcome = await api.upsertRow(
        rowId: envelope.entityId,
        data: _rowOf(envelope),
        permissions: _ownerPermissions,
      );
      switch (outcome) {
        // Already applied counts as accepted: the outbox must drop it, not
        // retry it. Treating a successful replay as a failure is how a queue
        // gets stuck on work the server already has.
        case AppwriteSyncWriteOutcome.written:
        case AppwriteSyncWriteOutcome.alreadyApplied:
          accepted.add(envelope.id);
        case AppwriteSyncWriteOutcome.rejected:
          rejected.add(envelope.id);
          rejectionReason ??= 'rejected-by-server';
      }
    }

    return SyncPushResult(
      acceptedEnvelopeIds: accepted,
      rejectedEnvelopeIds: rejected,
      rejectionReason: rejectionReason,
    );
  }

  @override
  Future<SyncPullPage> pull({
    required SyncCursor after,
    int limit = 100,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
    final page = await api.listRowsAfter(cursor: after.value, limit: limit);
    final envelopes = <SyncEnvelope>[
      for (final row in page.rows) _envelopeOf(row),
    ];
    return SyncPullPage(
      envelopes: envelopes,
      // An empty page leaves the cursor exactly where it was. Advancing it
      // past nothing would be harmless today and a silent skip the moment the
      // server starts filtering rows it will not return again.
      cursor: page.lastRowId == null ? after : SyncCursor(page.lastRowId!),
      hasMore: page.hasMore,
    );
  }

  /// Read, update and delete for this owner alone. Creation is granted at the
  /// table, so it is deliberately absent here.
  List<String> get _ownerPermissions => <String>[
    'read("user:$userId")',
    'update("user:$userId")',
    'delete("user:$userId")',
  ];

  Map<String, Object?> _rowOf(SyncEnvelope envelope) => <String, Object?>{
    'userId': userId,
    'deviceId': envelope.deviceId,
    'entityType': envelope.entityType.name,
    'entityId': envelope.entityId,
    'operation': envelope.operation.name,
    'schemaVersion': envelope.schemaVersion,
    'createdAtUtc': envelope.createdAtUtc.toIso8601String(),
    'updatedAtUtc': envelope.updatedAtUtc.toIso8601String(),
    'idempotencyKey': envelope.idempotencyKey,
    // A tombstone carries no payload, and writing `{}` instead of null would
    // make "deleted" and "deleted with empty content" indistinguishable.
    'payload': envelope.operation == SyncOperation.delete
        ? null
        : jsonEncode(envelope.payload),
  };

  SyncEnvelope _envelopeOf(Map<String, Object?> row) {
    final entityTypeName = _requireString(row, 'entityType');
    final entityType = SyncEntityType.values
        .where((candidate) => candidate.name == entityTypeName)
        .firstOrNull;
    if (entityType == null) {
      // A row this build cannot describe was written by a newer one. Stalling
      // the pull is the honest outcome: skipping it would advance the cursor
      // past data that is then never fetched again, which loses a change
      // silently and permanently.
      throw const SyncTransportException('remote-entity-type-unknown');
    }
    final operationName = _requireString(row, 'operation');
    final operation = switch (operationName) {
      'upsert' => SyncOperation.upsert,
      'delete' => SyncOperation.delete,
      _ => throw const SyncTransportException('remote-operation-unknown'),
    };
    final payload = row['payload'];
    return SyncEnvelope(
      id: _requireString(row, '\$id'),
      deviceId: _requireString(row, 'deviceId'),
      entityType: entityType,
      entityId: _requireString(row, 'entityId'),
      operation: operation,
      schemaVersion: _requireInt(row, 'schemaVersion'),
      createdAtUtc: _requireUtc(row, 'createdAtUtc'),
      updatedAtUtc: _requireUtc(row, 'updatedAtUtc'),
      idempotencyKey: _requireString(row, 'idempotencyKey'),
      userId: _requireString(row, 'userId'),
      payload: operation == SyncOperation.delete || payload is! String
          ? const <String, Object?>{}
          : _decodePayload(payload),
    );
  }

  static Map<String, Object?> _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Fall through: a payload that will not parse is a broken row, not a
      // network problem.
    }
    throw const SyncTransportException('remote-payload-malformed');
  }

  static String _requireString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is String && value.isNotEmpty) return value;
    throw SyncTransportException('remote-field-missing-${_safe(key)}');
  }

  static int _requireInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw SyncTransportException('remote-field-missing-${_safe(key)}');
  }

  static DateTime _requireUtc(Map<String, Object?> row, String key) {
    final parsed = DateTime.tryParse(_requireString(row, key));
    if (parsed == null) {
      throw SyncTransportException('remote-field-malformed-${_safe(key)}');
    }
    return parsed.toUtc();
  }

  /// Field names are ours, not user content — but stripping anything unusual
  /// keeps a reason string safe to log even if that stops being true.
  static String _safe(String key) =>
      key.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
}
