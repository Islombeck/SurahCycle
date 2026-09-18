import 'sync_envelope.dart';
import 'sync_ports.dart';

/// A local, in-process stand-in for the real backend.
///
/// It exists so the sync contracts can be exercised without a cloud project,
/// and so the rules the server must enforce — per-user isolation, idempotency,
/// a monotonic cursor, tombstones that survive — are written down as executable
/// behaviour rather than prose. It is a **test double**: it is never wired into
/// the running app, and it is not a preview of a working sync.
final class FakeSyncBackend {
  FakeSyncBackend({this.maxSupportedSchemaVersion = 6});

  /// An envelope from a newer client is refused permanently rather than
  /// retried forever, so an upgraded device cannot wedge an older one's queue.
  final int maxSupportedSchemaVersion;

  int _cursor = 0;
  final Map<String, List<_StoredRecord>> _recordsByUserId =
      <String, List<_StoredRecord>>{};
  final Map<String, List<_StoredRecord>> _auditByUserId =
      <String, List<_StoredRecord>>{};
  final Map<String, Map<String, SyncEnvelope>>
  _requestsByIdempotencyKeyByUserId = <String, Map<String, SyncEnvelope>>{};

  /// Everything stored for one user, for assertions and for the export path.
  List<SyncEnvelope> recordsOf(String userId) =>
      List<SyncEnvelope>.unmodifiable(
        (_recordsByUserId[userId] ?? const <_StoredRecord>[]).map(
          (record) => record.envelope,
        ),
      );

  /// Every accepted unique mutation, including versions that lost conflict
  /// resolution. A real backend keeps this audit trail away from normal pulls.
  List<SyncEnvelope> auditLogOf(String userId) =>
      List<SyncEnvelope>.unmodifiable(
        (_auditByUserId[userId] ?? const <_StoredRecord>[]).map(
          (record) => record.envelope,
        ),
      );

  SyncPushResult push(String userId, List<SyncEnvelope> envelopes) {
    final accepted = <String>[];
    final rejected = <String>[];
    String? rejectionReason;
    final requestsByKey = _requestsByIdempotencyKeyByUserId.putIfAbsent(
      userId,
      () => <String, SyncEnvelope>{},
    );
    final records = _recordsByUserId.putIfAbsent(
      userId,
      () => <_StoredRecord>[],
    );
    final audit = _auditByUserId.putIfAbsent(userId, () => <_StoredRecord>[]);

    for (final envelope in envelopes) {
      if (envelope.userId != null && envelope.userId != userId) {
        // One user may never write into another's data, even by mistake.
        rejected.add(envelope.id);
        rejectionReason ??= 'user_mismatch';
        continue;
      }
      if (envelope.schemaVersion > maxSupportedSchemaVersion) {
        rejected.add(envelope.id);
        rejectionReason ??= 'schema_too_new';
        continue;
      }
      final previousRequest = requestsByKey[envelope.idempotencyKey];
      if (previousRequest != null) {
        // A retry after an ambiguous failure is a no-op, not a duplicate — and
        // still reports success. Reusing the key for different content is a
        // protocol error rather than permission to lose the second change.
        if (previousRequest == envelope) {
          accepted.add(envelope.id);
        } else {
          rejected.add(envelope.id);
          rejectionReason ??= 'idempotency_conflict';
        }
        continue;
      }
      final owned = envelope.withUserId(userId);
      final existingIndex = records.indexWhere(
        (record) => record.envelope.entityKey == owned.entityKey,
      );
      if (existingIndex >= 0 && owned.isAppendOnly && !owned.isTombstone) {
        rejected.add(envelope.id);
        rejectionReason ??= 'append_only_conflict';
        continue;
      }

      requestsByKey[envelope.idempotencyKey] = envelope;
      _cursor += 1;
      final stored = _StoredRecord(envelope: owned, cursor: _cursor);
      audit.add(stored);
      if (existingIndex < 0) {
        records.add(stored);
      } else if (_wins(records[existingIndex].envelope, owned)) {
        records[existingIndex] = stored;
      } else {
        // The incoming version lost the deterministic comparison, but it still
        // consumed a cursor so the client's queue drains.
        accepted.add(envelope.id);
        continue;
      }
      accepted.add(envelope.id);
    }

    return SyncPushResult(
      acceptedEnvelopeIds: accepted,
      rejectedEnvelopeIds: rejected,
      rejectionReason: rejectionReason,
    );
  }

  /// The deterministic rule every device must reach the same answer with:
  /// newer `updatedAtUtc` wins, a tombstone breaks an exact tie, and
  /// `deviceId` breaks what is left.
  ///
  /// **Time comes first here, unlike in the outbox**, and the difference is
  /// principled rather than an oversight. The outbox holds envelopes from one
  /// device, where "deleted after editing" is a sequence and needs no clock, so
  /// a deletion there supersedes a queued edit outright. Here the envelopes
  /// come from different devices and time is the only ordering that exists.
  ///
  /// This rule used to put a tombstone ahead of *any* upsert. That made a
  /// restore unsendable: History's undo would push an upsert the server then
  /// discarded, leaving every other device believing the recitation gone while
  /// the one that restored it showed it back, with nothing able to correct
  /// either. The local queue had the same flaw and was fixed with it; the two
  /// must agree, or a device and its account disagree permanently.
  ///
  /// A tombstone still wins an exact tie, because the two sides must converge
  /// and "withdrawn" is the recoverable answer — History can undo it, while a
  /// resurrection cannot be told apart from the user adding the record again.
  static bool _wins(SyncEnvelope current, SyncEnvelope incoming) {
    final byTime = incoming.updatedAtUtc.compareTo(current.updatedAtUtc);
    if (byTime != 0) return byTime > 0;
    if (incoming.isTombstone != current.isTombstone) {
      return incoming.isTombstone;
    }
    return incoming.deviceId.compareTo(current.deviceId) > 0;
  }

  SyncPullPage pull(
    String userId, {
    required SyncCursor after,
    int limit = 100,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
    final afterCursor = after.isBeginning ? 0 : int.parse(after.value);
    final records =
        (_recordsByUserId[userId] ?? const <_StoredRecord>[])
            .where((record) => record.cursor > afterCursor)
            .toList()
          ..sort((left, right) => left.cursor.compareTo(right.cursor));
    final page = records.take(limit).toList();
    final hasMore = records.length > page.length;
    final nextCursor = page.isEmpty ? after : SyncCursor('${page.last.cursor}');
    return SyncPullPage(
      envelopes: page.map((record) => record.envelope),
      cursor: nextCursor,
      hasMore: hasMore,
    );
  }

  void deleteUser(String userId) {
    _recordsByUserId.remove(userId);
    _auditByUserId.remove(userId);
    _requestsByIdempotencyKeyByUserId.remove(userId);
  }
}

final class _StoredRecord {
  const _StoredRecord({required this.envelope, required this.cursor});

  final SyncEnvelope envelope;
  final int cursor;
}

/// A [SyncGateway] bound to one user of a [FakeSyncBackend].
final class FakeSyncGateway implements SyncGateway {
  FakeSyncGateway({
    required this.backend,
    required this.userId,
    this.failNextPush = false,
  });

  final FakeSyncBackend backend;
  final String userId;

  /// Simulates a retryable transport failure, so the outbox's "failure is not
  /// loss" rule can be exercised.
  bool failNextPush;

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) async {
    if (failNextPush) {
      failNextPush = false;
      throw const SyncTransportException('offline');
    }
    return backend.push(userId, envelopes);
  }

  @override
  Future<SyncPullPage> pull({
    required SyncCursor after,
    int limit = 100,
  }) async => backend.pull(userId, after: after, limit: limit);
}

/// A local [AccountGateway] that enforces the identity rules on a fake.
final class FakeAccountGateway implements AccountGateway {
  FakeAccountGateway({required this.backend, this.userId = 'user-1'});

  final FakeSyncBackend backend;
  final String userId;

  SyncAccount? _account;

  @override
  Future<SyncAccount?> currentAccount() async => _account;

  @override
  Future<SyncAccount> signIn(SyncAuthProvider provider) async {
    final existing = _account;
    if (existing != null) {
      if (existing.linkedProviders.contains(provider)) return existing;
      throw const SyncIdentityLinkException('already_authenticated');
    }
    return _account = SyncAccount(
      userId: userId,
      linkedProviders: <SyncAuthProvider>{provider},
    );
  }

  @override
  Future<SyncAccount> linkIdentity(SyncAuthProvider provider) async {
    final existing = _account;
    if (existing == null) {
      // The rule that matters: linking is only ever initiated by someone who
      // has already proved they own the account.
      throw const SyncIdentityLinkException('not_authenticated');
    }
    if (existing.linkedProviders.contains(provider)) {
      throw const SyncIdentityLinkException('already_linked');
    }
    return _account = SyncAccount(
      userId: existing.userId,
      linkedProviders: <SyncAuthProvider>{
        ...existing.linkedProviders,
        provider,
      },
    );
  }

  @override
  Future<void> signOut() async => _account = null;

  @override
  Future<Map<String, Object?>> exportCloudData() async {
    final account = _account;
    if (account == null) {
      throw const SyncIdentityLinkException('not_authenticated');
    }
    return <String, Object?>{
      'formatVersion': 1,
      'userId': account.userId,
      'records': <Map<String, Object?>>[
        for (final envelope in backend.recordsOf(account.userId))
          <String, Object?>{
            'id': envelope.id,
            'userId': envelope.userId,
            'deviceId': envelope.deviceId,
            'entityType': envelope.entityType.name,
            'entityId': envelope.entityId,
            'operation': envelope.operation.name,
            'schemaVersion': envelope.schemaVersion,
            'createdAtUtc': envelope.createdAtUtc.toIso8601String(),
            'updatedAtUtc': envelope.updatedAtUtc.toIso8601String(),
            'idempotencyKey': envelope.idempotencyKey,
            'payload': envelope.payload,
          },
      ],
    };
  }

  @override
  Future<void> deleteCloudAccount() async {
    final account = _account;
    if (account == null) {
      throw const SyncIdentityLinkException('not_authenticated');
    }
    // Erases the stored copy, not just the session.
    backend.deleteUser(account.userId);
    _account = null;
  }
}

/// Local first-sync gate used by contract tests.
///
/// Preparing a preview represents creating a backup and comparing the two
/// stores. Authentication alone never activates synchronization.
final class FakeSyncActivationGateway implements SyncActivationGateway {
  FakeSyncActivationGateway({required this.preview});

  final SyncMergePreview preview;
  String? _preparedForUserId;
  String? _activeForUserId;

  @override
  Future<SyncMergePreview> prepareFirstSync(SyncAccount account) async {
    _preparedForUserId = account.userId;
    _activeForUserId = null;
    return preview;
  }

  @override
  Future<void> finishFirstSync({
    required String previewToken,
    required SyncActivationChoice choice,
  }) async {
    final userId = _preparedForUserId;
    if (userId == null || previewToken != preview.token) {
      throw const SyncIdentityLinkException('stale_merge_preview');
    }
    _activeForUserId = choice == SyncActivationChoice.merge ? userId : null;
    _preparedForUserId = null;
  }

  @override
  Future<bool> isSyncActiveFor(String userId) async =>
      _activeForUserId == userId;
}
