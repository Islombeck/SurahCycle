import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

import 'sync_fixtures.dart';

/// The engine's job is to never lose a local change and never skip a remote
/// one. Both halves are failure-path behaviour, so that is what these test.
void main() {
  late FakeSyncBackend backend;
  late InMemorySyncOutbox outbox;
  late FakeSyncGateway gateway;
  late SyncEngine engine;

  setUp(() {
    backend = FakeSyncBackend();
    outbox = InMemorySyncOutbox();
    gateway = FakeSyncGateway(backend: backend, userId: 'user-1');
    engine = SyncEngine(outbox: outbox, gateway: gateway);
  });

  group('draining', () {
    test('an empty outbox is a no-op', () async {
      final outcome = await engine.drain();

      expect(outcome.didPushAnything, isFalse);
      expect(outcome.remaining, 0);
      expect(outcome.hasFailure, isFalse);
    });

    test('queued changes reach the backend and leave the queue', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'b', id: 'e2'),
        nowUtc: at(2),
      );

      final outcome = await engine.drain();

      expect(outcome.pushedEnvelopeIds, <String>['e1', 'e2']);
      expect(outcome.remaining, 0);
      expect(backend.recordsOf('user-1'), hasLength(2));
    });

    test('a transport failure loses nothing', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      gateway.failNextPush = true;

      final outcome = await engine.drain();

      expect(outcome.didPushAnything, isFalse);
      expect(outcome.failureReason, 'offline');
      expect(
        outcome.remaining,
        1,
        reason: 'the local write already succeeded and must survive',
      );
      expect((await outbox.peek()).single.attemptCount, 1);
      expect(backend.recordsOf('user-1'), isEmpty);
    });

    test('the next drain after a failure succeeds', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      gateway.failNextPush = true;
      await engine.drain();

      final outcome = await engine.drain();

      expect(outcome.pushedEnvelopeIds, <String>['e1']);
      expect(outcome.remaining, 0);
      expect(backend.recordsOf('user-1'), hasLength(1));
    });

    test('a retried push does not duplicate the record', () async {
      final envelope = envelopeOf(
        entityId: 'a',
        id: 'e1',
        idempotencyKey: 'stable-key',
      );
      await outbox.enqueue(envelope, nowUtc: at(1));
      await engine.drain();

      // The same change queued again, as an ambiguous failure would leave it.
      await outbox.enqueue(envelope, nowUtc: at(2));
      await engine.drain();

      expect(backend.recordsOf('user-1'), hasLength(1));
    });

    test(
      'a permanent rejection is quarantined rather than retried forever',
      () async {
        await outbox.enqueue(
          envelopeOf(entityId: 'a', id: 'e1', schemaVersion: 99),
          nowUtc: at(1),
        );

        final outcome = await engine.drain();

        expect(outcome.rejectedEnvelopeIds, <String>['e1']);
        expect(outcome.pushedEnvelopeIds, isEmpty);
        expect(outcome.remaining, 0);
        expect(await outbox.peek(), isEmpty);
        final quarantined = await outbox.quarantined();
        expect(quarantined, hasLength(1));
        expect(quarantined.single.lastFailureReason, 'schema_too_new');
      },
    );

    test('a mixed batch accepts what it can', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'ok'),
        nowUtc: at(1),
      );
      await outbox.enqueue(
        envelopeOf(entityId: 'b', id: 'bad', schemaVersion: 99),
        nowUtc: at(2),
      );

      final outcome = await engine.drain();

      expect(outcome.pushedEnvelopeIds, <String>['ok']);
      expect(outcome.rejectedEnvelopeIds, <String>['bad']);
      expect(outcome.remaining, 0);
      expect((await outbox.quarantined()).single.envelope.id, 'bad');
    });

    test('the batch size is respected', () async {
      for (var index = 0; index < 5; index += 1) {
        await outbox.enqueue(
          envelopeOf(entityId: 'e$index', id: 'id$index'),
          nowUtc: at(index + 1),
        );
      }

      final outcome = await engine.drain(batchSize: 2);

      expect(outcome.pushedEnvelopeIds, hasLength(2));
      expect(outcome.remaining, 3);
    });

    test('an invalid gateway response acknowledges nothing', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      final broken = _FixedResultGateway(
        SyncPushResult(acceptedEnvelopeIds: const <String>['not-sent']),
      );
      final guardedEngine = SyncEngine(outbox: outbox, gateway: broken);

      final outcome = await guardedEngine.drain();

      expect(outcome.failureReason, 'invalid_response');
      expect(outcome.remaining, 1);
      expect((await outbox.peek()).single.envelope.id, 'e1');
      expect((await outbox.peek()).single.attemptCount, 1);
    });

    test('accepted and rejected response ids must be disjoint', () async {
      await outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      final broken = _FixedResultGateway(
        SyncPushResult(
          acceptedEnvelopeIds: const <String>['e1'],
          rejectedEnvelopeIds: const <String>['e1'],
        ),
      );

      final outcome = await SyncEngine(outbox: outbox, gateway: broken).drain();

      expect(outcome.failureReason, 'invalid_response');
      expect(await outbox.pendingCount(), 1);
    });

    test('a non-positive push batch is refused', () {
      expect(() => engine.drain(batchSize: 0), throwsArgumentError);
    });
  });

  group('pulling', () {
    Future<SyncCursor> seedRemote(int count) async {
      for (var index = 0; index < count; index += 1) {
        backend.push('user-1', <SyncEnvelope>[
          envelopeOf(
            entityId: 'remote-$index',
            id: 'remote-id-$index',
            idempotencyKey: 'remote-key-$index',
          ),
        ]);
      }
      return SyncCursor.beginning;
    }

    test('an empty remote leaves the cursor alone', () async {
      final applied = <SyncEnvelope>[];

      final cursor = await engine.pull(
        from: SyncCursor.beginning,
        apply: (page) async => applied.addAll(page.envelopes),
      );

      expect(applied, isEmpty);
      expect(cursor, SyncCursor.beginning);
    });

    test('every page is applied and the cursor advances', () async {
      final from = await seedRemote(5);
      final applied = <SyncEnvelope>[];

      final cursor = await engine.pull(
        from: from,
        pageSize: 2,
        apply: (page) async => applied.addAll(page.envelopes),
      );

      expect(applied, hasLength(5));
      expect(cursor, isNot(SyncCursor.beginning));

      final again = <SyncEnvelope>[];
      await engine.pull(
        from: cursor,
        apply: (page) async => again.addAll(page.envelopes),
      );
      expect(again, isEmpty, reason: 'the cursor must not replay applied data');
    });

    test('a failed apply does not advance the cursor', () async {
      final from = await seedRemote(3);

      await expectLater(
        engine.pull(
          from: from,
          apply: (page) async => throw StateError('local commit failed'),
        ),
        throwsStateError,
      );

      final retried = <SyncEnvelope>[];
      await engine.pull(
        from: from,
        apply: (page) async => retried.addAll(page.envelopes),
      );
      expect(
        retried,
        hasLength(3),
        reason: 'an interrupted pull is retried, never skipped',
      );
    });

    test('a partially failed pull resumes from the committed page', () async {
      final from = await seedRemote(4);
      var pagesApplied = 0;
      var cursor = from;

      await expectLater(
        engine.pull(
          from: from,
          pageSize: 2,
          apply: (page) async {
            pagesApplied += 1;
            if (pagesApplied == 2) throw StateError('local commit failed');
            cursor = page.cursor;
          },
        ),
        throwsStateError,
      );

      final remaining = <SyncEnvelope>[];
      await engine.pull(
        from: cursor,
        apply: (page) async => remaining.addAll(page.envelopes),
      );
      expect(
        remaining,
        hasLength(2),
        reason: 'only the uncommitted half is fetched again',
      );
    });

    test('a non-positive page budget is refused', () async {
      expect(
        () => engine.pull(
          from: SyncCursor.beginning,
          apply: (page) async {},
          maxPages: 0,
        ),
        throwsArgumentError,
      );
    });

    test('a non-positive page size is refused', () async {
      expect(
        () => engine.pull(
          from: SyncCursor.beginning,
          pageSize: 0,
          apply: (page) async {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('accounts', () {
    late FakeAccountGateway account;

    setUp(() => account = FakeAccountGateway(backend: backend));

    test('nobody is signed in to begin with', () async {
      expect(await account.currentAccount(), isNull);
    });

    test('signing in establishes one account with its provider', () async {
      final signedIn = await account.signIn(SyncAuthProvider.google);

      expect(signedIn.linkedProviders, <SyncAuthProvider>{
        SyncAuthProvider.google,
      });
      expect(await account.currentAccount(), signedIn);
    });

    test('linking requires an authenticated user', () async {
      await expectLater(
        account.linkIdentity(SyncAuthProvider.yandex),
        throwsA(isA<SyncIdentityLinkException>()),
      );
    });

    test('an authenticated user can link the second provider', () async {
      await account.signIn(SyncAuthProvider.google);

      final linked = await account.linkIdentity(SyncAuthProvider.yandex);

      expect(linked.linkedProviders, <SyncAuthProvider>{
        SyncAuthProvider.google,
        SyncAuthProvider.yandex,
      });
      expect(linked.userId, 'user-1');
    });

    test('linking the same provider twice is refused', () async {
      await account.signIn(SyncAuthProvider.google);

      await expectLater(
        account.linkIdentity(SyncAuthProvider.google),
        throwsA(isA<SyncIdentityLinkException>()),
      );
    });

    test('signing out drops the session but keeps the data', () async {
      await account.signIn(SyncAuthProvider.google);
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'a')]);

      await account.signOut();

      expect(await account.currentAccount(), isNull);
      expect(backend.recordsOf('user-1'), hasLength(1));
    });

    test('export returns the user\'s own records', () async {
      await account.signIn(SyncAuthProvider.google);
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'a')]);

      final exported = await account.exportCloudData();

      expect(exported['formatVersion'], 1);
      expect(exported['userId'], 'user-1');
      expect(exported['records'], hasLength(1));
      final record = (exported['records'] as List<Object?>).single;
      expect(record, isA<Map<String, Object?>>());
      final fields = record! as Map<String, Object?>;
      expect(fields['id'], isNotEmpty);
      expect(fields['deviceId'], isNotEmpty);
      expect(fields['idempotencyKey'], isNotEmpty);
    });

    test('export requires a session', () async {
      await expectLater(
        account.exportCloudData(),
        throwsA(isA<SyncIdentityLinkException>()),
      );
    });

    test('deleting the account erases the stored copy too', () async {
      await account.signIn(SyncAuthProvider.google);
      backend.push('user-1', <SyncEnvelope>[envelopeOf(entityId: 'a')]);

      await account.deleteCloudAccount();

      expect(await account.currentAccount(), isNull);
      expect(
        backend.recordsOf('user-1'),
        isEmpty,
        reason: 'a delete that only signs out would be a lie',
      );
    });

    test('sign-in cannot silently link a second provider', () async {
      await account.signIn(SyncAuthProvider.google);

      await expectLater(
        account.signIn(SyncAuthProvider.yandex),
        throwsA(isA<SyncIdentityLinkException>()),
      );
      expect(
        (await account.currentAccount())?.linkedProviders,
        <SyncAuthProvider>{SyncAuthProvider.google},
      );
    });

    test('first sync requires a backup-bound explicit merge choice', () async {
      final signedIn = await account.signIn(SyncAuthProvider.google);
      final activation = FakeSyncActivationGateway(
        preview: SyncMergePreview(
          token: 'preview-1',
          backupId: 'backup-1',
          localOnlyCount: 3,
          remoteOnlyCount: 2,
          sharedCount: 1,
          conflictCount: 1,
        ),
      );

      expect(await activation.isSyncActiveFor(signedIn.userId), isFalse);
      final preview = await activation.prepareFirstSync(signedIn);
      expect(preview.backupId, 'backup-1');
      expect(preview.hasConflicts, isTrue);
      expect(await activation.isSyncActiveFor(signedIn.userId), isFalse);

      await activation.finishFirstSync(
        previewToken: preview.token,
        choice: SyncActivationChoice.merge,
      );
      expect(await activation.isSyncActiveFor(signedIn.userId), isTrue);
    });

    test('a stale preview cannot activate sync', () async {
      final signedIn = await account.signIn(SyncAuthProvider.google);
      final activation = FakeSyncActivationGateway(
        preview: SyncMergePreview(
          token: 'preview-1',
          backupId: 'backup-1',
          localOnlyCount: 0,
          remoteOnlyCount: 0,
          sharedCount: 0,
          conflictCount: 0,
        ),
      );
      await activation.prepareFirstSync(signedIn);

      await expectLater(
        activation.finishFirstSync(
          previewToken: 'stale',
          choice: SyncActivationChoice.merge,
        ),
        throwsA(isA<SyncIdentityLinkException>()),
      );
      expect(await activation.isSyncActiveFor(signedIn.userId), isFalse);
    });
  });
}

final class _FixedResultGateway implements SyncGateway {
  const _FixedResultGateway(this.result);

  final SyncPushResult result;

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) async => result;

  @override
  Future<SyncPullPage> pull({
    required SyncCursor after,
    int limit = 100,
  }) async => SyncPullPage(
    envelopes: const <SyncEnvelope>[],
    cursor: after,
    hasMore: false,
  );
}
