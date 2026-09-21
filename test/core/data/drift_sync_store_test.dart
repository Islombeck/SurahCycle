import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';

import '../sync/sync_fixtures.dart';

void main() {
  late AppDatabase database;
  late DriftSyncStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    store = DriftSyncStore(database);
  });

  Future<int> settingCount() async =>
      (await database.select(database.appSettings).get()).length;

  Future<void> writeSetting(String key) => database.customStatement(
    'INSERT INTO app_settings (key, value, value_type, updated_at_utc) '
    'VALUES (?, ?, ?, ?)',
    <Object?>[key, 'v', 'string', 0],
  );

  group('a local change and its queue entry commit together', () {
    test('both land when the local write succeeds', () async {
      await store.commitLocalChangeAndEnqueue(
        envelopeOf(entityId: 'theme', id: 'e1'),
        enqueuedAtUtc: at(1),
        applyLocalChange: () => writeSetting('theme'),
      );

      expect(await settingCount(), 1);
      expect(await store.outbox.pendingCount(), 1);
    });

    test('a failed local write queues nothing', () async {
      await expectLater(
        store.commitLocalChangeAndEnqueue(
          envelopeOf(entityId: 'theme', id: 'e1'),
          enqueuedAtUtc: at(1),
          applyLocalChange: () async {
            await writeSetting('theme');
            throw StateError('domain rule rejected the change');
          },
        ),
        throwsStateError,
      );

      expect(await settingCount(), 0);
      expect(
        await store.outbox.pendingCount(),
        0,
        reason: 'a change that never happened must not be pushed',
      );
    });

    test('a refused enqueue rolls the local write back', () async {
      await store.commitLocalChangeAndEnqueue(
        envelopeOf(entityId: 'theme', id: 'shared'),
        enqueuedAtUtc: at(1),
        applyLocalChange: () => writeSetting('theme'),
      );

      // Reusing one envelope id for a different entity is a programming error.
      // The local write must not survive it, or the device would hold a change
      // the account can never learn about.
      await expectLater(
        store.commitLocalChangeAndEnqueue(
          envelopeOf(entityId: 'locale', id: 'shared'),
          enqueuedAtUtc: at(2),
          applyLocalChange: () => writeSetting('locale'),
        ),
        throwsStateError,
      );

      expect(await settingCount(), 1);
      expect(await store.outbox.pendingCount(), 1);
    });
  });

  group('the pull cursor advances only with the page it describes', () {
    SyncPullPage pageOf(String cursor, List<SyncEnvelope> envelopes) =>
        SyncPullPage(
          envelopes: envelopes,
          cursor: SyncCursor(cursor),
          hasMore: false,
        );

    test('a fresh owner starts at the beginning', () async {
      expect(await store.pullCursor(), SyncCursor.beginning);
      expect((await store.pullCursor()).isBeginning, isTrue);
    });

    test('applying a page saves its cursor', () async {
      await store.applyPulledPage(
        pageOf('page-1', <SyncEnvelope>[envelopeOf(entityId: 'theme')]),
        apply: (envelope) => writeSetting(envelope.entityId),
        nowUtc: at(1),
      );

      expect(await store.pullCursor(), const SyncCursor('page-1'));
      expect(await settingCount(), 1);
    });

    test('a page that fails to apply leaves the cursor where it was', () async {
      await store.applyPulledPage(
        pageOf('page-1', <SyncEnvelope>[envelopeOf(entityId: 'theme')]),
        apply: (envelope) => writeSetting(envelope.entityId),
        nowUtc: at(1),
      );

      await expectLater(
        store.applyPulledPage(
          pageOf('page-2', <SyncEnvelope>[
            envelopeOf(entityId: 'locale', id: 'e2'),
            envelopeOf(entityId: 'broken', id: 'e3'),
          ]),
          apply: (envelope) async {
            if (envelope.entityId == 'broken') {
              throw StateError('cannot apply');
            }
            await writeSetting(envelope.entityId);
          },
          nowUtc: at(2),
        ),
        throwsStateError,
      );

      expect(
        await store.pullCursor(),
        const SyncCursor('page-1'),
        reason: 'the page is re-fetched, never skipped',
      );
      expect(
        await settingCount(),
        1,
        reason: 'half an applied page is not a page',
      );
    });

    test('two owners keep separate cursors', () async {
      final forA = DriftSyncStore(database, owner: SyncOwnerKey.user('a'));
      final forB = DriftSyncStore(database, owner: SyncOwnerKey.user('b'));

      await forA.applyPulledPage(
        pageOf('a-page', const <SyncEnvelope>[]),
        apply: (_) async {},
        nowUtc: at(1),
      );

      expect(await forA.pullCursor(), const SyncCursor('a-page'));
      expect(await forB.pullCursor(), SyncCursor.beginning);
    });

    test('a local timestamp is refused', () {
      // Thrown before any future exists, like `SyncOutbox.enqueue`: a local
      // clock here is a programming error, not a runtime outcome to await.
      expect(
        () => store.applyPulledPage(
          pageOf('page-1', const <SyncEnvelope>[]),
          apply: (_) async {},
          nowUtc: DateTime(2026, 9, 16),
        ),
        throwsArgumentError,
      );
    });
  });

  group('activation is a decision, not a side effect of signing in', () {
    test('an unknown owner is not active', () async {
      expect(await store.activation(), isNull);
      expect(await store.isSyncActive(), isFalse);
    });

    test('choosing merge activates and records the backup', () async {
      await store.recordActivationChoice(
        choice: SyncActivationChoice.merge,
        backupId: 'backup-1',
        decidedAtUtc: at(1),
      );

      final activation = await store.activation();
      expect(activation!.isActive, isTrue);
      expect(activation.choice, SyncActivationChoice.merge);
      expect(activation.backupId, 'backup-1');
      expect(activation.decidedAtUtc, at(1));
      expect(activation.lastSuccessAtUtc, isNull);
    });

    test('choosing to stay local is remembered, not forgotten', () async {
      await store.recordActivationChoice(
        choice: SyncActivationChoice.keepDeviceLocalOnly,
        backupId: 'backup-1',
        decidedAtUtc: at(1),
      );

      final activation = await store.activation();
      expect(activation!.isActive, isFalse);
      expect(
        activation.choice,
        SyncActivationChoice.keepDeviceLocalOnly,
        reason: 'the account screen has to be able to say this was asked',
      );
      expect(await store.isSyncActive(), isFalse);
    });

    test('activation is per owner', () async {
      final forA = DriftSyncStore(database, owner: SyncOwnerKey.user('a'));
      final forB = DriftSyncStore(database, owner: SyncOwnerKey.user('b'));

      await forA.recordActivationChoice(
        choice: SyncActivationChoice.merge,
        backupId: 'backup-a',
        decidedAtUtc: at(1),
      );

      expect(await forA.isSyncActive(), isTrue);
      expect(
        await forB.isSyncActive(),
        isFalse,
        reason: 'one account\'s consent never speaks for another',
      );
    });

    test('a successful sync is recorded against the active owner', () async {
      await store.recordActivationChoice(
        choice: SyncActivationChoice.merge,
        backupId: 'backup-1',
        decidedAtUtc: at(1),
      );

      await store.recordSuccessfulSync(at(5));

      expect((await store.activation())!.lastSuccessAtUtc, at(5));
    });

    test('an empty backup id and a local timestamp are refused', () async {
      await expectLater(
        store.recordActivationChoice(
          choice: SyncActivationChoice.merge,
          backupId: '',
          decidedAtUtc: at(1),
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.recordActivationChoice(
          choice: SyncActivationChoice.merge,
          backupId: 'backup-1',
          decidedAtUtc: DateTime(2026, 9, 16),
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.recordSuccessfulSync(DateTime(2026, 9, 16)),
        throwsArgumentError,
      );
    });
  });

  group('the summary the account screen is derived from', () {
    test('an untouched device claims nothing', () async {
      final snapshot = await store.transportSnapshot();

      expect(snapshot.isActivated, isFalse);
      expect(snapshot.queuedCount, 0);
      expect(snapshot.quarantinedCount, 0);
      expect(
        snapshot.lastSuccessAtUtc,
        isNull,
        reason:
            'no success on record is the difference between "nothing to send" '
            'and "nothing has ever been protected"',
      );
    });

    test('pending and quarantined are counted apart', () async {
      await store.outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await store.outbox.enqueue(
        envelopeOf(entityId: 'b', id: 'e2'),
        nowUtc: at(1),
      );
      await store.outbox.enqueue(
        envelopeOf(entityId: 'c', id: 'e3'),
        nowUtc: at(1),
      );
      await store.outbox.quarantine(<String>['e3'], 'schema-too-new');

      final snapshot = await store.transportSnapshot();

      expect(snapshot.queuedCount, 2);
      expect(
        snapshot.quarantinedCount,
        1,
        reason:
            'a refused change blocks nothing, so an empty-looking queue would '
            'hide it completely',
      );
    });

    test('a failing queue says so, with the attempts behind it', () async {
      await store.outbox.enqueue(
        envelopeOf(entityId: 'a', id: 'e1'),
        nowUtc: at(1),
      );
      await store.outbox.recordFailure(<String>['e1'], 'network-unreachable');
      await store.outbox.recordFailure(<String>['e1'], 'network-unreachable');

      final snapshot = await store.transportSnapshot();

      expect(snapshot.lastFailureReason, 'network-unreachable');
      expect(
        snapshot.consecutiveFailureCount,
        2,
        reason:
            'a success removes the entry, so its attempts are consecutive by '
            'construction',
      );
    });

    test('it reads one owner and not the other', () async {
      final mine = DriftSyncStore(database, owner: SyncOwnerKey.user('a'));
      final theirs = DriftSyncStore(database, owner: SyncOwnerKey.user('b'));
      await mine.outbox.enqueue(
        envelopeOf(entityId: 'x', id: 'e1'),
        nowUtc: at(1),
      );
      await mine.recordActivationChoice(
        choice: SyncActivationChoice.merge,
        backupId: 'backup-1',
        decidedAtUtc: at(1),
      );

      expect((await mine.transportSnapshot()).queuedCount, 1);
      expect((await mine.transportSnapshot()).isActivated, isTrue);
      expect(
        (await theirs.transportSnapshot()).queuedCount,
        0,
        reason: 'two accounts on one phone share a database and nothing else',
      );
      expect((await theirs.transportSnapshot()).isActivated, isFalse);
    });
  });

  test('forgetting one owner leaves every other owner untouched', () async {
    final forA = DriftSyncStore(database, owner: SyncOwnerKey.user('a'));
    final forB = DriftSyncStore(database, owner: SyncOwnerKey.user('b'));
    for (final owned in <DriftSyncStore>[forA, forB]) {
      await owned.outbox.enqueue(
        envelopeOf(entityId: 'theme', id: '${owned.owner.value}-e1'),
        nowUtc: at(1),
      );
      await owned.applyPulledPage(
        SyncPullPage(
          envelopes: const <SyncEnvelope>[],
          cursor: SyncCursor('${owned.owner.value}-page'),
          hasMore: false,
        ),
        apply: (_) async {},
        nowUtc: at(1),
      );
      await owned.recordActivationChoice(
        choice: SyncActivationChoice.merge,
        backupId: 'backup',
        decidedAtUtc: at(1),
      );
    }

    await forB.forgetOwner();

    expect(await forA.outbox.pendingCount(), 1);
    expect(await forA.pullCursor(), const SyncCursor('user:a-page'));
    expect(await forA.isSyncActive(), isTrue);
    expect(await forB.outbox.pendingCount(), 0);
    expect(await forB.pullCursor(), SyncCursor.beginning);
    expect(await forB.activation(), isNull);
  });
}
