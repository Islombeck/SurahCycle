import 'sync_envelope.dart';
import 'sync_ports.dart';

/// Reference [SyncOutbox] held in memory.
///
/// This is the implementation the contract suite is written against, and it is
/// what the local fake backend is exercised with. It is deliberately **not**
/// durable: the durable version is database-backed and ships with the migration
/// that carries real sync, and it will have to pass the same contract.
final class InMemorySyncOutbox implements SyncOutbox {
  final Map<String, SyncOutboxEntry> _entriesById = <String, SyncOutboxEntry>{};
  final Map<String, SyncOutboxEntry> _quarantinedById =
      <String, SyncOutboxEntry>{};

  /// Insertion order per entity, so coalescing can find the pending entry.
  final Map<String, String> _envelopeIdByEntityKey = <String, String>{};

  @override
  Future<void> enqueue(
    SyncEnvelope envelope, {
    required DateTime nowUtc,
  }) async {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'Must be UTC.');
    }
    final sameId = _entriesById[envelope.id];
    final quarantinedWithSameId = _quarantinedById[envelope.id];
    if ((sameId != null && sameId.envelope.entityKey != envelope.entityKey) ||
        quarantinedWithSameId != null) {
      throw StateError(
        'Envelope id "${envelope.id}" is already present in the outbox.',
      );
    }
    final existingId = _envelopeIdByEntityKey[envelope.entityKey];
    if (existingId != null) {
      final existing = _entriesById[existingId];
      if (existing != null && _supersedes(existing.envelope, envelope)) {
        // Ten offline edits to one template are one push, not ten. A pending
        // delete swallows pending upserts entirely: there is nothing left to
        // describe once the record is gone.
        _entriesById.remove(existingId);
      } else if (existing != null) {
        return;
      }
    }
    // Re-inserted rather than updated in place, so a coalesced entry moves to
    // the back of the queue exactly as it does in the durable one.
    _entriesById.remove(envelope.id);
    _entriesById[envelope.id] = SyncOutboxEntry(
      envelope: envelope,
      enqueuedAtUtc: nowUtc,
    );
    _sequenceById[envelope.id] = _nextSequence++;
    _envelopeIdByEntityKey[envelope.entityKey] = envelope.id;
  }

  /// The order entries were added in, which is the order they must leave in.
  ///
  /// Held explicitly rather than taken from the map, because entries are
  /// removed and re-added and a `LinkedHashMap`'s order is easy to rely on by
  /// accident. `DriftSyncOutbox` gets the same answer from SQLite's `rowid`.
  final Map<String, int> _sequenceById = <String, int>{};
  int _nextSequence = 0;

  /// Whether [incoming] replaces [pending] for the same entity.
  ///
  /// Must agree with `DriftSyncOutbox` exactly — the shared contract test is
  /// what holds them together. A deletion supersedes a queued edit whatever the
  /// clock says; everything else, **including an upsert after a tombstone**, is
  /// decided by time. That last case is History's undo: a restore is an upsert
  /// whose purpose is to bring the record back everywhere, and the timestamp is
  /// what still stops a stale edit from resurrecting anything.
  static bool _supersedes(SyncEnvelope pending, SyncEnvelope incoming) {
    if (incoming.isTombstone && !pending.isTombstone) return true;
    return !incoming.updatedAtUtc.isBefore(pending.updatedAtUtc);
  }

  @override
  Future<List<SyncOutboxEntry>> peek({int limit = 50}) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
    final entries = _entriesById.values.toList()
      ..sort((left, right) {
        final byTime = left.enqueuedAtUtc.compareTo(right.enqueuedAtUtc);
        if (byTime != 0) return byTime;
        // Insertion order, not envelope id. Ids are random, so ordering ties by
        // them is stable across reads and says nothing about sequence — which
        // was invisible until a backfill enqueued a whole history in one
        // instant and the queue drained it in an arbitrary order.
        return (_sequenceById[left.envelope.id] ?? 0).compareTo(
          _sequenceById[right.envelope.id] ?? 0,
        );
      });
    return List<SyncOutboxEntry>.unmodifiable(entries.take(limit));
  }

  @override
  Future<void> acknowledge(Iterable<String> envelopeIds) async {
    for (final id in envelopeIds) {
      final removed = _entriesById.remove(id);
      if (removed == null) continue;
      final key = removed.envelope.entityKey;
      if (_envelopeIdByEntityKey[key] == id) {
        _envelopeIdByEntityKey.remove(key);
      }
    }
  }

  @override
  Future<void> recordFailure(
    Iterable<String> envelopeIds,
    String reason,
  ) async {
    for (final id in envelopeIds) {
      final entry = _entriesById[id];
      // A failed push keeps the entry queued. Dropping it would lose a change
      // the user already saw succeed locally.
      if (entry != null) _entriesById[id] = entry.withFailure(reason);
    }
  }

  @override
  Future<void> quarantine(Iterable<String> envelopeIds, String reason) async {
    if (reason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Must not be empty.');
    }
    for (final id in envelopeIds) {
      final entry = _entriesById.remove(id);
      if (entry == null) continue;
      final key = entry.envelope.entityKey;
      if (_envelopeIdByEntityKey[key] == id) {
        _envelopeIdByEntityKey.remove(key);
      }
      _quarantinedById[id] = entry.withFailure(reason);
    }
  }

  @override
  Future<List<SyncOutboxEntry>> quarantined({int limit = 50}) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
    final entries = _quarantinedById.values.toList()
      ..sort((left, right) {
        final byTime = left.enqueuedAtUtc.compareTo(right.enqueuedAtUtc);
        return byTime != 0
            ? byTime
            : left.envelope.id.compareTo(right.envelope.id);
      });
    return List<SyncOutboxEntry>.unmodifiable(entries.take(limit));
  }

  @override
  Future<int> pendingCount() async => _entriesById.length;

  @override
  @override
  Future<int> requeueQuarantined() async {
    final byEntity = <String, SyncOutboxEntry>{};
    for (final entry in _quarantinedById.values) {
      final key = entry.envelope.entityKey;
      // A pending entry carries the newer state of the same record; an older
      // quarantined copy of it has nothing left to say.
      if (_envelopeIdByEntityKey.containsKey(key)) continue;
      final kept = byEntity[key];
      if (kept == null ||
          entry.envelope.updatedAtUtc.isAfter(kept.envelope.updatedAtUtc)) {
        byEntity[key] = entry;
      }
    }
    _quarantinedById.clear();
    for (final entry in byEntity.values) {
      // The attempt count and the reason describe a queue that was failing.
      // This entry is being offered for the first time since the reason was
      // fixed, and carrying the old tally forward would make the next failure
      // look like the continuation of an older one.
      _entriesById[entry.envelope.id] = SyncOutboxEntry(
        envelope: entry.envelope,
        enqueuedAtUtc: entry.enqueuedAtUtc,
      );
      _sequenceById[entry.envelope.id] = _nextSequence++;
      _envelopeIdByEntityKey[entry.envelope.entityKey] = entry.envelope.id;
    }
    return byEntity.length;
  }

  @override
  Future<void> clear() async {
    _entriesById.clear();
    _envelopeIdByEntityKey.clear();
    _quarantinedById.clear();
  }
}
