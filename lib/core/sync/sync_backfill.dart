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

/// The date an envelope carries when this device cannot honestly supply one.
///
/// Schema v10 added `updated_at_utc` to six tables and backfilled nothing, so a
/// row untouched since that upgrade records no last-changed time at all. An
/// envelope must carry one, and both obvious answers are a lie: "now" claims
/// the row changed at activation, and it did not; anything in between invents
/// an edit that never happened.
///
/// So it carries a date that is recognisably not a real one, and the choice of
/// *which* unreal date is the whole decision, because last-writer-wins reads it.
/// The epoch makes an undatable local row lose to anything the account can
/// date. That is the safe direction, and it is also the correct one: the only
/// way the account holds a dated copy of a row this device cannot date is that
/// some other device edited it after v10, while this one has not touched it
/// since before. The remote copy really is the newer one.
///
/// The opposite rule — stamping "now" — would let a phone that has not opened a
/// screen in a year overwrite a newer edit from another phone, simply by
/// signing in. That is the loss this whole activation gate exists to prevent,
/// arriving through the back door.
///
/// The user is not being surprised by this. The preview counts exactly these
/// entities on their own line — "cannot be compared" — and the merge they agree
/// to is the one where the account's copy stands for those, with the local copy
/// still in the backup that was taken first.
///
/// A local-only entity is unaffected: with nothing to conflict with, it uploads
/// in full, and the sentinel simply means "as far as this device knows, this
/// has always been so".
final DateTime kUndatedByThisDevice = DateTime.utc(1970);

/// Queues what this device holds, for an account allowed to have it.
abstract interface class SyncBackfill {
  /// Enqueues every syncable record. Safe to call again after a failure.
  Future<SyncBackfillReport> enqueueEverything({required DateTime nowUtc});

  /// Enqueues only what has changed at or after [since].
  ///
  /// This is how changes made *after* activation reach the queue, and it is
  /// deliberately the same walk as the full backfill rather than a second
  /// mechanism beside it. The alternative — a recorder method called from
  /// inside every repository write — has to be remembered at every call site,
  /// and a call site that forgets is a silent hole that nothing fails on. This
  /// asks the database instead, and the database already knows: schema v10 put
  /// touch triggers on every versioned table, so an insert or an update stamps
  /// `updated_at_utc` whether or not the code that did it knew about sync.
  ///
  /// What it cannot see is a row that was **deleted outright**, which leaves
  /// nothing behind to find. The append-only journals are safe — they withdraw
  /// by writing `deleted_at_utc` rather than by removing the row — and the one
  /// remaining hard delete is a learning plan.
  ///
  /// [since] is inclusive, so an entity whose change lands in the same second
  /// as the watermark is offered again rather than risked. That costs a handful
  /// of identical envelopes per cycle and never loses one.
  Future<SyncBackfillReport> enqueueChangedSince({
    required DateTime nowUtc,
    required DateTime since,
  });
}
