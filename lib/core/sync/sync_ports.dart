import 'sync_envelope.dart';

/// A queued change waiting to be pushed.
final class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.envelope,
    required this.enqueuedAtUtc,
    this.attemptCount = 0,
    this.lastFailureReason,
  });

  final SyncEnvelope envelope;
  final DateTime enqueuedAtUtc;
  final int attemptCount;

  /// A short, content-free reason. Never a payload and never a token: the
  /// outbox can end up in a log, and a user's recitation history must not.
  final String? lastFailureReason;

  SyncOutboxEntry withFailure(String reason) => SyncOutboxEntry(
    envelope: envelope,
    enqueuedAtUtc: enqueuedAtUtc,
    attemptCount: attemptCount + 1,
    lastFailureReason: reason,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOutboxEntry &&
          envelope == other.envelope &&
          enqueuedAtUtc == other.enqueuedAtUtc &&
          attemptCount == other.attemptCount &&
          lastFailureReason == other.lastFailureReason;

  @override
  int get hashCode =>
      Object.hash(envelope, enqueuedAtUtc, attemptCount, lastFailureReason);
}

/// The queue of local changes that have not reached the server yet.
///
/// A local write commits to the database first and is never blocked on the
/// network; enqueuing here is what makes it eventually reach an account. An
/// implementation must survive process death — which is why the real one will
/// be database-backed — and must satisfy [runSyncOutboxContract].
abstract interface class SyncOutbox {
  /// Adds a change, coalescing it with any pending change for the same entity.
  Future<void> enqueue(SyncEnvelope envelope, {required DateTime nowUtc});

  /// The next entries to push, oldest first, at most [limit].
  Future<List<SyncOutboxEntry>> peek({int limit = 50});

  /// Removes entries that the server has durably accepted.
  Future<void> acknowledge(Iterable<String> envelopeIds);

  /// Keeps entries queued and records that an attempt failed.
  Future<void> recordFailure(Iterable<String> envelopeIds, String reason);

  /// Moves permanently rejected entries out of the retry queue without
  /// deleting them. They remain inspectable until an explicit recovery or
  /// account-erasure flow resolves them.
  Future<void> quarantine(Iterable<String> envelopeIds, String reason);

  /// Permanently rejected entries, oldest first.
  Future<List<SyncOutboxEntry>> quarantined({int limit = 50});

  Future<int> pendingCount();

  /// Explicitly drops both pending and quarantined transport state.
  ///
  /// Ordinary sign-out must not call this: queued changes need to resume when
  /// the same account returns. This is reserved for confirmed account erasure
  /// or a merge decision that deliberately keeps the device local-only.
  Future<void> clear();
}

/// Where a pull left off. Opaque to the client by design: only the server knows
/// what it means, so the client cannot invent one and skip data.
extension type const SyncCursor(String value) {
  static const SyncCursor beginning = SyncCursor('');

  bool get isBeginning => value.isEmpty;
}

/// One page of remote changes.
final class SyncPullPage {
  SyncPullPage({
    required Iterable<SyncEnvelope> envelopes,
    required this.cursor,
    required this.hasMore,
  }) : envelopes = List<SyncEnvelope>.unmodifiable(envelopes);

  final List<SyncEnvelope> envelopes;

  /// Save this together with the applied envelopes, in one transaction. The
  /// cursor advancing without the data is how a device silently loses changes.
  final SyncCursor cursor;
  final bool hasMore;
}

/// Outcome of pushing a batch.
final class SyncPushResult {
  SyncPushResult({
    required Iterable<String> acceptedEnvelopeIds,
    Iterable<String> rejectedEnvelopeIds = const <String>[],
    this.rejectionReason,
  }) : acceptedEnvelopeIds = List<String>.unmodifiable(acceptedEnvelopeIds),
       rejectedEnvelopeIds = List<String>.unmodifiable(rejectedEnvelopeIds);

  final List<String> acceptedEnvelopeIds;

  /// Envelopes the server refused permanently — a malformed or too-new schema,
  /// not a network failure. Retrying these forever would be a stuck queue.
  final List<String> rejectedEnvelopeIds;
  final String? rejectionReason;
}

/// Raised when a push or pull failed in a way that is worth retrying.
final class SyncTransportException implements Exception {
  const SyncTransportException(this.reason);

  /// Content-free: a category, never the payload that failed.
  final String reason;

  @override
  String toString() => 'SyncTransportException($reason)';
}

/// Moves envelopes between this device and the user's account.
///
/// There is no production implementation while no backend project exists, and
/// deliberately so: a stub that reported success would be worse than an absent
/// feature.
abstract interface class SyncGateway {
  /// Idempotent by `idempotencyKey`: pushing the same envelope twice must not
  /// create two records.
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes);

  Future<SyncPullPage> pull({required SyncCursor after, int limit = 100});
}

/// Which provider a session came from.
enum SyncAuthProvider { google, yandex }

/// The signed-in user, as far as the client needs to know.
final class SyncAccount {
  SyncAccount({
    required this.userId,
    required Iterable<SyncAuthProvider> linkedProviders,
  }) : linkedProviders = Set<SyncAuthProvider>.unmodifiable(linkedProviders);

  final String userId;
  final Set<SyncAuthProvider> linkedProviders;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncAccount &&
          userId == other.userId &&
          linkedProviders.length == other.linkedProviders.length &&
          linkedProviders.containsAll(other.linkedProviders);

  @override
  int get hashCode => Object.hash(userId, linkedProviders.length);
}

/// Raised when linking a second provider is not allowed.
final class SyncIdentityLinkException implements Exception {
  const SyncIdentityLinkException(this.reason);

  final String reason;

  @override
  String toString() => 'SyncIdentityLinkException($reason)';
}

/// Sign-in, identity linking, export and erasure.
abstract interface class AccountGateway {
  Future<SyncAccount?> currentAccount();

  Future<SyncAccount> signIn(SyncAuthProvider provider);

  /// Attaches another provider to the **already signed-in** account.
  ///
  /// Linking from an anonymous state is refused on purpose: an unauthenticated
  /// OAuth login is a sign-in, never a link, or anyone controlling an email
  /// address could attach themselves to someone else's history.
  Future<SyncAccount> linkIdentity(SyncAuthProvider provider);

  Future<void> signOut();

  /// Portable JSON of the user's own data. Excludes the Quran corpus and the
  /// audio cache, which are re-fetched by manifest rather than copied.
  Future<Map<String, Object?>> exportCloudData();

  /// Erases the account and its cloud data, then ends the session. Local data
  /// is a separate, explicit user choice.
  Future<void> deleteCloudAccount();
}

/// A recoverable local backup made before first sync or destructive restore.
final class LocalBackupDescriptor {
  factory LocalBackupDescriptor({
    required String id,
    required int schemaVersion,
    required DateTime createdAtUtc,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    return LocalBackupDescriptor._(
      id: id,
      schemaVersion: schemaVersion,
      createdAtUtc: createdAtUtc,
    );
  }

  const LocalBackupDescriptor._({
    required this.id,
    required this.schemaVersion,
    required this.createdAtUtc,
  });

  final String id;
  final int schemaVersion;
  final DateTime createdAtUtc;
}

/// Device-owned export and recovery, available without an account or network.
abstract interface class LocalBackupGateway {
  Future<Map<String, Object?>> exportLocalData();

  Future<LocalBackupDescriptor> createBackup();

  Future<void> restoreBackup(String backupId);
}

/// Transaction boundary required of the future Drift sync adapter.
///
/// Applying the local payload and enqueuing its envelope must commit together.
/// A separate `local write; await outbox.enqueue(...)` sequence can lose a
/// change if the process dies between those calls and is not conforming.
abstract interface class SyncAwareLocalStore {
  Future<void> commitLocalChangeAndEnqueue(
    SyncEnvelope envelope, {
    required DateTime enqueuedAtUtc,
  });
}

/// What the user chose after reviewing the first-sync preview.
enum SyncActivationChoice { merge, keepDeviceLocalOnly }

/// Counts shown before an account is allowed to touch existing local data.
///
/// [backupId] proves the recovery copy was created before the preview. The
/// opaque [token] binds confirmation to this exact snapshot so a stale dialog
/// cannot authorize a different merge later.
final class SyncMergePreview {
  factory SyncMergePreview({
    required String token,
    required String backupId,
    required int localOnlyCount,
    required int remoteOnlyCount,
    required int sharedCount,
    required int conflictCount,
  }) {
    if (token.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Must not be empty.');
    }
    if (backupId.isEmpty) {
      throw ArgumentError.value(backupId, 'backupId', 'Must not be empty.');
    }
    for (final entry in <String, int>{
      'localOnlyCount': localOnlyCount,
      'remoteOnlyCount': remoteOnlyCount,
      'sharedCount': sharedCount,
      'conflictCount': conflictCount,
    }.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must be non-negative.',
        );
      }
    }
    return SyncMergePreview._(
      token: token,
      backupId: backupId,
      localOnlyCount: localOnlyCount,
      remoteOnlyCount: remoteOnlyCount,
      sharedCount: sharedCount,
      conflictCount: conflictCount,
    );
  }

  const SyncMergePreview._({
    required this.token,
    required this.backupId,
    required this.localOnlyCount,
    required this.remoteOnlyCount,
    required this.sharedCount,
    required this.conflictCount,
  });

  final String token;
  final String backupId;
  final int localOnlyCount;
  final int remoteOnlyCount;
  final int sharedCount;
  final int conflictCount;

  bool get hasConflicts => conflictCount > 0;
}

/// Gate between authentication and the first data synchronization.
///
/// Signing in establishes identity only. A production coordinator must create
/// a local backup, fetch remote metadata, show this preview, and receive one
/// explicit choice before constructing an active [SyncGateway].
abstract interface class SyncActivationGateway {
  Future<SyncMergePreview> prepareFirstSync(SyncAccount account);

  Future<void> finishFirstSync({
    required String previewToken,
    required SyncActivationChoice choice,
  });

  Future<bool> isSyncActiveFor(String userId);
}
