import 'dart:convert';

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
    this.backfill,
  });

  static const SyncTransportSnapshot inactive = SyncTransportSnapshot(
    isActivated: false,
    queuedCount: 0,
    quarantinedCount: 0,
    lastSuccessAtUtc: null,
    lastFailureReason: null,
    consecutiveFailureCount: 0,
  );

  /// What the last backfill did, or null on a device that has never merged.
  ///
  /// Counted separately from the queue because it is a different fact: a
  /// queued record is on its way, and a skipped one is not going at all.
  final SyncBackfillOutcome? backfill;

  final bool isActivated;
  final int queuedCount;
  final int quarantinedCount;
  final DateTime? lastSuccessAtUtc;

  /// The queue's own content-free category, never a server message: this
  /// reaches a screen and a log, and a user's recitation must not.
  final String? lastFailureReason;

  final int consecutiveFailureCount;
}

/// What a pulled page left behind: the records that could not be placed yet,
/// and the first reason one of them gave.
///
/// Empty is the ordinary outcome and the only one that moves the cursor.
typedef SyncPageResidue = ({List<SyncEnvelope> deferred, String? reason});

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
  DriftSyncStore(
    this._database, {
    this.owner = SyncOwnerKey.local,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? _systemNowUtc,
       outbox = DriftSyncOutbox(_database, owner: owner);

  final AppDatabase _database;

  /// Only for the `updated_at_utc` of the settings rows written here; every
  /// sync-visible timestamp arrives as an argument from the caller that owns
  /// the decision. Injectable so a test is not at the mercy of the wall clock.
  final DateTime Function() _nowUtc;

  static DateTime _systemNowUtc() => DateTime.now().toUtc();

  @override
  final SyncOwnerKey owner;
  final DriftSyncOutbox outbox;

  /// The same store for a different account, sharing this database.
  DriftSyncStore forOwner(SyncOwnerKey other) =>
      DriftSyncStore(_database, owner: other, nowUtc: _nowUtc);

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
  /// **A record whose prerequisite has not arrived is set aside, not thrown.**
  /// The appliers call those refusals retryable — "the roster entry is itself
  /// an entity that syncs" — but until 2026-09-23 nothing anywhere retried
  /// them, and the refusal killed the whole page instead. His account holds
  /// 842 recitations written a day *before* the 27 rotation schemes they point
  /// at, because those schemes were refused by an older build and recovered
  /// later; `$createdAt` is the order pages come back in, so the dependants
  /// come first and always will. Every page his second phone fetched died on
  /// the first recitation, the cursor never moved, and it received nothing.
  ///
  /// **Since v11 what could not be placed is written down, and the cursor
  /// moves anyway.** Carrying refusals in memory and holding the cursar behind
  /// them was the previous answer, and it had two faults the audit of
  /// 2026-09-24 named: a restart lost them, and a record this build can never
  /// place — a type from a newer client, a prayer naming a scheme this device
  /// absorbed — pinned the cursor for good, so every later cycle re-read the
  /// whole account from that point and re-applied all of it.
  ///
  /// The inbox row and the cursor are written in **one** transaction, which is
  /// what makes moving the cursor safe: nothing is skipped, because the record
  /// is still here. It is retried every cycle and counted until it applies.
  ///
  /// Anything that is *not* a [SyncTransportException] still aborts the page
  /// and commits nothing: a record this build cannot read is not a record
  /// waiting for its turn.
  Future<SyncPageResidue> applyPulledPage(
    SyncPullPage page, {
    required Future<void> Function(SyncEnvelope envelope) apply,
    required DateTime nowUtc,
    Future<void> Function()? afterAll,
    Set<String> retrying = const <String>{},
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'Must be UTC.');
    }
    return _database.transaction(() async {
      final deferred = <SyncEnvelope>[];
      String? reason;
      for (final envelope in page.envelopes) {
        try {
          // A savepoint of its own, because a refusal can be thrown halfway
          // through an applier: undoing that applier's writes and nothing
          // else is the difference between setting a record aside and
          // corrupting the ones around it.
          await _database.transaction(() => apply(envelope));
          if (retrying.contains(envelope.id)) {
            await _forgetInbox(envelope.id);
          }
        } on SyncTransportException catch (error) {
          deferred.add(envelope);
          reason ??= error.reason;
          await _rememberInbox(envelope, error.reason, nowUtc);
        }
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
      return (deferred: deferred, reason: reason);
    });
  }

  /// The incoming records this owner is still waiting to place, oldest first.
  ///
  /// Only `pending` ones. A `withdrawn` mark is not a problem to be retried —
  /// see `SyncWithdrawalMarks` — and counting it as one would tell a device
  /// that had just restored an account it had a hundred unresolved records.
  Future<List<SyncEnvelope>> pendingInbox({int limit = 200}) async {
    final rows =
        await (_database.select(_database.syncInboxEntries)
              ..where(
                (SyncInboxEntries row) =>
                    row.ownerKey.equals(owner.value) &
                    row.status.equals('pending'),
              )
              ..orderBy(<OrderClauseGenerator<SyncInboxEntries>>[
                (SyncInboxEntries row) =>
                    OrderingTerm(expression: row.receivedAtUs),
              ])
              ..limit(limit))
            .get();
    return <SyncEnvelope>[
      for (final row in rows)
        SyncEnvelope.fromJson(
          jsonDecode(row.envelopeJson) as Map<String, Object?>,
        ),
    ];
  }

  /// How many incoming records this owner cannot place yet.
  Future<int> unresolvedInboxCount() async =>
      (await _database
              .customSelect(
                'SELECT count(*) AS n FROM sync_inbox_entries '
                "WHERE owner_key = ? AND status = 'pending'",
                variables: <Variable<Object>>[Variable<String>(owner.value)],
              )
              .getSingle())
          .read<int>('n');

  Future<void> _rememberInbox(
    SyncEnvelope envelope,
    String reason,
    DateTime nowUtc,
  ) async {
    final existing =
        await (_database.select(_database.syncInboxEntries)..where(
              (SyncInboxEntries row) =>
                  row.ownerKey.equals(owner.value) &
                  row.envelopeId.equals(envelope.id),
            ))
            .getSingleOrNull();
    await _database
        .into(_database.syncInboxEntries)
        .insertOnConflictUpdate(
          SyncInboxEntriesCompanion.insert(
            ownerKey: owner.value,
            envelopeId: envelope.id,
            entityKey: envelope.entityKey,
            status: 'pending',
            // The moment it first arrived, kept across retries so the retry
            // order stays the order the account handed them over in.
            receivedAtUs:
                existing?.receivedAtUs ?? nowUtc.microsecondsSinceEpoch,
            envelopeUpdatedAtUs: envelope.updatedAtUtc.microsecondsSinceEpoch,
            attemptCount: Value<int>((existing?.attemptCount ?? 0) + 1),
            lastFailureReason: Value<String?>(reason),
            envelopeJson: jsonEncode(envelope.toJson()),
          ),
        );
  }

  Future<void> _forgetInbox(String envelopeId) async {
    await (_database.delete(_database.syncInboxEntries)..where(
          (SyncInboxEntries row) =>
              row.ownerKey.equals(owner.value) &
              row.envelopeId.equals(envelopeId),
        ))
        .go();
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

  /// Where this owner's last backfill outcome is kept.
  ///
  /// In `app_settings` for the same reason the watermark is: a column of its
  /// own would have meant a schema migration to hold one small fact. Outside
  /// the sync allowlist by construction, and rightly — how much of *this*
  /// device's history reached the account is not something to hand to another
  /// device as if it were about theirs.
  String get _backfillKey => 'sync.backfill.${owner.value}';

  @override
  Future<void> recordBackfillOutcome({
    required int enqueuedCount,
    required int skippedCount,
    required Set<String> skippedFields,
  }) async {
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _backfillKey,
            value: jsonEncode(<String, Object?>{
              'enqueued': enqueuedCount,
              'skipped': skippedCount,
              // Field names only. They are categories; the values behind them
              // are the owner's history and never leave the row they are in.
              'fields': skippedFields.toList()..sort(),
            }),
            // `string`, not `json`: `value_type` is constrained to the four
            // types a setting can be read back as, and a fifth would be a
            // schema migration for one internal row. The shape is JSON and the
            // storage is text; only `_backfillOutcome` reads this key, and it
            // already treats anything it cannot parse as absent.
            valueType: 'string',
            updatedAtUtc: _nowUtc(),
          ),
        );
  }

  /// Where the last exchange's failure category is kept.
  ///
  /// In `app_settings` beside the watermark, for the same reason: one small
  /// fact is not worth a schema migration. Outside the sync allowlist by
  /// construction, and rightly — whether *this* device's last exchange failed
  /// is not something to hand another device as if it were about theirs.
  String get _cycleFailureKey => 'sync.lastFailure.${owner.value}';

  /// Remembers why the last exchange failed, or clears it when one succeeds.
  ///
  /// The queue carries a reason for anything it could not push, so a failing
  /// **push** has always been visible. A failing **pull** leaves no trace in it
  /// at all: the queue is empty, the cursor simply never moves. His second
  /// phone spent an afternoon reporting "Синхронизация включена · Ждут
  /// отправки: 0" over a pull that had been dead-ended on its first page —
  /// the most convincing kind of wrong a status can be, because every number
  /// on the screen was true.
  ///
  /// A category, never a server message: this reaches a screen, and the user's
  /// own recitation must not.
  Future<void> recordCycleFailure(String? reason) async {
    if (reason == null) {
      await (_database.delete(
        _database.appSettings,
      )..where((row) => row.key.equals(_cycleFailureKey))).go();
      return;
    }
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _cycleFailureKey,
            value: reason,
            valueType: 'string',
            updatedAtUtc: _nowUtc(),
          ),
        );
  }

  Future<String?> _storedCycleFailure() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(_cycleFailureKey))).getSingleOrNull();
    final value = row?.value;
    return value == null || value.isEmpty ? null : value;
  }

  Future<SyncBackfillOutcome?> _backfillOutcome() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(_backfillKey))).getSingleOrNull();
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.value) as Map<String, Object?>;
      return SyncBackfillOutcome(
        enqueuedCount: decoded['enqueued'] as int? ?? 0,
        skippedCount: decoded['skipped'] as int? ?? 0,
        skippedFields: <String>{
          for (final field
              in decoded['fields'] as List<Object?>? ?? const <Object?>[])
            if (field is String) field,
        },
      );
    } on Object {
      // A row this build cannot read is not worth failing the whole summary
      // for: the screen loses one line and keeps the rest.
      return null;
    }
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
        final backfill = await _backfillOutcome();
        final cycleFailure = await _storedCycleFailure();
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

        // A queued entry's own reason first — it names a record the user can be
        // told about — and the last exchange's only when the queue has none.
        // An empty queue with a dead pull has nothing else to report it.
        final reported = failure ?? cycleFailure;
        return SyncTransportSnapshot(
          isActivated: activation?.isActive ?? false,
          queuedCount: queued,
          quarantinedCount: quarantined,
          lastSuccessAtUtc: activation?.lastSuccessAtUtc?.toUtc(),
          lastFailureReason: reported,
          // Counted from the queue only. A pull that keeps failing has no
          // attempt count of its own, and inventing one would be a number on a
          // screen that nothing measured.
          consecutiveFailureCount: failure == null ? 0 : attempts,
          backfill: backfill,
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
      _database.syncInboxEntries,
    )..where((row) => row.ownerKey.equals(owner.value))).go();
    await (_database.delete(
      _database.syncCursors,
    )..where((row) => row.ownerKey.equals(owner.value))).go();
    await (_database.delete(
      _database.syncActivations,
    )..where((row) => row.ownerKey.equals(owner.value))).go();
    // The two owner-scoped settings rows go with them. They are transport
    // state that happens to live in `app_settings` rather than in a table of
    // its own, and leaving them would contradict the row that was just
    // deleted: a device with no activation would still be reporting how a
    // merge went, and a device that has forgotten its queue would still claim
    // to have scanned up to a watermark that no longer describes anything.
    // Dropping the watermark makes a later activation re-offer everything,
    // which is the safe direction — too much rather than too little.
    await (_database.delete(_database.appSettings)..where(
          (row) => row.key.isIn(<String>[
            _watermarkKey,
            _backfillKey,
            _cycleFailureKey,
          ]),
        ))
        .go();
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
