import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_versioned_rows.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/mastered_surah_sync_payload.dart';
import 'package:murajaah/core/sync/rotation_scheme_sync_payload.dart';
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

  group('a pull that dies has nothing in the queue to say so', () {
    test('so the cycle writes the reason down itself', () async {
      await activate();
      await queue('theme');
      gateway.pullFailure = 'remote-scheme-version-already-used';

      final outcome = await runner.runOnce();
      expect(outcome.failureReason, 'remote-scheme-version-already-used');

      final snapshot = await store.transportSnapshot();
      expect(
        snapshot.queuedCount,
        0,
        reason: 'the push went through; it is only the pull that died',
      );
      expect(
        snapshot.lastFailureReason,
        'remote-scheme-version-already-used',
        reason:
            'without this the screen reads "Синхронизация включена · Ждут '
            'отправки: 0" over a device that is receiving nothing — every '
            'number on it true, and the whole of it false',
      );
      expect(
        SyncStatus.resolve(
          config: AppwriteConfig.resolve(
            projectId: 'project',
            endpoint: 'https://example.invalid/v1',
          ),
          isSignedIn: true,
          isActivated: snapshot.isActivated,
          queuedCount: snapshot.queuedCount,
          quarantinedCount: snapshot.quarantinedCount,
          lastSuccessAtUtc: snapshot.lastSuccessAtUtc,
          lastFailureReason: snapshot.lastFailureReason,
        ).health,
        SyncHealth.retrying,
      );
    });

    test('and an exception nobody expected is written down too', () async {
      await activate();
      gateway.pullError = const FormatException('unreadable row');

      final outcome = await runner.runOnce();

      expect(
        outcome.failureReason,
        'pull-failed-FormatException',
        reason:
            'it used to escape runOnce entirely: watermark advanced, cursor '
            'unmoved, nothing written down, and a device that had stopped '
            'receiving with no sign of it anywhere',
      );
      expect(
        (await store.transportSnapshot()).lastFailureReason,
        'pull-failed-FormatException',
      );
      expect(
        outcome.failureReason,
        isNot(contains('unreadable row')),
        reason: 'a message can quote a row, and a row is his',
      );
    });

    test('and the next cycle that works takes it back off', () async {
      await activate();
      await queue('theme');
      gateway.pullFailure = 'remote-scheme-version-already-used';
      await runner.runOnce();

      gateway.pullFailure = null;
      await queue('language', id: 'e2');
      await runner.runOnce();

      expect(
        (await store.transportSnapshot()).lastFailureReason,
        isNull,
        reason:
            'a reason that outlived the problem would send him looking for a '
            'fault that is no longer there',
      );
    });
  });

  group('a prerequisite one page late', () {
    /// The order his account really holds: on 2026-09-22 a build addressed
    /// each row by the record's own id, so every id carrying a colon came back
    /// 400. All his rotation schemes were refused and recovered a day later —
    /// **after** the 842 recitations that point at them. `$createdAt` is the
    /// order pages come back in, so the dependant comes first and always will.
    ///
    /// Scheme then roster is the same shape in two envelopes: the scheme
    /// applier refuses a surah that is not in the roster, retryably.
    setUp(() async {
      await SurahRepository(database).upsertCatalog(
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
    });

    /// A split of his own — version 2, in two parts. Deliberately **not** the
    /// default: taking a roster entry derives `surah-112:scheme:1` locally and
    /// names it identically, so a test built on the default passes whether the
    /// arriving scheme was applied or invented. This one cannot be invented.
    SyncEnvelope schemeEnvelope() => RotationSchemeSyncPayload.upsert(
      RotationSchemeSyncRecord(
        id: 'surah-112:scheme:2',
        surahId: 'surah-112',
        version: 2,
        ayahCountSnapshot: 4,
        baselineScore: 0,
        baselineTotalRecitations: 0,
        isActive: true,
        parts: <RotationSchemeSyncPart>[
          RotationSchemeSyncPart(
            id: 'surah-112:scheme:2:part:1',
            ordinal: 1,
            startAyah: 1,
            endAyah: 2,
          ),
          RotationSchemeSyncPart(
            id: 'surah-112:scheme:2:part:2',
            ordinal: 2,
            startAyah: 3,
            endAyah: 4,
          ),
        ],
      ),
      envelopeId: 'envelope-scheme',
      deviceId: 'other-device',
      idempotencyKey: 'key-scheme',
      schemaVersion: 10,
      updatedAtUtc: now,
    );

    SyncEnvelope rosterEnvelope() => MasteredSurahSyncPayload.upsert(
      MasteredSurahSyncRecord(
        surahId: 'surah-112',
        isCurrentlyMastered: true,
        isActive: true,
        hasEnteredRotation: true,
      ),
      envelopeId: 'envelope-roster',
      deviceId: 'other-device',
      idempotencyKey: 'key-roster',
      schemaVersion: 10,
      updatedAtUtc: now,
    );

    Future<bool> hasHisSplit() async =>
        (await database
                .customSelect(
                  "SELECT count(*) AS n FROM rotation_schemes "
                  "WHERE id = 'surah-112:scheme:2'",
                )
                .getSingle())
            .read<int>('n') ==
        1;

    test('is waited for, and the record it blocks still arrives', () async {
      await activate();
      gateway.pullPages = <SyncPullPage>[
        SyncPullPage(
          envelopes: <SyncEnvelope>[schemeEnvelope()],
          cursor: const SyncCursor('page-1'),
          hasMore: true,
        ),
        SyncPullPage(
          envelopes: <SyncEnvelope>[rosterEnvelope()],
          cursor: const SyncCursor('page-2'),
          hasMore: false,
        ),
      ];

      final outcome = await runner.runOnce();

      expect(
        outcome.failureReason,
        isNull,
        reason:
            'sorting a page cannot put into it something that is not in it; '
            'carrying the record forward is the retry these refusals were '
            'always documented to expect',
      );
      expect(
        await hasHisSplit(),
        isTrue,
        reason: 'his own split, not the default the roster entry derives',
      );
      expect(
        await store.pullCursor(),
        const SyncCursor('page-2'),
        reason: 'the cursor moves once nothing is left waiting',
      );
    });

    test('holds the cursor back while it waits', () async {
      await activate();
      gateway.pullPages = <SyncPullPage>[
        SyncPullPage(
          envelopes: <SyncEnvelope>[schemeEnvelope()],
          cursor: const SyncCursor('page-1'),
          hasMore: false,
        ),
      ];

      final outcome = await runner.runOnce();

      expect(
        outcome.failureReason,
        'remote-scheme-surah-not-in-roster',
        reason:
            'the prerequisite never came, and a cycle that reported success '
            'over a record it could not place would be the fake green this '
            'whole type exists to prevent',
      );
      expect(await hasHisSplit(), isFalse);
      expect(
        await store.pullCursor(),
        SyncCursor.beginning,
        reason: 'the page is fetched again next cycle, never skipped',
      );
    });

    test('what could be placed is kept, even when something cannot', () async {
      await activate();
      gateway.pullPages = <SyncPullPage>[
        SyncPullPage(
          envelopes: <SyncEnvelope>[rosterEnvelope(), _unplaceable()],
          cursor: const SyncCursor('page-1'),
          hasMore: false,
        ),
      ];

      await runner.runOnce();

      expect(
        await database
            .customSelect('SELECT count(*) AS n FROM mastered_surahs')
            .getSingle()
            .then((row) => row.read<int>('n')),
        1,
        reason:
            'one record this build cannot place must not cost him the rest of '
            'the page — that is how a single bad row emptied a whole sync',
      );
    });
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

  group('changes made after activation', () {
    late SyncCycleRunner scanning;
    late _CountingScan scan;

    setUp(() {
      scan = _CountingScan();
      scanning = SyncCycleRunner(
        database: database,
        store: store,
        gateway: gateway,
        nowUtc: () => now,
        scan: scan,
      );
    });

    test('are collected before the queue is drained', () async {
      await activate();

      await scanning.runOnce();

      expect(
        scan.windows,
        hasLength(1),
        reason:
            'a change written after activation reaches the queue because the '
            'database noticed it, not because a repository remembered to say so',
      );
      expect(
        scan.calledBeforeDrain,
        isTrue,
        reason: 'collecting after the drain would push it a cycle late',
      );
    });

    test('a device kept local is not even scanned', () async {
      await store.recordActivationChoice(
        choice: SyncActivationChoice.keepDeviceLocalOnly,
        backupId: 'backup-1',
        decidedAtUtc: now,
      );

      await scanning.runOnce();

      expect(scan.windows, isEmpty);
    });

    test('the first scan looks all the way back', () async {
      await activate();

      await scanning.runOnce();

      expect(
        scan.windows.single,
        kUndatedByThisDevice,
        reason:
            'a device that has never scanned has everything still to offer, '
            'and a watermark that started at "now" would skip all of it',
      );
    });

    test(
      'the next scan starts where this one began, not where it ended',
      () async {
        await activate();

        await scanning.runOnce();
        await scanning.runOnce();

        expect(
          scan.windows.last,
          now,
          reason:
              'advancing to the newest row seen would step over anything written '
              'while the scan was running',
        );
      },
    );

    test('a failed scan does not move the watermark on', () async {
      await activate();
      scan.failure = StateError('queue unavailable');

      await expectLater(scanning.runOnce(), throwsA(isA<StateError>()));
      scan.failure = null;
      await scanning.runOnce();

      expect(
        scan.windows.last,
        kUndatedByThisDevice,
        reason:
            'repeating a window costs duplicate envelopes that coalesce; '
            'skipping one costs a change',
      );
    });
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

  test('one cycle empties the queue, not one batch of it', () async {
    // The engine pushes a batch at a time and the cycle used to call it once,
    // so a backfill of several hundred envelopes moved fifty per tap. The
    // owner pressed «Синхронизировать сейчас», watched the number barely move
    // and reported that nothing had happened — which was very nearly true.
    await activate();
    for (var index = 0; index < 120; index += 1) {
      await store.outbox.enqueue(
        envelopeOf(entityId: 'entity-$index', id: 'e$index'),
        nowUtc: now,
      );
    }

    final outcome = await runner.runOnce();

    expect(await store.outbox.pendingCount(), 0);
    expect(outcome.pushedCount, 120);
    expect(
      gateway.pushes.length,
      greaterThan(1),
      reason: 'it took several batches, which is the point: it kept going',
    );
  });

  test('a queue that stops moving is not drained forever', () async {
    await activate();
    for (var index = 0; index < 120; index += 1) {
      await store.outbox.enqueue(
        envelopeOf(entityId: 'entity-$index', id: 'e$index'),
        nowUtc: now,
      );
    }
    // Accepts nothing and refuses nothing: the queue stays exactly as it is.
    gateway.acceptNothing = true;

    final outcome = await runner.runOnce();

    expect(
      gateway.pushes,
      hasLength(1),
      reason:
          'a round that moved nothing will move nothing next time either, and '
          'a loop that kept asking would hammer the server over it',
    );
    expect(outcome.remainingCount, 120);
  });

  test(
    'an account holding an older copy is left holding it, and nothing is sent',
    () async {
      // The account hands this device a record the owner has already moved
      // past. The device keeps its own — that is ADR-0002 — and the account
      // goes on holding the stale row, which is safe: it is a log, rows are
      // never rewritten, and every device that reads it makes this same
      // comparison. What must *not* happen is this device trying to correct it.
      final surahs = SurahRepository(database);
      await surahs.upsertCatalog(<SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlas',
          ayahCount: 4,
        ),
      ]);
      await surahs.addMastered('surah-112');
      await SyncVersionedRows(database).stampAuthored(
        table: 'mastered_surahs',
        key: 'surah-112',
        authoredAtUtc: now.subtract(const Duration(hours: 1)),
      );
      await activate();
      // Already sent once and not touched since, which is the whole point: the
      // ordinary scan has nothing to offer for this entity, so anything that
      // reaches the account can only be the correction.
      await store.recordPushWatermark(now);

      final stale = SyncEnvelope(
        id: 'remote-1',
        deviceId: 'other-device',
        entityType: SyncEntityType.masteredSurah,
        entityId: 'surah-112',
        operation: SyncOperation.upsert,
        schemaVersion: 10,
        createdAtUtc: now.subtract(const Duration(days: 3)),
        updatedAtUtc: now.subtract(const Duration(days: 2)),
        idempotencyKey: 'remote-key-1',
        payload: const <String, Object?>{
          'isCurrentlyMastered': true,
          'isActive': false,
          'hasEnteredRotation': true,
          'activationBaselineScore': null,
          'alias': 'его старое имя',
          'displayOrder': 0,
        },
      );
      gateway.pullPages = <SyncPullPage>[
        SyncPullPage(
          envelopes: <SyncEnvelope>[stale],
          cursor: const SyncCursor('page-1'),
          hasMore: false,
        ),
      ];

      var ids = 0;
      final withScan = SyncCycleRunner(
        database: database,
        store: store,
        gateway: gateway,
        nowUtc: () => now,
        scan: DriftSyncBackfill(
          database: database,
          outbox: store.outbox,
          deviceId: () async => 'this-device',
          newId: () => 'id-${++ids}',
        ),
      );
      await withScan.runOnce();

      final row =
          await (database.select(database.masteredSurahs)
                ..where((MasteredSurahs r) => r.surahId.equals('surah-112')))
              .getSingle();
      expect(
        row.alias,
        isNull,
        reason: 'the older copy must not have been applied at all',
      );
      expect(
        gateway.pushes.expand((page) => page).map((one) => one.entityKey),
        isNot(contains(stale.entityKey)),
        reason:
            'and nothing is offered back to correct the account. There used '
            'to be a re-scan here, written for an account that kept one '
            'rewritten row per record; this one is a log and every device '
            'makes the same comparison, so the older row down the log misleads '
            'nobody — `two_device_sync_test` proves that with a third phone. '
            'The re-scan took a window rather than a name, and an undated '
            'record starts that window at 1970: his second phone re-offered '
            'its whole database, 919 records, moments after receiving them',
      );
    },
  );
}

/// Records the window each scan was asked about, without touching a table.
/// A record no build places: `rotationState` is the rotation projection, which
/// is rebuilt rather than synced, and the router refuses it by name.
SyncEnvelope _unplaceable() => SyncEnvelope(
  id: 'envelope-unplaceable',
  deviceId: 'other-device',
  entityType: SyncEntityType.rotationState,
  entityId: 'rotation-state',
  operation: SyncOperation.upsert,
  schemaVersion: 10,
  createdAtUtc: DateTime.utc(2026, 9, 21, 12),
  updatedAtUtc: DateTime.utc(2026, 9, 21, 12),
  idempotencyKey: 'key-unplaceable',
  payload: const <String, Object?>{},
);

final class _CountingScan implements SyncBackfill {
  final List<DateTime> windows = <DateTime>[];
  bool calledBeforeDrain = false;
  Object? failure;

  /// Set by the gateway the moment a push happens, so the scan can tell
  /// whether it ran first.
  bool drained = false;

  @override
  Future<SyncBackfillReport> enqueueEverything({required DateTime nowUtc}) =>
      enqueueChangedSince(nowUtc: nowUtc, since: kUndatedByThisDevice);

  @override
  Future<SyncBackfillReport> enqueueChangedSince({
    required DateTime nowUtc,
    required DateTime since,
  }) async {
    if (failure != null) throw failure!;
    if (windows.isEmpty) calledBeforeDrain = !drained;
    windows.add(since);
    return SyncBackfillReport(enqueuedByType: const <SyncEntityType, int>{});
  }
}

final class _RecordingGateway implements SyncGateway {
  final List<List<SyncEnvelope>> pushes = <List<SyncEnvelope>>[];
  final List<SyncCursor> pulls = <SyncCursor>[];
  final List<String> order = <String>[];

  String? pushFailure;

  /// A pull that cannot be applied — an arriving record this build refuses,
  /// say. It leaves the queue empty and the cursor still, which is why it has
  /// to be reported from somewhere other than the queue.
  String? pullFailure;

  /// Not a `SyncTransportException` — the shape that used to escape the cycle.
  Object? pullError;
  bool rejectEverything = false;

  /// Neither accepts nor refuses: the queue comes back exactly as it went.
  bool acceptNothing = false;

  /// Pages handed out one per pull; an empty list means the account has
  /// nothing, which is what most tests here want.
  List<SyncPullPage> pullPages = <SyncPullPage>[];

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) async {
    order.add('push');
    pushes.add(envelopes);
    if (pushFailure != null) throw SyncTransportException(pushFailure!);
    if (acceptNothing) {
      return SyncPushResult(acceptedEnvelopeIds: const <String>[]);
    }
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
    if (pullFailure != null) throw SyncTransportException(pullFailure!);
    if (pullError != null) throw pullError!;
    if (pullPages.isEmpty) {
      return SyncPullPage(
        envelopes: const <SyncEnvelope>[],
        cursor: after,
        hasMore: false,
      );
    }
    return pullPages.removeAt(0);
  }
}
