/// The gate between signing in and letting an account touch this device.
///
/// Signing in establishes identity. It does not move a recitation, and it must
/// not: the one failure this whole architecture exists to prevent is an account
/// that quietly rewrites local history on first login. So between the two sits
/// a backup, a preview of what would change, and one explicit answer.
///
/// Every rule here is about refusing to proceed on an assumption:
///
/// - the backup is made **before** the preview is offered, because a merge you
///   cannot undo is not a merge anyone can meaningfully agree to;
/// - the confirmation is bound to the exact snapshot it was shown for, so a
///   dialog left open while the data moved cannot authorise a different merge;
/// - "keep this device local" is a real answer with durable consequences, not a
///   postponement: it drops the transport state rather than leaving work queued
///   for an account the user declined.
library;

import 'sync_backfill.dart';
import 'sync_owner.dart';
import 'sync_ports.dart';

/// What each side holds: an entity key mapped to the time it last changed.
///
/// Keys must be comparable across devices — entity type and id, never a local
/// row id, or every entity would look local-only and the preview would offer to
/// merge a user's history with itself. The timestamps are what separate "both
/// sides have this" from "both sides have this and they disagree".
///
/// A **null** timestamp means the entity is present and its last change cannot
/// be dated. Several local tables carry no such column, and inventing one — the
/// creation time, the epoch, now — would turn "we do not know" into a claim
/// that two sides agree or disagree. The preview reports these separately.
abstract interface class SyncInventory {
  Future<Map<String, DateTime?>> localEntities();

  Future<Map<String, DateTime?>> remoteEntities(String userId);
}

/// The durable half of activation, narrowed to what this coordinator needs.
///
/// `DriftSyncStore` satisfies it — named in prose rather than imported, because
/// the data layer depends on this one and not the other way round. The
/// interface exists so these rules can be tested without a database, and so the
/// coordinator cannot reach past it into the queue or the cursor.
abstract interface class SyncActivationStore {
  /// Which account this store's rows belong to. Every durable sync row is
  /// scoped by it, so a coordinator holding the wrong store would write one
  /// account's decision into another's row.
  SyncOwnerKey get owner;

  Future<bool> isSyncActive();

  Future<void> recordActivationChoice({
    required SyncActivationChoice choice,
    required String backupId,
    required DateTime decidedAtUtc,
  });

  Future<void> forgetOwner();
}

/// Raised when activation cannot proceed on the terms it was asked to.
final class SyncActivationException implements Exception {
  const SyncActivationException(this.reason);

  /// A category, never a payload: this can reach a log.
  final String reason;

  @override
  String toString() => 'SyncActivationException($reason)';
}

final class SyncActivationCoordinator implements SyncActivationGateway {
  SyncActivationCoordinator({
    required SyncActivationStore store,
    required LocalBackupGateway backups,
    required SyncInventory inventory,
    required SyncBackfill backfill,
    required DateTime Function() nowUtc,
    required String Function() createToken,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _store = store,
       // ignore: prefer_initializing_formals
       _backups = backups,
       // ignore: prefer_initializing_formals
       _inventory = inventory,
       // ignore: prefer_initializing_formals
       _backfill = backfill,
       // ignore: prefer_initializing_formals
       _nowUtc = nowUtc,
       // ignore: prefer_initializing_formals
       _createToken = createToken;

  final SyncActivationStore _store;
  final LocalBackupGateway _backups;
  final SyncInventory _inventory;

  /// What turns an agreement to merge into an account that actually holds the
  /// history. Required rather than optional: a coordinator without one would
  /// activate sync and send nothing, which looks like success and is the exact
  /// silent-nothing-happened outcome this gate exists to avoid.
  final SyncBackfill _backfill;

  final DateTime Function() _nowUtc;
  final String Function() _createToken;

  /// The one preview awaiting an answer. Deliberately single: a second
  /// preparation supersedes the first, and answering the older one afterwards
  /// would be answering a question about data that has since moved.
  _PendingActivation? _pending;

  /// The token of the last preview that was actually answered.
  ///
  /// Kept only so a double-tapped dialog can be told apart from a call that
  /// never prepared anything: the first is a harmless repeat the UI can
  /// swallow, the second is a wiring mistake that has to surface. One token,
  /// not a growing set — the distinction is only interesting for the most
  /// recent question.
  String? _answeredToken;

  @override
  Future<SyncMergePreview> prepareFirstSync(SyncAccount account) async {
    final owner = SyncOwnerKey.user(account.userId);
    if (owner != _store.owner) {
      // This store holds someone else's rows. Continuing would file the new
      // account's decision under the old account's key — the exact
      // sign-out-of-A-into-B mixing that owner scoping exists to prevent.
      throw const SyncActivationException('store-belongs-to-another-account');
    }

    // Before anything is counted, let alone merged. If this throws, no choice
    // is ever offered — which is correct: the offer is only honest while it is
    // still reversible.
    final backup = await _backups.createBackup();

    final local = await _inventory.localEntities();
    final remote = await _inventory.remoteEntities(account.userId);

    var localOnly = 0;
    var shared = 0;
    var conflicts = 0;
    var undetermined = 0;
    for (final entry in local.entries) {
      // `containsKey`, not a null check on the value: a null timestamp means
      // "present, undatable", and treating it as absent would report an entity
      // the account already holds as local-only.
      if (!remote.containsKey(entry.key)) {
        localOnly++;
        continue;
      }
      shared++;
      final theirs = remote[entry.key];
      final ours = entry.value;
      if (theirs == null || ours == null) {
        // Neither agreement nor disagreement can be established. Recorded as
        // its own answer rather than folded into either, because both of the
        // alternatives would present a guess as a finding.
        undetermined++;
      } else if (!theirs.isAtSameMomentAs(ours)) {
        // Present on both sides **and** disagreeing. Counting every shared
        // entity as a conflict would frighten a user away from a merge that
        // has none. Compared as instants, so the same moment stored in
        // different zones is not reported as a disagreement.
        conflicts++;
      }
    }

    final preview = SyncMergePreview(
      token: _createToken(),
      backupId: backup.id,
      localOnlyCount: localOnly,
      remoteOnlyCount: remote.length - shared,
      sharedCount: shared,
      conflictCount: conflicts,
      undeterminedCount: undetermined,
    );
    _pending = _PendingActivation(token: preview.token, backupId: backup.id);
    return preview;
  }

  @override
  Future<void> finishFirstSync({
    required String previewToken,
    required SyncActivationChoice choice,
  }) async {
    if (previewToken == _answeredToken) {
      // A double-tapped dialog. Refused rather than repeated: replaying it
      // could turn a device its owner chose to keep local back into an active
      // one, and the second tap carries no new consent.
      throw const SyncActivationException('preview-already-answered');
    }
    final pending = _pending;
    if (pending == null) {
      throw const SyncActivationException('no-preview-was-prepared');
    }
    if (pending.token != previewToken) {
      // A dialog that outlived its preview. Honouring it would apply a
      // decision the user made about counts that are no longer true.
      throw const SyncActivationException('preview-superseded');
    }
    // Consumed before the writes below, so a failed write does not leave the
    // preview re-answerable with a different choice.
    _pending = null;
    _answeredToken = previewToken;

    if (choice == SyncActivationChoice.merge) {
      // Before the choice is recorded, so a failure here leaves sync inactive
      // rather than active with an empty account. The user re-prepares and
      // answers again; the backfill reads current rows and the outbox coalesces
      // per entity, so the second run finishes what the first started instead
      // of duplicating it.
      //
      // This is also the only moment the whole existing history can be sent. A
      // recorder queues a change as it is written and therefore has nothing to
      // say about anything written before the account existed.
      await _backfill.enqueueEverything(nowUtc: _nowUtc().toUtc());
    }

    if (choice == SyncActivationChoice.keepDeviceLocalOnly) {
      // Dropped **before** the decision is written, not after: `forgetOwner`
      // deletes this owner's activation row along with the queue and the
      // cursor, so the reverse order would erase the very "no" that the
      // account screen has to be able to show. A crash between the two leaves
      // a device that is inactive and simply has not answered yet, which is
      // the question being asked again rather than a wrong answer kept.
      await _store.forgetOwner();
    }
    await _store.recordActivationChoice(
      choice: choice,
      backupId: pending.backupId,
      decidedAtUtc: _nowUtc(),
    );
  }

  @override
  Future<bool> isSyncActiveFor(String userId) async {
    if (SyncOwnerKey.user(userId) != _store.owner) {
      // Answering `false` would be the tempting default, but a caller that
      // believes it asked about B and got B's answer will then set B up
      // against A's store. A wiring mistake has to be loud here.
      throw const SyncActivationException('store-belongs-to-another-account');
    }
    return _store.isSyncActive();
  }
}

final class _PendingActivation {
  const _PendingActivation({required this.token, required this.backupId});

  final String token;

  /// Carried from the preview rather than re-read at confirmation time: the
  /// recorded decision must name the backup the user was actually shown.
  final String backupId;
}
