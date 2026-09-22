/// Writes a pulled rotation scheme into this device's database.
///
/// Two local invariants have to survive every application, and neither is
/// optional:
///
/// - **exactly one scheme per surah is in force.** A partial unique index
///   enforces it, and the projection reads it with `getSingle()`, so leaving a
///   surah with none crashes the screen rather than degrading it;
/// - **a part that some recitation covered cannot be removed.** The schema says
///   so with `ON DELETE RESTRICT`, and it is right to: dropping it would orphan
///   the coverage the rotation balance is built from.
///
/// The journal sequences are not read from the payload because they are not in
/// it. `activated_journal_sequence` is set to zero for an arriving scheme — the
/// column is written and never read anywhere, so zero is as meaningful as any
/// other number and is at least honest about having no local provenance.
library;

import 'package:drift/drift.dart';

import '../../sync/rotation_scheme_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import '../repositories/rotation_projection_store.dart';
import 'sync_versioned_rows.dart';

final class RotationSchemeSyncApplier {
  RotationSchemeSyncApplier(this._database, {this.rebuildsProjection = true})
    : _projection = RotationProjectionStore(_database);

  final AppDatabase _database;
  final RotationProjectionStore _projection;

  /// Whether this applier rebuilds the rotation projection itself. See
  /// [RecitationSyncApplier.rebuildsProjection] — the router batches a page.
  final bool rebuildsProjection;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == RotationSchemeSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a scheme envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      // A scheme is never deleted, only superseded — recitations reference it
      // and the schema refuses. The owner "removing" a split means choosing a
      // different one, which arrives as that scheme becoming active.
      throw const SyncTransportException('remote-scheme-cannot-be-deleted');
    }

    final record = RotationSchemeSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    await _requireRoster(record.surahId);
    await _writeScheme(record);
    await _writeParts(record);
    await _settleWhichIsActive(record);
    await SyncVersionedRows(_database).stampAuthored(
      table: 'rotation_schemes',
      key: record.id,
      authoredAtUtc: envelope.updatedAtUtc,
    );

    if (!rebuildsProjection) return;
    final state = await _projection.loadSnapshot();
    await _projection.rebuildFromJournal(targetFloor: state.rotationTarget);
  }

  Future<void> _requireRoster(String surahId) async {
    final roster =
        await (_database.select(_database.masteredSurahs)
              ..where((MasteredSurahs row) => row.surahId.equals(surahId)))
            .getSingleOrNull();
    if (roster == null) {
      // Retryable: the roster entry is itself an entity that syncs, and a
      // scheme without one cannot be written because the schema forbids it.
      throw const SyncTransportException('remote-scheme-surah-not-in-roster');
    }
  }

  /// Clears a row holding this scheme's `(surahId, version)` under another id.
  ///
  /// A device that has just taken a roster entry has a locally derived default
  /// scheme, named `<surahId>:scheme:1` the way this build names one. The
  /// owner's real scheme may carry an id an **older** build wrote — his are
  /// `v1:<surahId>:scheme:1` — and the unique index on `(surah_id, version)`
  /// refuses the second of the two. Found against his real database, where all
  /// twenty-eight of his schemes collided and none of them arrived.
  ///
  /// The incoming record wins: the account is the shared truth and the local
  /// row is a placeholder this device invented a moment ago. His recitations
  /// carry the real id too, so the placeholder cannot simply be kept under its
  /// own name — nothing would find it.
  ///
  /// Removing it is refused when something actually references it, and that
  /// refusal is correct rather than inconvenient: a referenced row is no longer
  /// a placeholder but a second *real* scheme for the same version, and quietly
  /// dropping one of two real ones is exactly the loss this feature exists to
  /// prevent.
  Future<void> _clearColliding(RotationSchemeSyncRecord record) async {
    final clash =
        await (_database.select(_database.rotationSchemes)..where(
              (RotationSchemes row) =>
                  row.surahId.equals(record.surahId) &
                  row.version.equals(record.version) &
                  row.id.equals(record.id).not(),
            ))
            .getSingleOrNull();
    if (clash == null) return;

    final recitations =
        await (_database.select(_database.recitationEvents)..where(
              (RecitationEvents row) => row.rotationSchemeId.equals(clash.id),
            ))
            .get();
    final adjustments =
        await (_database.select(_database.rotationAdjustments)..where(
              (RotationAdjustments row) =>
                  row.rotationSchemeId.equals(clash.id),
            ))
            .get();
    if (recitations.isNotEmpty || adjustments.isNotEmpty) {
      throw const SyncTransportException('remote-scheme-version-already-used');
    }

    await (_database.delete(
      _database.rotationSchemes,
    )..where((RotationSchemes row) => row.id.equals(clash.id))).go();
  }

  Future<void> _writeScheme(RotationSchemeSyncRecord record) async {
    final existing =
        await (_database.select(_database.rotationSchemes)
              ..where((RotationSchemes row) => row.id.equals(record.id)))
            .getSingleOrNull();
    if (existing == null) {
      await _clearColliding(record);
      await _database
          .into(_database.rotationSchemes)
          .insert(
            RotationSchemesCompanion.insert(
              id: record.id,
              surahId: record.surahId,
              version: record.version,
              ayahCountSnapshot: record.ayahCountSnapshot,
              baselineScore: record.baselineScore,
              baselineTotalRecitations: record.baselineTotalRecitations,
              baselineLastUsedAtUtc: Value<DateTime?>(
                record.baselineLastUsedAtUtc,
              ),
              resetsRotationBaseline: Value<bool>(
                record.resetsRotationBaseline,
              ),
              activatedJournalSequence: 0,
              // Superseded for now; [_settleWhichIsActive] decides. Inserting
              // it as active first could collide with the scheme currently in
              // force before that one has been stood down.
              supersededJournalSequence: const Value<int?>(0),
            ),
          );
      return;
    }
    await (_database.update(
      _database.rotationSchemes,
    )..where((RotationSchemes row) => row.id.equals(record.id))).write(
      RotationSchemesCompanion(
        version: Value<int>(record.version),
        ayahCountSnapshot: Value<int>(record.ayahCountSnapshot),
        baselineScore: Value<int>(record.baselineScore),
        baselineTotalRecitations: Value<int>(record.baselineTotalRecitations),
        baselineLastUsedAtUtc: Value<DateTime?>(record.baselineLastUsedAtUtc),
        resetsRotationBaseline: Value<bool>(record.resetsRotationBaseline),
      ),
    );
  }

  Future<void> _writeParts(RotationSchemeSyncRecord record) async {
    final incoming = <String, RotationSchemeSyncPart>{
      for (final part in record.parts) part.id: part,
    };
    final local = await (_database.select(
      _database.rotationParts,
    )..where((RotationParts row) => row.schemeId.equals(record.id))).get();

    for (final row in local) {
      if (incoming.containsKey(row.id)) continue;
      final covered = await (_database.select(
        _database.recitationEventParts,
      )..where((RecitationEventParts r) => r.partId.equals(row.id))).get();
      if (covered.isNotEmpty) {
        // Should not happen: re-splitting a surah creates a *new* scheme
        // version rather than editing this one's parts. If it does, refusing is
        // the only safe answer — removing the part would orphan the coverage
        // the rotation balance is built from.
        throw const SyncTransportException(
          'remote-scheme-drops-a-covered-part',
        );
      }
      await (_database.delete(
        _database.rotationParts,
      )..where((RotationParts r) => r.id.equals(row.id))).go();
    }

    for (final part in record.parts) {
      await _database
          .into(_database.rotationParts)
          .insertOnConflictUpdate(
            RotationPartsCompanion.insert(
              id: part.id,
              schemeId: record.id,
              ordinal: part.ordinal,
              startAyah: part.startAyah,
              endAyah: part.endAyah,
              // Left at zero; the journal rebuild owns these.
              cachedScore: 0,
              cachedRecitationCount: 0,
            ),
          );
    }
  }

  Future<void> _settleWhichIsActive(RotationSchemeSyncRecord record) async {
    if (record.isActive) {
      // Stand the others down first: the unique index allows only one active
      // scheme per surah, so activating before superseding would collide.
      await (_database.update(_database.rotationSchemes)..where(
            (RotationSchemes row) =>
                row.surahId.equals(record.surahId) &
                row.id.equals(record.id).not() &
                row.supersededJournalSequence.isNull(),
          ))
          .write(
            const RotationSchemesCompanion(
              supersededJournalSequence: Value<int?>(0),
            ),
          );
      await (_database.update(
        _database.rotationSchemes,
      )..where((RotationSchemes row) => row.id.equals(record.id))).write(
        const RotationSchemesCompanion(
          supersededJournalSequence: Value<int?>(null),
        ),
      );
      return;
    }

    // Standing this one down would leave the surah with no scheme in force, and
    // the projection reads that with `getSingle()`. The pair "deactivate the
    // old, activate the new" arrives as two envelopes, and between pages there
    // would otherwise be a window with none. Staying active until its successor
    // arrives is self-healing; the successor supersedes it above.
    final others =
        await (_database.select(_database.rotationSchemes)..where(
              (RotationSchemes row) =>
                  row.surahId.equals(record.surahId) &
                  row.id.equals(record.id).not() &
                  row.supersededJournalSequence.isNull(),
            ))
            .get();
    if (others.isEmpty) return;
    await (_database.update(
      _database.rotationSchemes,
    )..where((RotationSchemes row) => row.id.equals(record.id))).write(
      const RotationSchemesCompanion(supersededJournalSequence: Value<int?>(0)),
    );
  }
}
