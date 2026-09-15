import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

import 'sync_fixtures.dart';

/// These are the rules a real server has to enforce. Writing them against the
/// local fake makes them executable now, so the eventual backend adapter has a
/// definition to satisfy rather than an intention.
void main() {
  late FakeSyncBackend backend;

  setUp(() => backend = FakeSyncBackend());

  group('isolation', () {
    test('one user never sees another user\'s records', () {
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'mine')]);

      expect(backend.recordsOf('user-2'), isEmpty);
      expect(
        backend.pull('user-2', after: SyncCursor.beginning).envelopes,
        isEmpty,
      );
    });

    test('an envelope addressed to another user is refused', () {
      final result = backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', userId: 'user-2'),
      ]);

      expect(result.acceptedEnvelopeIds, isEmpty);
      expect(result.rejectedEnvelopeIds, hasLength(1));
      expect(result.rejectionReason, 'user_mismatch');
      expect(backend.recordsOf('user-1'), isEmpty);
    });

    test('a pushed envelope is stamped with its owner', () {
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'a')]);

      expect(backend.recordsOf('user-1').single.userId, 'user-1');
    });
  });

  group('idempotency', () {
    test('the same idempotency key is stored once', () {
      final envelope = envelopeOf(entityId: 'a', idempotencyKey: 'k1');

      backend.push('user-1', <SyncEnvelope>[envelope]);
      final retry = backend.push('user-1', <SyncEnvelope>[envelope]);

      expect(backend.recordsOf('user-1'), hasLength(1));
      expect(
        retry.acceptedEnvelopeIds,
        hasLength(1),
        reason: 'a retry must report success or the client retries forever',
      );
    });

    test('a retry does not advance the cursor past unseen data', () {
      final envelope = envelopeOf(entityId: 'a', idempotencyKey: 'k1');
      backend.push('user-1', <SyncEnvelope>[envelope]);
      final first = backend.pull('user-1', after: SyncCursor.beginning);

      backend.push('user-1', <SyncEnvelope>[envelope]);

      expect(
        backend.pull('user-1', after: first.cursor).envelopes,
        isEmpty,
        reason: 'a no-op retry must not look like new data',
      );
    });

    test('distinct keys for the same entity are distinct writes', () {
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'e1', idempotencyKey: 'k1'),
      ]);
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(
          entityId: 'a',
          id: 'e2',
          idempotencyKey: 'k2',
          updatedMinute: 5,
        ),
      ]);

      expect(backend.recordsOf('user-1'), hasLength(1));
      expect(backend.recordsOf('user-1').single.id, 'e2');
    });
  });

  group('deterministic resolution', () {
    test('a newer update wins', () {
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'old', updatedMinute: 1),
      ]);
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'new', updatedMinute: 9),
      ]);

      expect(backend.recordsOf('user-1').single.id, 'new');
    });

    test('an older update never overwrites a newer one', () {
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'new', updatedMinute: 9),
      ]);
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'old', updatedMinute: 1),
      ]);

      expect(backend.recordsOf('user-1').single.id, 'new');
    });

    test('a tie is broken by device so both devices agree', () {
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(
          entityId: 'a',
          id: 'from-a',
          deviceId: 'device-a',
          updatedMinute: 5,
        ),
      ]);
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(
          entityId: 'a',
          id: 'from-b',
          deviceId: 'device-b',
          updatedMinute: 5,
          idempotencyKey: 'other',
        ),
      ]);

      expect(backend.recordsOf('user-1').single.deviceId, 'device-b');
    });

    test('a tombstone beats the record it refers to', () {
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'live', updatedMinute: 9),
      ]);
      backend.push('user-1', <SyncEnvelope>[
        tombstoneOf(entityId: 'a', id: 'gone', updatedMinute: 1),
      ]);

      final stored = backend.recordsOf('user-1').single;
      expect(
        stored.isTombstone,
        isTrue,
        reason: 'a delete must win even when its clock is behind',
      );
    });

    test('an edit does not resurrect a tombstoned record', () {
      backend.push('user-1', <SyncEnvelope>[
        tombstoneOf(entityId: 'a', id: 'gone', updatedMinute: 1),
      ]);
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'back', updatedMinute: 9),
      ]);

      expect(backend.recordsOf('user-1').single.isTombstone, isTrue);
    });

    test('a tombstone stays in the sync log', () {
      backend.push('user-1', <SyncEnvelope>[
        tombstoneOf(entityId: 'a', id: 'gone'),
      ]);

      final pulled = backend.pull('user-1', after: SyncCursor.beginning);
      expect(
        pulled.envelopes.single.isTombstone,
        isTrue,
        reason: 'an offline device learns about the deletion from this',
      );
    });
  });

  group('cursor and paging', () {
    test('pulling from the beginning returns everything', () {
      for (var index = 0; index < 3; index += 1) {
        backend.push('user-1', <SyncEnvelope>[
          envelopeOf(entityId: 'e$index', id: 'id$index'),
        ]);
      }

      final page = backend.pull('user-1', after: SyncCursor.beginning);
      expect(page.envelopes, hasLength(3));
      expect(page.hasMore, isFalse);
    });

    test('a saved cursor returns only what came after it', () {
      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', id: 'first'),
      ]);
      final first = backend.pull('user-1', after: SyncCursor.beginning);

      backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'b', id: 'second'),
      ]);

      final second = backend.pull('user-1', after: first.cursor);
      expect(second.envelopes.map((e) => e.id), <String>['second']);
    });

    test('paging reports more and then finishes', () {
      for (var index = 0; index < 5; index += 1) {
        backend.push('user-1', <SyncEnvelope>[
          envelopeOf(entityId: 'e$index', id: 'id$index'),
        ]);
      }

      final first = backend.pull(
        'user-1',
        after: SyncCursor.beginning,
        limit: 2,
      );
      expect(first.envelopes, hasLength(2));
      expect(first.hasMore, isTrue);

      final second = backend.pull('user-1', after: first.cursor, limit: 2);
      expect(second.hasMore, isTrue);

      final third = backend.pull('user-1', after: second.cursor, limit: 2);
      expect(third.envelopes, hasLength(1));
      expect(third.hasMore, isFalse);
    });

    test('an exhausted cursor keeps its value', () {
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'a')]);
      final first = backend.pull('user-1', after: SyncCursor.beginning);

      final empty = backend.pull('user-1', after: first.cursor);

      expect(empty.envelopes, isEmpty);
      expect(empty.cursor, first.cursor);
    });

    test('a non-positive page size is refused', () {
      expect(
        () => backend.pull('user-1', after: SyncCursor.beginning, limit: 0),
        throwsArgumentError,
      );
    });
  });

  group('schema guard', () {
    test('an envelope from a newer client is refused permanently', () {
      final result = backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', schemaVersion: 99),
      ]);

      expect(result.rejectedEnvelopeIds, hasLength(1));
      expect(result.rejectionReason, 'schema_too_new');
      expect(backend.recordsOf('user-1'), isEmpty);
    });

    test('a supported version is accepted', () {
      final result = backend.push('user-1', <SyncEnvelope>[
        envelopeOf(entityId: 'a', schemaVersion: 6),
      ]);

      expect(result.acceptedEnvelopeIds, hasLength(1));
      expect(result.rejectedEnvelopeIds, isEmpty);
    });
  });

  group('erasure', () {
    test('deleting a user removes their records', () {
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'a')]);

      backend.deleteUser('user-1');

      expect(backend.recordsOf('user-1'), isEmpty);
    });

    test('deleting one user leaves another untouched', () {
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'a')]);
      backend.push('user-2', <SyncEnvelope>[envelopeOf(entityId: 'b')]);

      backend.deleteUser('user-1');

      expect(backend.recordsOf('user-2'), hasLength(1));
    });
  });
}
