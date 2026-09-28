import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';
import '../sync/sync_recorder.dart';
import 'prayer_session_completion.dart';
import 'rotation_projection_store.dart';

final class RecitationUndoToken {
  RecitationUndoToken._({
    required this._owner,
    required this.eventId,
    required this.journalSequence,
    required this._previousJournalSequence,
    required this._beforeSnapshot,
    required this._afterSnapshot,
  });

  final Object _owner;
  final String eventId;
  final int journalSequence;
  final int _previousJournalSequence;
  final RotationSnapshot _beforeSnapshot;
  final RotationSnapshot _afterSnapshot;
  bool _consumed = false;
}

final class RecitationRegistration {
  const RecitationRegistration({
    required this.event,
    required this.snapshot,
    required this.undoToken,
  });

  final SurahRecitationEvent event;
  final RotationSnapshot snapshot;
  final RecitationUndoToken undoToken;
}

final class RecitationUndoResult {
  const RecitationUndoResult({
    required this.didUndo,
    required this.snapshot,
    this.undoneEventId,
  });

  final bool didUndo;
  final RotationSnapshot snapshot;
  final String? undoneEventId;
}

final class JournalDeletionResult {
  const JournalDeletionResult({
    required this.didDelete,
    required this.snapshot,
  });

  final bool didDelete;
  final RotationSnapshot snapshot;
}

/// Outcome of putting a deleted journal entry back.
final class JournalRestorationResult {
  const JournalRestorationResult({
    required this.didRestore,
    required this.snapshot,
  });

  /// False when there was nothing to restore — an unknown id, or an entry that
  /// was never deleted. Not an error: a second tap on the same row must be a
  /// no-op rather than a second restoration.
  final bool didRestore;
  final RotationSnapshot snapshot;
}

final class RecitationHistoryEntry {
  const RecitationHistoryEntry({
    required this.event,
    required this.surah,
    required this.journalSequence,
    this.coveredParts = const <SurahRotationPart>[],
    this.isWholeSurah = false,
    this.deletedAtUtc,
    this.stateChangedAtUtc,
  });

  final SurahRecitationEvent event;
  final SurahDescriptor surah;
  final int journalSequence;
  final List<SurahRotationPart> coveredParts;
  final bool isWholeSurah;

  /// When this entry was withdrawn, or null while it still counts.
  ///
  /// A deletion is a tombstone rather than a removal, so the entry is still
  /// here and can be put back. Only a history asked for it with
  /// `includeDeleted` ever sees one.
  final DateTime? deletedAtUtc;

  /// When the standing of this entry last changed — withdrawn, or put back.
  ///
  /// Null for anything written before v11 added the column, which is honest:
  /// nobody knows when a record from last year last changed hands.
  ///
  /// It exists here because a restore is invisible without it. Clearing the
  /// withdrawal puts [deletedAtUtc] back to null, so "created, or withdrawn"
  /// collapses to the creation time and the change looks months old to
  /// anything asking what is new.
  final DateTime? stateChangedAtUtc;

  bool get isDeleted => deletedAtUtc != null;
}

final class SurahRecitationStat {
  const SurahRecitationStat({
    required this.surah,
    required this.count,
    this.actionCount = 0,
    this.lastUsedAtUtc,
    this.byPrayer = const <PrayerContext, int>{},
    this.byPart = const <String, int>{},
  });

  final SurahDescriptor surah;
  final int count;
  final int actionCount;
  final DateTime? lastUsedAtUtc;
  final Map<PrayerContext, int> byPrayer;
  final Map<String, int> byPart;
}

final class PrayerRecitationStat {
  const PrayerRecitationStat({
    required this.context,
    required this.count,
    this.actionCount = 0,
  });

  final PrayerContext context;
  final int count;
  final int actionCount;
}

final class RecitationStats {
  const RecitationStats({
    required this.total,
    required this.bySurah,
    required this.byPrayer,
    this.actionCount = 0,
  });

  final int total;
  final int actionCount;
  final List<SurahRecitationStat> bySurah;
  final List<PrayerRecitationStat> byPrayer;
}

enum PrayerSessionSlotUnavailableReason {
  exactSlotRequired,
  missingSession,
  contextMismatch,
  dateMismatch,
  missingPart,
  foreignPart,
  nonCurrentPart,
  completedPart,
  slotOutOfRange,
  slotNotNext,
  occupiedSlot,
  qadaPartNotEligible,
}

/// A typed stale-target failure for exact prayer-session slot registrations.
///
/// It remains a [StateError] for existing app callers, while widget actions
/// can safely map only this known validation family to a user-facing rejection
/// without hiding unrelated persistence or projection failures.
final class PrayerSessionSlotUnavailableException extends StateError {
  PrayerSessionSlotUnavailableException(this.reason, String message)
    : super(message);

  final PrayerSessionSlotUnavailableReason reason;
}

/// Atomic journal writes, projection rebuild, history, statistics, and Undo.
final class RecitationRepository {
  RecitationRepository(
    this.database, {
    RotationEngine engine = const RotationEngine(),
    SyncRecorder? syncRecorder,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _engine = engine,
       // ignore: prefer_initializing_formals
       _syncRecorder = syncRecorder,
       _projection = RotationProjectionStore(database);

  final AppDatabase database;
  final RotationEngine _engine;

  /// Queues each change for an account, or null until one has been activated.
  ///
  /// Null is the ordinary state and costs nothing: a device that never signs in
  /// does no extra work and stores no extra rows. History written before
  /// activation reaches the account through a backfill instead — the only
  /// mechanism that can carry records made before sync existed.
  ///
  /// Every call to it sits **inside** the transaction that made the change, so
  /// a crash cannot leave a written row with no queue entry behind it.
  final SyncRecorder? _syncRecorder;
  final RotationProjectionStore _projection;
  final Object _undoOwner = Object();
  RecitationUndoToken? _activeUndoToken;

  /// Returns whether an immutable journal identifier has already been used.
  ///
  /// Interactive widget action tokens reuse the recitation UUID. Checking both
  /// journal tables prevents an identifier collision from ever becoming a
  /// second user action.
  Future<bool> containsJournalEventId(String id) async {
    final recitation = await (database.select(
      database.recitationEvents,
    )..where((RecitationEvents row) => row.id.equals(id))).getSingleOrNull();
    if (recitation != null) return true;
    final adjustment = await (database.select(
      database.rotationAdjustments,
    )..where((RotationAdjustments row) => row.id.equals(id))).getSingleOrNull();
    return adjustment != null;
  }

  /// Registers at most one event for [event.id]. A repeated delivery returns
  /// null, including after a later History deletion, so retries cannot
  /// resurrect an action the user deliberately removed.
  Future<RecitationRegistration?> registerOnce(
    SurahRecitationEvent event,
  ) async {
    if (await containsJournalEventId(event.id)) return null;
    try {
      return await register(event);
    } on Object {
      // Concurrent background deliveries can both pass the first read. The
      // primary-key/unique checks inside register serialize the winner; only a
      // now-present ID is converted into idempotent success.
      if (await containsJournalEventId(event.id)) return null;
      rethrow;
    }
  }

  Future<RecitationRegistration> register(SurahRecitationEvent event) async {
    final normalizedEvent = _atDatabasePrecision(event);
    final registration = await database.transaction(() async {
      await _ensureUnusedJournalId(normalizedEvent.id);
      final prayerSessionPart = await _validatePrayerSession(normalizedEvent);
      final state = await _projection.loadRotationState();
      final before = await _projection.loadSnapshot();
      final persistedEvent = _engine.resolveRecitation(before, normalizedEvent);
      final after = _engine.registerRecitation(before, persistedEvent);
      final sequence = state.lastJournalSequence + 1;
      final committedAfter = after.copyWith(revision: sequence);

      await database
          .into(database.recitationEvents)
          .insert(
            RecitationEventsCompanion.insert(
              id: persistedEvent.id,
              journalSequence: sequence,
              surahId: persistedEvent.surahId,
              rotationSchemeId: persistedEvent.rotationSchemeId!,
              rakaatSpanCount: persistedEvent.rakaatSpanCount,
              prayerSessionId: Value<String?>(persistedEvent.prayerSessionId),
              prayerSessionPartId: Value<String?>(
                persistedEvent.prayerSessionPartId,
              ),
              slotIndex: Value<int?>(persistedEvent.slotIndex),
              createdAtUtc: persistedEvent.createdAtUtc,
              localDate: persistedEvent.localDate.toString(),
              prayerType: persistedEvent.prayerType.name,
              isQada: Value<bool>(persistedEvent.isQada),
              qadaOriginIsUnknown: Value<bool>(
                persistedEvent.qadaOriginIsUnknown,
              ),
              qadaFulfilledLocalDate: Value<String?>(
                persistedEvent.qadaFulfilledLocalDate?.toString(),
              ),
            ),
          );
      for (final partId in persistedEvent.coveredPartIds) {
        await database
            .into(database.recitationEventParts)
            .insert(
              RecitationEventPartsCompanion.insert(
                eventId: persistedEvent.id,
                schemeId: persistedEvent.rotationSchemeId!,
                partId: partId,
              ),
            );
      }
      if (prayerSessionPart != null && persistedEvent.slotIndex != null) {
        await _reconcileRecitationCompletion(prayerSessionPart.id);
      }
      await _projection.writeSnapshot(
        committedAfter,
        lastJournalSequence: sequence,
      );
      // `persistedEvent`, not the argument: the engine resolves which scheme
      // and which parts this recitation actually covered, and the account must
      // receive what was stored rather than what was asked for.
      await _syncRecorder?.recordRecitationUpsert(
        persistedEvent,
        atUtc: persistedEvent.createdAtUtc,
      );

      final token = RecitationUndoToken._(
        owner: _undoOwner,
        eventId: persistedEvent.id,
        journalSequence: sequence,
        previousJournalSequence: state.lastJournalSequence,
        beforeSnapshot: before,
        afterSnapshot: committedAfter,
      );
      return RecitationRegistration(
        event: persistedEvent,
        snapshot: committedAfter,
        undoToken: token,
      );
    });
    _activeUndoToken = registration.undoToken;
    return registration;
  }

  Future<RotationSnapshot> applyAdjustment(
    RotationAdjustmentEvent event,
  ) async {
    final result = await database.transaction(() async {
      await _ensureUnusedJournalId(event.id);
      final state = await _projection.loadRotationState();
      final before = await _projection.loadSnapshot();
      final current = before.surahById(event.surahId);
      if (!current.hasEnteredRotation) {
        throw StateError(
          'A never-activated surah cannot receive a rotation adjustment.',
        );
      }
      final persistedEvent = _engine.resolveAdjustment(before, event);
      final after = _engine.applyAdjustment(before, persistedEvent);
      final sequence = state.lastJournalSequence + 1;
      await database
          .into(database.rotationAdjustments)
          .insert(
            RotationAdjustmentsCompanion.insert(
              id: event.id,
              journalSequence: sequence,
              surahId: persistedEvent.surahId,
              rotationSchemeId: persistedEvent.rotationSchemeId!,
              delta: persistedEvent.delta,
              reason: persistedEvent.reason,
              createdAtUtc: persistedEvent.createdAtUtc,
            ),
          );
      await _projection.writeSnapshot(after, lastJournalSequence: sequence);
      return after;
    });
    _activeUndoToken = null;
    return result;
  }

  Future<RecitationUndoResult> undo(RecitationUndoToken token) async {
    if (!identical(token._owner, _undoOwner) ||
        token._consumed ||
        !identical(token, _activeUndoToken)) {
      return RecitationUndoResult(
        didUndo: false,
        snapshot: await _projection.loadSnapshot(),
      );
    }

    final result = await database.transaction(() async {
      final state = await _projection.loadRotationState();
      final current = await _projection.loadSnapshot();
      if (state.lastJournalSequence != token.journalSequence ||
          current != token._afterSnapshot) {
        return RecitationUndoResult(didUndo: false, snapshot: current);
      }
      final event =
          await (database.select(database.recitationEvents)..where(
                (RecitationEvents row) =>
                    row.id.equals(token.eventId) & row.deletedAtUtc.isNull(),
              ))
              .getSingleOrNull();
      if (event == null || event.journalSequence != token.journalSequence) {
        return RecitationUndoResult(didUndo: false, snapshot: current);
      }

      final deleted = await (database.delete(
        database.recitationEvents,
      )..where((RecitationEvents row) => row.id.equals(token.eventId))).go();
      if (deleted != 1) {
        throw StateError('Failed to remove undoable recitation.');
      }
      if (event.prayerSessionPartId case final prayerSessionPartId?) {
        await _reconcileRecitationCompletion(prayerSessionPartId);
      }
      await _projection.writeSnapshot(
        token._beforeSnapshot,
        lastJournalSequence: token._previousJournalSequence,
      );
      return RecitationUndoResult(
        didUndo: true,
        snapshot: token._beforeSnapshot,
        undoneEventId: token.eventId,
      );
    });

    if (result.didUndo) token._consumed = true;
    _activeUndoToken = null;
    return result;
  }

  Future<JournalDeletionResult> deleteRecitation(
    String eventId, {
    required DateTime deletedAtUtc,
  }) async {
    _requireUtc(deletedAtUtc, 'deletedAtUtc');
    final result = await database.transaction(() async {
      final existing =
          await (database.select(database.recitationEvents)..where(
                (RecitationEvents row) =>
                    row.id.equals(eventId) & row.deletedAtUtc.isNull(),
              ))
              .getSingleOrNull();
      final before = await _projection.loadSnapshot();
      if (existing == null) {
        return JournalDeletionResult(didDelete: false, snapshot: before);
      }
      await (database.update(
        database.recitationEvents,
      )..where((RecitationEvents row) => row.id.equals(eventId))).write(
        RecitationEventsCompanion(
          deletedAtUtc: Value<DateTime?>(deletedAtUtc),
          // The same version the applier compares against when the account
          // speaks. Written here too, or a withdrawal made on this phone would
          // have no date another device could weigh a restore against — see
          // `RecitationStateVersion`.
          stateChangedAtUtc: Value<DateTime?>(deletedAtUtc),
        ),
      );
      if (existing.prayerSessionPartId case final prayerSessionPartId?) {
        await _reconcileRecitationCompletion(prayerSessionPartId);
      }
      // A tombstone, so the account learns the recitation was withdrawn rather
      // than simply stopping to hear about it — a device that was offline would
      // otherwise keep it forever and push it back.
      await _syncRecorder?.recordRecitationDelete(
        entityId: eventId,
        originalCreatedAtUtc: existing.createdAtUtc,
        deletedAtUtc: deletedAtUtc,
      );
      final rebuilt = await _projection.rebuildFromJournal(
        targetFloor: before.rotationTarget,
      );
      return JournalDeletionResult(didDelete: true, snapshot: rebuilt);
    });
    _activeUndoToken = null;
    return result;
  }

  /// Puts a deleted recitation back.
  ///
  /// Deliberately the mirror image of [deleteRecitation], down to reusing the
  /// same reconciliation and the same `rebuildFromJournal` call rather than
  /// reversing their effects by hand. A restore that recomputed the balance its
  /// own way would be a second implementation of the rotation rules, free to
  /// drift out of agreement with the first.
  ///
  /// The entry keeps its original `journalSequence`, its local date and its
  /// prayer context: this is the same recitation coming back, not a new one
  /// recorded today. That is the whole reason a deletion is a tombstone.
  Future<JournalRestorationResult> restoreRecitation(
    String eventId, {
    required DateTime restoredAtUtc,
  }) async {
    _requireUtc(restoredAtUtc, 'restoredAtUtc');
    final result = await database.transaction(() async {
      final existing =
          await (database.select(database.recitationEvents)..where(
                (RecitationEvents row) =>
                    row.id.equals(eventId) & row.deletedAtUtc.isNotNull(),
              ))
              .getSingleOrNull();
      final before = await _projection.loadSnapshot();
      if (existing == null) {
        // Unknown, or never deleted. Either way there is nothing to undo, and
        // saying so beats resurrecting something on a guess.
        return JournalRestorationResult(didRestore: false, snapshot: before);
      }
      await (database.update(
        database.recitationEvents,
      )..where((RecitationEvents row) => row.id.equals(eventId))).write(
        RecitationEventsCompanion(
          deletedAtUtc: const Value<DateTime?>(null),
          stateChangedAtUtc: Value<DateTime?>(restoredAtUtc),
        ),
      );
      if (existing.prayerSessionPartId case final prayerSessionPartId?) {
        // The same reconciliation the deletion ran. It derives the slot's state
        // from the events that are active *now*, so it re-completes the part
        // without needing to know which direction it is moving.
        await _reconcileRecitationCompletion(prayerSessionPartId);
      }
      // An upsert, which is what undoes a tombstone: the account is told the
      // recitation is back, carrying the same identity and the same prayer it
      // always had.
      if (_syncRecorder case final recorder?) {
        final coverage =
            await (database.select(database.recitationEventParts)..where(
                  (RecitationEventParts row) => row.eventId.equals(eventId),
                ))
                .get();
        await recorder.recordRecitationUpsert(
          _eventFromRow(existing, <String>[
            for (final row in coverage) row.partId,
          ]),
          atUtc: restoredAtUtc,
        );
      }
      final rebuilt = await _projection.rebuildFromJournal(
        targetFloor: before.rotationTarget,
      );
      return JournalRestorationResult(didRestore: true, snapshot: rebuilt);
    });
    // A pending single-step undo refers to a journal that has just changed
    // underneath it, so it is dropped rather than left to apply a stale
    // snapshot — exactly as deletion does.
    _activeUndoToken = null;
    return result;
  }

  Future<JournalDeletionResult> deleteAdjustment(
    String adjustmentId, {
    required DateTime deletedAtUtc,
  }) async {
    _requireUtc(deletedAtUtc, 'deletedAtUtc');
    final result = await database.transaction(() async {
      final existing =
          await (database.select(database.rotationAdjustments)..where(
                (RotationAdjustments row) =>
                    row.id.equals(adjustmentId) & row.deletedAtUtc.isNull(),
              ))
              .getSingleOrNull();
      final before = await _projection.loadSnapshot();
      if (existing == null) {
        return JournalDeletionResult(didDelete: false, snapshot: before);
      }
      await (database.update(
        database.rotationAdjustments,
      )..where((RotationAdjustments row) => row.id.equals(adjustmentId))).write(
        RotationAdjustmentsCompanion(
          deletedAtUtc: Value<DateTime?>(deletedAtUtc),
        ),
      );
      final rebuilt = await _projection.rebuildFromJournal(
        targetFloor: before.rotationTarget,
      );
      return JournalDeletionResult(didDelete: true, snapshot: rebuilt);
    });
    _activeUndoToken = null;
    return result;
  }

  Future<List<RecitationHistoryEntry>> getHistory({
    int limit = 100,
    int offset = 0,
    PrayerType? prayerType,
    bool? isQada,
    LocalDate? from,
    LocalDate? through,
    bool includeDeleted = false,
    DateTime? changedSince,
  }) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    if (changedSince != null && !changedSince.isUtc) {
      throw ArgumentError.value(changedSince, 'changedSince', 'Must be UTC.');
    }
    final query = database.select(database.recitationEvents);
    if (changedSince != null) {
      // Written, withdrawn, **or put back** at or after this moment. All three
      // columns matter: a withdrawal is an edit to a row whose creation time
      // has not moved, so asking only about `created_at_utc` would miss every
      // deletion — and a restore clears `deleted_at_utc` again, so asking only
      // about those two would miss every restore, which is how a prayer
      // brought back on one device stayed gone on the others.
      //
      // Added for the sync scan, which runs on every app resume. Reading the
      // whole journal and discarding most of it in Dart worked and did not
      // scale: this is the one caller that asks "what is new" rather than
      // "what is there".
      query.where(
        (RecitationEvents row) =>
            row.createdAtUtc.isBiggerOrEqualValue(changedSince) |
            row.deletedAtUtc.isBiggerOrEqualValue(changedSince) |
            row.stateChangedAtUtc.isBiggerOrEqualValue(changedSince),
      );
    }
    if (!includeDeleted) {
      // Off by default, and every counting caller leaves it off: a deleted
      // entry must never reach statistics, the rotation balance or the set of
      // parts already marked for a prayer. Only a screen offering to undo the
      // deletion has any business seeing one.
      query.where((RecitationEvents row) => row.deletedAtUtc.isNull());
    }
    if (prayerType != null) {
      query.where(
        (RecitationEvents row) => row.prayerType.equals(prayerType.name),
      );
    }
    if (isQada != null) {
      query.where((RecitationEvents row) => row.isQada.equals(isQada));
    }
    if (from != null) {
      query.where(
        (RecitationEvents row) =>
            row.localDate.isBiggerOrEqualValue(from.toString()),
      );
    }
    if (through != null) {
      query.where(
        (RecitationEvents row) =>
            row.localDate.isSmallerOrEqualValue(through.toString()),
      );
    }
    query
      ..orderBy(<OrderingTerm Function(RecitationEvents)>[
        (RecitationEvents row) => OrderingTerm.desc(row.journalSequence),
      ])
      ..limit(limit, offset: offset);
    final events = await query.get();
    return _mapHistory(events);
  }

  /// Covered rotation parts already committed for one local prayer context.
  Future<Set<String>> getMarkedPartIds({
    required PrayerContext context,
    required LocalDate localDate,
    String? prayerSessionPartId,
  }) async {
    final entries = await getHistory(
      limit: 10000,
      prayerType: context.prayerType,
      isQada: context.isQada,
      from: localDate,
      through: localDate,
    );
    return <String>{
      for (final entry in entries)
        if (prayerSessionPartId == null ||
            entry.event.prayerSessionPartId == prayerSessionPartId)
          for (final partId in entry.event.coveredPartIds) partId,
    };
  }

  Stream<List<RecitationHistoryEntry>> watchHistory({
    int limit = 100,
    bool includeDeleted = false,
  }) => database
      .customSelect(
        'SELECT 1 AS recitation_history_watch',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.recitationEvents,
          database.recitationEventParts,
          database.rotationParts,
          database.surahMetadata,
          database.masteredSurahs,
        },
      )
      .watch()
      .asyncMap(
        (List<QueryRow> _) =>
            getHistory(limit: limit, includeDeleted: includeDeleted),
      );

  Future<RecitationStats> getStats({
    LocalDate? from,
    LocalDate? through,
    PrayerType? prayerType,
    bool? isQada,
  }) async {
    final query = database.select(database.recitationEvents)
      ..where((RecitationEvents row) => row.deletedAtUtc.isNull());
    if (from != null) {
      query.where(
        (RecitationEvents row) =>
            row.localDate.isBiggerOrEqualValue(from.toString()),
      );
    }
    if (through != null) {
      query.where(
        (RecitationEvents row) =>
            row.localDate.isSmallerOrEqualValue(through.toString()),
      );
    }
    if (prayerType != null) {
      query.where(
        (RecitationEvents row) => row.prayerType.equals(prayerType.name),
      );
    }
    if (isQada != null) {
      query.where((RecitationEvents row) => row.isQada.equals(isQada));
    }
    final events = await query.get();
    final metadataRows = await database.select(database.surahMetadata).get();
    final masteredRows = await database.select(database.masteredSurahs).get();
    final coverageRows = await database
        .select(database.recitationEventParts)
        .get();
    final partRows = await database.select(database.rotationParts).get();
    final metadataById = <String, SurahMetadataRow>{
      for (final SurahMetadataRow row in metadataRows) row.id: row,
    };
    final masteredById = <String, MasteredSurahRow>{
      for (final MasteredSurahRow row in masteredRows) row.surahId: row,
    };
    final eventIds = events.map((event) => event.id).toSet();
    final coverageByEventId = <String, List<String>>{};
    for (final coverage in coverageRows) {
      if (!eventIds.contains(coverage.eventId)) continue;
      coverageByEventId
          .putIfAbsent(coverage.eventId, () => <String>[])
          .add(coverage.partId);
    }
    final partIdsBySchemeId = <String, List<String>>{};
    for (final part in partRows) {
      partIdsBySchemeId
          .putIfAbsent(part.schemeId, () => <String>[])
          .add(part.id);
    }

    final eventsBySurah = <String, List<RecitationEventRow>>{};
    final eventsByPrayer = <_PrayerKey, List<RecitationEventRow>>{};
    for (final event in events) {
      eventsBySurah
          .putIfAbsent(event.surahId, () => <RecitationEventRow>[])
          .add(event);
      final key = _PrayerKey(
        PrayerType.values.byName(event.prayerType),
        event.isQada,
      );
      eventsByPrayer.putIfAbsent(key, () => <RecitationEventRow>[]).add(event);
    }

    final bySurah =
        <SurahRecitationStat>[
          for (final entry in eventsBySurah.entries)
            SurahRecitationStat(
              surah: _descriptor(
                metadataById[entry.key],
                masteredById[entry.key],
              ),
              count: _fullEquivalentCount(
                entry.value,
                coverageByEventId,
                partIdsBySchemeId,
              ),
              actionCount: entry.value.length,
              lastUsedAtUtc: _latestEventTime(entry.value),
              byPrayer:
                  Map<PrayerContext, int>.unmodifiable(<PrayerContext, int>{
                    for (final prayer in _groupByPrayer(entry.value).entries)
                      PrayerContext(
                        prayerType: prayer.key.type,
                        isQada: prayer.key.isQada,
                      ): _fullEquivalentCount(
                        prayer.value,
                        coverageByEventId,
                        partIdsBySchemeId,
                      ),
                  }),
              byPart: Map<String, int>.unmodifiable(
                _partCreditCounts(entry.value, coverageByEventId),
              ),
            ),
        ]..sort((SurahRecitationStat left, SurahRecitationStat right) {
          final countOrder = right.count.compareTo(left.count);
          return countOrder != 0
              ? countOrder
              : left.surah.surahNumber.compareTo(right.surah.surahNumber);
        });
    final byPrayer =
        <PrayerRecitationStat>[
          for (final entry in eventsByPrayer.entries)
            PrayerRecitationStat(
              context: PrayerContext(
                prayerType: entry.key.type,
                isQada: entry.key.isQada,
              ),
              count: _fullEquivalentCount(
                entry.value,
                coverageByEventId,
                partIdsBySchemeId,
              ),
              actionCount: entry.value.length,
            ),
        ]..sort((PrayerRecitationStat left, PrayerRecitationStat right) {
          final typeOrder = left.context.prayerType.index.compareTo(
            right.context.prayerType.index,
          );
          return typeOrder != 0
              ? typeOrder
              : left.context.isQada.toString().compareTo(
                  right.context.isQada.toString(),
                );
        });
    return RecitationStats(
      total: _fullEquivalentCount(events, coverageByEventId, partIdsBySchemeId),
      actionCount: events.length,
      bySurah: List<SurahRecitationStat>.unmodifiable(bySurah),
      byPrayer: List<PrayerRecitationStat>.unmodifiable(byPrayer),
    );
  }

  Stream<RecitationStats> watchStats({PrayerType? prayerType, bool? isQada}) =>
      database
          .customSelect(
            'SELECT 1 AS recitation_stats_watch',
            readsFrom: <ResultSetImplementation<Table, Object?>>{
              database.recitationEvents,
              database.recitationEventParts,
              database.rotationParts,
              database.surahMetadata,
              database.masteredSurahs,
            },
          )
          .watch()
          .asyncMap(
            (List<QueryRow> _) =>
                getStats(prayerType: prayerType, isQada: isQada),
          );

  /// Last time each surah was recited within the one exact routine part
  /// matching [stableKey], scoped to [prayerType]/[isQada] so Qada history
  /// never blends with ordinary history for the same part.
  ///
  /// [stableKey] identifies a routine part slot across every session that
  /// ever used it (unlike [PrayerSessionPart.id], which is per-session), so
  /// this reflects "last read specifically as this Fard/Sunnah/etc. part",
  /// not just "last read for this prayer type".
  Future<Map<String, DateTime>> getLastUsedByRoutinePart({
    required PrayerType prayerType,
    required bool isQada,
    required String stableKey,
  }) async {
    final events =
        await (database.select(database.recitationEvents)
              ..where((RecitationEvents row) => row.deletedAtUtc.isNull())
              ..where(
                (RecitationEvents row) =>
                    row.prayerType.equals(prayerType.name),
              )
              ..where((RecitationEvents row) => row.isQada.equals(isQada))
              ..where(
                (RecitationEvents row) => row.prayerSessionPartId.isNotNull(),
              ))
            .get();
    if (events.isEmpty) return const <String, DateTime>{};
    final partIds = events
        .map((RecitationEventRow event) => event.prayerSessionPartId!)
        .toSet();
    final parts = await (database.select(
      database.prayerSessionParts,
    )..where((PrayerSessionParts row) => row.id.isIn(partIds))).get();
    final stableKeyByPartId = <String, String>{
      for (final part in parts) part.id: part.stableKey,
    };
    final result = <String, DateTime>{};
    for (final event in events) {
      if (stableKeyByPartId[event.prayerSessionPartId] != stableKey) continue;
      final createdAtUtc = event.createdAtUtc.toUtc();
      final existing = result[event.surahId];
      if (existing == null || createdAtUtc.isAfter(existing)) {
        result[event.surahId] = createdAtUtc;
      }
    }
    return Map<String, DateTime>.unmodifiable(result);
  }

  Stream<Map<String, DateTime>> watchLastUsedByRoutinePart({
    required PrayerType prayerType,
    required bool isQada,
    required String stableKey,
  }) => database
      .customSelect(
        'SELECT 1 AS recitation_routine_part_watch',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.recitationEvents,
          database.prayerSessionParts,
        },
      )
      .watch()
      .asyncMap(
        (List<QueryRow> _) => getLastUsedByRoutinePart(
          prayerType: prayerType,
          isQada: isQada,
          stableKey: stableKey,
        ),
      );

  Future<List<RecitationHistoryEntry>> _mapHistory(
    List<RecitationEventRow> rows,
  ) async {
    final metadataRows = await database.select(database.surahMetadata).get();
    final masteredRows = await database.select(database.masteredSurahs).get();
    final coverageRows = await database
        .select(database.recitationEventParts)
        .get();
    final partRows = await database.select(database.rotationParts).get();
    final metadataById = <String, SurahMetadataRow>{
      for (final SurahMetadataRow row in metadataRows) row.id: row,
    };
    final masteredById = <String, MasteredSurahRow>{
      for (final MasteredSurahRow row in masteredRows) row.surahId: row,
    };
    final coverageByEventId = <String, List<String>>{};
    for (final coverage in coverageRows) {
      coverageByEventId
          .putIfAbsent(coverage.eventId, () => <String>[])
          .add(coverage.partId);
    }
    final partById = <String, RotationPartRow>{
      for (final part in partRows) part.id: part,
    };
    for (final partIds in coverageByEventId.values) {
      partIds.sort(
        (left, right) => (partById[left]?.ordinal ?? 0).compareTo(
          partById[right]?.ordinal ?? 0,
        ),
      );
    }
    return <RecitationHistoryEntry>[
      for (final RecitationEventRow row in rows)
        RecitationHistoryEntry(
          event: _eventFromRow(row, coverageByEventId[row.id] ?? const []),
          surah: _descriptor(
            metadataById[row.surahId],
            masteredById[row.surahId],
          ),
          journalSequence: row.journalSequence,
          coveredParts:
              List<SurahRotationPart>.unmodifiable(<SurahRotationPart>[
                for (final partId
                    in coverageByEventId[row.id] ?? const <String>[])
                  if (partById[partId] case final part?)
                    SurahRotationPart(
                      id: part.id,
                      schemeId: part.schemeId,
                      partNumber: part.ordinal,
                      ayahRange: AyahRange(
                        startAyah: part.startAyah,
                        endAyah: part.endAyah,
                      ),
                      rotationScore: part.cachedScore,
                      recitationCount: part.cachedRecitationCount,
                      lastUsedAtUtc: part.cachedLastUsedAtUtc?.toUtc(),
                    ),
              ]),
          isWholeSurah:
              (coverageByEventId[row.id]?.length ?? 0) ==
              partRows
                  .where((part) => part.schemeId == row.rotationSchemeId)
                  .length,
          deletedAtUtc: row.deletedAtUtc?.toUtc(),
          stateChangedAtUtc: row.stateChangedAtUtc?.toUtc(),
        ),
    ];
  }

  SurahRecitationEvent _eventFromRow(
    RecitationEventRow row,
    Iterable<String> coveredPartIds,
  ) => SurahRecitationEvent(
    id: row.id,
    surahId: row.surahId,
    prayerSessionId: row.prayerSessionId,
    prayerSessionPartId: row.prayerSessionPartId,
    slotIndex: row.slotIndex,
    prayerContext: PrayerContext(
      prayerType: PrayerType.values.byName(row.prayerType),
      isQada: row.isQada,
    ),
    createdAtUtc: row.createdAtUtc.toUtc(),
    localDate: _parseLocalDate(row.localDate),
    rotationSchemeId: row.rotationSchemeId,
    coveredPartIds: coveredPartIds,
    rakaatSpanCount: row.rakaatSpanCount,
    qadaOriginIsUnknown: row.qadaOriginIsUnknown,
    qadaFulfilledLocalDate: row.qadaFulfilledLocalDate == null
        ? null
        : _parseLocalDate(row.qadaFulfilledLocalDate!),
  );

  SurahDescriptor _descriptor(
    SurahMetadataRow? metadata,
    MasteredSurahRow? mastered,
  ) {
    if (metadata == null) {
      throw StateError('A recitation references missing surah metadata.');
    }
    return SurahDescriptor(
      id: metadata.id,
      surahNumber: metadata.surahNumber,
      officialName: metadata.officialName,
      ayahCount: metadata.ayahCount,
      alias: mastered?.alias,
    );
  }

  Future<void> _ensureUnusedJournalId(String id) async {
    final recitation = await (database.select(
      database.recitationEvents,
    )..where((RecitationEvents row) => row.id.equals(id))).getSingleOrNull();
    final adjustment = await (database.select(
      database.rotationAdjustments,
    )..where((RotationAdjustments row) => row.id.equals(id))).getSingleOrNull();
    if (recitation != null || adjustment != null) {
      throw StateError('Rotation journal event "$id" already exists.');
    }
  }

  Future<PrayerSessionPartRow?> _validatePrayerSession(
    SurahRecitationEvent event,
  ) async {
    final sessionId = event.prayerSessionId;
    if (sessionId == null) {
      if (await _hasConfiguredRoutine(event)) {
        throw PrayerSessionSlotUnavailableException(
          PrayerSessionSlotUnavailableReason.exactSlotRequired,
          'This prayer has an active routine and requires an exact slot.',
        );
      }
      return null;
    }
    final session =
        await (database.select(database.prayerSessions)
              ..where((PrayerSessions row) => row.id.equals(sessionId)))
            .getSingleOrNull();
    if (session == null) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.missingSession,
        'Prayer session "$sessionId" does not exist.',
      );
    }
    if (session.prayerType != event.prayerType.name ||
        session.isQada != event.isQada) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.contextMismatch,
        'Recitation context does not match prayer session "$sessionId".',
      );
    }
    if (session.localDate != null &&
        session.localDate != event.localDate.toString()) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.dateMismatch,
        'Recitation date does not match prayer session "$sessionId".',
      );
    }

    final sessionParts =
        await (database.select(database.prayerSessionParts)
              ..where(
                (PrayerSessionParts row) =>
                    row.prayerSessionId.equals(sessionId),
              )
              ..orderBy(<OrderingTerm Function(PrayerSessionParts)>[
                (PrayerSessionParts row) => OrderingTerm.asc(row.orderIndex),
              ]))
            .get();
    if (sessionParts.isEmpty) {
      if (await _hasConfiguredRoutine(event)) {
        throw PrayerSessionSlotUnavailableException(
          PrayerSessionSlotUnavailableReason.exactSlotRequired,
          'This prayer has an active routine and requires an exact slot.',
        );
      }
      return null;
    }

    final partId = event.prayerSessionPartId;
    final slotIndex = event.slotIndex;
    if (partId == null || slotIndex == null) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.exactSlotRequired,
        'A routine recitation requires a session part and slot.',
      );
    }
    final part =
        await (database.select(database.prayerSessionParts)
              ..where((PrayerSessionParts row) => row.id.equals(partId)))
            .getSingleOrNull();
    if (part == null) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.missingPart,
        'Prayer session part "$partId" does not exist.',
      );
    }
    if (part.prayerSessionId != sessionId) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.foreignPart,
        'Prayer session part "$partId" does not belong to "$sessionId".',
      );
    }
    PrayerSessionPartRow? currentPart;
    for (final candidate in sessionParts) {
      if (candidate.completedAtUtc == null) {
        currentPart = candidate;
        break;
      }
    }
    if (currentPart == null) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.completedPart,
        'Prayer session "$sessionId" is already complete.',
      );
    }
    if (currentPart.id != partId) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.nonCurrentPart,
        'Prayer session part "$partId" is not the current part.',
      );
    }
    if (part.completedAtUtc != null) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.completedPart,
        'Prayer session part "$partId" is already completed.',
      );
    }
    // Re-checked here, not only when the snapshot was built: a legacy session
    // or a forged widget/deep-link payload must not create new Qada history on
    // a voluntary part.
    if (!PrayerQadaPolicy.allowsPart(
      prayerType: event.prayerType,
      isQada: event.isQada,
      kind: PrayerRoutinePartKind.values.byName(part.kind),
    )) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.qadaPartNotEligible,
        'Prayer session part "$partId" cannot carry Qada for '
        '${event.prayerType.name}.',
      );
    }

    if (slotIndex >= part.requiredSurahSlots) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.slotOutOfRange,
        'Slot $slotIndex is outside prayer session part "$partId".',
      );
    }
    final occupiedEvents =
        await (database.select(database.recitationEvents)..where(
              (RecitationEvents row) =>
                  row.prayerSessionPartId.equals(partId) &
                  row.slotIndex.isNotNull() &
                  row.deletedAtUtc.isNull(),
            ))
            .get();
    final occupiedSlots = <int>{
      for (final occupied in occupiedEvents) occupied.slotIndex!,
    };
    if (occupiedSlots.contains(slotIndex)) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.occupiedSlot,
        'Slot $slotIndex in prayer session part "$partId" is occupied.',
      );
    }
    int? nextSlotIndex;
    for (var index = 0; index < part.requiredSurahSlots; index += 1) {
      if (!occupiedSlots.contains(index)) {
        nextSlotIndex = index;
        break;
      }
    }
    if (slotIndex != nextSlotIndex) {
      throw PrayerSessionSlotUnavailableException(
        PrayerSessionSlotUnavailableReason.slotNotNext,
        'Slot $slotIndex is not the next slot in prayer session part "$partId".',
      );
    }
    return part;
  }

  Future<bool> _hasConfiguredRoutine(SurahRecitationEvent event) async {
    final sessions =
        await (database.select(database.prayerSessions)..where(
              (PrayerSessions row) =>
                  row.prayerType.equals(event.prayerType.name) &
                  row.isQada.equals(event.isQada) &
                  row.localDate.equals(event.localDate.toString()),
            ))
            .get();
    for (final session in sessions) {
      final part =
          await (database.select(database.prayerSessionParts)
                ..where(
                  (PrayerSessionParts row) =>
                      row.prayerSessionId.equals(session.id),
                )
                ..limit(1))
              .getSingleOrNull();
      if (part != null) return true;
    }

    final template =
        await (database.select(database.prayerRoutineTemplates)..where(
              (PrayerRoutineTemplates row) =>
                  row.prayerType.equals(event.prayerType.name) &
                  row.enabled.equals(true),
            ))
            .getSingleOrNull();
    if (template == null) return false;
    final templatePart =
        await (database.select(database.prayerRoutinePartTemplates)
              ..where(
                (PrayerRoutinePartTemplates row) =>
                    row.routineTemplateId.equals(template.id),
              )
              ..limit(1))
            .getSingleOrNull();
    return templatePart != null;
  }

  /// Delegates to [PrayerSessionCompletion], which the sync applier also uses.
  ///
  /// It used to live here, and that was the defect: the phone that *received*
  /// a recitation had no way to reach it, so a slot filled from the account
  /// never finished the prayer it belonged to.
  Future<void> _reconcileRecitationCompletion(String partId) =>
      PrayerSessionCompletion.reconcile(database, partId);
}

SurahRecitationEvent _atDatabasePrecision(SurahRecitationEvent event) {
  final createdAtUtc = DateTime.fromMillisecondsSinceEpoch(
    (event.createdAtUtc.millisecondsSinceEpoch ~/ 1000) * 1000,
    isUtc: true,
  );
  if (createdAtUtc == event.createdAtUtc) {
    return event;
  }
  return SurahRecitationEvent(
    id: event.id,
    surahId: event.surahId,
    prayerContext: event.prayerContext,
    createdAtUtc: createdAtUtc,
    localDate: event.localDate,
    prayerSessionId: event.prayerSessionId,
    prayerSessionPartId: event.prayerSessionPartId,
    slotIndex: event.slotIndex,
    coverage: event.coverage,
    rakaatSpanCount: event.rakaatSpanCount,
    qadaOriginIsUnknown: event.qadaOriginIsUnknown,
    qadaFulfilledLocalDate: event.qadaFulfilledLocalDate,
  );
}

int _fullEquivalentCount(
  Iterable<RecitationEventRow> events,
  Map<String, List<String>> coverageByEventId,
  Map<String, List<String>> partIdsBySchemeId,
) {
  final creditsByScheme = <String, Map<String, int>>{};
  for (final event in events) {
    final credits = creditsByScheme.putIfAbsent(
      event.rotationSchemeId,
      () => <String, int>{
        for (final partId
            in partIdsBySchemeId[event.rotationSchemeId] ?? const <String>[])
          partId: 0,
      },
    );
    for (final partId in coverageByEventId[event.id] ?? const <String>[]) {
      if (!credits.containsKey(partId)) {
        throw StateError('Recitation "${event.id}" references a foreign part.');
      }
      credits[partId] = credits[partId]! + 1;
    }
  }
  var result = 0;
  for (final credits in creditsByScheme.values) {
    if (credits.isEmpty) {
      throw StateError('A recitation references a scheme without parts.');
    }
    result += credits.values.reduce(
      (int left, int right) => left < right ? left : right,
    );
  }
  return result;
}

Map<_PrayerKey, List<RecitationEventRow>> _groupByPrayer(
  Iterable<RecitationEventRow> events,
) {
  final result = <_PrayerKey, List<RecitationEventRow>>{};
  for (final event in events) {
    final key = _PrayerKey(
      PrayerType.values.byName(event.prayerType),
      event.isQada,
    );
    result.putIfAbsent(key, () => <RecitationEventRow>[]).add(event);
  }
  return result;
}

Map<String, int> _partCreditCounts(
  Iterable<RecitationEventRow> events,
  Map<String, List<String>> coverageByEventId,
) {
  final result = <String, int>{};
  for (final event in events) {
    for (final partId in coverageByEventId[event.id] ?? const <String>[]) {
      result.update(partId, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return result;
}

DateTime? _latestEventTime(Iterable<RecitationEventRow> events) {
  DateTime? latest;
  for (final event in events) {
    final value = event.createdAtUtc.toUtc();
    if (latest == null || value.isAfter(latest)) latest = value;
  }
  return latest;
}

final class _PrayerKey {
  const _PrayerKey(this.type, this.isQada);

  final PrayerType type;
  final bool isQada;

  @override
  bool operator ==(Object other) =>
      other is _PrayerKey && type == other.type && isQada == other.isQada;

  @override
  int get hashCode => Object.hash(type, isQada);
}

LocalDate _parseLocalDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw StateError('Invalid stored local date "$value".');
  }
  return LocalDate(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'Must be UTC.');
  }
}
