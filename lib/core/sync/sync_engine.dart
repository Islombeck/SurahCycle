import 'sync_envelope.dart';
import 'sync_ports.dart';

/// What one drain attempt achieved.
final class SyncDrainOutcome {
  SyncDrainOutcome({
    required Iterable<String> pushedEnvelopeIds,
    required Iterable<String> rejectedEnvelopeIds,
    required this.remaining,
    this.failureReason,
  }) : pushedEnvelopeIds = List<String>.unmodifiable(pushedEnvelopeIds),
       rejectedEnvelopeIds = List<String>.unmodifiable(rejectedEnvelopeIds);

  final List<String> pushedEnvelopeIds;

  /// Envelopes the server refused permanently. They are moved to the outbox's
  /// inspectable quarantine so they do not block every later retry.
  final List<String> rejectedEnvelopeIds;
  final int remaining;

  /// Content-free category of a retryable failure, never a payload.
  final String? failureReason;

  bool get didPushAnything => pushedEnvelopeIds.isNotEmpty;
  bool get hasFailure => failureReason != null;
}

/// Applies one pulled page **and** persists its cursor, in a single local
/// transaction. Throwing means nothing was committed, so the page is retried.
typedef SyncPageApplier = Future<void> Function(SyncPullPage page);

/// Moves queued local changes out and remote changes in.
///
/// The engine owns no storage. It coordinates a [SyncOutbox] and a
/// [SyncGateway] and leaves every durable decision to the caller, which is what
/// lets the same logic run against the local fake and against a real backend.
final class SyncEngine {
  const SyncEngine({required this.outbox, required this.gateway});

  final SyncOutbox outbox;
  final SyncGateway gateway;

  /// Pushes at most [batchSize] queued envelopes.
  ///
  /// A transport failure leaves every entry queued with its attempt count
  /// raised. That is the whole point of an outbox: the local write already
  /// succeeded, and the network must never be able to undo it.
  Future<SyncDrainOutcome> drain({int batchSize = 50}) async {
    if (batchSize <= 0) {
      throw ArgumentError.value(batchSize, 'batchSize', 'Must be positive.');
    }
    final entries = await outbox.peek(limit: batchSize);
    if (entries.isEmpty) {
      return SyncDrainOutcome(
        pushedEnvelopeIds: const <String>[],
        rejectedEnvelopeIds: const <String>[],
        remaining: 0,
      );
    }

    final envelopes = <SyncEnvelope>[
      for (final entry in entries) entry.envelope,
    ];
    final SyncPushResult result;
    try {
      result = await gateway.push(envelopes);
    } on SyncTransportException catch (error) {
      await outbox.recordFailure(
        envelopes.map((envelope) => envelope.id),
        error.reason,
      );
      return SyncDrainOutcome(
        pushedEnvelopeIds: const <String>[],
        rejectedEnvelopeIds: const <String>[],
        remaining: await outbox.pendingCount(),
        failureReason: error.reason,
      );
    }

    final requestedIds = envelopes.map((envelope) => envelope.id).toSet();
    final acceptedIds = result.acceptedEnvelopeIds.toSet();
    final rejectedIds = result.rejectedEnvelopeIds.toSet();
    final responseIsValid =
        acceptedIds.length == result.acceptedEnvelopeIds.length &&
        rejectedIds.length == result.rejectedEnvelopeIds.length &&
        acceptedIds.intersection(rejectedIds).isEmpty &&
        requestedIds.containsAll(acceptedIds) &&
        requestedIds.containsAll(rejectedIds) &&
        acceptedIds.union(rejectedIds).containsAll(requestedIds);
    if (!responseIsValid) {
      await outbox.recordFailure(requestedIds, 'invalid_response');
      return SyncDrainOutcome(
        pushedEnvelopeIds: const <String>[],
        rejectedEnvelopeIds: const <String>[],
        remaining: await outbox.pendingCount(),
        failureReason: 'invalid_response',
      );
    }

    await outbox.acknowledge(result.acceptedEnvelopeIds);
    if (result.rejectedEnvelopeIds.isNotEmpty) {
      await outbox.quarantine(
        result.rejectedEnvelopeIds,
        result.rejectionReason ?? 'rejected',
      );
    }
    return SyncDrainOutcome(
      pushedEnvelopeIds: result.acceptedEnvelopeIds,
      rejectedEnvelopeIds: result.rejectedEnvelopeIds,
      remaining: await outbox.pendingCount(),
    );
  }

  /// Pulls pages from [from] until the server has nothing more, applying each
  /// through [apply] before asking for the next one.
  ///
  /// Returns the cursor that was last successfully committed. If [apply]
  /// throws, the cursor from before that page is returned, so the page is
  /// fetched again rather than skipped.
  Future<SyncCursor> pull({
    required SyncCursor from,
    required SyncPageApplier apply,
    int pageSize = 100,
    int maxPages = 100,
  }) async {
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive.');
    }
    if (maxPages <= 0) {
      throw ArgumentError.value(maxPages, 'maxPages', 'Must be positive.');
    }
    var cursor = from;
    for (var page = 0; page < maxPages; page += 1) {
      final pulled = await gateway.pull(after: cursor, limit: pageSize);
      if (pulled.envelopes.isEmpty) return cursor;
      await apply(pulled);
      cursor = pulled.cursor;
      if (!pulled.hasMore) return cursor;
    }
    return cursor;
  }
}
