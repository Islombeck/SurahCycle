/// Writes a pulled roster entry into this device's database.
///
/// The roster has to arrive before the recitations that depend on it, which is
/// why it is the first entity after recitations themselves to gain a mapper.
///
/// **It keeps an invariant the rest of the app relies on.** Every mastered
/// surah has at least one rotation scheme — `addMastered` has always created
/// one — and a great deal of code reads that as given. A pull applies one page
/// per transaction, so a roster entry could otherwise sit here with no scheme
/// until some later page brought one. Rather than leave that window open, this
/// creates the same default unsplit scheme `addMastered` would.
///
/// That is not inventing the owner's choices. The default is deterministic —
/// id `<surahId>:scheme:1`, one part spanning the whole surah, taken from the
/// corpus's own ayah count — and its id is the same one every device derives,
/// so a real scheme arriving later updates that row rather than competing with
/// it. If the owner had split the surah, that split arrives as its own entity
/// and takes over.
library;

import 'package:drift/drift.dart';

import '../../sync/mastered_surah_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'sync_versioned_rows.dart';

final class MasteredSurahSyncApplier {
  const MasteredSurahSyncApplier(this._database);

  final AppDatabase _database;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == MasteredSurahSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a roster envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      // Deliberately not a delete. Removing a roster row would cascade into
      // every recitation that references it — the schema forbids it outright
      // with `onDelete: restrict` — and the app already models "no longer in
      // the roster" as a flag rather than an absence, precisely so the history
      // survives. A tombstone therefore arrives as `isCurrentlyMastered:
      // false`, which is what the owner actually did.
      await _setNoLongerMastered(envelope.entityId);
      await _stampAuthoredAt(envelope.entityId, envelope.updatedAtUtc);
      return;
    }

    final record = MasteredSurahSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    final metadata =
        await (_database.select(_database.surahMetadata)
              ..where((SurahMetadata row) => row.id.equals(record.surahId)))
            .getSingleOrNull();
    if (metadata == null) {
      // The corpus is fetched by manifest rather than synced, so this is a
      // device that has not finished setting itself up rather than a broken
      // payload. Retryable: the surah will be there once it has.
      throw const SyncTransportException('remote-roster-surah-not-in-catalog');
    }

    final existing =
        await (_database.select(_database.masteredSurahs)..where(
              (MasteredSurahs row) => row.surahId.equals(record.surahId),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await _database
          .into(_database.masteredSurahs)
          .insert(
            MasteredSurahsCompanion.insert(
              surahId: record.surahId,
              isCurrentlyMastered: Value<bool>(record.isCurrentlyMastered),
              isActive: Value<bool>(record.isActive),
              hasEnteredRotation: Value<bool>(record.hasEnteredRotation),
              activationBaselineScore: Value<int?>(
                record.activationBaselineScore,
              ),
              alias: Value<String?>(record.alias),
              displayOrder: Value<int>(record.displayOrder),
              // The cached columns are left at their defaults on purpose: they
              // are a projection, and the journal rebuild owns them.
            ),
          );
    } else {
      await (_database.update(_database.masteredSurahs)
            ..where((MasteredSurahs row) => row.surahId.equals(record.surahId)))
          .write(
            MasteredSurahsCompanion(
              isCurrentlyMastered: Value<bool>(record.isCurrentlyMastered),
              isActive: Value<bool>(record.isActive),
              hasEnteredRotation: Value<bool>(record.hasEnteredRotation),
              activationBaselineScore: Value<int?>(
                record.activationBaselineScore,
              ),
              alias: Value<String?>(record.alias),
              displayOrder: Value<int>(record.displayOrder),
            ),
          );
    }
    await _stampAuthoredAt(record.surahId, envelope.updatedAtUtc);
    await _ensureDefaultScheme(record.surahId, metadata.ayahCount);
  }

  /// Writes the time the record was **authored**, not the time it arrived.
  ///
  /// The insert trigger stamps `now` unconditionally, and the update trigger
  /// steps aside when the writer sets the column itself — so this runs after
  /// the write and is left alone. Without it every device that receives a
  /// record would re-date it on arrival, and the copy would grow newer each
  /// time it was passed on until it outranked the edit it came from.
  Future<void> _stampAuthoredAt(String surahId, DateTime authoredAtUtc) =>
      SyncVersionedRows(_database).stampAuthored(
        table: 'mastered_surahs',
        key: surahId,
        authoredAtUtc: authoredAtUtc,
      );

  Future<void> _setNoLongerMastered(String surahId) async {
    await (_database.update(
      _database.masteredSurahs,
    )..where((MasteredSurahs row) => row.surahId.equals(surahId))).write(
      const MasteredSurahsCompanion(
        isCurrentlyMastered: Value<bool>(false),
        // A surah that is not currently mastered cannot be active — the table
        // refuses the combination, and so does the domain.
        isActive: Value<bool>(false),
      ),
    );
  }

  /// Creates `<surahId>:scheme:1` if the surah has no scheme at all.
  ///
  /// **Any, not the one.** A surah that has been re-split has a chain of them —
  /// his Al-Baqara has two — and asking for a single row threw `StateError:
  /// Too many elements` out of the whole sync cycle. It was not caught
  /// anywhere, so his phone advanced its watermark, moved no cursor, recorded
  /// nothing, and stopped receiving for a day and a night without a sign.
  Future<void> _ensureDefaultScheme(String surahId, int ayahCount) async {
    final any =
        await (_database.select(_database.rotationSchemes)
              ..where((RotationSchemes row) => row.surahId.equals(surahId))
              ..limit(1))
            .getSingleOrNull();
    if (any != null) return;

    const schemeSuffix = ':scheme:1';
    final schemeId = '$surahId$schemeSuffix';
    await _database
        .into(_database.rotationSchemes)
        .insert(
          RotationSchemesCompanion.insert(
            id: schemeId,
            surahId: surahId,
            version: 1,
            ayahCountSnapshot: ayahCount,
            baselineScore: 0,
            baselineTotalRecitations: 0,
            // Zero, not "the sequence this device is at": the scheme is not a
            // journal entry and claiming a position in this device's journal
            // would put it after recitations that arrive later.
            activatedJournalSequence: 0,
          ),
        );
    await _database
        .into(_database.rotationParts)
        .insert(
          RotationPartsCompanion.insert(
            id: '$schemeId:part:1',
            schemeId: schemeId,
            ordinal: 1,
            startAyah: 1,
            endAyah: ayahCount,
            cachedScore: 0,
            cachedRecitationCount: 0,
          ),
        );
    // Nobody authored this. The insert trigger dated it `now`, and left that
    // way it would outrank the owner's real scheme arriving a page later —
    // a placeholder invented during a pull refusing the record it was standing
    // in for.
    await SyncVersionedRows(
      _database,
    ).markUndated(table: 'rotation_schemes', key: schemeId);
  }
}
