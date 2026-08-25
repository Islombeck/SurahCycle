import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';

final class LearningRepository {
  const LearningRepository(this.database);

  final AppDatabase database;

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

  Future<bool> delete(String id) async =>
      (database.delete(database.learningSurahs)
            ..where((LearningSurahs row) => row.id.equals(id)))
          .go()
          .then((int count) => count == 1);

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
            stageKind: state.stage.kind.name,
            stageEndAyah: state.stage.endAyah,
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
          fromStageKind: event.fromStage.kind.name,
          fromStageEndAyah: event.fromStage.endAyah,
          toStageKind: event.toStage.kind.name,
          toStageEndAyah: event.toStage.endAyah,
        ),
      );

  LearningSurahState _stateFromRow(LearningSurahRow row) => LearningSurahState(
    id: row.id,
    surahId: row.surahId,
    ayahCount: row.ayahCount,
    stage: _stage(row.stageKind, row.stageEndAyah),
    status: LearningStatus.values.byName(row.status),
    lastLearningActivityAtUtc: row.lastLearningActivityAtUtc?.toUtc(),
    inactivityRollbackForActivityAtUtc: row.inactivityRollbackForActivityAtUtc
        ?.toUtc(),
  );

  LearningEvent _eventFromRow(LearningEventRow row) => LearningEvent(
    id: row.id,
    learningSurahId: row.learningSurahId,
    type: LearningEventType.values.byName(row.type),
    createdAtUtc: row.createdAtUtc.toUtc(),
    fromStage: _stage(row.fromStageKind, row.fromStageEndAyah),
    toStage: _stage(row.toStageKind, row.toStageEndAyah),
  );

  LearningStage _stage(String kind, int endAyah) =>
      switch (LearningStageKind.values.byName(kind)) {
        LearningStageKind.newAyah => LearningStage.newAyah(endAyah),
        LearningStageKind.cumulative => LearningStage.cumulative(endAyah),
      };

  bool _samePersistedState(
    LearningSurahState persisted,
    LearningSurahState candidate,
  ) =>
      persisted.id == candidate.id &&
      persisted.surahId == candidate.surahId &&
      persisted.ayahCount == candidate.ayahCount &&
      persisted.stage == candidate.stage &&
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
