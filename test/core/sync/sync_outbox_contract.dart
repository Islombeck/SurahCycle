import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

import 'sync_fixtures.dart';

/// The behaviour every [SyncOutbox] implementation must have.
///
/// This is written as a reusable suite on purpose: the durable, database-backed
/// outbox that ships with real sync has to pass exactly these tests, so the
/// guarantees are defined once rather than re-argued per implementation.
void runSyncOutboxContract(String name, SyncOutbox Function() createOutbox) {
  group('$name honours the outbox contract', () {
    late SyncOutbox outbox;

    setUp(() => outbox = createOutbox());

    test('an empty outbox has nothing pending', () async {
      expect(await outbox.pendingCount(), 0);
      expect(await outbox.peek(), isEmpty);
    });

    test('a queue drains in the order it was filled', () async {
      // Every entry of a backfill is enqueued in the same instant, so ordering
      // by time alone leaves several hundred of them in no order at all. This
      // was ordered by envelope id, which is stable across reads and random
      // across entries — and a rotation adjustment reaching an account ahead
      // of the recitations it adjusts is refused on the far side, because the
      // projection rebuilt from a journal missing them goes negative.
      const moment = 5;
      for (var index = 0; index < 20; index += 1) {
        await outbox.enqueue(
          envelopeOf(entityId: 'entity-$index', id: 'envelope-$index'),
          nowUtc: at(moment),
        );
      }

      expect(
        (await outbox.peek(
          limit: 50,
        )).map((entry) => entry.envelope.id).toList(),
        <String>[for (var index = 0; index < 20; index += 1) 'envelope-$index'],
        reason: 'a queue that reorders its own contents is not a queue',
      );
    });

    test('a coalesced entry goes to the back, not to its old place', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'first', id: 'e1'),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'second', id: 'e2'),
        nowUtc: at(1),
      );
      // A newer version of the first entity, at the same queue moment.
      await outbox.enqueue(
        envelopeOf(entityId: 'first', id: 'e3', updatedMinute: 9),
        nowUtc: at(1),
      );

      expect(
        (await outbox.peek()).map((entry) => entry.envelope.id).toList(),
        <String>['e2', 'e3'],
        reason:
            'the replacement is the newest thing in the queue, and pretending '
            'it is as old as what it replaced puts it before later work',
      );
    });

    test('an enqueued change is pending and readable', () async {
      await outbox.enqueue(envelopeOf(entityId: 'a'), nowUtc: at(1));

      expect(await outbox.pendingCount(), 1);
      final entries = await outbox.peek();
      expect(entries.single.envelope.entityId, 'a');
      expect(entries.single.attemptCount, 0);
      expect(entries.single.enqueuedAtUtc, at(1));
    });

    test('entries drain oldest first', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'b', id: 'e2'),
        nowUtc: at(2),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'c', id: 'e3'),
        nowUtc: at(3),
      );

      expect((await outbox.peek()).map((entry) => entry.envelope.id), <String>[
        'e1',
        'e2',
        'e3',
      ]);
    });

    test('peek respects its limit', () async {
      for (var index = 0; index < 5; index += 1) {
        await outbox.enqueue(
          envelopeOf(entityId: 'e$index', id: 'id$index'),
          nowUtc: at(index + 1),
        );
      }

      expect(await outbox.peek(limit: 2), hasLength(2));
      expect(
        await outbox.pendingCount(),
        5,
        reason: 'peek must not consume entries',
      );
    });

    test('repeated edits to one entity coalesce into one push', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1', updatedMinute: 1),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e2', updatedMinute: 2),
        nowUtc: at(2),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e3', updatedMinute: 3),
        nowUtc: at(3),
      );

      expect(await outbox.pendingCount(), 1);
      expect((await outbox.peek()).single.envelope.id, 'e3');
    });

    test('different entities never coalesce', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'b', id: 'e2'),
        nowUtc: at(2),
      );

      expect(await outbox.pendingCount(), 2);
    });

    test('one envelope id cannot silently overwrite another entity', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'shared-envelope'),
        nowUtc: at(1),
      );

      await expectLater(
        outbox.enqueue(
          envelopeOf(entityId: 'b', id: 'shared-envelope'),
          nowUtc: at(2),
        ),
        throwsStateError,
      );

      final queued = await outbox.peek();
      expect(queued, hasLength(1));
      expect(queued.single.envelope.entityId, 'a');
    });

    test('the same id under two entity types stays separate', () async {
      await outbox.enqueue(
        envelopeOf(
          entityId: 'shared',
          id: 'e1',
          entityType: SyncEntityType.appSetting,
        ),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(
          entityId: 'shared',
          id: 'e2',
          entityType: SyncEntityType.recallAttempt,
        ),
        nowUtc: at(2),
      );

      expect(await outbox.pendingCount(), 2);
    });

    test('a pending delete swallows a pending edit', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1', updatedMinute: 1),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        tombstoneOf(entityId: 'a', id: 'e2', updatedMinute: 2),
        nowUtc: at(2),
      );

      final entries = await outbox.peek();
      expect(entries, hasLength(1));
      expect(entries.single.envelope.isTombstone, isTrue);
    });

    test('a stale edit does not resurrect a pending delete', () async {
      await outbox.enqueue(
        tombstoneOf(entityId: 'a', id: 'e1', updatedMinute: 5),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e2', updatedMinute: 2),
        nowUtc: at(2),
      );

      final entries = await outbox.peek();
      expect(entries, hasLength(1));
      expect(
        entries.single.envelope.isTombstone,
        isTrue,
        reason:
            'the edit describes the record as it was before it was withdrawn, '
            'so letting it through would undo a deletion nobody asked to undo',
      );
    });

    test('a later edit does undo a pending delete', () async {
      // This inverts what the contract used to require, and deliberately.
      // "A pending delete is only superseded by a later delete" was right while
      // a deletion was final; History now has an undo, and a restore *is* an
      // upsert whose whole purpose is to bring the record back everywhere.
      // Under the old rule a delete-then-restore between two drains reached the
      // account as the deletion alone, leaving the device showing a recitation
      // the account believed gone — permanently, with nothing to correct it.
      await outbox.enqueue(
        tombstoneOf(entityId: 'a', id: 'e1', updatedMinute: 2),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e2', updatedMinute: 3),
        nowUtc: at(2),
      );

      final entries = await outbox.peek();
      expect(entries, hasLength(1));
      expect(entries.single.envelope.isTombstone, isFalse);
      expect(entries.single.envelope.id, 'e2');
    });

    test(
      'an out-of-order edit does not overwrite a newer pending one',
      () async {
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'newer', updatedMinute: 5),
          nowUtc: at(1),
        );
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'older', updatedMinute: 2),
          nowUtc: at(2),
        );

        expect((await outbox.peek()).single.envelope.id, 'newer');
      },
    );

    test('acknowledging removes only what was accepted', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'b', id: 'e2'),
        nowUtc: at(2),
      );

      await outbox.acknowledge(<String>['e1']);

      expect(await outbox.pendingCount(), 1);
      expect((await outbox.peek()).single.envelope.id, 'e2');
    });

    test('acknowledging an unknown id is harmless', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );

      await outbox.acknowledge(<String>['not-queued']);

      expect(await outbox.pendingCount(), 1);
    });

    test('an acknowledged entity can be enqueued again', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await outbox.acknowledge(<String>['e1']);

      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e2', updatedMinute: 5),
        nowUtc: at(5),
      );

      expect(await outbox.pendingCount(), 1);
      expect((await outbox.peek()).single.envelope.id, 'e2');
    });

    test('a failure keeps the entry and counts the attempt', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );

      await outbox.recordFailure(<String>['e1'], 'offline');

      final entries = await outbox.peek();
      expect(entries, hasLength(1), reason: 'a failed push must not lose data');
      expect(entries.single.attemptCount, 1);
      expect(entries.single.lastFailureReason, 'offline');

      await outbox.recordFailure(<String>['e1'], 'offline');
      expect((await outbox.peek()).single.attemptCount, 2);
    });

    test(
      'a permanent rejection is quarantined and remains inspectable',
      () async {
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e1'),
          nowUtc: at(1),
        );

        await outbox.quarantine(<String>['e1'], 'schema_too_new');

        expect(await outbox.pendingCount(), 0);
        expect(await outbox.peek(), isEmpty);
        final quarantined = await outbox.quarantined();
        expect(quarantined, hasLength(1));
        expect(quarantined.single.envelope.id, 'e1');
        expect(quarantined.single.lastFailureReason, 'schema_too_new');
        expect(quarantined.single.attemptCount, 1);
      },
    );

    group('offering the refused entries again', () {
      // The recovery `quarantine` has always promised. It was needed for real
      // on 2026-09-22: a defect in this client made the server refuse every
      // record whose id contains a colon — 112 of the owner's prayer sessions,
      // routines and schemes — and they were still good records.
      test('a refused entry goes back in the queue with its envelope', () async {
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e1'),
          nowUtc: at(1),
        );
        await outbox.quarantine(<String>['e1'], 'rejected-by-server');

        expect(await outbox.requeueQuarantined(), 1);

        expect(await outbox.quarantined(), isEmpty);
        final pending = await outbox.peek();
        expect(pending.single.envelope.id, 'e1');
        expect(
          pending.single.attemptCount,
          0,
          reason:
              'the count is about a queue that was failing; this one is being '
              'offered for the first time since the reason was fixed',
        );
        expect(pending.single.lastFailureReason, isNull);
      });

      test('a newer pending entry for the same record wins', () async {
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e1'),
          nowUtc: at(1),
        );
        await outbox.quarantine(<String>['e1'], 'rejected-by-server');
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e2', updatedMinute: 5),
          nowUtc: at(5),
        );

        expect(
          await outbox.requeueQuarantined(),
          0,
          reason:
              'the queue already holds a newer answer about that record, and '
              'only one entry per record may be pending at a time',
        );
        expect((await outbox.peek()).single.envelope.id, 'e2');
        expect(await outbox.quarantined(), isEmpty);
      });

      test('two refusals about one record come back as one', () async {
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e1'),
          nowUtc: at(1),
        );
        await outbox.quarantine(<String>['e1'], 'rejected-by-server');
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e2', updatedMinute: 5),
          nowUtc: at(5),
        );
        await outbox.quarantine(<String>['e2'], 'rejected-by-server');

        expect(await outbox.requeueQuarantined(), 1);

        expect(
          (await outbox.peek()).single.envelope.id,
          'e2',
          reason: 'the newer version of the record is the one worth sending',
        );
      });

      test('nothing refused is nothing to do', () async {
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e1'),
          nowUtc: at(1),
        );

        expect(await outbox.requeueQuarantined(), 0);
        expect((await outbox.peek()).single.envelope.id, 'e1');
      });
    });

    test('quarantining an unknown id is harmless', () async {
      await outbox.quarantine(<String>['missing'], 'rejected');

      expect(await outbox.pendingCount(), 0);
      expect(await outbox.quarantined(), isEmpty);
    });

    test('quarantine requires a reason and positive read limit', () async {
      expect(
        () => outbox.quarantine(const <String>[], ''),
        throwsArgumentError,
      );
      expect(() => outbox.quarantined(limit: 0), throwsArgumentError);
    });

    test('clearing empties the queue', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'b', id: 'e2'),
        nowUtc: at(2),
      );

      await outbox.clear();

      expect(await outbox.pendingCount(), 0);
      expect(await outbox.peek(), isEmpty);
      expect(await outbox.quarantined(), isEmpty);
    });

    test('a local timestamp is refused', () async {
      expect(
        () => outbox.enqueue(
          envelopeOf(entityId: 'a'),
          nowUtc: DateTime(2026, 9, 15),
        ),
        throwsArgumentError,
      );
    });

    test('a non-positive peek limit is refused', () async {
      expect(() => outbox.peek(limit: 0), throwsArgumentError);
    });
  });
}
