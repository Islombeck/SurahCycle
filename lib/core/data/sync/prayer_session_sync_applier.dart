/// Writes a pulled prayer session, with its parts, into this device.
///
/// A recitation points at both the session and the part it filled, so this has
/// to arrive before those recitations can — the same prerequisite relationship
/// the roster has, and the recitation applier now refuses on it by name.
library;

import 'package:drift/drift.dart';

import '../../sync/prayer_session_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';

final class PrayerSessionSyncApplier {
  const PrayerSessionSyncApplier(this._database);

  final AppDatabase _database;

  /// Far above any real routine, which has a handful of parts at most.
  static const int _parkedOrderBase = 1000000;

  bool handles(SyncEnvelope envelope) =>
      envelope.entityType == PrayerSessionSyncPayload.entityType;

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    if (!handles(envelope)) {
      throw StateError('Not a prayer session envelope: ${envelope.entityKey}');
    }
    if (envelope.isTombstone) {
      await _applyTombstone(envelope.entityId);
      return;
    }

    final record = PrayerSessionSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    await _database
        .into(_database.prayerSessions)
        .insertOnConflictUpdate(
          PrayerSessionsCompanion.insert(
            id: record.id,
            prayerType: record.prayerType,
            isQada: Value<bool>(record.isQada),
            startedAtUtc: record.startedAtUtc,
            localDate: Value<String?>(record.localDate),
          ),
        );
    await _writeParts(record);
  }

  Future<void> _applyTombstone(String sessionId) async {
    final covered = await _coveredPartIds(sessionId);
    if (covered.isNotEmpty) {
      // Deleting the session cascades into its parts, and a recitation points
      // at the part it filled. The database would set those references to null
      // rather than refuse, quietly detaching prayers from the prayer they were
      // recited in — so this refuses instead. A session the owner still has
      // recitations for is not one he deleted.
      throw const SyncTransportException('remote-session-still-has-prayers');
    }
    await (_database.delete(
      _database.prayerSessions,
    )..where((PrayerSessions row) => row.id.equals(sessionId))).go();
  }

  Future<void> _writeParts(PrayerSessionSyncRecord record) async {
    final incoming = <String>{for (final part in record.parts) part.id};
    final local =
        await (_database.select(_database.prayerSessionParts)..where(
              (PrayerSessionParts row) => row.prayerSessionId.equals(record.id),
            ))
            .get();

    // Removals first: `UNIQUE (prayer_session_id, order_index)` would otherwise
    // collide with a part that has moved into a position still occupied.
    for (final row in local) {
      if (incoming.contains(row.id)) continue;
      final covered =
          await (_database.select(_database.recitationEvents)..where(
                (RecitationEvents r) => r.prayerSessionPartId.equals(row.id),
              ))
              .get();
      if (covered.isNotEmpty) {
        // Same reasoning as a covered rotation part: the reference would be
        // nulled and the link between a surah and the slot it filled lost.
        throw const SyncTransportException('remote-session-drops-a-used-part');
      }
      await (_database.delete(
        _database.prayerSessionParts,
      )..where((PrayerSessionParts r) => r.id.equals(row.id))).go();
    }

    // Then park everything staying far out of the way, so two parts swapping
    // places cannot collide on `UNIQUE (prayer_session_id, order_index)` while
    // one is written and the other has not moved yet.
    //
    // Parked high rather than negative: the table also holds
    // `CHECK (order_index >= 0)`, so the obvious trick of negating the index
    // would trade one constraint failure for another.
    for (final row in local) {
      if (!incoming.contains(row.id)) continue;
      await (_database.update(
        _database.prayerSessionParts,
      )..where((PrayerSessionParts r) => r.id.equals(row.id))).write(
        PrayerSessionPartsCompanion(
          orderIndex: Value<int>(_parkedOrderBase + row.orderIndex),
        ),
      );
    }

    for (final part in record.parts) {
      await _database
          .into(_database.prayerSessionParts)
          .insertOnConflictUpdate(
            PrayerSessionPartsCompanion.insert(
              id: part.id,
              prayerSessionId: record.id,
              sourceTemplatePartId: Value<String?>(part.sourceTemplatePartId),
              templateRevision: Value<int?>(part.templateRevision),
              stableKey: part.stableKey,
              orderIndex: part.orderIndex,
              label: part.label,
              kind: part.kind,
              rakaatCount: part.rakaatCount,
              requiredSurahSlots: part.requiredSurahSlots,
              allowsFollowingImam: part.allowsFollowingImam,
              completionMode: Value<String>(part.completionMode),
              completedAtUtc: Value<DateTime?>(part.completedAtUtc),
            ),
          );
    }
  }

  Future<List<String>> _coveredPartIds(String sessionId) async {
    final rows =
        await (_database.select(_database.recitationEvents)..where(
              (RecitationEvents row) => row.prayerSessionId.equals(sessionId),
            ))
            .get();
    return <String>[for (final row in rows) row.id];
  }
}
