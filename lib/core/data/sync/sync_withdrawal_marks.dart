/// A withdrawal this device received for a prayer it has never had.
///
/// The backfill sends a withdrawn recitation **as the withdrawal alone**, never
/// as the record plus a deletion, so a device restoring an account is handed a
/// tombstone with nothing to attach it to — 106 of them, for this owner. There
/// is nothing to defer and nothing to retry: inventing a row so it can be
/// marked deleted would put a prayer in the journal that never happened here.
///
/// But forgetting it is not free either. A copy of that record can still arrive
/// afterwards — recovered from quarantine and pushed a day late, which is
/// exactly how this account came to hold whole types out of order — and it
/// would bring back a prayer the owner had withdrawn.
///
/// So the withdrawal is kept as a mark: not a problem to be solved, a fact to
/// be remembered. It lives in the inbox under its own status, because it is an
/// incoming record that was received and could not be fully applied, and it is
/// owner-scoped for the same reason everything else there is.
///
/// The owners are read from the activation table rather than passed in, which
/// is the shape `SyncTombstones` already uses: an applier has no business
/// knowing which account is signed in, and this is a fact about the data.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../sync/sync.dart';
import '../database/app_database.dart';

abstract final class SyncWithdrawalMarks {
  static const String _status = 'withdrawn';

  /// Remembers that [envelope] withdrew a record this device does not hold.
  static Future<void> record(
    AppDatabase database, {
    required SyncEnvelope envelope,
  }) async {
    final owners = await (database.select(
      database.syncActivations,
    )..where((row) => row.isActive.equals(true))).get();
    for (final owner in owners) {
      await database
          .into(database.syncInboxEntries)
          .insertOnConflictUpdate(
            SyncInboxEntriesCompanion.insert(
              ownerKey: owner.ownerKey,
              envelopeId: envelope.id,
              entityKey: envelope.entityKey,
              status: _status,
              receivedAtUs: envelope.updatedAtUtc.microsecondsSinceEpoch,
              envelopeUpdatedAtUs: envelope.updatedAtUtc.microsecondsSinceEpoch,
              envelopeJson: jsonEncode(envelope.toJson()),
            ),
          );
    }
  }

  /// The latest moment any active account says [entityKey] was withdrawn.
  static Future<DateTime?> withdrawnAt(
    AppDatabase database, {
    required String entityKey,
  }) async {
    final rows =
        await (database.select(database.syncInboxEntries)..where(
              (SyncInboxEntries row) =>
                  row.entityKey.equals(entityKey) &
                  row.status.equals(_status),
            ))
            .get();
    if (rows.isEmpty) return null;
    return rows
        .map(
          (row) => DateTime.fromMicrosecondsSinceEpoch(
            row.envelopeUpdatedAtUs,
            isUtc: true,
          ),
        )
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Drops the marks for [entityKey], once the record itself is here.
  ///
  /// Safe to do: the row now carries its own `state_changed_at_utc`, so a
  /// replay of the same envelopes settles the same way without the mark.
  static Future<void> clear(
    AppDatabase database, {
    required String entityKey,
  }) async {
    await (database.delete(database.syncInboxEntries)..where(
          (SyncInboxEntries row) =>
              row.entityKey.equals(entityKey) & row.status.equals(_status),
        ))
        .go();
  }
}
