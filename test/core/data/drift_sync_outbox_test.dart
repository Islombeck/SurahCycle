import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';

import '../sync/sync_fixtures.dart';
import '../sync/sync_outbox_contract.dart';

void main() {
  // The durable implementation must satisfy exactly the contract the in-memory
  // reference does. A weaker suite for the one that ships would move the
  // guarantees to wherever they were easiest to keep.
  runSyncOutboxContract('DriftSyncOutbox', () {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    return DriftSyncOutbox(database);
  });

  group('DriftSyncOutbox keeps owners apart', () {
    late AppDatabase database;
    late DriftSyncOutbox forA;
    late DriftSyncOutbox forB;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      forA = DriftSyncOutbox(database, owner: SyncOwnerKey.user('a'));
      forB = DriftSyncOutbox(database, owner: SyncOwnerKey.user('b'));
    });

    test('one account never drains another account\'s queue', () async {
      await forA.enqueue(
        envelopeOf(entityId: 'x', id: 'a1'),
        nowUtc: at(1),
      );

      expect(await forA.pendingCount(), 1);
      expect(
        await forB.pendingCount(),
        0,
        reason: 'signing in as B must not inherit A\'s unsent history',
      );
      expect(await forB.peek(), isEmpty);
    });

    test('the same entity can be queued once per owner', () async {
      await forA.enqueue(
        envelopeOf(entityId: 'x', id: 'a1'),
        nowUtc: at(1),
      );
      await forB.enqueue(
        envelopeOf(entityId: 'x', id: 'b1'),
        nowUtc: at(2),
      );

      expect((await forA.peek()).single.envelope.id, 'a1');
      expect((await forB.peek()).single.envelope.id, 'b1');
    });

    test('one envelope id may be reused by a different owner', () async {
      await forA.enqueue(
        envelopeOf(entityId: 'x', id: 'shared'),
        nowUtc: at(1),
      );

      // The id collision rule protects one owner's queue from itself; it is not
      // a global registry, and B has never seen A's envelope.
      await forB.enqueue(
        envelopeOf(entityId: 'y', id: 'shared'),
        nowUtc: at(2),
      );

      expect((await forA.peek()).single.envelope.entityId, 'x');
      expect((await forB.peek()).single.envelope.entityId, 'y');
    });

    test('acknowledging is scoped to its own owner', () async {
      await forA.enqueue(
        envelopeOf(entityId: 'x', id: 'shared'),
        nowUtc: at(1),
      );
      await forB.enqueue(
        envelopeOf(entityId: 'y', id: 'shared'),
        nowUtc: at(2),
      );

      await forB.acknowledge(<String>['shared']);

      expect(await forA.pendingCount(), 1);
      expect(await forB.pendingCount(), 0);
    });

    test('clearing one owner leaves the other queue intact', () async {
      await forA.enqueue(
        envelopeOf(entityId: 'x', id: 'a1'),
        nowUtc: at(1),
      );
      await forB.enqueue(
        envelopeOf(entityId: 'y', id: 'b1'),
        nowUtc: at(2),
      );
      await forB.quarantine(<String>['b1'], 'rejected');

      await forB.clear();

      expect(await forA.pendingCount(), 1);
      expect(await forB.pendingCount(), 0);
      expect(await forB.quarantined(), isEmpty);
      expect(await forA.quarantined(), isEmpty);
    });
  });

  test('a queued change outlives the process that made it', () async {
    final directory = await Directory.systemTemp.createTemp('murajaah-outbox-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/murajaah.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await DriftSyncOutbox(first).enqueue(
      envelopeOf(entityId: 'x', id: 'e1', updatedMinute: 4),
      nowUtc: at(1),
    );
    await first.close();

    // This is the whole reason the durable outbox exists: a change that already
    // committed locally must not depend on the process that made it staying
    // alive. The in-memory reference cannot make this promise.
    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final entry = (await DriftSyncOutbox(reopened).peek()).single;
    expect(entry.envelope.id, 'e1');
    expect(entry.envelope.entityId, 'x');
    expect(entry.envelope.updatedAtUtc, at(4));
    expect(
      entry.enqueuedAtUtc,
      at(1),
      reason: 'the enqueue instant must survive exactly, not to the second',
    );
  });

  test('a rejected envelope keeps its payload for inspection', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final outbox = DriftSyncOutbox(database);

    await outbox.enqueue(
      envelopeOf(
        entityId: 'x',
        id: 'e1',
        payload: const <String, Object?>{'value': 'cannot be lost'},
      ),
      nowUtc: at(1),
    );
    await outbox.quarantine(<String>['e1'], 'schema_too_new');

    final quarantined = (await outbox.quarantined()).single;
    expect(quarantined.envelope.payload['value'], 'cannot be lost');
    expect(quarantined.lastFailureReason, 'schema_too_new');
  });
}
