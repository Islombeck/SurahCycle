/// Turns the history this device already holds into queued envelopes.
///
/// Everything else in this feature carries *changes*: a recorder queues one
/// envelope as one row is written, and a device that signs in after years of
/// use would therefore send nothing at all. The whole of the existing history
/// reaches an account through this and only through this.
///
/// It runs at activation, after the user has seen the preview and chosen to
/// merge — never before. The preview is what they are agreeing to, and a queue
/// filled in before the question was asked would have pre-empted the answer.
///
/// **Re-running it is safe and is the recovery path.** No progress is recorded
/// anywhere: the backfill reads the rows as they are now, and the outbox
/// coalesces per entity, so a run interrupted halfway is finished by running it
/// again. That is why there is no cursor and no "backfill done" flag — a second
/// source of truth about what has been sent is a thing that can disagree with
/// the queue, and the queue is already the answer.
///
/// It reads current rows, never remembered ones, so an envelope it produces can
/// never be staler than a change queued beside it.
library;

import 'sync_envelope.dart';

/// What one backfill run put in the queue.
final class SyncBackfillReport {
  SyncBackfillReport({
    required Map<SyncEntityType, int> enqueuedByType,
    Map<SyncEntityType, int> skippedByType = const <SyncEntityType, int>{},
  }) : enqueuedByType = Map<SyncEntityType, int>.unmodifiable(enqueuedByType),
       skippedByType = Map<SyncEntityType, int>.unmodifiable(skippedByType);

  final Map<SyncEntityType, int> enqueuedByType;

  /// Rows this build could not turn into an envelope, by type.
  ///
  /// Counted rather than silently dropped: a backfill that quietly sends less
  /// than the whole history is the failure mode this feature can least afford,
  /// and a number the caller can log is what makes it noticeable.
  final Map<SyncEntityType, int> skippedByType;

  int get enqueuedCount =>
      enqueuedByType.values.fold(0, (int sum, int count) => sum + count);

  int get skippedCount =>
      skippedByType.values.fold(0, (int sum, int count) => sum + count);

  bool get isEmpty => enqueuedCount == 0;
}

/// Queues everything this device holds, for an account that has just been
/// allowed to have it.
abstract interface class SyncBackfill {
  /// Enqueues every syncable record. Safe to call again after a failure.
  Future<SyncBackfillReport> enqueueEverything({required DateTime nowUtc});
}
