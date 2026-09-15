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

    test('an edit does not resurrect a pending delete', () async {
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
      expect(
        entries.single.envelope.isTombstone,
        isTrue,
        reason: 'a deleted record must not come back through a queued edit',
      );
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
