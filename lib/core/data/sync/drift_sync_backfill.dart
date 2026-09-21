/// Reads this device's append-only journals and queues them for an account.
///
/// The four journals here — recitations, rotation adjustments, learning events
/// and recall attempts — are the bulk of what a long-standing user has, and
/// they are also the unambiguous half of the problem. Each row records a moment
/// and is never edited afterwards, so the envelope's `updatedAtUtc` is simply
/// when the thing happened (or when it was withdrawn). Nothing has to be
/// guessed, which is why these come first: the versioned tables raise a real
/// question about rows that carry no last-changed time, and that question
/// deserves its own answer rather than being smuggled in here.
///
/// **A row this build cannot express is counted, not thrown.** One legacy
/// learning event whose stage bounds no longer satisfy today's invariants must
/// not stop a user's entire history from reaching their account; the report
/// says how many were left behind so the caller can say so.
library;

import 'package:drift/drift.dart';

import '../../sync/journal_sync_payloads.dart';
import '../../sync/learning_sync_payloads.dart';
import '../../sync/recitation_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import '../repositories/recitation_repository.dart';

final class DriftSyncBackfill implements SyncBackfill {
  DriftSyncBackfill({
    required AppDatabase database,
    required SyncOutbox outbox,
    required Future<String> Function() deviceId,
    required String Function() newId,
    this.schemaVersion = kSyncPayloadSchemaVersion,
    this.pageSize = 200,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _database = database,
       // ignore: prefer_initializing_formals
       _outbox = outbox,
       // ignore: prefer_initializing_formals
       _deviceId = deviceId,
       // ignore: prefer_initializing_formals
       _newId = newId {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive.');
    }
  }

  final AppDatabase _database;
  final SyncOutbox _outbox;

  /// Read when a backfill runs rather than held from construction: the id
  /// lives in `app_settings` and is created on first use, which a provider
  /// cannot await.
  final Future<String> Function() _deviceId;

  final String Function() _newId;

  final int schemaVersion;

  /// How many rows are read at a time.
  ///
  /// A whole history does not need to be in memory at once, and the queue is a
  /// table rather than a request, so there is nothing to be gained by sending
  /// it in one piece and a phone's memory to be spent on it.
  final int pageSize;

  @override
  Future<SyncBackfillReport> enqueueEverything({
    required DateTime nowUtc,
  }) async {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'Must be UTC.');
    }
    final deviceId = await _deviceId();
    if (deviceId.isEmpty) {
      // Every envelope names the device that wrote it, and "which of my
      // devices was this" is unanswerable with a blank. Refused here rather
      // than written into a whole history.
      throw StateError('Refusing to back fill without a device id.');
    }
    final enqueued = <SyncEntityType, int>{};
    final skipped = <SyncEntityType, int>{};
    final tally = _Tally(
      outbox: _outbox,
      nowUtc: nowUtc,
      enqueued: enqueued,
      skipped: skipped,
    );

    await _backfillRecitations(tally, deviceId);
    await _backfillRotationAdjustments(tally, deviceId);
    await _backfillLearningEvents(tally, deviceId);
    await _backfillRecallAttempts(tally, deviceId);

    return SyncBackfillReport(enqueuedByType: enqueued, skippedByType: skipped);
  }

  Future<void> _backfillRecitations(_Tally tally, String deviceId) async {
    final recitations = RecitationRepository(_database);
    var offset = 0;
    while (true) {
      final page = await recitations.getHistory(
        limit: pageSize,
        offset: offset,
        includeDeleted: true,
      );
      if (page.isEmpty) return;
      for (final entry in page) {
        await tally.attempt(SyncEntityType.recitationEvent, () {
          final deletedAt = entry.deletedAtUtc;
          // A withdrawn recitation travels as the withdrawal, not as the
          // record plus a separate deletion: the account only ever needs to
          // know the end state, and sending both would race them.
          return deletedAt == null
              ? RecitationSyncPayload.upsert(
                  entry.event,
                  envelopeId: _newId(),
                  deviceId: deviceId,
                  idempotencyKey: _newId(),
                  schemaVersion: schemaVersion,
                  updatedAtUtc: entry.event.createdAtUtc,
                )
              : RecitationSyncPayload.tombstone(
                  entityId: entry.event.id,
                  envelopeId: _newId(),
                  deviceId: deviceId,
                  idempotencyKey: _newId(),
                  schemaVersion: schemaVersion,
                  originalCreatedAtUtc: entry.event.createdAtUtc,
                  deletedAtUtc: deletedAt,
                );
        });
      }
      if (page.length < pageSize) return;
      offset += page.length;
    }
  }

  Future<void> _backfillRotationAdjustments(
    _Tally tally,
    String deviceId,
  ) async {
    await _forEachPage<RotationAdjustmentRow>(
      read: (limit, offset) =>
          (_database.select(_database.rotationAdjustments)
                ..orderBy(<OrderingTerm Function(RotationAdjustments)>[
                  (RotationAdjustments row) =>
                      OrderingTerm(expression: row.journalSequence),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) => tally.attempt(SyncEntityType.rotationAdjustment, () {
        final deletedAt = row.deletedAtUtc?.toUtc();
        if (deletedAt != null) {
          return RotationAdjustmentSyncPayload.tombstone(
            entityId: row.id,
            envelopeId: _newId(),
            deviceId: deviceId,
            idempotencyKey: _newId(),
            schemaVersion: schemaVersion,
            originalCreatedAtUtc: row.createdAtUtc.toUtc(),
            deletedAtUtc: deletedAt,
          );
        }
        return RotationAdjustmentSyncPayload.upsert(
          RotationAdjustmentSyncRecord(
            id: row.id,
            surahId: row.surahId,
            rotationSchemeId: row.rotationSchemeId,
            delta: row.delta,
            reason: row.reason,
            createdAtUtc: row.createdAtUtc.toUtc(),
          ),
          envelopeId: _newId(),
          deviceId: deviceId,
          idempotencyKey: _newId(),
          schemaVersion: schemaVersion,
          updatedAtUtc: row.createdAtUtc.toUtc(),
        );
      }),
    );
  }

  Future<void> _backfillLearningEvents(_Tally tally, String deviceId) async {
    await _forEachPage<LearningEventRow>(
      read: (limit, offset) =>
          (_database.select(_database.learningEvents)
                ..orderBy(<OrderingTerm Function(LearningEvents)>[
                  (LearningEvents row) =>
                      OrderingTerm(expression: row.sequence),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) => tally.attempt(
        SyncEntityType.learningEvent,
        () => LearningEventSyncPayload.upsert(
          LearningEventSyncRecord(
            id: row.id,
            learningSurahId: row.learningSurahId,
            type: row.type,
            createdAtUtc: row.createdAtUtc.toUtc(),
            learningCycle: row.learningCycle,
            from: LearningPlanPosition(
              planKind: row.fromPlanKind,
              targetStartAyah: row.fromTargetStartAyah,
              targetEndAyah: row.fromTargetEndAyah,
              blockSize: row.fromBlockSize,
              stageKind: row.fromStageKind,
              stageStartAyah: row.fromStageStartAyah,
              stageEndAyah: row.fromStageEndAyah,
            ),
            to: LearningPlanPosition(
              planKind: row.toPlanKind,
              targetStartAyah: row.toTargetStartAyah,
              targetEndAyah: row.toTargetEndAyah,
              blockSize: row.toBlockSize,
              stageKind: row.toStageKind,
              stageStartAyah: row.toStageStartAyah,
              stageEndAyah: row.toStageEndAyah,
            ),
            reason: row.reason,
          ),
          envelopeId: _newId(),
          deviceId: deviceId,
          idempotencyKey: _newId(),
          schemaVersion: schemaVersion,
          updatedAtUtc: row.createdAtUtc.toUtc(),
        ),
      ),
    );
  }

  Future<void> _backfillRecallAttempts(_Tally tally, String deviceId) async {
    await _forEachPage<RecallAttemptRow>(
      read: (limit, offset) =>
          (_database.select(_database.recallAttempts)
                ..orderBy(<OrderingTerm Function(RecallAttempts)>[
                  (RecallAttempts row) =>
                      OrderingTerm(expression: row.sequence),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) => tally.attempt(
        SyncEntityType.recallAttempt,
        () => RecallAttemptSyncPayload.upsert(
          RecallAttemptSyncRecord(
            id: row.id,
            surahId: row.surahId,
            ayahStart: row.ayahStart,
            ayahEnd: row.ayahEnd,
            learningCycle: row.learningCycle,
            result: row.result,
            createdAtUtc: row.createdAtUtc.toUtc(),
            localDate: row.localDate,
            source: row.source,
          ),
          envelopeId: _newId(),
          deviceId: deviceId,
          idempotencyKey: _newId(),
          schemaVersion: schemaVersion,
          updatedAtUtc: row.createdAtUtc.toUtc(),
        ),
      ),
    );
  }

  /// Walks a table in pages, ordered by its journal sequence.
  ///
  /// Ordered on purpose: `LIMIT`/`OFFSET` over an unordered select is not
  /// guaranteed to partition the table, so an unlucky plan could hand back the
  /// same row twice and never show another.
  Future<void> _forEachPage<R>({
    required Future<List<R>> Function(int limit, int offset) read,
    required Future<void> Function(R row) each,
  }) async {
    var offset = 0;
    while (true) {
      final page = await read(pageSize, offset);
      if (page.isEmpty) return;
      for (final row in page) {
        await each(row);
      }
      if (page.length < pageSize) return;
      offset += page.length;
    }
  }
}

/// Counts what went in and what could not, and enqueues the rest.
final class _Tally {
  _Tally({
    required SyncOutbox outbox,
    required DateTime nowUtc,
    required Map<SyncEntityType, int> enqueued,
    required Map<SyncEntityType, int> skipped,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _outbox = outbox,
       // ignore: prefer_initializing_formals
       _nowUtc = nowUtc,
       // ignore: prefer_initializing_formals
       _enqueued = enqueued,
       // ignore: prefer_initializing_formals
       _skipped = skipped;

  final SyncOutbox _outbox;

  /// When these entries joined the queue — which is now, and is not the
  /// envelope's `updatedAtUtc`, which is when the thing it describes actually
  /// happened. Coalescing compares the latter; only ordering uses this.
  final DateTime _nowUtc;

  final Map<SyncEntityType, int> _enqueued;
  final Map<SyncEntityType, int> _skipped;

  Future<void> attempt(
    SyncEntityType type,
    SyncEnvelope Function() build,
  ) async {
    final SyncEnvelope envelope;
    try {
      envelope = build();
    } on ArgumentError {
      // A row today's invariants refuse. Counted and left behind rather than
      // allowed to abort a history that is otherwise fine.
      _skipped[type] = (_skipped[type] ?? 0) + 1;
      return;
    } on Exception {
      _skipped[type] = (_skipped[type] ?? 0) + 1;
      return;
    }
    await _outbox.enqueue(envelope, nowUtc: _nowUtc);
    _enqueued[type] = (_enqueued[type] ?? 0) + 1;
  }
}
