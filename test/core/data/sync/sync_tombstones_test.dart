import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The one deletion a scan cannot see.
///
/// Everything else in this app withdraws by writing a date — a recitation, a
/// rotation adjustment — so the change is a row the scan reads like any other.
/// Stopping a surah's learning plan removes the row outright, and a row that is
/// gone leaves nothing to notice. Without this the plan would stay in the
/// account forever, and a second device would keep showing it.
void main() {
  late AppDatabase database;
  late LearningRepository learning;
  late SurahRepository surahs;

  final now = DateTime.utc(2026, 9, 21, 12);

  var ids = 0;

  setUp(() async {
    ids = 0;
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    surahs = SurahRepository(database);
    learning = LearningRepository(
      database,
      syncDeviceId: () async => 'device-a',
      newSyncId: () => 'tombstone-${++ids}',
      syncNowUtc: () => now,
    );
    await surahs.getRotationSnapshot();
    await surahs.upsertCatalog(<SurahDescriptor>[
      SurahDescriptor(
        id: 'surah-a',
        surahNumber: 112,
        officialName: 'Test',
        ayahCount: 4,
      ),
    ]);
  });

  Future<void> addPlan(String id) => database
      .into(database.learningSurahs)
      .insert(
        LearningSurahsCompanion.insert(
          id: id,
          surahId: 'surah-a',
          ayahCount: 4,
          stageKind: 'newAyah',
          stageStartAyah: 1,
          stageEndAyah: 2,
          targetStartAyah: 1,
          targetEndAyah: 4,
          status: 'active',
        ),
      );

  Future<DriftSyncStore> activate(String userId) async {
    final store = DriftSyncStore(database, owner: SyncOwnerKey.user(userId));
    await store.recordActivationChoice(
      choice: SyncActivationChoice.merge,
      backupId: 'backup-1',
      decidedAtUtc: now,
    );
    return store;
  }

  test('a device with no account queues nothing', () async {
    await addPlan('plan-1');

    expect(await learning.delete('plan-1'), isTrue);

    expect(
      await DriftSyncStore(database).outbox.pendingCount(),
      0,
      reason:
          'no rows, no growth, not one extra write for a device that never '
          'signed in — the same promise the recorder makes',
    );
  });

  test('a deletion reaches the account that agreed to receive it', () async {
    final store = await activate('user-a');
    await addPlan('plan-1');

    expect(await learning.delete('plan-1'), isTrue);

    final queued = await store.outbox.peek();
    expect(queued, hasLength(1));
    expect(queued.single.envelope.entityType, SyncEntityType.learningState);
    expect(queued.single.envelope.entityId, 'plan-1');
    expect(
      queued.single.envelope.isTombstone,
      isTrue,
      reason: 'the account is being told it is gone, not handed it again',
    );
    expect(queued.single.envelope.updatedAtUtc, now);
  });

  test('every activated account is told, not just one', () async {
    final first = await activate('user-a');
    final second = await activate('user-b');
    await addPlan('plan-1');

    await learning.delete('plan-1');

    expect(await first.outbox.pendingCount(), 1);
    expect(
      await second.outbox.pendingCount(),
      1,
      reason:
          'a tombstone is a fact about the data, not about whichever session '
          'happens to be open',
    );
  });

  test('a device kept local is not told', () async {
    final store = DriftSyncStore(database, owner: SyncOwnerKey.user('user-a'));
    await store.recordActivationChoice(
      choice: SyncActivationChoice.keepDeviceLocalOnly,
      backupId: 'backup-1',
      decidedAtUtc: now,
    );
    await addPlan('plan-1');

    await learning.delete('plan-1');

    expect(
      await store.outbox.pendingCount(),
      0,
      reason: '"keep this device local" is an answer here too',
    );
  });

  test('deleting nothing queues nothing', () async {
    await activate('user-a');

    expect(await learning.delete('no-such-plan'), isFalse);

    expect(
      await DriftSyncStore(
        database,
        owner: SyncOwnerKey.user('user-a'),
      ).outbox.pendingCount(),
      0,
      reason:
          'a tombstone for a record that was never there would tell the account '
          'to remove something on no evidence at all',
    );
  });

  test('the plan really is gone, tombstone or not', () async {
    await activate('user-a');
    await addPlan('plan-1');

    await learning.delete('plan-1');

    expect(await learning.getById('plan-1'), isNull);
  });
}
