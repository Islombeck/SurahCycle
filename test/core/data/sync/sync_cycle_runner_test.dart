import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';

import '../../sync/sync_fixtures.dart';

/// Every part of this feature already did its job when asked. Nothing asked.
/// The queue filled, the engine sat still, and the account screen reported work
/// that would never move — which is worse than an absent feature, because it
/// looks like one that works.
void main() {
  late AppDatabase database;
  late DriftSyncStore store;
  late _RecordingGateway gateway;
  late SyncCycleRunner runner;

  final now = DateTime.utc(2026, 9, 21, 12);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    store = DriftSyncStore(database, owner: SyncOwnerKey.user('user-a'));
    gateway = _RecordingGateway();
    runner = SyncCycleRunner(
      database: database,
      store: store,
      gateway: gateway,
      nowUtc: () => now,
    );
  });

  Future<void> activate() => store.recordActivationChoice(
    choice: SyncActivationChoice.merge,
    backupId: 'backup-1',
    decidedAtUtc: now,
  );

  Future<void> queue(String entityId, {String id = 'e1'}) =>
      store.outbox.enqueue(
        envelopeOf(entityId: entityId, id: id),
        nowUtc: now,
      );

  test('a device that was kept local never talks to the server', () async {
    await store.recordActivationChoice(
      choice: SyncActivationChoice.keepDeviceLocalOnly,
      backupId: 'backup-1',
      decidedAtUtc: now,
    );
    await queue('theme');

    final outcome = await runner.runOnce();

    expect(outcome.ran, isFalse);
    expect(
      gateway.pushes,
      isEmpty,
      reason:
          '"keep this device local" is an answer, and a cycle that talked to '
          'the server anyway would be ignoring it',
    );
    expect(gateway.pulls, isEmpty);
  });

  test('a device that was never asked does not sync either', () async {
    await queue('theme');

    final outcome = await runner.runOnce();

    expect(outcome.ran, isFalse);
    expect(gateway.pushes, isEmpty);
  });

  test('an activated device sends the queue and then reads', () async {
    await activate();
    await queue('theme');

    final outcome = await runner.runOnce();

    expect(outcome.ran, isTrue);
    expect(outcome.pushedCount, 1);
    expect(await store.outbox.pendingCount(), 0);
    expect(
      gateway.order,
      <String>['push', 'pull'],
      reason:
          'the first cycle after activation carries a lifetime of history; it '
          'has to land before anything can be applied on top of it',
    );
  });

  test('an unreachable server leaves the queue exactly as it was', () async {
    await activate();
    await queue('theme');
    gateway.pushFailure = 'network-unreachable';

    final outcome = await runner.runOnce();

    expect(outcome.failureReason, 'network-unreachable');
    expect(
      await store.outbox.pendingCount(),
      1,
      reason: 'the local write already succeeded; a network cannot undo it',
    );
    expect(
      gateway.pulls,
      isEmpty,
      reason:
          'taking records down over local work that failed to go up is the one '
          'ordering that can lose a change',
    );
    expect(
      (await store.activation())?.lastSuccessAtUtc,
      isNull,
      reason: 'a failed cycle is not a success on record',
    );
  });

  test('a cycle that moved something records the success', () async {
    await activate();
    await queue('theme');

    await runner.runOnce();

    expect((await store.activation())?.lastSuccessAtUtc, now);
  });

  test('a cycle that moved nothing records no success', () async {
    await activate();

    final outcome = await runner.runOnce();

    expect(outcome.ran, isTrue);
    expect(outcome.didAnything, isFalse);
    expect(
      (await store.activation())?.lastSuccessAtUtc,
      isNull,
      reason:
          'reaching the server proves it is reachable, not that any of this '
          "device's data is safe there — which is what neverSynced is for",
    );
  });

  test('two callers at once share one cycle', () async {
    await activate();
    await queue('theme');

    final both = await Future.wait(<Future<SyncCycleOutcome>>[
      runner.runOnce(),
      runner.runOnce(),
    ]);

    expect(
      gateway.pushes,
      hasLength(1),
      reason:
          'two drains would peek the same entries, and the second acknowledge '
          'would remove what the first was still working on',
    );
    expect(both.first.pushedCount, both.last.pushedCount);
  });

  test('a permanently refused envelope is quarantined, not retried', () async {
    await activate();
    await queue('theme');
    gateway.rejectEverything = true;

    final outcome = await runner.runOnce();

    expect(outcome.rejectedCount, 1);
    expect(await store.outbox.pendingCount(), 0);
    expect(
      (await store.outbox.quarantined()).length,
      1,
      reason:
          'it blocks nothing and waits to be looked at, rather than rotting',
    );
  });
}

final class _RecordingGateway implements SyncGateway {
  final List<List<SyncEnvelope>> pushes = <List<SyncEnvelope>>[];
  final List<SyncCursor> pulls = <SyncCursor>[];
  final List<String> order = <String>[];

  String? pushFailure;
  bool rejectEverything = false;

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) async {
    order.add('push');
    pushes.add(envelopes);
    if (pushFailure != null) throw SyncTransportException(pushFailure!);
    if (rejectEverything) {
      return SyncPushResult(
        acceptedEnvelopeIds: const <String>[],
        rejectedEnvelopeIds: envelopes.map((envelope) => envelope.id),
        rejectionReason: 'schema-too-new',
      );
    }
    return SyncPushResult(
      acceptedEnvelopeIds: envelopes.map((envelope) => envelope.id),
    );
  }

  @override
  Future<SyncPullPage> pull({
    required SyncCursor after,
    int limit = 100,
  }) async {
    order.add('pull');
    pulls.add(after);
    return SyncPullPage(
      envelopes: const <SyncEnvelope>[],
      cursor: after,
      hasMore: false,
    );
  }
}
