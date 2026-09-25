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

  /// Empties the queue, rather than taking one batch out of it.
  ///
  /// The engine pushes at most a batch per call, and the cycle used to call it
  /// once. A backfill queues a lifetime of history — his was 985 envelopes —
  /// so "Синхронизировать сейчас" moved fifty of them and stopped, and the
  /// owner pressing it read the unchanged-looking number as nothing happening.
  /// It happened for real on 2026-09-23, with 112 recovered records leaving
  /// fifty at a time.
  ///
  /// Three ways to stop, and a queue can only be one of them: emptied, refused
  /// by the network, or making no progress. The round cap is a backstop
  /// against a queue that somehow reports work it never drains, not a limit
  /// anyone should reach.
  Future<SyncDrainOutcome> _drainQueue() async {
    const maxRounds = 40;
    final pushed = <String>[];
    final rejected = <String>[];
    var remaining = 0;
    for (var round = 0; round < maxRounds; round += 1) {
      final outcome = await _engine.drain();
      pushed.addAll(outcome.pushedEnvelopeIds);
      rejected.addAll(outcome.rejectedEnvelopeIds);
      remaining = outcome.remaining;
      final movedNothing =
          outcome.pushedEnvelopeIds.isEmpty &&
          outcome.rejectedEnvelopeIds.isEmpty;
      if (outcome.hasFailure || remaining == 0 || movedNothing) {
        return SyncDrainOutcome(
          pushedEnvelopeIds: pushed,
          rejectedEnvelopeIds: rejected,
          remaining: remaining,
          failureReason: outcome.failureReason,
        );
      }
    }
    return SyncDrainOutcome(
      pushedEnvelopeIds: pushed,
      rejectedEnvelopeIds: rejected,
      remaining: remaining,
    );
  }

  Future<SyncCycleOutcome> _run() async {
    if (!await _store.isSyncActive()) return SyncCycleOutcome.skipped;

    await _collectLocalChanges();

    final drain = await _drainQueue();
    if (drain.hasFailure) {
      await _store.recordCycleFailure(drain.failureReason);
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
    // Records whose prerequisite was not in their own page. The account hands
    // pages back in the order rows reached it, and that order is **not**
    // dependency order: his 842 recitations were written a day before the
    // rotation schemes they point at, because those schemes were refused by an
    // older build and only recovered afterwards. Sorting a page cannot fix what
    // is not in the page.
    //
    // Since v11 they are **durable**, so this list is a working copy of a table
    // rather than the only record of them: a restart keeps them, and the cursor
    // no longer has to wait behind one that can never be placed.
    var deferred = await _store.pendingInbox();
    String? deferredReason;
    try {
      await _engine.pull(
        from: await _store.pullCursor(),
        apply: (page) async {
          pages++;
          // The page is applied and its cursor saved in one transaction: a
          // cursor that moved without its data is how a device silently loses
          // remote changes. The router sorts first — the carried-over records
          // ahead of the new ones at the same rank, which is the order they
          // arrived in — so a page that is self-contained applies in one go.
          final carried = <String>{for (final one in deferred) one.id};
          final residue = await _store.applyPulledPage(
            _router.ordered(
              SyncPullPage(
                envelopes: <SyncEnvelope>[...deferred, ...page.envelopes],
                cursor: page.cursor,
                hasMore: page.hasMore,
              ),
            ),
            apply: _router.apply,
            // One rotation rebuild for the page rather than one per record.
            afterAll: _router.settleProjection,
            nowUtc: _nowUtc().toUtc(),
            retrying: carried,
          );
          deferred = residue.deferred;
          deferredReason = residue.reason;
        },
      );
    } on SyncTransportException catch (error) {
      // A transport failure, or a record this build cannot place at all. The
      // cursor stayed where it was, so the same page is fetched again next
      // time rather than skipped.
      pullFailure = error.reason;
    } on Object catch (error) {
      // **Anything else, which used to escape the cycle entirely.** A row this
      // build cannot read, a constraint the appliers did not expect, a plain
      // bug: `runOnce` threw, whoever called it had no answer for that, and
      // the device was left with its watermark advanced, its cursor unmoved
      // and nothing written down. His phone spent 2026-09-23 and the night
      // after it in exactly that state — pushing fine, receiving nothing,
      // reporting success from the morning before.
      //
      // The type only, never the message: a message can quote a row, and a row
      // is his. It is enough to tell a network apart from a defect.
      pullFailure = 'pull-failed-${error.runtimeType}';
    }

    // Records still waiting when the account ran out of pages. Their
    // prerequisite did not come in this cycle, so this is a real failure and
    // says so on the account screen. It no longer holds the cursor: they are in
    // the inbox, they are counted, and the next cycle retries them ahead of
    // whatever arrives next.
    if (pullFailure == null && deferred.isNotEmpty) {
      pullFailure = deferredReason ?? 'remote-prerequisite-never-arrived';
    }

    // **Nothing is re-offered to correct the account.** There used to be a
    // re-scan here: when an incoming record lost to a local one, the cycle
    // scanned again from the losing record's date and pushed whatever that
    // window held, so the account would stop "holding a stale copy".
    //
    // It was written for an account that kept one row per record and rewrote
    // it. This one is a log — a row is written once and never rewritten — and
    // §1 of ADR-0002 is decided per record on every device, so an older row
    // further down the log cannot mislead anyone who reads it. The two-device
    // suite proves that directly: a third phone joining after the older edit
    // was pushed last still ends on the newer one.
    //
    // And the window was not a detail. An undated record carries the epoch, so
    // on his second phone the scan started at 1970 and re-offered the entire
    // database — 919 records, moments after it had received them.
    //
    // Recorded, or cleared, on every cycle that got this far. A pull that
    // stalls leaves nothing in the queue to explain itself — the queue is
    // empty and the cursor merely stops moving — so without this the account
    // screen reports a perfectly healthy device that is receiving nothing.
    await _store.recordCycleFailure(pullFailure);

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
