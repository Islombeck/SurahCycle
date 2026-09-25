/// Writes a pulled recitation into this device's database.
///
/// The other half of `RecitationSyncPayload`: that turns a recitation into an
/// envelope and back, this puts the result where it belongs. It is the `apply`
/// callback `DriftSyncStore.applyPulledPage` expects, so everything here runs
/// inside the transaction that also advances the pull cursor — a page that
/// fails to apply leaves the cursor where it was and is fetched again, rather
/// than being skipped and lost.
///
/// **It does not decide conflicts; the router does.** That is a correction:
/// this used to say the *server* had already chosen the winner, and the server
/// chooses nothing — TablesDB upserts what it is handed. Since 2026-09-22 the
/// rule runs on the device, once, in `SyncEnvelopeRouter`, so this still writes
/// what it is given and there is still exactly one resolver.
///
/// A recitation is append-only, so the router does not compare it at all: two
/// devices can produce different prayers, not two versions of the same one.
/// What they *can* both touch is whether it stands, and that is the withdrawal
/// rule below rather than a comparison of the record.
///
/// That one comparison is `RecitationStateVersion`, over the state stamp v11
/// added, and it is the same rule the local withdrawal and restore paths write
/// with. Arrival order cannot serve here: the account's log is ordered by when
/// a change reached it, so a withdrawal made offline on Monday arrives after a
/// restore made on Tuesday and would undo it.
library;

import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../../sync/recitation_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import '../repositories/rotation_projection_store.dart';
import 'recitation_state_version.dart';
import 'sync_entity_aliases.dart';
import 'sync_withdrawal_marks.dart';

final class RecitationSyncApplier {
  RecitationSyncApplier(this._database, {this.rebuildsProjection = true})
    : _projection = RotationProjectionStore(_database);

  final AppDatabase _database;
  final RotationProjectionStore _projection;

  /// Whether this applier rebuilds the rotation projection itself.
  ///
  /// True by default, because an applier used on its own has to leave the
  /// device consistent. `SyncEnvelopeRouter` sets it false and rebuilds once
  /// for a whole page: the rebuild reads the entire journal, so doing it per
  /// envelope is quadratic — applying a real history of nine hundred records
  /// took seventeen seconds before this, all of it inside transactions where
  /// the app would simply appear to have stopped.
  final bool rebuildsProjection;

  /// Whether this applier handles [envelope].
  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == RecitationSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a recitation envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      await _applyTombstone(envelope);
      return;
    }
    await _applyUpsert(envelope);
  }

  Future<void> _applyTombstone(SyncEnvelope envelope) async {
    final existing = await _rowOf(envelope.entityId);
    if (existing == null) {
      // A deletion for something this device never had. Nothing to withdraw,
      // and inventing a row so it can be marked deleted would put a prayer in
      // the journal that never happened here — but it is remembered, so a copy
      // of that record arriving out of order cannot bring the prayer back.
      await SyncWithdrawalMarks.record(_database, envelope: envelope);
      return;
    }
    if (!RecitationStateVersion.incomingWins(
      incomingAtUtc: envelope.updatedAtUtc,
      localAtUtc: existing.stateChangedAtUtc,
      incomingWithdraws: true,
    )) {
      // He brought this prayer back after the withdrawal that is arriving now.
      // Obeying it would undo the newer decision, which is the defect ADR-0002
      // carried as "a withdrawal made offline can beat a newer restore".
      return;
    }
    if (existing.deletedAtUtc != null) {
      // Already withdrawn here; only the version moves, so nothing rebuilds.
      await _stampStateVersion(envelope.entityId, envelope.updatedAtUtc);
      return;
    }
    await (_database.update(
      _database.recitationEvents,
    )..where((RecitationEvents row) => row.id.equals(envelope.entityId))).write(
      RecitationEventsCompanion(
        deletedAtUtc: Value<DateTime?>(envelope.updatedAtUtc),
        stateChangedAtUtc: Value<DateTime?>(envelope.updatedAtUtc),
      ),
    );
    // A withdrawal lowers the surah's standing exactly as writing it raised it,
    // and this did not rebuild. The score stayed where the recitation had put
    // it until something unrelated happened to rebuild, so a recitation undone
    // on another phone went on counting here.
    await _rebuild();
  }

  Future<void> _applyUpsert(SyncEnvelope envelope) async {
    final event = RecitationSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    final sentSchemeId = event.coverage?.rotationSchemeId;
    if (sentSchemeId == null) {
      // The local table requires one, so a recitation without coverage cannot
      // be stored at all. Refusing keeps it on the server to be fetched again
      // rather than dropping a prayer.
      throw const SyncTransportException('remote-recitation-has-no-coverage');
    }
    // The sending device names the ids *it* knows. Where this one recognised
    // an arriving scheme as the split it already held under another name, the
    // two sets of ids differ and every record naming the arriving ones would
    // otherwise be refused for a scheme that does not exist here.
    final aliases = SyncAliasMap(_database);
    final schemeId = await aliases.resolve(
      sentSchemeId,
      SyncAliasKind.rotationScheme,
    );
    final coveredPartIds = await aliases.resolveAll(
      event.coveredPartIds,
      SyncAliasKind.rotationPart,
    );
    await _requirePrerequisites(event.surahId, schemeId);
    await _requirePrayerSession(event);

    final existing = await _rowOf(event.id);
    if (existing == null) {
      await _insert(event, schemeId, envelope.updatedAtUtc);
      await _applyAnyWithdrawalMark(event.id, envelope.updatedAtUtc);
    } else {
      await _update(event, existing, envelope.updatedAtUtc);
    }
    await _replaceCoverage(event, schemeId, coveredPartIds);
    await _rebuild();
  }

  /// Withdraws a record that arrived after the withdrawal that removed it.
  ///
  /// The account's log is ordered by when each change reached it, not by when
  /// it happened, and a record recovered from quarantine reaches it late. So a
  /// prayer can arrive *after* its own withdrawal. The mark left by that
  /// withdrawal is applied here, and only if it is the newer of the two.
  Future<void> _applyAnyWithdrawalMark(
    String entityId,
    DateTime arrivedAtUtc,
  ) async {
    final entityKey = '${SyncEntityType.recitationEvent.name}:$entityId';
    final withdrawnAt = await SyncWithdrawalMarks.withdrawnAt(
      _database,
      entityKey: entityKey,
    );
    if (withdrawnAt != null &&
        RecitationStateVersion.incomingWins(
          incomingAtUtc: withdrawnAt,
          localAtUtc: arrivedAtUtc,
          incomingWithdraws: true,
        )) {
      await (_database.update(
        _database.recitationEvents,
      )..where((RecitationEvents row) => row.id.equals(entityId))).write(
        RecitationEventsCompanion(
          deletedAtUtc: Value<DateTime?>(withdrawnAt),
          stateChangedAtUtc: Value<DateTime?>(withdrawnAt),
        ),
      );
    }
    await SyncWithdrawalMarks.clear(_database, entityKey: entityKey);
  }

  Future<void> _stampStateVersion(String id, DateTime atUtc) =>
      (_database.update(
        _database.recitationEvents,
      )..where((RecitationEvents row) => row.id.equals(id))).write(
        RecitationEventsCompanion(stateChangedAtUtc: Value<DateTime?>(atUtc)),
      );

  /// Rebuilt from the journal rather than adjusted by hand, for the same reason
  /// a restore rebuilds: a second implementation of the rotation rules is free
  /// to disagree with the first.
  Future<void> _rebuild() async {
    if (!rebuildsProjection) return;
    final state = await _projection.loadSnapshot();
    await _projection.rebuildFromJournal(targetFloor: state.rotationTarget);
  }

  /// Refuses a recitation whose surah or scheme this device does not have.
  ///
  /// The local schema enforces both as foreign keys, so the write would fail
  /// anyway — this only makes the reason legible. It is **retryable**, and
  /// deliberately: the missing roster entry or scheme is itself an entity that
  /// syncs, so the ordinary case is that it arrives and the page then applies.
  ///
  /// The cost of being wrong is asymmetric, which is what decides it. A stalled
  /// pull is loud and reports itself; dropping the recitation instead would
  /// lose a prayer silently and permanently, with the cursor moved past it.
  Future<void> _requirePrerequisites(String surahId, String schemeId) async {
    final surah =
        await (_database.select(_database.masteredSurahs)
              ..where((MasteredSurahs row) => row.surahId.equals(surahId)))
            .getSingleOrNull();
    if (surah == null) {
      throw const SyncTransportException('remote-recitation-surah-missing');
    }
    final scheme =
        await (_database.select(_database.rotationSchemes)..where(
              (RotationSchemes row) =>
                  row.id.equals(schemeId) & row.surahId.equals(surahId),
            ))
            .getSingleOrNull();
    if (scheme == null) {
      throw const SyncTransportException('remote-recitation-scheme-missing');
    }
  }

  /// Refuses a recitation whose prayer session or session part is not here yet.
  ///
  /// Both are foreign keys, so the insert would fail regardless — with an
  /// opaque database error rather than a reason anyone can act on. Nulling them
  /// instead was the tempting alternative and is worse: it would silently drop
  /// the link between a prayer and which part of it the surah filled, which is
  /// the whole basis of the routine's "slots for surahs" and of the calendar.
  ///
  /// Retryable, like the roster: a prayer session is itself an entity that
  /// syncs.
  Future<void> _requirePrayerSession(SurahRecitationEvent event) async {
    if (event.prayerSessionId case final sessionId?) {
      final session =
          await (_database.select(_database.prayerSessions)
                ..where((PrayerSessions row) => row.id.equals(sessionId)))
              .getSingleOrNull();
      if (session == null) {
        throw const SyncTransportException('remote-recitation-session-missing');
      }
    }
    if (event.prayerSessionPartId case final partId?) {
      final part =
          await (_database.select(_database.prayerSessionParts)
                ..where((PrayerSessionParts row) => row.id.equals(partId)))
              .getSingleOrNull();
      if (part == null) {
        throw const SyncTransportException(
          'remote-recitation-session-part-missing',
        );
      }
    }
  }

  Future<void> _insert(
    SurahRecitationEvent event,
    String schemeId,
    DateTime stateChangedAtUtc,
  ) async {
    // A journal sequence is this device's own ordering and is never carried
    // across: two devices number their journals independently, and importing a
    // number would collide with one already used here.
    //
    // Taken from the **shared** counter, which recitations and adjustments both
    // draw from, because the projection rebuild sorts the two together into one
    // history. Two independent per-table counters put a correction before the
    // recitations it corrects.
    final next = await _projection.takeJournalSequence();
    await _database
        .into(_database.recitationEvents)
        .insert(
          RecitationEventsCompanion.insert(
            id: event.id,
            journalSequence: next,
            surahId: event.surahId,
            rotationSchemeId: schemeId,
            rakaatSpanCount: event.rakaatSpanCount,
            prayerSessionId: Value<String?>(event.prayerSessionId),
            prayerSessionPartId: Value<String?>(event.prayerSessionPartId),
            slotIndex: Value<int?>(event.slotIndex),
            createdAtUtc: event.createdAtUtc,
            localDate: event.localDate.toString(),
            prayerType: event.prayerType.name,
            isQada: Value<bool>(event.isQada),
            qadaOriginIsUnknown: Value<bool>(event.qadaOriginIsUnknown),
            qadaFulfilledLocalDate: Value<String?>(
              event.qadaFulfilledLocalDate?.toString(),
            ),
            stateChangedAtUtc: Value<DateTime?>(stateChangedAtUtc),
          ),
        );
  }

  Future<void> _update(
    SurahRecitationEvent event,
    RecitationEventRow existing,
    DateTime incomingAtUtc,
  ) async {
    // An upsert that arrives for a row withdrawn here is a restore made on
    // another device — but only if it is the newer of the two decisions. The
    // fields below are the same record either way and are written regardless;
    // whether the prayer *stands* is the one thing that has to be settled.
    final revives = RecitationStateVersion.incomingWins(
      incomingAtUtc: incomingAtUtc,
      localAtUtc: existing.stateChangedAtUtc,
      incomingWithdraws: false,
    );
    await (_database.update(
      _database.recitationEvents,
    )..where((RecitationEvents row) => row.id.equals(event.id))).write(
      RecitationEventsCompanion(
        rakaatSpanCount: Value<int>(event.rakaatSpanCount),
        prayerSessionId: Value<String?>(event.prayerSessionId),
        prayerSessionPartId: Value<String?>(event.prayerSessionPartId),
        slotIndex: Value<int?>(event.slotIndex),
        createdAtUtc: Value<DateTime>(event.createdAtUtc),
        localDate: Value<String>(event.localDate.toString()),
        prayerType: Value<String>(event.prayerType.name),
        isQada: Value<bool>(event.isQada),
        qadaOriginIsUnknown: Value<bool>(event.qadaOriginIsUnknown),
        qadaFulfilledLocalDate: Value<String?>(
          event.qadaFulfilledLocalDate?.toString(),
        ),
        deletedAtUtc: revives
            ? const Value<DateTime?>(null)
            : const Value<DateTime?>.absent(),
        stateChangedAtUtc: revives
            ? Value<DateTime?>(incomingAtUtc)
            : const Value<DateTime?>.absent(),
      ),
    );
  }

  Future<void> _replaceCoverage(
    SurahRecitationEvent event,
    String schemeId,
    List<String> coveredPartIds,
  ) async {
    await (_database.delete(
      _database.recitationEventParts,
    )..where((RecitationEventParts row) => row.eventId.equals(event.id))).go();
    for (final partId in coveredPartIds) {
      await _database
          .into(_database.recitationEventParts)
          .insert(
            RecitationEventPartsCompanion.insert(
              eventId: event.id,
              schemeId: schemeId,
              partId: partId,
            ),
          );
    }
  }

  Future<RecitationEventRow?> _rowOf(String id) => (_database.select(
    _database.recitationEvents,
  )..where((RecitationEvents row) => row.id.equals(id))).getSingleOrNull();
}
