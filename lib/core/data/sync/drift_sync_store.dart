import 'package:drift/drift.dart';

import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'drift_sync_outbox.dart';

/// What this device has decided about one account.
final class SyncActivationRecord {
  const SyncActivationRecord({
    required this.owner,
    required this.isActive,
    required this.choice,
    required this.backupId,
    required this.decidedAtUtc,
    required this.lastSuccessAtUtc,
  });

  final SyncOwnerKey owner;
  final bool isActive;
  final SyncActivationChoice? choice;
  final String? backupId;
  final DateTime? decidedAtUtc;
  final DateTime? lastSuccessAtUtc;
}

/// Durable, owner-scoped sync state: the queue, the pull cursor and whether an
/// account has been allowed to touch this device's data.
///
/// The two transactional guarantees live here because both are about a *pair*
/// of writes that must not be separable:
///
/// - a local domain change and its queue entry commit together, so a crash
///   between them cannot leave a change that will never be pushed;
/// - a pulled page and its cursor commit together, so an interrupted pull is
///   re-fetched rather than skipped.
///
/// Everything is keyed by [owner]. That is what makes "sign out of A, sign in
/// as B" safe: B's engine reads B's queue and B's cursor, and A's rows are
/// simply not visible to it.
final class DriftSyncStore implements SyncAwareLocalStore {
  DriftSyncStore(this._database, {this.owner = SyncOwnerKey.local})
    : outbox = DriftSyncOutbox(_database, owner: owner);

  final AppDatabase _database;
  final SyncOwnerKey owner;
  final DriftSyncOutbox outbox;

  /// The same store for a different account, sharing this database.
  DriftSyncStore forOwner(SyncOwnerKey other) =>
      DriftSyncStore(_database, owner: other);

  @override
  Future<void> commitLocalChangeAndEnqueue(
    SyncEnvelope envelope, {
    required DateTime enqueuedAtUtc,
    required Future<void> Function() applyLocalChange,
  }) => _database.transaction(() async {
    await applyLocalChange();
    await outbox.enqueue(envelope, nowUtc: enqueuedAtUtc);
  });

  Future<SyncCursor> pullCursor() async {
    final row = await _cursorRow();
    return row == null ? SyncCursor.beginning : SyncCursor(row.pullCursor);
  }

  /// Applies one pulled page and advances the cursor in a single transaction.
  ///
  /// If [apply] throws, nothing commits and the cursor stays where it was, so
  /// the same page is fetched again. Advancing the cursor without the data is
  /// precisely how a device silently loses remote changes.
  Future<void> applyPulledPage(
    SyncPullPage page, {
    required Future<void> Function(SyncEnvelope envelope) apply,
    required DateTime nowUtc,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'Must be UTC.');
    }
    return _database.transaction(() async {
      for (final envelope in page.envelopes) {
        await apply(envelope);
      }
      await _database
          .into(_database.syncCursors)
          .insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              ownerKey: owner.value,
              pullCursor: page.cursor.value,
              updatedAtUtc: nowUtc,
            ),
          );
    });
  }

  Future<SyncActivationRecord?> activation() async {
    final row = await _activationRow();
    if (row == null) return null;
    return SyncActivationRecord(
      owner: owner,
      isActive: row.isActive,
      choice: _choiceFrom(row.choice),
      backupId: row.backupId,
      decidedAtUtc: row.decidedAtUtc?.toUtc(),
      lastSuccessAtUtc: row.lastSuccessAtUtc?.toUtc(),
    );
  }

  Future<bool> isSyncActive() async =>
      (await _activationRow())?.isActive ?? false;

  /// Records the user's answer to the first-sync preview.
  ///
  /// [SyncActivationChoice.keepDeviceLocalOnly] is stored, not forgotten: the
  /// account screen has to be able to say that this device was deliberately
  /// left local, and a forgotten "no" would look like a question never asked.
  Future<void> recordActivationChoice({
    required SyncActivationChoice choice,
    required String backupId,
    required DateTime decidedAtUtc,
  }) async {
    if (backupId.isEmpty) {
      throw ArgumentError.value(backupId, 'backupId', 'Must not be empty.');
    }
    if (!decidedAtUtc.isUtc) {
      throw ArgumentError.value(decidedAtUtc, 'decidedAtUtc', 'Must be UTC.');
    }
    await _database
        .into(_database.syncActivations)
        .insertOnConflictUpdate(
          SyncActivationsCompanion.insert(
            ownerKey: owner.value,
            isActive: Value<bool>(choice == SyncActivationChoice.merge),
            choice: Value<String>(choice.name),
            backupId: Value<String>(backupId),
            decidedAtUtc: Value<DateTime>(decidedAtUtc),
          ),
        );
  }

  Future<void> recordSuccessfulSync(DateTime atUtc) async {
    if (!atUtc.isUtc) {
      throw ArgumentError.value(atUtc, 'atUtc', 'Must be UTC.');
    }
    await (_database.update(
      _database.syncActivations,
    )..where((row) => row.ownerKey.equals(owner.value))).write(
      SyncActivationsCompanion(lastSuccessAtUtc: Value<DateTime>(atUtc)),
    );
  }

  /// Drops this owner's transport state only.
  ///
  /// Never called by ordinary sign-out: queued changes have to resume when the
  /// same account comes back. This is for confirmed account erasure, or for a
  /// user who chose to keep the device local after seeing the preview.
  Future<void> forgetOwner() => _database.transaction(() async {
    await outbox.clear();
    await (_database.delete(
      _database.syncCursors,
    )..where((row) => row.ownerKey.equals(owner.value))).go();
    await (_database.delete(
      _database.syncActivations,
    )..where((row) => row.ownerKey.equals(owner.value))).go();
  });

  static SyncActivationChoice? _choiceFrom(String? stored) {
    if (stored == null) return null;
    for (final choice in SyncActivationChoice.values) {
      if (choice.name == stored) return choice;
    }
    return null;
  }

  Future<SyncCursorRow?> _cursorRow() => (_database.select(
    _database.syncCursors,
  )..where((row) => row.ownerKey.equals(owner.value))).getSingleOrNull();

  Future<SyncActivationRow?> _activationRow() => (_database.select(
    _database.syncActivations,
  )..where((row) => row.ownerKey.equals(owner.value))).getSingleOrNull();
}
