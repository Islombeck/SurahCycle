/// Writes a pulled routine template, with its parts, into this device.
///
/// The routine is the one entity here that a device already has before it ever
/// syncs: eight templates are seeded at startup as `routine:<prayerType>`, so
/// an arriving one always updates a row that exists rather than creating one.
/// That is what keeps `UNIQUE (prayer_type)` safe — two devices cannot have
/// invented different ids for the same prayer.
library;

import 'package:drift/drift.dart';

import '../../sync/prayer_routine_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'sync_versioned_rows.dart';

final class PrayerRoutineSyncApplier {
  const PrayerRoutineSyncApplier(this._database);

  final AppDatabase _database;

  /// Far above any real routine, which has a handful of parts at most.
  static const int _parkedOrderBase = 1000000;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == PrayerRoutineSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a routine envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      // A routine template is never deleted. The eight are seeded and always
      // present; "removing" one means emptying it or turning it off, both of
      // which arrive as an ordinary upsert. Deleting would cascade into its
      // parts and leave a prayer with no template at all, which nothing in the
      // app expects.
      throw const SyncTransportException('remote-routine-cannot-be-deleted');
    }

    final record = PrayerRoutineSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    await _writeTemplate(record);
    await _writeParts(record);
    await SyncVersionedRows(_database).stampAuthored(
      table: 'prayer_routine_templates',
      key: record.id,
      authoredAtUtc: envelope.updatedAtUtc,
    );
  }

  Future<void> _writeTemplate(PrayerRoutineSyncRecord record) async {
    final clash =
        await (_database.select(_database.prayerRoutineTemplates)..where(
              (PrayerRoutineTemplates row) =>
                  row.prayerType.equals(record.prayerType) &
                  row.id.equals(record.id).not(),
            ))
            .getSingleOrNull();
    if (clash != null) {
      // Only reachable if some device stopped seeding deterministic ids. The
      // unique index would refuse the write anyway; saying so by name is the
      // difference between a legible refusal and a constraint failure nobody
      // can act on.
      throw const SyncTransportException('remote-routine-prayer-type-taken');
    }
    await _database
        .into(_database.prayerRoutineTemplates)
        .insertOnConflictUpdate(
          PrayerRoutineTemplatesCompanion.insert(
            id: record.id,
            prayerType: record.prayerType,
            displayName: record.displayName,
            enabled: Value<bool>(record.enabled),
            revision: Value<int>(record.revision),
          ),
        );
  }

  Future<void> _writeParts(PrayerRoutineSyncRecord record) async {
    final incoming = <String>{for (final part in record.parts) part.id};
    final local =
        await (_database.select(_database.prayerRoutinePartTemplates)..where(
              (PrayerRoutinePartTemplates row) =>
                  row.routineTemplateId.equals(record.id),
            ))
            .get();

    // A template part carries no history — a prayer session copies it rather
    // than referencing it — so removing one is safe and needs no check. That is
    // the difference between this and a *session* part, which a recitation
    // points at and which therefore cannot be dropped.
    for (final row in local) {
      if (incoming.contains(row.id)) continue;
      await (_database.delete(
        _database.prayerRoutinePartTemplates,
      )..where((PrayerRoutinePartTemplates r) => r.id.equals(row.id))).go();
    }

    // Park what stays: both `UNIQUE (template, order_index)` and
    // `UNIQUE (template, stable_key)` would otherwise collide while one part
    // had moved and another had not. Parked high rather than negated, because
    // `CHECK (order_index >= 0)` rules the obvious trick out.
    for (final row in local) {
      if (!incoming.contains(row.id)) continue;
      await (_database.update(
        _database.prayerRoutinePartTemplates,
      )..where((PrayerRoutinePartTemplates r) => r.id.equals(row.id))).write(
        PrayerRoutinePartTemplatesCompanion(
          orderIndex: Value<int>(_parkedOrderBase + row.orderIndex),
          stableKey: Value<String>('parked:${row.id}'),
        ),
      );
    }

    for (final part in record.parts) {
      await _database
          .into(_database.prayerRoutinePartTemplates)
          .insertOnConflictUpdate(
            PrayerRoutinePartTemplatesCompanion.insert(
              id: part.id,
              routineTemplateId: record.id,
              stableKey: part.stableKey,
              orderIndex: part.orderIndex,
              kind: part.kind,
              customLabel: Value<String?>(part.customLabel),
              rakaatCount: part.rakaatCount,
              requiredSurahSlots: part.requiredSurahSlots,
              allowsFollowingImam: Value<bool>(part.allowsFollowingImam),
              defaultCompletionMode: Value<String>(part.defaultCompletionMode),
            ),
          );
    }
  }
}
