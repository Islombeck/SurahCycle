import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import '../sync/sync_tombstones.dart';

final class LearningRepository {
  const LearningRepository(
    this.database, {
    this.syncDeviceId,
    this.newSyncId,
    this.syncNowUtc,
  });

  final AppDatabase database;

  /// What a tombstone needs in order to exist: who wrote it, what to call it,
  /// and when. All three or none — they are one piece of wiring, and a
  /// deletion simply does not travel without it, which is what it did before
  /// any of this existed.
  final Future<String> Function()? syncDeviceId;
  final String Function()? newSyncId;
  final DateTime Function()? syncNowUtc;

  Future<void> saveState(LearningSurahState state) =>
      database.transaction(() => _writeState(state));

  Future<void> saveOutcome(LearningActionOutcome outcome) =>
      database.transaction(() async {
        await _writeState(outcome.state);
        final event = outcome.event;
        if (event != null) await _insertEvent(event);
      });

  Future<bool> undoOutcome(
    LearningActionOutcome outcome, {
    required LearningSurahState restoredState,
  }) => database.transaction(() async {
    final event = outcome.event;
    if (event == null) return false;
    if (restoredState.id != outcome.state.id ||
        restoredState.surahId != outcome.state.surahId) {
      throw ArgumentError.value(
        restoredState,
        'restoredState',
        'Must refer to the outcome learning state.',
      );
    }

    final currentRow =
        await (database.select(database.learningSurahs)
              ..where((LearningSurahs row) => row.id.equals(outcome.state.id)))
            .getSingleOrNull();
    if (currentRow == null ||
        !_samePersistedState(_stateFromRow(currentRow), outcome.state)) {
      return false;
    }

    final latestEvent =
        await (database.select(database.learningEvents)
              ..where(
                (LearningEvents row) =>
                    row.learningSurahId.equals(outcome.state.id),
              )
              ..orderBy(<OrderingTerm Function(LearningEvents)>[
                (LearningEvents row) => OrderingTerm.desc(row.sequence),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (latestEvent?.id != event.id) return false;

    final deleted = await (database.delete(
      database.learningEvents,
    )..where((LearningEvents row) => row.id.equals(event.id))).go();
    if (deleted != 1) {
      throw StateError('Learning event "${event.id}" does not exist.');
    }
    await _writeState(restoredState);
    return true;
  });

  Future<LearningSurahState?> getById(String id) async {
    final row = await (database.select(
      database.learningSurahs,
    )..where((LearningSurahs row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _stateFromRow(row);
  }

  Future<LearningSurahState?> getBySurahId(String surahId) async {
    final row =
        await (database.select(database.learningSurahs)
              ..where((LearningSurahs table) => table.surahId.equals(surahId)))
            .getSingleOrNull();
    return row == null ? null : _stateFromRow(row);
  }

  Stream<List<LearningSurahState>> watchAll() {
    final query = database.select(database.learningSurahs)
      ..orderBy(<OrderingTerm Function(LearningSurahs)>[
        (LearningSurahs row) => OrderingTerm.asc(row.surahId),
      ]);
    return query.watch().map(
      (List<LearningSurahRow> rows) =>
          rows.map(_stateFromRow).toList(growable: false),
    );
  }

  Stream<List<LearningSurahState>> watchActive() {
    final query = database.select(database.learningSurahs)
      ..where(
        (LearningSurahs row) => row.status.equals(LearningStatus.active.name),
      )
      ..orderBy(<OrderingTerm Function(LearningSurahs)>[
        (LearningSurahs row) => OrderingTerm.asc(row.surahId),
      ]);
    return query.watch().map(
      (List<LearningSurahRow> rows) =>
          rows.map(_stateFromRow).toList(growable: false),
    );
  }

  Future<List<LearningEvent>> getEvents(String learningSurahId) async {
    final query = database.select(database.learningEvents)
      ..where(
        (LearningEvents row) => row.learningSurahId.equals(learningSurahId),
      )
      ..orderBy(<OrderingTerm Function(LearningEvents)>[
        (LearningEvents row) => OrderingTerm.asc(row.sequence),
      ]);
    final rows = await query.get();
    return rows.map(_eventFromRow).toList(growable: false);
  }

  Stream<List<LearningEvent>> watchEvents(String learningSurahId) {
    final query = database.select(database.learningEvents)
      ..where(
        (LearningEvents row) => row.learningSurahId.equals(learningSurahId),
      )
      ..orderBy(<OrderingTerm Function(LearningEvents)>[
        (LearningEvents row) => OrderingTerm.asc(row.sequence),
      ]);
    return query.watch().map(
      (List<LearningEventRow> rows) =>
          rows.map(_eventFromRow).toList(growable: false),
    );
  }

  /// Stops learning a surah, removing the plan and cascading its journal.
  ///
  /// The one hard delete in the app, and therefore the one deletion a sync scan
  /// cannot see: every other kind writes a date rather than removing a row, and
  /// a row that is gone leaves nothing to notice. So this records a tombstone
  /// itself, inside the same transaction — one that committed separately could
  /// be lost to a crash in the gap, leaving the plan gone here and present in
  /// the account forever.
  Future<bool> delete(String id) => database.transaction(() async {
    final removed = await (database.delete(
      database.learningSurahs,
    )..where((LearningSurahs row) => row.id.equals(id))).go();
    if (removed != 1) return false;

    final deviceId = syncDeviceId;
    final newId = newSyncId;
    final nowUtc = syncNowUtc;
    if (deviceId == null || newId == null || nowUtc == null) return true;
    await SyncTombstones.recordDelete(
      database,
      entityType: SyncEntityType.learningState,
      entityId: id,
      // The plan's own last-changed time went with it, so the deletion is
      // dated now — which is honest: now is when it happened.
      deletedAtUtc: nowUtc().toUtc(),
      newId: newId,
      deviceId: deviceId,
    );
    return true;
  });

  Future<void> _writeState(LearningSurahState state) async {
    final sameSurah =
        await (database.select(
              database.learningSurahs,
            )..where((LearningSurahs row) => row.surahId.equals(state.surahId)))
            .getSingleOrNull();
    if (sameSurah != null && sameSurah.id != state.id) {
      throw StateError(
        'Surah "${state.surahId}" is already tracked by "${sameSurah.id}".',
      );
    }
    await database
        .into(database.learningSurahs)
        .insertOnConflictUpdate(
          LearningSurahsCompanion.insert(
            id: state.id,
            surahId: state.surahId,
            ayahCount: state.ayahCount,
            planKind: Value<String>(state.plan.kind.name),
            stageKind: state.stage.kind.name,
            stageStartAyah: state.stage.startAyah,
            stageEndAyah: state.stage.endAyah,
            targetStartAyah: state.plan.targetStartAyah,
            targetEndAyah: state.plan.targetEndAyah,
            blockSize: Value<int?>(state.plan.blockSize),
            learningCycle: Value<int>(state.learningCycle),
            status: state.status.name,
            lastLearningActivityAtUtc: Value<DateTime?>(
              state.lastLearningActivityAtUtc,
            ),
            inactivityRollbackForActivityAtUtc: Value<DateTime?>(
              state.inactivityRollbackForActivityAtUtc,
            ),
          ),
        );
  }

  Future<void> _insertEvent(LearningEvent event) => database
      .into(database.learningEvents)
      .insert(
        LearningEventsCompanion.insert(
          id: event.id,
          learningSurahId: event.learningSurahId,
          type: event.type.name,
          createdAtUtc: event.createdAtUtc,
          learningCycle: Value<int>(event.learningCycle),
          fromPlanKind: event.fromPlan.kind.name,
          fromTargetStartAyah: event.fromPlan.targetStartAyah,
          fromTargetEndAyah: event.fromPlan.targetEndAyah,
          fromBlockSize: Value<int?>(event.fromPlan.blockSize),
          fromStageKind: event.fromStage.kind.name,
          fromStageStartAyah: event.fromStage.startAyah,
          fromStageEndAyah: event.fromStage.endAyah,
          toPlanKind: event.toPlan.kind.name,
          toTargetStartAyah: event.toPlan.targetStartAyah,
          toTargetEndAyah: event.toPlan.targetEndAyah,
          toBlockSize: Value<int?>(event.toPlan.blockSize),
          toStageKind: event.toStage.kind.name,
          toStageStartAyah: event.toStage.startAyah,
          toStageEndAyah: event.toStage.endAyah,
          reason: Value<String?>(event.reason),
        ),
      );

  LearningSurahState _stateFromRow(LearningSurahRow row) {
    final plan = _plan(
      row.planKind,
      row.targetStartAyah,
      row.targetEndAyah,
      row.blockSize,
    );
    return LearningSurahState(
      id: row.id,
      surahId: row.surahId,
      ayahCount: row.ayahCount,
      plan: plan,
      stage: plan.canonicalStage(
        _stage(row.stageKind, row.stageStartAyah, row.stageEndAyah),
      ),
      learningCycle: row.learningCycle,
      status: LearningStatus.values.byName(row.status),
      lastLearningActivityAtUtc: row.lastLearningActivityAtUtc?.toUtc(),
      inactivityRollbackForActivityAtUtc: row.inactivityRollbackForActivityAtUtc
          ?.toUtc(),
    );
  }

  LearningEvent _eventFromRow(LearningEventRow row) {
    final fromPlan = _plan(
      row.fromPlanKind,
      row.fromTargetStartAyah,
      row.fromTargetEndAyah,
      row.fromBlockSize,
    );
    final toPlan = _plan(
      row.toPlanKind,
      row.toTargetStartAyah,
      row.toTargetEndAyah,
      row.toBlockSize,
    );
    return LearningEvent(
      id: row.id,
      learningSurahId: row.learningSurahId,
      type: LearningEventType.values.byName(row.type),
      createdAtUtc: row.createdAtUtc.toUtc(),
      learningCycle: row.learningCycle,
      fromPlan: fromPlan,
      fromStage: fromPlan.canonicalStage(
        _stage(row.fromStageKind, row.fromStageStartAyah, row.fromStageEndAyah),
      ),
      toPlan: toPlan,
      toStage: toPlan.canonicalStage(
        _stage(row.toStageKind, row.toStageStartAyah, row.toStageEndAyah),
      ),
      reason: row.reason,
    );
  }

  LearningPlan _plan(
    String kind,
    int targetStartAyah,
    int targetEndAyah,
    int? blockSize,
  ) => LearningPlan(
    kind: LearningPlanKind.values.byName(kind),
    targetStartAyah: targetStartAyah,
    targetEndAyah: targetEndAyah,
    blockSize: blockSize,
  );

  LearningStage _stage(String kind, int startAyah, int endAyah) =>
      LearningStage.persisted(
        kind: LearningStageKind.values.byName(kind),
        startAyah: startAyah,
        endAyah: endAyah,
      );

  bool _samePersistedState(
    LearningSurahState persisted,
    LearningSurahState candidate,
  ) =>
      persisted.id == candidate.id &&
      persisted.surahId == candidate.surahId &&
      persisted.ayahCount == candidate.ayahCount &&
      persisted.plan == candidate.plan &&
      persisted.stage == candidate.stage &&
      persisted.learningCycle == candidate.learningCycle &&
      persisted.status == candidate.status &&
      _sameDatabaseTime(
        persisted.lastLearningActivityAtUtc,
        candidate.lastLearningActivityAtUtc,
      ) &&
      _sameDatabaseTime(
        persisted.inactivityRollbackForActivityAtUtc,
        candidate.inactivityRollbackForActivityAtUtc,
      );

  bool _sameDatabaseTime(DateTime? left, DateTime? right) {
    if (left == null || right == null) return left == right;
    return left.toUtc().millisecondsSinceEpoch ~/ 1000 ==
        right.toUtc().millisecondsSinceEpoch ~/ 1000;
  }
}
