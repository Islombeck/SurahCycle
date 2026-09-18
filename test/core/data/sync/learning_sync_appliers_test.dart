import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/learning_sync_appliers.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/learning_sync_payloads.dart';
import 'package:murajaah/core/sync/sync.dart';

/// A plan is where the owner has got to in memorising a surah. Getting it wrong
/// on the second device does not merely lose data — it tells him he is at a
/// place in the surah he has never been.
void main() {
  late AppDatabase database;
  late LearningStateSyncApplier plans;
  late LearningEventSyncApplier events;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    plans = LearningStateSyncApplier(database);
    events = LearningEventSyncApplier(database);
    await SurahRepository(database).upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-2',
          surahNumber: 2,
          officialName: 'Al-Baqara',
          ayahCount: 20,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
  });

  tearDown(() => database.close());

  LearningPlanPosition position({
    String planKind = 'classicCumulative',
    int? blockSize,
    String stageKind = 'cumulative',
    int stageStart = 1,
    int stageEnd = 5,
    int targetStart = 1,
    int targetEnd = 10,
  }) => LearningPlanPosition(
    planKind: planKind,
    targetStartAyah: targetStart,
    targetEndAyah: targetEnd,
    blockSize: blockSize,
    stageKind: stageKind,
    stageStartAyah: stageStart,
    stageEndAyah: stageEnd,
  );

  LearningStateSyncRecord plan({
    String id = 'plan-1',
    String surahId = 'surah-2',
    String status = 'active',
    LearningPlanPosition? at,
    DateTime? lastActivity,
    DateTime? rollbackFor,
  }) => LearningStateSyncRecord(
    id: id,
    surahId: surahId,
    ayahCount: 20,
    position: at ?? position(),
    learningCycle: 2,
    status: status,
    lastLearningActivityAtUtc: lastActivity,
    inactivityRollbackForActivityAtUtc: rollbackFor,
  );

  SyncEnvelope planEnvelope(LearningStateSyncRecord source, {int minute = 0}) =>
      LearningStateSyncPayload.upsert(
        source,
        envelopeId: 'envelope-${source.id}-$minute',
        deviceId: 'other-device',
        idempotencyKey: 'key-${source.id}-$minute',
        schemaVersion: 10,
        updatedAtUtc: DateTime.utc(2026, 9, 18, 9, minute),
      );

  Future<void> applyIn(Future<void> Function() body) =>
      database.transaction(body);

  Matcher refuses(String reason) => throwsA(
    isA<SyncTransportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  group('a learning plan', () {
    test('arrives at exactly the position it left', () async {
      await applyIn(() => plans.apply(planEnvelope(plan())));

      final stored = await database.select(database.learningSurahs).getSingle();
      expect(stored.id, 'plan-1');
      expect(stored.surahId, 'surah-2');
      expect(stored.planKind, 'classicCumulative');
      expect(stored.stageKind, 'cumulative');
      expect(stored.stageStartAyah, 1);
      expect(stored.stageEndAyah, 5);
      expect(stored.targetEndAyah, 10);
      expect(stored.learningCycle, 2);
      expect(stored.status, 'active');
      expect(stored.blockSize, isNull);
    });

    test('the inactivity guard travels, or a rollback fires twice', () async {
      await applyIn(
        () => plans.apply(
          planEnvelope(
            plan(
              lastActivity: DateTime.utc(2026, 9, 1, 10),
              rollbackFor: DateTime.utc(2026, 8, 20, 10),
            ),
          ),
        ),
      );

      final stored = await database.select(database.learningSurahs).getSingle();
      expect(
        stored.lastLearningActivityAtUtc?.toUtc(),
        DateTime.utc(2026, 9, 1, 10),
        reason: 'nothing else records when he last worked on this plan',
      );
      expect(
        stored.inactivityRollbackForActivityAtUtc?.toUtc(),
        DateTime.utc(2026, 8, 20, 10),
        reason:
            'this is what stops one idle stretch being rolled back a second '
            'time on the receiving device',
      );
    });

    test('a chunked plan keeps its block size', () async {
      await applyIn(
        () => plans.apply(
          planEnvelope(plan(at: position(planKind: 'chunked', blockSize: 3))),
        ),
      );

      final stored = await database.select(database.learningSurahs).getSingle();
      expect(stored.planKind, 'chunked');
      expect(stored.blockSize, 3);
    });

    test('a chunked plan without a block size is refused', () {
      expect(
        () => position(planKind: 'chunked'),
        throwsA(isA<ArgumentError>()),
        reason: 'the table refuses it too, and a column name explains nothing',
      );
    });

    test('a classic plan carrying a block size is refused', () {
      expect(() => position(blockSize: 3), throwsA(isA<ArgumentError>()));
    });

    test('a stage outside its target is refused', () {
      expect(
        () => position(stageStart: 1, stageEnd: 12, targetEnd: 10),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a target past the end of the surah is refused', () {
      expect(
        () => plan(at: position(targetEnd: 20)).ayahCount,
        returnsNormally,
      );
      expect(
        () => LearningStateSyncRecord(
          id: 'plan-1',
          surahId: 'surah-2',
          ayahCount: 10,
          position: position(targetEnd: 20, stageEnd: 20),
          learningCycle: 1,
          status: 'active',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('applying it twice changes nothing', () async {
      final envelope = planEnvelope(plan());
      await applyIn(() => plans.apply(envelope));

      await applyIn(() => plans.apply(envelope));

      expect(
        await database.select(database.learningSurahs).get(),
        hasLength(1),
      );
    });

    test('a second plan for the same surah is a real conflict', () async {
      await applyIn(() => plans.apply(planEnvelope(plan())));

      await expectLater(
        () => applyIn(() => plans.apply(planEnvelope(plan(id: 'plan-other')))),
        refuses('remote-learning-plan-already-here'),
        reason:
            'two devices each started learning this surah before ever syncing; '
            'merging two positions would invent a place in the surah he was '
            'never at',
      );
    });

    test('stopping a plan removes it and its journal', () async {
      await applyIn(() => plans.apply(planEnvelope(plan())));
      await applyIn(
        () => events.apply(
          LearningEventSyncPayload.upsert(
            LearningEventSyncRecord(
              id: 'event-1',
              learningSurahId: 'plan-1',
              type: 'repeated',
              createdAtUtc: DateTime.utc(2026, 9, 10),
              learningCycle: 2,
              from: position(stageEnd: 4),
              to: position(),
            ),
            envelopeId: 'envelope-e',
            deviceId: 'other-device',
            idempotencyKey: 'key-e',
            schemaVersion: 10,
            updatedAtUtc: DateTime.utc(2026, 9, 10),
          ),
        ),
      );

      await applyIn(
        () => plans.apply(
          SyncEnvelope(
            id: 'envelope-gone',
            deviceId: 'other-device',
            entityType: SyncEntityType.learningState,
            entityId: 'plan-1',
            operation: SyncOperation.delete,
            schemaVersion: 10,
            createdAtUtc: DateTime.utc(2026, 9, 18, 9),
            updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
            idempotencyKey: 'key-gone',
          ),
        ),
      );

      expect(await database.select(database.learningSurahs).get(), isEmpty);
      expect(
        await database.select(database.learningEvents).get(),
        isEmpty,
        reason: 'the journal describes that plan and means nothing without it',
      );
    });
  });

  group('a learning event', () {
    LearningEventSyncRecord event({String id = 'event-1'}) =>
        LearningEventSyncRecord(
          id: id,
          learningSurahId: 'plan-1',
          type: 'repeated',
          createdAtUtc: DateTime.utc(2026, 9, 10, 8),
          learningCycle: 2,
          from: position(stageEnd: 4),
          to: position(),
          reason: 'Продвинулся',
        );

    SyncEnvelope envelopeOf(LearningEventSyncRecord source) =>
        LearningEventSyncPayload.upsert(
          source,
          envelopeId: 'envelope-${source.id}',
          deviceId: 'other-device',
          idempotencyKey: 'key-${source.id}',
          schemaVersion: 10,
          updatedAtUtc: DateTime.utc(2026, 9, 10, 9),
        );

    test('carries where the plan moved from and to', () async {
      await applyIn(() => plans.apply(planEnvelope(plan())));

      await applyIn(() => events.apply(envelopeOf(event())));

      final stored = await database.select(database.learningEvents).getSingle();
      expect(stored.id, 'event-1');
      expect(stored.fromStageEndAyah, 4);
      expect(
        stored.toStageEndAyah,
        5,
        reason: 'a rollback reads this to know where to return to',
      );
      expect(stored.reason, 'Продвинулся');
      expect(stored.createdAtUtc.toUtc(), DateTime.utc(2026, 9, 10, 8));
    });

    test('an event type this build does not know is refused', () {
      // Found by a failing test rather than by reading: the column has its own
      // CHECK vocabulary, and without this the payload arrived as
      // `CHECK constraint failed: type IN (...)` — the unreadable failure this
      // whole layer exists to replace.
      expect(
        () => LearningEventSyncRecord(
          id: 'event-x',
          learningSurahId: 'plan-1',
          type: 'advance',
          createdAtUtc: DateTime.utc(2026, 9, 10, 8),
          learningCycle: 1,
          from: position(),
          to: position(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('one whose plan is not here is refused, retryably', () async {
      await expectLater(
        () => applyIn(() => events.apply(envelopeOf(event()))),
        refuses('remote-learning-event-plan-missing'),
      );
    });

    test('applying it twice changes nothing', () async {
      await applyIn(() => plans.apply(planEnvelope(plan())));
      final envelope = envelopeOf(event());
      await applyIn(() => events.apply(envelope));

      await applyIn(() => events.apply(envelope));

      expect(
        await database.select(database.learningEvents).get(),
        hasLength(1),
      );
    });

    test('it is never deleted on its own', () async {
      await applyIn(() => plans.apply(planEnvelope(plan())));
      await applyIn(() => events.apply(envelopeOf(event())));

      await expectLater(
        () => applyIn(
          () => events.apply(
            SyncEnvelope(
              id: 'envelope-gone',
              deviceId: 'other-device',
              entityType: SyncEntityType.learningEvent,
              entityId: 'event-1',
              operation: SyncOperation.delete,
              schemaVersion: 10,
              createdAtUtc: DateTime.utc(2026, 9, 10, 8),
              updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
              idempotencyKey: 'key-gone',
            ),
          ),
        ),
        refuses('remote-learning-event-is-permanent'),
        reason:
            'removing one would leave a plan whose history no longer explains '
            'its position',
      );
    });
  });
}
