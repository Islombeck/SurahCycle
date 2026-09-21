/// One complete exchange with the account: send what is queued, then take what
/// the account has.
///
/// Everything else in this feature is a part that does its job when asked.
/// Nothing asked. The outbox filled, the engine sat still, and the account
/// screen reported a queue that would never move — which is worse than an
/// absent feature, because it looks like one that works.
///
/// **Push before pull, always.** Either order converges under last-writer-wins,
/// but the first cycle after activation is the one that matters: the backfill
/// has just queued a lifetime of history, and sending it before taking anything
/// down means the account has the user's work before anything can land on top
/// of it. The reverse order would apply remote records first and only then
/// discover what this device was holding.
///
/// **A device that was kept local never runs.** Not "runs and finds nothing" —
/// refused outright, because "keep this device local" is an answer and a cycle
/// that quietly talked to the server anyway would be ignoring it.
///
/// **A failure is not an error here.** Being offline is the ordinary state of a
/// phone, the queue is durable, and the whole point of an outbox is that the
/// network cannot undo a local write. So a cycle reports what happened and
/// leaves the retry to whoever asks next.
library;

import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'drift_sync_store.dart';
import 'sync_envelope_router.dart';

final class SyncCycleRunner implements SyncCycle {
  SyncCycleRunner({
    required AppDatabase database,
    required DriftSyncStore store,
    required SyncGateway gateway,
    required DateTime Function() nowUtc,
    SyncBackfill? scan,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _store = store,
       // ignore: prefer_initializing_formals
       _nowUtc = nowUtc,
       // ignore: prefer_initializing_formals
       _scan = scan,
       _router = SyncEnvelopeRouter(database),
       _engine = SyncEngine(outbox: store.outbox, gateway: gateway);

  final DriftSyncStore _store;
  final DateTime Function() _nowUtc;

  /// Collects local changes made since the last cycle, so they are in the queue
  /// before it is drained.
  ///
  /// Optional only so a test can watch the transport without a database full of
  /// rows behind it. In the app it is always present: without it, a change made
  /// after activation would sit in the database with nothing to carry it.
  final SyncBackfill? _scan;

  final SyncEnvelopeRouter _router;
  final SyncEngine _engine;

  /// Guards against two cycles overlapping.
  ///
  /// Two drains would peek the same entries and push them twice; the server's
  /// idempotency key makes that harmless on its side, but the second
  /// acknowledge would remove entries the first was still working on. One at a
  /// time, and a caller that asks during a cycle joins the one already running
  /// rather than starting a second.
  Future<SyncCycleOutcome>? _inFlight;

  @override
  Future<SyncCycleOutcome> runOnce() {
    final running = _inFlight;
    if (running != null) return running;
    final started = _run();
    _inFlight = started;
    return started.whenComplete(() => _inFlight = null);
  }

  /// Puts everything written since the last cycle into the queue.
  ///
  /// The watermark is advanced to **this cycle's start**, not to the latest row
  /// found. A row written while the scan was running carries a time at or after
  /// that start and is therefore picked up next cycle; advancing to the newest
  /// row seen would step over anything written in between.
  ///
  /// It is also never advanced past the clock. A device whose time jumps
  /// backwards would otherwise hold a watermark in its own future and stop
  /// noticing its own changes; scanning again from further back only costs a
  /// few duplicate envelopes, which coalesce.
  ///
  /// The watermark moves only after the enqueue returns. A failure leaves it
  /// where it was and the same window is scanned again, which is the direction
  /// that repeats work rather than skipping it.
  Future<void> _collectLocalChanges() async {
    final scan = _scan;
    if (scan == null) return;
    final now = _nowUtc().toUtc();
    // Truncated to whole seconds, because that is the resolution the v10 touch
    // triggers write at. A watermark carrying milliseconds would sit *after* a
    // row stamped in the same second, and that row would be passed over — for
    // one cycle, since the stored watermark is truncated too, but a change that
    // needs a second cycle to be noticed is a change that looks lost.
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      (now.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final stored = await _store.pushWatermark();
    final since = stored.isAfter(startedAt) ? startedAt : stored;
    await scan.enqueueChangedSince(nowUtc: now, since: since);
    await _store.recordPushWatermark(startedAt);
  }

  Future<SyncCycleOutcome> _run() async {
    if (!await _store.isSyncActive()) return SyncCycleOutcome.skipped;

    await _collectLocalChanges();

    final drain = await _engine.drain();
    if (drain.hasFailure) {
      // Stop here rather than pulling anyway. The queue is what this device
      // knows and the network has just said it cannot be reached; taking
      // records down over local work that failed to go up is the one ordering
      // that can lose a change.
      return SyncCycleOutcome(
        ran: true,
        remainingCount: drain.remaining,
        failureReason: drain.failureReason,
      );
    }

    var pages = 0;
    String? pullFailure;
    try {
      await _engine.pull(
        from: await _store.pullCursor(),
        apply: (page) async {
          pages++;
          // The page is applied and its cursor saved in one transaction: a
          // cursor that moved without its data is how a device silently loses
          // remote changes. The router sorts first so a self-contained page
          // does not stall on its own ordering.
          await _store.applyPulledPage(
            _router.ordered(page),
            apply: _router.apply,
            // One rotation rebuild for the page rather than one per record.
            afterAll: _router.settleProjection,
            nowUtc: _nowUtc().toUtc(),
          );
        },
      );
    } on SyncTransportException catch (error) {
      // Includes an applier refusing a record whose prerequisite has not
      // arrived yet. The cursor stayed where it was, so the same page is
      // fetched again next time rather than skipped.
      pullFailure = error.reason;
    }

    if (pullFailure == null && (drain.didPushAnything || pages > 0)) {
      // Recorded only for a cycle that actually moved something. A successful
      // round trip that carried nothing proves the server is reachable, not
      // that any of this device's data is safe there — and `neverSynced`
      // exists precisely so an empty queue cannot be shown as protection.
      await _store.recordSuccessfulSync(_nowUtc().toUtc());
    }

    return SyncCycleOutcome(
      ran: true,
      pushedCount: drain.pushedEnvelopeIds.length,
      rejectedCount: drain.rejectedEnvelopeIds.length,
      remainingCount: drain.remaining,
      pulledPageCount: pages,
      failureReason: pullFailure,
    );
  }
}
