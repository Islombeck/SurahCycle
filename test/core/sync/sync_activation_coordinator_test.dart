import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Signing in is not consent to overwrite a lifetime of recitation history.
/// This coordinator is the only thing standing between the two, so the tests
/// here are mostly about what it *refuses* to do.
void main() {
  Matcher activationReason(String reason) => throwsA(
    isA<SyncActivationException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  group('preparing: nothing is offered that cannot be undone', () {
    test('the backup is taken before the data is even counted', () async {
      final store = _FakeActivationStore(_ownerA);
      final backups = _FakeBackups();
      final inventory = _FakeInventory(
        local: <String, DateTime>{'recitation:1': _at(1)},
        remote: <String, DateTime>{},
        // Not a flag the inventory sets on itself — that would read `true`
        // whichever order they ran in. It reports what the backup gateway had
        // actually done by the time counting started.
        backupsSoFar: () => backups.created,
      );
      final coordinator = _coordinatorFor(store, backups, inventory);

      await coordinator.prepareFirstSync(_accountA);

      expect(backups.created, 1);
      expect(
        inventory.backupsAtCountTime,
        1,
        reason:
            'counting first would mean the window between reading and merging '
            'is unprotected',
      );
    });

    test('a failed backup produces no preview at all', () async {
      final store = _FakeActivationStore(_ownerA);
      final backups = _FakeBackups(fail: true);
      final coordinator = _coordinatorFor(store, backups, _FakeInventory());

      await expectLater(
        () => coordinator.prepareFirstSync(_accountA),
        throwsA(isA<StateError>()),
      );
      // And the failure must not leave a half-open gate behind it.
      await expectLater(
        () => coordinator.finishFirstSync(
          previewToken: 'token-1',
          choice: SyncActivationChoice.merge,
        ),
        activationReason('no-preview-was-prepared'),
      );
      expect(store.recorded, isEmpty);
    });

    test('a store belonging to another account is refused', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerB),
        _FakeBackups(),
        _FakeInventory(),
      );

      await expectLater(
        () => coordinator.prepareFirstSync(_accountA),
        activationReason('store-belongs-to-another-account'),
      );
    });
  });

  group('the counts a user decides on', () {
    test('each entity lands in exactly one bucket', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerA),
        _FakeBackups(),
        _FakeInventory(
          local: <String, DateTime>{
            'recitation:1': _at(1),
            'recitation:2': _at(2),
            'recitation:3': _at(3),
          },
          remote: <String, DateTime>{
            'recitation:2': _at(2),
            'recitation:3': _at(9),
            'recitation:4': _at(4),
            'recitation:5': _at(5),
          },
        ),
      );

      final preview = await coordinator.prepareFirstSync(_accountA);

      expect(preview.localOnlyCount, 1, reason: 'recitation:1');
      expect(preview.remoteOnlyCount, 2, reason: 'recitation:4 and 5');
      expect(preview.sharedCount, 2, reason: 'recitation:2 and 3');
      expect(preview.conflictCount, 1, reason: 'only recitation:3 disagrees');
      expect(preview.hasConflicts, isTrue);
    });

    test('an entity both sides agree on is shared, not a conflict', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerA),
        _FakeBackups(),
        _FakeInventory(
          local: <String, DateTime>{'recitation:1': _at(1)},
          // The same instant, carried in a different zone. Reporting this as a
          // disagreement would scare a user off a merge with nothing in it.
          remote: <String, DateTime>{'recitation:1': _at(1).toLocal()},
        ),
      );

      final preview = await coordinator.prepareFirstSync(_accountA);

      expect(preview.sharedCount, 1);
      expect(preview.conflictCount, 0);
      expect(preview.hasConflicts, isFalse);
    });

    test('an undatable entity is neither a match nor a conflict', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerA),
        _FakeBackups(),
        _FakeInventory(
          local: <String, DateTime?>{
            // Six local tables carry no last-changed column, so this is the
            // ordinary case for a roster entry, not an edge case.
            'masteredSurah:surah-a': null,
            'recitationEvent:1': _at(1),
          },
          remote: <String, DateTime?>{
            'masteredSurah:surah-a': _at(5),
            'recitationEvent:1': _at(1),
          },
        ),
      );

      final preview = await coordinator.prepareFirstSync(_accountA);

      expect(preview.sharedCount, 2);
      expect(
        preview.conflictCount,
        0,
        reason:
            'the timestamps differ, but one of them is absent — calling that '
            'a disagreement presents a guess as a finding',
      );
      expect(preview.undeterminedCount, 1);
      expect(preview.hasConflicts, isFalse);
      expect(
        preview.needsReview,
        isTrue,
        reason: 'a merge that might overwrite something still wants a look',
      );
    });

    test('a first sync on an empty account is all local-only', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerA),
        _FakeBackups(),
        _FakeInventory(
          local: <String, DateTime>{
            'recitation:1': _at(1),
            'recitation:2': _at(2),
          },
          remote: <String, DateTime>{},
        ),
      );

      final preview = await coordinator.prepareFirstSync(_accountA);

      expect(preview.localOnlyCount, 2);
      expect(preview.remoteOnlyCount, 0);
      expect(preview.sharedCount, 0);
      expect(preview.conflictCount, 0);
    });
  });

  group('confirming: the answer must belong to the question', () {
    test('a token from a superseded preview is refused', () async {
      final store = _FakeActivationStore(_ownerA);
      final coordinator = _coordinatorFor(
        store,
        _FakeBackups(),
        _FakeInventory(),
      );

      final first = await coordinator.prepareFirstSync(_accountA);
      final second = await coordinator.prepareFirstSync(_accountA);
      expect(first.token, isNot(second.token));

      await expectLater(
        () => coordinator.finishFirstSync(
          previewToken: first.token,
          choice: SyncActivationChoice.merge,
        ),
        activationReason('preview-superseded'),
        reason:
            'the counts the user read are stale; agreeing to them would '
            'authorise a merge they were never shown',
      );
      expect(store.recorded, isEmpty);

      await coordinator.finishFirstSync(
        previewToken: second.token,
        choice: SyncActivationChoice.merge,
      );
      expect(store.recorded, hasLength(1));
    });

    test('a confirmation cannot be replayed', () async {
      final store = _FakeActivationStore(_ownerA);
      final coordinator = _coordinatorFor(
        store,
        _FakeBackups(),
        _FakeInventory(),
      );

      final preview = await coordinator.prepareFirstSync(_accountA);
      await coordinator.finishFirstSync(
        previewToken: preview.token,
        choice: SyncActivationChoice.keepDeviceLocalOnly,
      );

      await expectLater(
        () => coordinator.finishFirstSync(
          previewToken: preview.token,
          choice: SyncActivationChoice.merge,
        ),
        activationReason('preview-already-answered'),
        reason:
            'a double-tapped dialog must not turn a declined device into an '
            'active one — and it is a distinct situation from a call that '
            'prepared nothing, which is a wiring bug the UI has to surface',
      );
      expect(await store.isSyncActive(), isFalse);
      expect(store.recorded, hasLength(1));
    });

    test('the recorded decision names the backup that was shown', () async {
      final store = _FakeActivationStore(_ownerA);
      final backups = _FakeBackups();
      final coordinator = _coordinatorFor(store, backups, _FakeInventory());

      final preview = await coordinator.prepareFirstSync(_accountA);
      await coordinator.finishFirstSync(
        previewToken: preview.token,
        choice: SyncActivationChoice.merge,
      );

      expect(store.recorded.single.backupId, preview.backupId);
      expect(store.recorded.single.decidedAtUtc.isUtc, isTrue);
    });
  });

  group('the two answers have different consequences', () {
    test('merge activates the device', () async {
      final store = _FakeActivationStore(_ownerA);
      final coordinator = _coordinatorFor(
        store,
        _FakeBackups(),
        _FakeInventory(),
      );

      final preview = await coordinator.prepareFirstSync(_accountA);
      await coordinator.finishFirstSync(
        previewToken: preview.token,
        choice: SyncActivationChoice.merge,
      );

      expect(await store.isSyncActive(), isTrue);
      expect(store.forgotten, 0, reason: 'a merge keeps the queue');
    });

    test(
      'keeping the device local drops the queue but keeps the "no"',
      () async {
        final store = _FakeActivationStore(_ownerA);
        final coordinator = _coordinatorFor(
          store,
          _FakeBackups(),
          _FakeInventory(),
        );

        final preview = await coordinator.prepareFirstSync(_accountA);
        await coordinator.finishFirstSync(
          previewToken: preview.token,
          choice: SyncActivationChoice.keepDeviceLocalOnly,
        );

        expect(
          store.forgotten,
          1,
          reason: 'nothing stays queued for a declined account',
        );
        expect(await store.isSyncActive(), isFalse);
        // The ordering trap: `forgetOwner` deletes the activation row too, so
        // recording the choice first would erase the answer it just stored and
        // the account screen could not tell "declined" from "never asked".
        expect(
          store.survivingChoice,
          SyncActivationChoice.keepDeviceLocalOnly,
          reason: 'a forgotten "no" looks exactly like a question never asked',
        );
      },
    );
  });

  group('the history an account is agreeing to receive', () {
    test('a merge sends what this device already had', () async {
      final store = _FakeActivationStore(_ownerA);
      final backfill = _FakeBackfill();
      final coordinator = _coordinatorFor(
        store,
        _FakeBackups(),
        _FakeInventory(),
        backfill: backfill,
      );

      final preview = await coordinator.prepareFirstSync(_accountA);
      await coordinator.finishFirstSync(
        previewToken: preview.token,
        choice: SyncActivationChoice.merge,
      );

      expect(
        backfill.runs,
        hasLength(1),
        reason:
            'nothing else can send history written before the account existed; '
            'a recorder only ever sees changes made after it',
      );
    });

    test('a device kept local sends nothing at all', () async {
      final store = _FakeActivationStore(_ownerA);
      final backfill = _FakeBackfill();
      final coordinator = _coordinatorFor(
        store,
        _FakeBackups(),
        _FakeInventory(),
        backfill: backfill,
      );

      final preview = await coordinator.prepareFirstSync(_accountA);
      await coordinator.finishFirstSync(
        previewToken: preview.token,
        choice: SyncActivationChoice.keepDeviceLocalOnly,
      );

      expect(
        backfill.runs,
        isEmpty,
        reason: '"keep this device local" is an answer, not a slower merge',
      );
    });

    test('a backfill that fails leaves sync switched off', () async {
      final store = _FakeActivationStore(_ownerA);
      final coordinator = _coordinatorFor(
        store,
        _FakeBackups(),
        _FakeInventory(),
        backfill: _FakeBackfill(failure: StateError('queue unavailable')),
      );

      final preview = await coordinator.prepareFirstSync(_accountA);
      await expectLater(
        () => coordinator.finishFirstSync(
          previewToken: preview.token,
          choice: SyncActivationChoice.merge,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        await store.isSyncActive(),
        isFalse,
        reason:
            'active with an empty account is the worst outcome available: it '
            'looks like it worked and the history is nowhere',
      );
      expect(store.recorded, isEmpty);
    });
  });

  group('asking whether sync is active', () {
    test('an untouched device is not active', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerA),
        _FakeBackups(),
        _FakeInventory(),
      );

      expect(await coordinator.isSyncActiveFor(_accountA.userId), isFalse);
    });

    test('asking about the wrong account is loud, not false', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerA),
        _FakeBackups(),
        _FakeInventory(),
      );

      await expectLater(
        () => coordinator.isSyncActiveFor('user-b'),
        activationReason('store-belongs-to-another-account'),
        reason:
            'answering false would send the caller off to set B up against '
            "A's store",
      );
    });

    test('an empty user id is rejected outright', () async {
      final coordinator = _coordinatorFor(
        _FakeActivationStore(_ownerA),
        _FakeBackups(),
        _FakeInventory(),
      );

      await expectLater(
        () => coordinator.isSyncActiveFor(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test('no refusal reason carries anything but a category', () async {
    final coordinator = _coordinatorFor(
      _FakeActivationStore(_ownerA),
      _FakeBackups(),
      _FakeInventory(),
    );

    try {
      await coordinator.isSyncActiveFor('user-b');
      fail('expected a refusal');
    } on SyncActivationException catch (thrown) {
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(thrown.reason), isTrue);
      expect(thrown.reason, isNot(contains('user-b')));
    }
  });
}

final _accountA = SyncAccount(
  userId: 'user-a',
  linkedProviders: const <SyncAuthProvider>{SyncAuthProvider.google},
);
final _ownerA = SyncOwnerKey.user('user-a');
final _ownerB = SyncOwnerKey.user('user-b');

DateTime _at(int day) => DateTime.utc(2026, 9, day);

SyncActivationCoordinator _coordinatorFor(
  _FakeActivationStore store,
  _FakeBackups backups,
  _FakeInventory inventory, {
  _FakeBackfill? backfill,
}) {
  var token = 0;
  return SyncActivationCoordinator(
    store: store,
    backups: backups,
    inventory: inventory,
    backfill: backfill ?? _FakeBackfill(),
    nowUtc: () => DateTime.utc(2026, 9, 18, 12),
    createToken: () => 'token-${++token}',
  );
}

/// Records whether the history was offered to the account, and can refuse to.
final class _FakeBackfill implements SyncBackfill {
  _FakeBackfill({this.failure});

  /// Set to make a run fail, which is how the "activation stays off if the
  /// history could not be sent" rule is checked.
  final Object? failure;

  final List<DateTime> runs = <DateTime>[];

  @override
  Future<SyncBackfillReport> enqueueEverything({
    required DateTime nowUtc,
  }) async {
    runs.add(nowUtc);
    if (failure != null) throw failure!;
    return SyncBackfillReport(
      enqueuedByType: const <SyncEntityType, int>{
        SyncEntityType.recitationEvent: 3,
      },
    );
  }
}

final class _RecordedChoice {
  const _RecordedChoice(this.choice, this.backupId, this.decidedAtUtc);

  final SyncActivationChoice choice;
  final String backupId;
  final DateTime decidedAtUtc;
}

/// Mirrors `DriftSyncStore`, including the part that matters most here:
/// `forgetOwner` deletes the activation row along with the transport state.
final class _FakeActivationStore implements SyncActivationStore {
  _FakeActivationStore(this.owner);

  @override
  final SyncOwnerKey owner;

  final List<_RecordedChoice> recorded = <_RecordedChoice>[];
  int forgotten = 0;

  _RecordedChoice? _row;

  /// What a later read of the database would actually find.
  SyncActivationChoice? get survivingChoice => _row?.choice;

  @override
  Future<bool> isSyncActive() async =>
      _row?.choice == SyncActivationChoice.merge;

  @override
  Future<void> recordActivationChoice({
    required SyncActivationChoice choice,
    required String backupId,
    required DateTime decidedAtUtc,
  }) async {
    final entry = _RecordedChoice(choice, backupId, decidedAtUtc);
    recorded.add(entry);
    _row = entry;
  }

  @override
  Future<void> forgetOwner() async {
    forgotten++;
    _row = null;
  }
}

final class _FakeBackups implements LocalBackupGateway {
  _FakeBackups({this.fail = false});

  final bool fail;
  int created = 0;

  @override
  Future<LocalBackupDescriptor> createBackup() async {
    if (fail) throw StateError('no space');
    created++;
    return LocalBackupDescriptor(
      id: 'backup-$created',
      schemaVersion: 9,
      createdAtUtc: DateTime.utc(2026, 9, 18, 11),
    );
  }

  @override
  Future<Map<String, Object?>> exportLocalData() async =>
      const <String, Object?>{};

  @override
  Future<void> restoreBackup(String backupId) async {}
}

final class _FakeInventory implements SyncInventory {
  _FakeInventory({
    this.local = const <String, DateTime?>{},
    this.remote = const <String, DateTime?>{},
    int Function()? backupsSoFar,
  }) : _backupsSoFar = backupsSoFar ?? _none;

  static int _none() => 0;

  final Map<String, DateTime?> local;
  final Map<String, DateTime?> remote;
  final int Function() _backupsSoFar;

  /// How many backups existed when counting began. Observed, not asserted by
  /// the fake itself: see the first test.
  int? backupsAtCountTime;

  @override
  Future<Map<String, DateTime?>> localEntities() async {
    backupsAtCountTime = _backupsSoFar();
    return local;
  }

  @override
  Future<Map<String, DateTime?>> remoteEntities(String userId) async => remote;
}
