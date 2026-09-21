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

/// Everything the account screen's summary is derived from, read at once.
///
/// One read rather than five, because the parts have to describe the same
/// moment: a queue counted before a success was recorded and an activation read
/// after it would produce a screen that is individually accurate and jointly
/// false.
final class SyncTransportSnapshot {
  const SyncTransportSnapshot({
    required this.isActivated,
    required this.queuedCount,
    required this.quarantinedCount,
    required this.lastSuccessAtUtc,
    required this.lastFailureReason,
    required this.consecutiveFailureCount,
  });

  static const SyncTransportSnapshot inactive = SyncTransportSnapshot(
    isActivated: false,
    queuedCount: 0,
    quarantinedCount: 0,
    lastSuccessAtUtc: null,
    lastFailureReason: null,
    consecutiveFailureCount: 0,
  );

  final bool isActivated;
  final int queuedCount;
  final int quarantinedCount;
  final DateTime? lastSuccessAtUtc;

  /// The queue's own content-free category, never a server message: this
  /// reaches a screen and a log, and a user's recitation must not.
  final String? lastFailureReason;

  final int consecutiveFailureCount;
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
final class DriftSyncStore implements SyncAwareLocalStore, SyncActivationStore {
  DriftSyncStore(this._database, {this.owner = SyncOwnerKey.local})
    : outbox = DriftSyncOutbox(_database, owner: owner);

  final AppDatabase _database;

  @override
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
    Future<void> Function()? afterAll,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'Must be UTC.');
    }
    return _database.transaction(() async {
      for (final envelope in page.envelopes) {
        await apply(envelope);
      }
      // Whatever the page as a whole implies — rebuilding a projection, say —
      // done once, inside the same transaction, before the cursor moves. A
      // rebuild after the commit could be interrupted and leave a cursor that
      // says the page arrived and a projection that does not reflect it.
      await afterAll?.call();
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

  @override
  Future<bool> isSyncActive() async =>
      (await _activationRow())?.isActive ?? false;

  /// The key this owner's push watermark is stored under.
  ///
  /// In `app_settings` rather than a column of its own, which would have meant
  /// a schema migration for one integer. It is scoped by owner for the same
  /// reason every other row here is: two accounts on one phone have scanned
  /// different amounts of the same database.
  ///
  /// Closed out of sync by construction — [SyncAppSettingPolicy] is an
  /// allowlist, and how far this device has scanned is nobody else's business.
  String get _watermarkKey => 'sync.pushWatermark.${owner.value}';

  /// How far the local scan has already looked for changes to queue.
  ///
  /// The beginning of time when nothing has been scanned yet, which is exactly
  /// right: a device that has never scanned has everything still to offer.
  Future<DateTime> pushWatermark() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(_watermarkKey))).getSingleOrNull();
    final seconds = int.tryParse(row?.value ?? '');
    if (seconds == null) return kUndatedByThisDevice;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  Future<void> recordPushWatermark(DateTime atUtc) async {
    if (!atUtc.isUtc) {
      throw ArgumentError.value(atUtc, 'atUtc', 'Must be UTC.');
    }
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _watermarkKey,
            // Whole seconds, matching what the v10 touch triggers write, so a
            // watermark and a row's `updated_at_utc` are comparable without
            // one of them being rounded behind the other's back.
            value: '${atUtc.millisecondsSinceEpoch ~/ 1000}',
            valueType: 'int',
            updatedAtUtc: atUtc,
          ),
        );
  }

  /// The whole summary in one pass.
  ///
  /// The quarantined count is queried here rather than taken from
  /// `outbox.quarantined()`: that returns a page, and a screen that said "3
  /// refused" because the page stops at fifty would understate the one thing
  /// on this screen nobody else will notice.
  Future<SyncTransportSnapshot> transportSnapshot() =>
      _database.transaction(() async {
        final activation = await _activationRow();
        final rows = await (_database.select(
          _database.syncOutboxEntries,
        )..where((row) => row.ownerKey.equals(owner.value))).get();

        var queued = 0;
        var quarantined = 0;
        String? failure;
        var attempts = 0;
        for (final row in rows) {
          if (row.status == 'quarantined') {
            quarantined++;
            continue;
          }
          queued++;
          // Any pending failure is worth reporting, and the most-attempted
          // entry is the honest number for "how long has this been failing":
          // a success removes an entry, so its attempts are consecutive by
          // construction.
          if (row.lastFailureReason != null) failure ??= row.lastFailureReason;
          if (row.attemptCount > attempts) attempts = row.attemptCount;
        }

        return SyncTransportSnapshot(
          isActivated: activation?.isActive ?? false,
          queuedCount: queued,
          quarantinedCount: quarantined,
          lastSuccessAtUtc: activation?.lastSuccessAtUtc?.toUtc(),
          lastFailureReason: failure,
          consecutiveFailureCount: failure == null ? 0 : attempts,
        );
      });

  /// Records the user's answer to the first-sync preview.
  ///
  /// [SyncActivationChoice.keepDeviceLocalOnly] is stored, not forgotten: the
  /// account screen has to be able to say that this device was deliberately
  /// left local, and a forgotten "no" would look like a question never asked.
  @override
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
  @override
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
