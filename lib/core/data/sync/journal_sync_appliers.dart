/// Writes pulled journal entries — rotation adjustments and recall attempts —
/// into this device.
///
/// Both are append-only and both carry a local sequence number that does not
/// travel, so both take the next one here. An adjustment additionally feeds the
/// rotation balance, so applying one rebuilds the projection; a recall attempt
/// feeds nothing but itself.
library;

import 'package:drift/drift.dart';

import '../../sync/journal_sync_payloads.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import '../repositories/rotation_projection_store.dart';

final class RotationAdjustmentSyncApplier {
  RotationAdjustmentSyncApplier(
    this._database, {
    this.rebuildsProjection = true,
  }) : _projection = RotationProjectionStore(_database);

  final AppDatabase _database;
  final RotationProjectionStore _projection;

  /// Whether this applier rebuilds the rotation projection itself. See
  /// [RecitationSyncApplier.rebuildsProjection] — the router batches a page.
  final bool rebuildsProjection;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == RotationAdjustmentSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not an adjustment envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      await _withdraw(envelope);
      return;
    }

    final record = RotationAdjustmentSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    await _requireScheme(record.surahId, record.rotationSchemeId);

    final existing = await _rowOf(record.id);
    if (existing == null) {
      // From the shared journal counter, never from this table's own maximum.
      // Recitations and adjustments are sorted together when the projection is
      // rebuilt, so an adjustment numbered one on a device holding a thousand
      // recitations would sort ahead of every one of them and subtract from a
      // score nothing had raised.
      final next = await _projection.takeJournalSequence();
      await _database
          .into(_database.rotationAdjustments)
          .insert(
            RotationAdjustmentsCompanion.insert(
              id: record.id,
              journalSequence: next,
              surahId: record.surahId,
              rotationSchemeId: record.rotationSchemeId,
              delta: record.delta,
              reason: record.reason,
              createdAtUtc: record.createdAtUtc,
            ),
          );
    } else {
      await (_database.update(
        _database.rotationAdjustments,
      )..where((RotationAdjustments row) => row.id.equals(record.id))).write(
        RotationAdjustmentsCompanion(
          delta: Value<int>(record.delta),
          reason: Value<String>(record.reason),
          createdAtUtc: Value<DateTime>(record.createdAtUtc),
          // An upsert after a withdrawal brings it back, exactly as it does
          // for a recitation: the server already decided it beat the tombstone.
          deletedAtUtc: const Value<DateTime?>(null),
        ),
      );
    }
    await _rebuild();
  }

  Future<void> _withdraw(SyncEnvelope envelope) async {
    final existing = await _rowOf(envelope.entityId);
    if (existing == null || existing.deletedAtUtc != null) return;
    await (_database.update(
          _database.rotationAdjustments,
        )..where((RotationAdjustments row) => row.id.equals(envelope.entityId)))
        .write(
          RotationAdjustmentsCompanion(
            deletedAtUtc: Value<DateTime?>(envelope.updatedAtUtc),
          ),
        );
    await _rebuild();
  }

  Future<void> _requireScheme(String surahId, String schemeId) async {
    final scheme =
        await (_database.select(_database.rotationSchemes)..where(
              (RotationSchemes row) =>
                  row.id.equals(schemeId) & row.surahId.equals(surahId),
            ))
            .getSingleOrNull();
    if (scheme == null) {
      // The compound foreign key would refuse the write anyway; retryable
      // because the scheme is itself an entity that syncs.
      throw const SyncTransportException('remote-adjustment-scheme-missing');
    }
  }

  Future<void> _rebuild() async {
    if (!rebuildsProjection) return;
    final state = await _projection.loadSnapshot();
    await _projection.rebuildFromJournal(targetFloor: state.rotationTarget);
  }

  Future<RotationAdjustmentRow?> _rowOf(String id) => (_database.select(
    _database.rotationAdjustments,
  )..where((RotationAdjustments row) => row.id.equals(id))).getSingleOrNull();
}

final class RecallAttemptSyncApplier {
  const RecallAttemptSyncApplier(this._database);

  final AppDatabase _database;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == RecallAttemptSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a recall envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      // A recall attempt has no withdrawal in the app: nothing deletes one, so
      // there is no local operation a tombstone could mean. Refusing is louder
      // than inventing a delete for a table that has no `deleted_at_utc`.
      throw const SyncTransportException('remote-recall-cannot-be-deleted');
    }

    final record = RecallAttemptSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    final surah =
        await (_database.select(_database.surahMetadata)
              ..where((SurahMetadata row) => row.id.equals(record.surahId)))
            .getSingleOrNull();
    if (surah == null) {
      // The corpus arrives by manifest, not by sync — a device still setting
      // itself up rather than a broken payload.
      throw const SyncTransportException('remote-recall-surah-not-in-catalog');
    }

    final existing =
        await (_database.select(_database.recallAttempts)
              ..where((RecallAttempts row) => row.id.equals(record.id)))
            .getSingleOrNull();
    if (existing != null) {
      // Append-only in practice: nothing edits an attempt after the fact, so a
      // repeat is a replay and there is nothing to change.
      return;
    }
    await _database
        .into(_database.recallAttempts)
        .insert(
          RecallAttemptsCompanion.insert(
            id: record.id,
            surahId: record.surahId,
            ayahStart: record.ayahStart,
            ayahEnd: record.ayahEnd,
            learningCycle: Value<int>(record.learningCycle),
            result: record.result,
            createdAtUtc: record.createdAtUtc,
            localDate: record.localDate,
            source: record.source,
          ),
        );
  }
}
