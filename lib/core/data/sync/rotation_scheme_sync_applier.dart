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
import 'sync_entity_aliases.dart';
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
    // Nothing further when this device already holds the same split under its
    // own name: the rest of this method would write a second copy of it.
    if (!await _writeScheme(record)) return;
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
  /// Removing it is refused when something actually references it — with one
  /// exception, which the owner's second phone found on 2026-09-23.
  ///
  /// **A referenced clash that describes the same split is the same scheme.**
  /// His second phone had put surah 104 in rotation by itself, so it held
  /// `surah-104:scheme:1`; the account held `v1:surah-104:scheme:1`, written by
  /// an older build. Identical surah, identical version, identical single part
  /// over all nine ayahs — two names for one split. The phone took the
  /// account's copy (the clash was a placeholder then and was cleared), pushed
  /// its own up, and pulled it back a page later, by which time the local row
  /// carried seven hundred recitations and could not be removed. Refusing was
  /// permanent: the cursor never moved, the same page came back forever, and
  /// **both** of his phones would have stopped receiving anything.
  ///
  /// So when the two describe the same split, the arriving one is taken as
  /// already held and nothing is written. Nothing is lost by that — the local
  /// row *is* that split, and it is the one his recitations point at.
  ///
  /// A clash whose parts differ is still refused, and still rightly: that is
  /// two genuinely different splits claiming one version number, and quietly
  /// dropping either is the loss this feature exists to prevent.
  ///
  /// Returns whether the caller should go on writing the arriving record.
  Future<bool> _clearColliding(RotationSchemeSyncRecord record) async {
    final clash =
        await (_database.select(_database.rotationSchemes)..where(
              (RotationSchemes row) =>
                  row.surahId.equals(record.surahId) &
                  row.version.equals(record.version) &
                  row.id.equals(record.id).not(),
            ))
            .getSingleOrNull();
    if (clash == null) return true;

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
      if (await _isTheSameSplit(clash, record)) {
        await _rememberAbsorption(clash, record);
        return false;
      }
      throw const SyncTransportException('remote-scheme-version-already-used');
    }

    await (_database.delete(
      _database.rotationSchemes,
    )..where((RotationSchemes row) => row.id.equals(clash.id))).go();
    return true;
  }

  /// Writes down that the arriving scheme and its parts are this device's.
  ///
  /// Keeping the local row is only half the answer. The other device goes on
  /// naming the ids it knows — a recitation's coverage carries the scheme id
  /// **and** each part id — and without this every such record is refused for
  /// a scheme that does not exist here, one at a time, forever.
  ///
  /// The parts are paired **by ordinal**, which is sound precisely because
  /// [_isTheSameSplit] has just established that both sides carry the same
  /// ordinals over the same ayah ranges. Pairing them by id would be pairing
  /// the thing that differs.
  Future<void> _rememberAbsorption(
    RotationSchemeRow clash,
    RotationSchemeSyncRecord record,
  ) async {
    final aliases = SyncAliasMap(_database);
    final now = DateTime.now().toUtc();
    await aliases.remember(
      aliasId: record.id,
      canonicalId: clash.id,
      kind: SyncAliasKind.rotationScheme,
      recordedAtUtc: now,
    );
    final local =
        await (_database.select(_database.rotationParts)
              ..where((RotationParts row) => row.schemeId.equals(clash.id))
              ..orderBy(<OrderClauseGenerator<RotationParts>>[
                (RotationParts row) => OrderingTerm(expression: row.ordinal),
              ]))
            .get();
    for (var index = 0; index < local.length; index += 1) {
      await aliases.remember(
        aliasId: record.parts[index].id,
        canonicalId: local[index].id,
        kind: SyncAliasKind.rotationPart,
        recordedAtUtc: now,
      );
    }
  }

  /// Whether [clash] and [record] are one split under two names.
  ///
  /// Surah and version match by construction — that is how the clash was
  /// found — so what remains is the shape: the surah's length when the split
  /// was made, and which ayahs each part covers.
  ///
  /// Part **ids** are deliberately not compared. Two builds name the same
  /// derived part differently, and that difference is the entire reason these
  /// two rows exist at all; comparing the names would answer "are they spelled
  /// alike", which nobody is asking.
  ///
  /// The baselines are not compared either. They are a starting score, the
  /// rebuild recomputes them for every scheme after the first, and treating a
  /// difference in them as a conflict would stall a pull forever over a number
  /// that the next rotation rebuild overwrites anyway.
  Future<bool> _isTheSameSplit(
    RotationSchemeRow clash,
    RotationSchemeSyncRecord record,
  ) async {
    if (clash.ayahCountSnapshot != record.ayahCountSnapshot) return false;
    final local =
        await (_database.select(_database.rotationParts)
              ..where((RotationParts row) => row.schemeId.equals(clash.id))
              ..orderBy(<OrderClauseGenerator<RotationParts>>[
                (RotationParts row) => OrderingTerm(expression: row.ordinal),
              ]))
            .get();
    if (local.length != record.parts.length) return false;
    // `record.parts` is sorted by ordinal by its own constructor.
    for (var index = 0; index < local.length; index += 1) {
      final mine = local[index];
      final theirs = record.parts[index];
      if (mine.ordinal != theirs.ordinal ||
          mine.startAyah != theirs.startAyah ||
          mine.endAyah != theirs.endAyah) {
        return false;
      }
    }
    return true;
  }

  /// Returns whether the arriving record still has to be written out.
  Future<bool> _writeScheme(RotationSchemeSyncRecord record) async {
    final existing =
        await (_database.select(_database.rotationSchemes)
              ..where((RotationSchemes row) => row.id.equals(record.id)))
            .getSingleOrNull();
    if (existing == null) {
      if (!await _clearColliding(record)) return false;
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
      return true;
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
    return true;
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

  /// Stands a scheme down by writing **its own activation point**, never zero.
  ///
  /// The table holds `superseded_journal_sequence IS NULL OR
  /// superseded_journal_sequence >= activated_journal_sequence`, and zero
  /// satisfies that only for a scheme this device inserted — an arriving one,
  /// which is activated at zero because the sender's journal positions mean
  /// nothing here. A scheme the *owner* created carries the real position it
  /// was activated at, and standing it down with zero raised
  /// `SqliteException(275)` out of the sync cycle, uncaught, on the one surah
  /// he has re-split. That is what stopped his own phone receiving.
  ///
  /// The value itself is meaningless: every reader of this column tests it for
  /// null and nothing else. What matters is that it is not null and not below
  /// the row's own activation, and the row already carries a number that
  /// satisfies both without reading anything else.
  /// Every scheme of [surahId] except [exceptId] that is still in force.
  Future<void> _standDownOthers(String surahId, String exceptId) =>
      _database.customStatement(
        'UPDATE rotation_schemes '
        'SET superseded_journal_sequence = activated_journal_sequence '
        'WHERE surah_id = ? AND id <> ? '
        'AND superseded_journal_sequence IS NULL',
        <Object?>[surahId, exceptId],
      );

  /// This one scheme, whoever else is in force.
  Future<void> _standDownOne(String id) => _database.customStatement(
    'UPDATE rotation_schemes '
    'SET superseded_journal_sequence = activated_journal_sequence '
    'WHERE id = ?',
    <Object?>[id],
  );

  Future<void> _settleWhichIsActive(RotationSchemeSyncRecord record) async {
    if (record.isActive) {
      // Stand the others down first: the unique index allows only one active
      // scheme per surah, so activating before superseding would collide.
      await _standDownOthers(record.surahId, record.id);
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
    await _standDownOne(record.id);
  }
}
