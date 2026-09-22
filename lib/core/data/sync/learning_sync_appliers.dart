/// Writes pulled learning plans and their events into this device.
///
/// The plan has to arrive before its events: `learning_events.learning_surah_id`
/// references it with `ON DELETE CASCADE`, so an event without its plan cannot
/// be written at all.
///
/// An event's `sequence` is an autoincrementing primary key and does not
/// travel, for the reason every other journal here does not: two devices number
/// independently. The event's own `id` is what identifies it across them.
library;

import 'package:drift/drift.dart';

import '../../sync/learning_sync_payloads.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'sync_versioned_rows.dart';

final class LearningStateSyncApplier {
  const LearningStateSyncApplier(this._database);

  final AppDatabase _database;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == LearningStateSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a learning plan envelope: ${envelope.entityKey}');
    }
    // ADR-0002's rule, run here because the server does not run it.
    if (!SyncMergeDecision.incomingWins(
      incomingUpdatedAtUtc: envelope.updatedAtUtc,
      localUpdatedAtUtc: await SyncVersionedRows(
        _database,
      ).updatedAtUtc(table: 'learning_surahs', key: envelope.entityId),
    )) {
      return;
    }
    if (envelope.isTombstone) {
      await _remove(envelope.entityId);
      return;
    }

    final record = LearningStateSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    final surah =
        await (_database.select(_database.surahMetadata)
              ..where((SurahMetadata row) => row.id.equals(record.surahId)))
            .getSingleOrNull();
    if (surah == null) {
      throw const SyncTransportException(
        'remote-learning-surah-not-in-catalog',
      );
    }
    final clash =
        await (_database.select(_database.learningSurahs)..where(
              (LearningSurahs row) =>
                  row.surahId.equals(record.surahId) &
                  row.id.equals(record.id).not(),
            ))
            .getSingleOrNull();
    if (clash != null) {
      // `surah_id` is unique: one plan per surah. Two devices that each started
      // learning the same surah before ever syncing produce exactly this, and
      // it is a genuine conflict rather than a transport problem — merging two
      // positions would invent a place in the surah the owner was never at.
      throw const SyncTransportException('remote-learning-plan-already-here');
    }

    final position = record.position;
    await _database
        .into(_database.learningSurahs)
        .insertOnConflictUpdate(
          LearningSurahsCompanion.insert(
            id: record.id,
            surahId: record.surahId,
            ayahCount: record.ayahCount,
            planKind: Value<String>(position.planKind),
            stageKind: position.stageKind,
            stageStartAyah: position.stageStartAyah,
            stageEndAyah: position.stageEndAyah,
            targetStartAyah: position.targetStartAyah,
            targetEndAyah: position.targetEndAyah,
            blockSize: Value<int?>(position.blockSize),
            learningCycle: Value<int>(record.learningCycle),
            status: record.status,
            lastLearningActivityAtUtc: Value<DateTime?>(
              record.lastLearningActivityAtUtc,
            ),
            inactivityRollbackForActivityAtUtc: Value<DateTime?>(
              record.inactivityRollbackForActivityAtUtc,
            ),
          ),
        );
    await SyncVersionedRows(_database).stampAuthored(
      table: 'learning_surahs',
      key: record.id,
      authoredAtUtc: envelope.updatedAtUtc,
    );
  }

  Future<void> _remove(String id) async {
    // Deleting a plan cascades into its events, which is right: the journal
    // describes that plan's movement and means nothing without it. Stopping
    // learning a surah is a real thing the owner can do.
    await (_database.delete(
      _database.learningSurahs,
    )..where((LearningSurahs row) => row.id.equals(id))).go();
  }
}

final class LearningEventSyncApplier {
  const LearningEventSyncApplier(this._database);

  final AppDatabase _database;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == LearningEventSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a learning event envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      // Nothing in the app deletes a learning event; the journal is what a
      // rollback reads to know where to return to. A tombstone has no local
      // meaning, and removing one would leave a plan whose history no longer
      // explains its position.
      throw const SyncTransportException('remote-learning-event-is-permanent');
    }

    final record = LearningEventSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    final plan =
        await (_database.select(_database.learningSurahs)..where(
              (LearningSurahs row) => row.id.equals(record.learningSurahId),
            ))
            .getSingleOrNull();
    if (plan == null) {
      // Retryable: the plan is itself an entity that syncs, and the foreign key
      // would refuse this write anyway.
      throw const SyncTransportException('remote-learning-event-plan-missing');
    }

    final existing =
        await (_database.select(_database.learningEvents)
              ..where((LearningEvents row) => row.id.equals(record.id)))
            .getSingleOrNull();
    if (existing != null) return;

    await _database
        .into(_database.learningEvents)
        .insert(
          LearningEventsCompanion.insert(
            id: record.id,
            learningSurahId: record.learningSurahId,
            type: record.type,
            createdAtUtc: record.createdAtUtc,
            learningCycle: Value<int>(record.learningCycle),
            fromPlanKind: record.from.planKind,
            fromTargetStartAyah: record.from.targetStartAyah,
            fromTargetEndAyah: record.from.targetEndAyah,
            fromBlockSize: Value<int?>(record.from.blockSize),
            fromStageKind: record.from.stageKind,
            fromStageStartAyah: record.from.stageStartAyah,
            fromStageEndAyah: record.from.stageEndAyah,
            toPlanKind: record.to.planKind,
            toTargetStartAyah: record.to.targetStartAyah,
            toTargetEndAyah: record.to.targetEndAyah,
            toBlockSize: Value<int?>(record.to.blockSize),
            toStageKind: record.to.stageKind,
            toStageStartAyah: record.to.stageStartAyah,
            toStageEndAyah: record.to.stageEndAyah,
            reason: Value<String?>(record.reason),
          ),
        );
  }
}
