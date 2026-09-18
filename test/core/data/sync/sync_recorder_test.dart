import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_recorder.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The queue fills only once an account has been activated, and the decision
/// shows up here as the recorder being absent. That is the owner's choice
/// recorded in code: history written before sync existed reaches an account
/// through a backfill, so a queue kept running "just in case" would duplicate
/// that work rather than replace it — and would charge every device that never
/// signs in for the privilege.
///
/// The second property is the one a crash would expose: the queue entry is made
/// inside the same transaction as the write, so a row can never exist with no
/// envelope behind it.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlas',
          ayahCount: 4,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-112');
  });

  tearDown(() => database.close());

  SurahRecitationEvent event({
    String id = 'event-1',
    bool isQada = false,
    bool qadaOriginIsUnknown = false,
  }) => SurahRecitationEvent(
    id: id,
    surahId: 'surah-112',
    prayerContext: PrayerContext(prayerType: PrayerType.asr, isQada: isQada),
    createdAtUtc: DateTime.utc(2026, 9, 17, 16, 58),
    localDate: LocalDate(2026, 9, 17),
    rakaatSpanCount: 1,
    qadaOriginIsUnknown: qadaOriginIsUnknown,
  );

  ({RecitationRepository repository, DriftSyncStore store}) activated() {
    var counter = 0;
    final store = DriftSyncStore(database, owner: SyncOwnerKey.user('user-a'));
    return (
      repository: RecitationRepository(
        database,
        syncRecorder: OutboxSyncRecorder(
          outbox: store.outbox,
          deviceId: 'device-1',
          schemaVersion: 10,
          newId: () => 'id-${++counter}',
        ),
      ),
      store: store,
    );
  }

  test('without activation nothing is queued at all', () async {
    final repository = RecitationRepository(database);
    final store = DriftSyncStore(database, owner: SyncOwnerKey.user('user-a'));

    await repository.register(event());

    expect(
      await store.outbox.pendingCount(),
      0,
      reason:
          'a device that never signs in must do no extra work and store no '
          'extra rows',
    );
    expect((await repository.getHistory()), hasLength(1));
  });

  group('once activated', () {
    test('a registered recitation is queued with what was stored', () async {
      final (:repository, :store) = activated();

      await repository.register(event());

      final queued = await store.outbox.peek();
      expect(queued, hasLength(1));
      final envelope = queued.single.envelope;
      expect(envelope.entityKey, 'recitationEvent:event-1');
      expect(envelope.operation, SyncOperation.upsert);
      expect(envelope.deviceId, 'device-1');
      expect(envelope.schemaVersion, 10);
      expect(
        envelope.createdAtUtc,
        DateTime.utc(2026, 9, 17, 16, 58),
        reason: 'the envelope is dated by the prayer, not by the push',
      );
      expect(
        envelope.payload['rotationSchemeId'],
        isNotNull,
        reason:
            'the engine decides which scheme and parts were covered, and the '
            'account must receive what was stored rather than what was asked '
            'for',
      );
    });

    test('a Qada keeps every flag that makes it one', () async {
      final (:repository, :store) = activated();

      await repository.register(event(isQada: true, qadaOriginIsUnknown: true));

      final payload = (await store.outbox.peek()).single.envelope.payload;
      expect(payload['isQada'], isTrue);
      expect(payload['qadaOriginIsUnknown'], isTrue);
    });

    test('a deletion queues a tombstone, not a silence', () async {
      final (:repository, :store) = activated();
      await repository.register(event());

      await repository.deleteRecitation(
        'event-1',
        deletedAtUtc: DateTime.utc(2026, 9, 17, 17),
      );

      final queued = await store.outbox.peek();
      final tombstone = queued.last.envelope;
      expect(tombstone.isTombstone, isTrue);
      expect(
        tombstone.payload,
        isEmpty,
        reason: 'keeping the last known values is how resurrection starts',
      );
      expect(
        tombstone.createdAtUtc,
        DateTime.utc(2026, 9, 17, 16, 58),
        reason:
            'a tombstone is a statement about that prayer, so it keeps the '
            "prayer's own moment",
      );
      expect(tombstone.updatedAtUtc, DateTime.utc(2026, 9, 17, 17));
    });

    test('a restore queues the recitation coming back', () async {
      final (:repository, :store) = activated();
      await repository.register(event());
      await repository.deleteRecitation(
        'event-1',
        deletedAtUtc: DateTime.utc(2026, 9, 17, 17),
      );

      await repository.restoreRecitation(
        'event-1',
        restoredAtUtc: DateTime.utc(2026, 9, 18, 9),
      );

      final last = (await store.outbox.peek()).last.envelope;
      expect(last.operation, SyncOperation.upsert);
      expect(last.entityId, 'event-1');
      expect(
        last.payload['localDate'],
        '2026-09-17',
        reason:
            'it returns to the day it was prayed, not to the day it came '
            'back',
      );
    });

    test('the queue entry shares the write transaction', () async {
      final (:repository, :store) = activated();

      // A register that the database refuses part-way: the same journal id
      // twice. If the envelope were queued outside the transaction, the queue
      // would keep an entry for a recitation that does not exist.
      await repository.register(event());
      await expectLater(
        () => repository.register(event()),
        throwsA(isA<Object>()),
      );

      expect(
        await store.outbox.pendingCount(),
        1,
        reason: 'the failed write rolled its envelope back with it',
      );
    });

    test('envelopes are queued under their owner and nobody else', () async {
      final (:repository, store: _) = activated();
      final other = DriftSyncStore(
        database,
        owner: SyncOwnerKey.user('user-b'),
      );

      await repository.register(event());

      expect(
        await other.outbox.pendingCount(),
        0,
        reason: "one account must never find another's history in its queue",
      );
    });
  });

  group('the device id', () {
    test('is generated once and then reused', () async {
      final settings = AppSettingsRepository(database);
      var calls = 0;

      final first = await SyncDeviceId.ensure(
        settings,
        newId: () => 'device-${++calls}',
        nowUtc: DateTime.utc(2026, 9, 18),
      );
      final second = await SyncDeviceId.ensure(
        settings,
        newId: () => 'device-${++calls}',
        nowUtc: DateTime.utc(2026, 9, 18),
      );

      expect(first, 'device-1');
      expect(
        second,
        first,
        reason:
            'a device that renamed itself every launch would look like a new '
            'device to the account on every change',
      );
      expect(calls, 1);
    });
  });
}
