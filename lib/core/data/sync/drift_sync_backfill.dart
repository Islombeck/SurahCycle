/// Reads everything this device holds and queues it for an account.
///
/// Two kinds of table, and the difference decides what date an envelope gets.
///
/// **The four append-only journals** — recitations, rotation adjustments,
/// learning events, recall attempts — each record a moment and are never edited
/// afterwards, so the envelope is dated when the thing happened, or when it was
/// withdrawn. Nothing is guessed.
///
/// **The six versioned tables** resolve conflicts by `updatedAtUtc`, and schema
/// v10 added that column without backfilling it, so a row untouched since the
/// upgrade has none. Those travel with [kUndatedByThisDevice], which explains
/// itself at length: the short version is that an undatable local row must lose
/// to anything the account can date, because the only way the account has a
/// dated copy is that another device edited it more recently.
///
/// **`rotationState` is not sent at all**, matching `SyncEnvelopeRouter`: the
/// rotation projection is rebuilt from the journal rather than synced, and
/// queueing envelopes nothing can apply would stall every other device's pull
/// on a record none of them can place.
///
/// **A row this build cannot express is counted, not thrown.** One legacy
/// learning event whose stage bounds no longer satisfy today's invariants must
/// not stop a user's entire history from reaching their account; the report
/// says how many were left behind so the caller can say so.
library;

import 'package:drift/drift.dart';

import '../../sync/app_setting_sync_payload.dart';
import '../../sync/journal_sync_payloads.dart';
import '../../sync/learning_sync_payloads.dart';
import '../../sync/mastered_surah_sync_payload.dart';
import '../../sync/prayer_routine_sync_payload.dart';
import '../../sync/prayer_session_sync_payload.dart';
import '../../sync/recitation_sync_payload.dart';
import '../../sync/rotation_scheme_sync_payload.dart';
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

    // The roster and the schemes first, in the order the router applies them:
    // a queue that arrives in dependency order is one the far side can take in
    // one page instead of stalling on a record whose prerequisite is behind it.
    await _backfillMasteredSurahs(tally, deviceId);
    await _backfillRotationSchemes(tally, deviceId);
    await _backfillPrayerSessions(tally, deviceId);
    await _backfillPrayerRoutines(tally, deviceId);
    await _backfillLearningStates(tally, deviceId);

    await _backfillRecitations(tally, deviceId);
    await _backfillRotationAdjustments(tally, deviceId);
    await _backfillLearningEvents(tally, deviceId);
    await _backfillRecallAttempts(tally, deviceId);

    await _backfillAppSettings(tally, deviceId);

    return SyncBackfillReport(enqueuedByType: enqueued, skippedByType: skipped);
  }

  /// What date an envelope for a versioned row carries.
  ///
  /// [kUndatedByThisDevice] when the row has none, which is honest and which
  /// loses to anything the account can date. See its documentation.
  static DateTime _versionedAt(DateTime? updatedAtUtc) =>
      updatedAtUtc?.toUtc() ?? kUndatedByThisDevice;

  Future<void> _backfillMasteredSurahs(_Tally tally, String deviceId) async {
    await _forEachPage<MasteredSurahRow>(
      read: (limit, offset) =>
          (_database.select(_database.masteredSurahs)
                ..orderBy(<OrderingTerm Function(MasteredSurahs)>[
                  (MasteredSurahs row) =>
                      OrderingTerm(expression: row.displayOrder),
                  (MasteredSurahs row) => OrderingTerm(expression: row.surahId),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) => tally.attempt(
        SyncEntityType.masteredSurah,
        () => MasteredSurahSyncPayload.upsert(
          MasteredSurahSyncRecord(
            surahId: row.surahId,
            isCurrentlyMastered: row.isCurrentlyMastered,
            isActive: row.isActive,
            hasEnteredRotation: row.hasEnteredRotation,
            activationBaselineScore: row.activationBaselineScore,
            alias: row.alias,
            displayOrder: row.displayOrder,
          ),
          envelopeId: _newId(),
          deviceId: deviceId,
          idempotencyKey: _newId(),
          schemaVersion: schemaVersion,
          updatedAtUtc: _versionedAt(row.updatedAtUtc),
        ),
      ),
    );
  }

  Future<void> _backfillRotationSchemes(_Tally tally, String deviceId) async {
    await _forEachPage<RotationSchemeRow>(
      read: (limit, offset) =>
          (_database.select(_database.rotationSchemes)
                ..orderBy(<OrderingTerm Function(RotationSchemes)>[
                  (RotationSchemes row) =>
                      OrderingTerm(expression: row.surahId),
                  (RotationSchemes row) =>
                      OrderingTerm(expression: row.version),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) async {
        final parts =
            await (_database.select(_database.rotationParts)
                  ..where((RotationParts part) => part.schemeId.equals(row.id))
                  ..orderBy(<OrderingTerm Function(RotationParts)>[
                    (RotationParts part) =>
                        OrderingTerm(expression: part.ordinal),
                  ]))
                .get();
        await tally.attempt(
          SyncEntityType.rotationScheme,
          () => RotationSchemeSyncPayload.upsert(
            RotationSchemeSyncRecord(
              id: row.id,
              surahId: row.surahId,
              version: row.version,
              ayahCountSnapshot: row.ayahCountSnapshot,
              baselineScore: row.baselineScore,
              baselineTotalRecitations: row.baselineTotalRecitations,
              baselineLastUsedAtUtc: row.baselineLastUsedAtUtc?.toUtc(),
              resetsRotationBaseline: row.resetsRotationBaseline,
              // One scheme per surah is in force, and the table says which by
              // leaving its superseding sequence null.
              isActive: row.supersededJournalSequence == null,
              parts: <RotationSchemeSyncPart>[
                for (final part in parts)
                  RotationSchemeSyncPart(
                    id: part.id,
                    ordinal: part.ordinal,
                    startAyah: part.startAyah,
                    endAyah: part.endAyah,
                  ),
              ],
            ),
            envelopeId: _newId(),
            deviceId: deviceId,
            idempotencyKey: _newId(),
            schemaVersion: schemaVersion,
            updatedAtUtc: _versionedAt(row.updatedAtUtc),
          ),
        );
      },
    );
  }

  Future<void> _backfillPrayerSessions(_Tally tally, String deviceId) async {
    await _forEachPage<PrayerSessionRow>(
      read: (limit, offset) =>
          (_database.select(_database.prayerSessions)
                ..orderBy(<OrderingTerm Function(PrayerSessions)>[
                  (PrayerSessions row) =>
                      OrderingTerm(expression: row.startedAtUtc),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) async {
        final parts =
            await (_database.select(_database.prayerSessionParts)
                  ..where(
                    (PrayerSessionParts part) =>
                        part.prayerSessionId.equals(row.id),
                  )
                  ..orderBy(<OrderingTerm Function(PrayerSessionParts)>[
                    (PrayerSessionParts part) =>
                        OrderingTerm(expression: part.orderIndex),
                  ]))
                .get();
        await tally.attempt(
          SyncEntityType.prayerSession,
          () => PrayerSessionSyncPayload.upsert(
            PrayerSessionSyncRecord(
              id: row.id,
              prayerType: row.prayerType,
              isQada: row.isQada,
              startedAtUtc: row.startedAtUtc.toUtc(),
              localDate: row.localDate,
              parts: <PrayerSessionSyncPart>[
                for (final part in parts)
                  PrayerSessionSyncPart(
                    id: part.id,
                    stableKey: part.stableKey,
                    orderIndex: part.orderIndex,
                    label: part.label,
                    kind: part.kind,
                    rakaatCount: part.rakaatCount,
                    requiredSurahSlots: part.requiredSurahSlots,
                    allowsFollowingImam: part.allowsFollowingImam,
                    completionMode: part.completionMode,
                    sourceTemplatePartId: part.sourceTemplatePartId,
                    templateRevision: part.templateRevision,
                    completedAtUtc: part.completedAtUtc?.toUtc(),
                  ),
              ],
            ),
            envelopeId: _newId(),
            deviceId: deviceId,
            idempotencyKey: _newId(),
            schemaVersion: schemaVersion,
            updatedAtUtc: _versionedAt(row.updatedAtUtc),
          ),
        );
      },
    );
  }

  Future<void> _backfillPrayerRoutines(_Tally tally, String deviceId) async {
    await _forEachPage<PrayerRoutineTemplateRow>(
      read: (limit, offset) =>
          (_database.select(_database.prayerRoutineTemplates)
                ..orderBy(<OrderingTerm Function(PrayerRoutineTemplates)>[
                  (PrayerRoutineTemplates row) =>
                      OrderingTerm(expression: row.prayerType),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) async {
        final parts =
            await (_database.select(_database.prayerRoutinePartTemplates)
                  ..where(
                    (PrayerRoutinePartTemplates part) =>
                        part.routineTemplateId.equals(row.id),
                  )
                  ..orderBy(<OrderingTerm Function(PrayerRoutinePartTemplates)>[
                    (PrayerRoutinePartTemplates part) =>
                        OrderingTerm(expression: part.orderIndex),
                  ]))
                .get();
        await tally.attempt(
          SyncEntityType.prayerRoutineTemplate,
          () => PrayerRoutineSyncPayload.upsert(
            PrayerRoutineSyncRecord(
              id: row.id,
              prayerType: row.prayerType,
              displayName: row.displayName,
              enabled: row.enabled,
              revision: row.revision,
              parts: <PrayerRoutineSyncPart>[
                for (final part in parts)
                  PrayerRoutineSyncPart(
                    id: part.id,
                    stableKey: part.stableKey,
                    orderIndex: part.orderIndex,
                    kind: part.kind,
                    customLabel: part.customLabel,
                    rakaatCount: part.rakaatCount,
                    requiredSurahSlots: part.requiredSurahSlots,
                    allowsFollowingImam: part.allowsFollowingImam,
                    defaultCompletionMode: part.defaultCompletionMode,
                  ),
              ],
            ),
            envelopeId: _newId(),
            deviceId: deviceId,
            idempotencyKey: _newId(),
            schemaVersion: schemaVersion,
            updatedAtUtc: _versionedAt(row.updatedAtUtc),
          ),
        );
      },
    );
  }

  Future<void> _backfillLearningStates(_Tally tally, String deviceId) async {
    await _forEachPage<LearningSurahRow>(
      read: (limit, offset) =>
          (_database.select(_database.learningSurahs)
                ..orderBy(<OrderingTerm Function(LearningSurahs)>[
                  (LearningSurahs row) => OrderingTerm(expression: row.id),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) => tally.attempt(
        SyncEntityType.learningState,
        () => LearningStateSyncPayload.upsert(
          LearningStateSyncRecord(
            id: row.id,
            surahId: row.surahId,
            ayahCount: row.ayahCount,
            position: LearningPlanPosition(
              planKind: row.planKind,
              targetStartAyah: row.targetStartAyah,
              targetEndAyah: row.targetEndAyah,
              blockSize: row.blockSize,
              stageKind: row.stageKind,
              stageStartAyah: row.stageStartAyah,
              stageEndAyah: row.stageEndAyah,
            ),
            learningCycle: row.learningCycle,
            status: row.status,
            lastLearningActivityAtUtc: row.lastLearningActivityAtUtc?.toUtc(),
            inactivityRollbackForActivityAtUtc: row
                .inactivityRollbackForActivityAtUtc
                ?.toUtc(),
          ),
          envelopeId: _newId(),
          deviceId: deviceId,
          idempotencyKey: _newId(),
          schemaVersion: schemaVersion,
          updatedAtUtc: _versionedAt(row.updatedAtUtc),
        ),
      ),
    );
  }

  Future<void> _backfillAppSettings(_Tally tally, String deviceId) async {
    await _forEachPage<AppSettingRow>(
      read: (limit, offset) =>
          (_database.select(_database.appSettings)
                ..orderBy(<OrderingTerm Function(AppSettings)>[
                  (AppSettings row) => OrderingTerm(expression: row.key),
                ])
                ..limit(limit, offset: offset))
              .get(),
      each: (row) async {
        // Asked before building rather than caught after: a setting outside the
        // reviewed allow-list is not a failure to count, it is one this feature
        // has decided never travels. Counting it as skipped would report a gap
        // where there is a rule.
        if (!AppSettingSyncPayload.isSyncable(row.key)) return;
        await tally.attempt(
          SyncEntityType.appSetting,
          () => AppSettingSyncPayload.upsert(
            AppSettingSyncRecord(
              key: row.key,
              value: row.value,
              valueType: row.valueType,
              updatedAtUtc: row.updatedAtUtc.toUtc(),
            ),
            envelopeId: _newId(),
            deviceId: deviceId,
            idempotencyKey: _newId(),
            schemaVersion: schemaVersion,
          ),
        );
      },
    );
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

  /// Walks a table in pages, ordered so `LIMIT`/`OFFSET` really partitions it.
  ///
  /// Ordered on purpose: an unordered select is not guaranteed to hand back the
  /// same sequence twice, so an unlucky plan could repeat one row and never
  /// show another.
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
