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
    _entriesById[envelope.id] = SyncOutboxEntry(
      envelope: envelope,
      enqueuedAtUtc: nowUtc,
    );
    _envelopeIdByEntityKey[envelope.entityKey] = envelope.id;
  }

  /// Whether [incoming] replaces [pending] for the same entity.
  static bool _supersedes(SyncEnvelope pending, SyncEnvelope incoming) {
    if (pending.isTombstone) {
      // Nothing supersedes a pending delete except a later delete.
      return incoming.isTombstone &&
          !incoming.updatedAtUtc.isBefore(pending.updatedAtUtc);
    }
    if (incoming.isTombstone) return true;
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
        // A stable tiebreak keeps two entries enqueued in the same millisecond
        // from swapping between reads.
        return byTime != 0
            ? byTime
            : left.envelope.id.compareTo(right.envelope.id);
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
  Future<void> clear() async {
    _entriesById.clear();
    _envelopeIdByEntityKey.clear();
    _quarantinedById.clear();
  }
}
