import 'dart:convert';

import 'package:drift/drift.dart';

import '../../sync/sync.dart';
import '../database/app_database.dart';

const String _pending = 'pending';
const String _quarantined = 'quarantined';

/// The durable [SyncOutbox]: the queue survives process death.
///
/// This is the implementation real sync runs on, and it has to pass the same
/// `runSyncOutboxContract` suite as the in-memory reference — the guarantees
/// are defined once, in one place, rather than re-argued per backing store.
///
/// Every row is scoped to a [SyncOwnerKey]. Two owners on one device share a
/// database and share nothing else: signing out of one account and into another
/// can never drain the first account's queue under the second's identity.
final class DriftSyncOutbox implements SyncOutbox {
  DriftSyncOutbox(this._database, {this.owner = SyncOwnerKey.local});

  final AppDatabase _database;
  final SyncOwnerKey owner;

  @override
  Future<void> enqueue(SyncEnvelope envelope, {required DateTime nowUtc}) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'Must be UTC.');
    }
    return _database.transaction(() async {
      final sameId = await _byEnvelopeId(envelope.id);
      // Reusing one envelope id for a different entity, or for something
      // already quarantined, is a programming error. Refuse it loudly instead
      // of overwriting a queued change that belongs to a different record.
      if (sameId != null &&
          (sameId.status == _quarantined ||
              sameId.entityKey != envelope.entityKey)) {
        throw StateError(
          'Envelope id "${envelope.id}" is already present in the outbox.',
        );
      }

      final pending = await _pendingForEntity(envelope.entityKey);
      if (pending != null) {
        if (!_supersedes(pending, envelope)) return;
        await (_database.delete(_database.syncOutboxEntries)..where(
              (row) =>
                  row.ownerKey.equals(owner.value) &
                  row.envelopeId.equals(pending.envelopeId),
            ))
            .go();
      }

      await _database
          .into(_database.syncOutboxEntries)
          .insert(
            SyncOutboxEntriesCompanion.insert(
              ownerKey: owner.value,
              envelopeId: envelope.id,
              entityKey: envelope.entityKey,
              status: _pending,
              isTombstone: Value<bool>(envelope.isTombstone),
              enqueuedAtUs: nowUtc.microsecondsSinceEpoch,
              envelopeUpdatedAtUs: envelope.updatedAtUtc.microsecondsSinceEpoch,
              envelopeJson: jsonEncode(envelope.toJson()),
            ),
          );
    });
  }

  /// Whether [incoming] replaces the [pending] entry for the same entity.
  ///
  /// A pending delete is only superseded by a later delete: once a record is
  /// gone there is nothing left for a queued edit to describe, and letting one
  /// through would resurrect it on every other device.
  static bool _supersedes(SyncOutboxEntryRow pending, SyncEnvelope incoming) {
    final pendingUpdatedAt = DateTime.fromMicrosecondsSinceEpoch(
      pending.envelopeUpdatedAtUs,
      isUtc: true,
    );
    if (pending.isTombstone) {
      return incoming.isTombstone &&
          !incoming.updatedAtUtc.isBefore(pendingUpdatedAt);
    }
    if (incoming.isTombstone) return true;
    return !incoming.updatedAtUtc.isBefore(pendingUpdatedAt);
  }

  @override
  Future<List<SyncOutboxEntry>> peek({int limit = 50}) =>
      _read(status: _pending, limit: limit);

  @override
  Future<List<SyncOutboxEntry>> quarantined({int limit = 50}) =>
      _read(status: _quarantined, limit: limit);

  Future<List<SyncOutboxEntry>> _read({
    required String status,
    required int limit,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
    final query = _database.select(_database.syncOutboxEntries)
      ..where(
        (row) => row.ownerKey.equals(owner.value) & row.status.equals(status),
      )
      // A stable second key keeps two entries enqueued in the same
      // microsecond from swapping places between reads.
      ..orderBy(<OrderClauseGenerator<$SyncOutboxEntriesTable>>[
        (row) => OrderingTerm.asc(row.enqueuedAtUs),
        (row) => OrderingTerm.asc(row.envelopeId),
      ])
      ..limit(limit);
    final rows = await query.get();
    return List<SyncOutboxEntry>.unmodifiable(rows.map(_toEntry));
  }

  @override
  Future<void> acknowledge(Iterable<String> envelopeIds) async {
    final ids = envelopeIds.toList();
    if (ids.isEmpty) return;
    await (_database.delete(_database.syncOutboxEntries)..where(
          (row) =>
              row.ownerKey.equals(owner.value) &
              row.status.equals(_pending) &
              row.envelopeId.isIn(ids),
        ))
        .go();
  }

  @override
  Future<void> recordFailure(Iterable<String> envelopeIds, String reason) =>
      // A failed push keeps the entry queued. Dropping it would lose a change
      // the user already watched succeed locally.
      _markAttempt(envelopeIds, reason: reason, newStatus: _pending);

  @override
  Future<void> quarantine(Iterable<String> envelopeIds, String reason) {
    if (reason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Must not be empty.');
    }
    return _markAttempt(envelopeIds, reason: reason, newStatus: _quarantined);
  }

  Future<void> _markAttempt(
    Iterable<String> envelopeIds, {
    required String reason,
    required String newStatus,
  }) async {
    final ids = envelopeIds.toList();
    if (ids.isEmpty) return;
    // `attempt_count = attempt_count + 1` has no companion form, and reading
    // then writing each row would race with a concurrent drain.
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    await _database.customUpdate(
      'UPDATE sync_outbox_entries '
      'SET status = ?, attempt_count = attempt_count + 1, '
      'last_failure_reason = ? '
      "WHERE owner_key = ? AND status = 'pending' "
      'AND envelope_id IN ($placeholders)',
      variables: <Variable<Object>>[
        Variable<String>(newStatus),
        Variable<String>(reason),
        Variable<String>(owner.value),
        for (final id in ids) Variable<String>(id),
      ],
      updates: <TableInfo<Table, Object>>{_database.syncOutboxEntries},
    );
  }

  @override
  Future<int> pendingCount() async {
    final count = _database.syncOutboxEntries.envelopeId.count();
    final query = _database.selectOnly(_database.syncOutboxEntries)
      ..addColumns(<Expression<Object>>[count])
      ..where(
        _database.syncOutboxEntries.ownerKey.equals(owner.value) &
            _database.syncOutboxEntries.status.equals(_pending),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  @override
  Future<void> clear() async {
    await (_database.delete(
      _database.syncOutboxEntries,
    )..where((row) => row.ownerKey.equals(owner.value))).go();
  }

  Future<SyncOutboxEntryRow?> _byEnvelopeId(String envelopeId) =>
      (_database.select(_database.syncOutboxEntries)..where(
            (row) =>
                row.ownerKey.equals(owner.value) &
                row.envelopeId.equals(envelopeId),
          ))
          .getSingleOrNull();

  Future<SyncOutboxEntryRow?> _pendingForEntity(String entityKey) =>
      (_database.select(_database.syncOutboxEntries)..where(
            (row) =>
                row.ownerKey.equals(owner.value) &
                row.entityKey.equals(entityKey) &
                row.status.equals(_pending),
          ))
          .getSingleOrNull();

  static SyncOutboxEntry _toEntry(SyncOutboxEntryRow row) => SyncOutboxEntry(
    envelope: SyncEnvelope.fromJson(
      jsonDecode(row.envelopeJson) as Map<String, Object?>,
    ),
    enqueuedAtUtc: DateTime.fromMicrosecondsSinceEpoch(
      row.enqueuedAtUs,
      isUtc: true,
    ),
    attemptCount: row.attemptCount,
    lastFailureReason: row.lastFailureReason,
  );
}
