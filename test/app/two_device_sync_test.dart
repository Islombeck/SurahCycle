import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_versioned_rows.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The whole feature, end to end, with two real databases and one account.
///
/// Every part of this has its own tests and all of them pass; none of them
/// establishes that the parts fit together. The backfill fills a queue nobody
/// reads in those tests, the appliers apply envelopes nobody sent, and the
/// cycle runner drains a queue containing envelopes a fake put there. This is
/// the first place a recitation written on one device has to arrive on another
/// by going through all of it.
///
/// It is not the two-device check the handoff still owes — that needs two
/// phones and the real Appwrite project — but it is the honest step before it.
/// `FakeSyncBackend` is the written-down form of what the server must do, so a
/// real backend that disagrees with this is a bug in the backend.
void main() {
  late FakeSyncBackend cloud;
  late _Device alice;
  late _Device bob;

  const userId = 'user-a';
  var clock = DateTime.utc(2026, 9, 21, 9);

  DateTime tick([int minutes = 1]) {
    clock = clock.add(Duration(minutes: minutes));
    return clock;
  }

  setUp(() async {
    clock = DateTime.utc(2026, 9, 21, 9);
    cloud = FakeSyncBackend(maxSupportedSchemaVersion: 6);
    alice = await _Device.create(
      name: 'alice',
      gateway: _BackendGateway(cloud, userId),
      userId: userId,
      nowUtc: () => clock,
    );
    bob = await _Device.create(
      name: 'bob',
      gateway: _BackendGateway(cloud, userId),
      userId: userId,
      nowUtc: () => clock,
    );
  });

  tearDown(() async {
    await alice.close();
    await bob.close();
  });

  test('a lifetime of history reaches a second device', () async {
    // Alice has been using the app for a while. Bob is a new phone.
    await alice.addSurah('surah-a', 112);
    await alice.addSurah('surah-b', 108);
    await bob.knowSurah('surah-a', 112);
    await bob.knowSurah('surah-b', 108);
    await alice.recite('r1', 'surah-a', at: tick());
    await alice.recite('r2', 'surah-b', at: tick());

    await alice.activateAndSync();
    await bob.activateAndSync();

    expect(
      await bob.masteredSurahIds(),
      <String>{'surah-a', 'surah-b'},
      reason:
          'the roster has to arrive before the recitations that point at it, '
          'which is what the router s dependency order is for',
    );
    expect(
      await bob.recitationIds(),
      <String>{'r1', 'r2'},
      reason:
          'nothing but the backfill can send history written before the '
          'account existed',
    );
    // Stated as a number rather than only as "the same as hers". Two zeros are
    // also the same, and an assertion that a device which received nothing
    // agrees with one that has everything is no assertion at all.
    expect(
      await alice.scoreOf('surah-a'),
      1,
      reason: 'she recited it once, so her standing says one',
    );
    expect(
      await bob.scoreOf('surah-a'),
      1,
      reason:
          'the standing is derived, not carried, so the two must compute the '
          'same answer — a device that took the history and never rebuilt its '
          'projection would show a rotation that disagrees with its own journal',
    );
  });

  test(
    'a recitation written afterwards arrives without anyone asking',
    () async {
      await alice.addSurah('surah-a', 112);
      await bob.knowSurah('surah-a', 112);
      await alice.activateAndSync();
      await bob.activateAndSync();

      // No recorder call anywhere. The row is written, the database stamps it,
      // and the next cycle finds it.
      await alice.recite('later', 'surah-a', at: tick());
      await alice.sync();
      await bob.sync();

      expect(await bob.recitationIds(), <String>{'later'});
      expect(
        await bob.scoreOf('surah-a'),
        await alice.scoreOf('surah-a'),
        reason: 'and it counts toward his rotation as it does toward hers',
      );
    },
  );

  test('a withdrawal travels, and does not come back', () async {
    await alice.addSurah('surah-a', 112);
    await alice.recite('r1', 'surah-a', at: tick());
    await bob.knowSurah('surah-a', 112);
    await alice.activateAndSync();
    await bob.activateAndSync();
    expect(await bob.recitationIds(), <String>{'r1'});

    await alice.withdraw('r1', at: tick());
    await alice.sync();
    await bob.sync();

    expect(
      await bob.recitationIds(),
      isEmpty,
      reason: 'a tombstone is how a deletion reaches a device that was away',
    );
    expect(
      await bob.scoreOf('surah-a'),
      await alice.scoreOf('surah-a'),
      reason:
          'a withdrawal lowers the standing exactly as writing it raised it, '
          'and a device that marked the row gone without rebuilding would go '
          'on counting a recitation that no longer exists',
    );

    // And a later cycle must not resurrect it: the record is still in the
    // account as a withdrawal, and applying that again is still a withdrawal.
    await bob.sync();
    await alice.sync();
    expect(await bob.recitationIds(), isEmpty);
    expect(await alice.recitationIds(), isEmpty);
  });

  test('both devices settle on the same answer to the same edit', () async {
    await alice.addSurah('surah-a', 112);
    await bob.knowSurah('surah-a', 112);
    await alice.activateAndSync();
    await bob.activateAndSync();

    // Each renames the same surah while the other is offline, and Bob's edit
    // is the later one.
    await alice.rename('surah-a', 'Alice', at: tick());
    await bob.rename('surah-a', 'Bob', at: tick());

    await alice.sync();
    await bob.sync();
    await alice.sync();
    await bob.sync();

    expect(
      await alice.aliasOf('surah-a'),
      await bob.aliasOf('surah-a'),
      reason:
          'a rule that leaves two devices disagreeing is not a rule; this is '
          'the property the merge ADR exists for',
    );
    expect(
      await alice.aliasOf('surah-a'),
      'Bob',
      reason: 'and the later edit is the one they agree on',
    );
  });

  test('a device kept local sends nothing and receives nothing', () async {
    await alice.addSurah('surah-a', 112);
    await alice.recite('r1', 'surah-a', at: tick());
    await bob.knowSurah('surah-a', 112);
    await alice.activateAndSync();

    await bob.addSurah('surah-b', 108);
    await bob.keepLocal();
    await bob.sync();

    expect(
      await bob.recitationIds(),
      isEmpty,
      reason: '"keep this device local" is an answer, and this is it kept',
    );
    expect(
      cloud.recordsOf(userId).any((one) => one.entityId == 'surah-b'),
      isFalse,
      reason: 'and nothing of his left the phone either',
    );
  });

  test('syncing twice changes nothing the second time', () async {
    await alice.addSurah('surah-a', 112);
    await alice.recite('r1', 'surah-a', at: tick());
    await bob.knowSurah('surah-a', 112);
    await alice.activateAndSync();
    await bob.activateAndSync();

    final before = cloud.recordsOf(userId).length;
    await alice.sync();
    await bob.sync();

    expect(
      cloud.recordsOf(userId).length,
      before,
      reason:
          'a cycle with nothing to say must be quiet; an account that grew on '
          'every sync would be a queue that never empties',
    );
    expect(await bob.recitationIds(), <String>{'r1'});
  });

  /// The same two phones, over a server shaped like the one this app uses.
  ///
  /// `FakeSyncBackend` above decides conflicts itself — it compares
  /// `updatedAtUtc`, refuses an update to an append-only record and keeps an
  /// audit trail. **Appwrite's TablesDB does none of that**: `upsertRow` writes
  /// what it is handed, and the project deploys no function to compare anything
  /// in. So every convergence property proved above was proved against a
  /// server this app does not have, and the one below is the same property
  /// proved against the one it does.
  group('against a server that decides nothing', () {
    late _DumbCloud cloud;

    setUp(() async {
      clock = DateTime.utc(2026, 9, 21, 9);
      cloud = _DumbCloud();
      alice = await _Device.create(
        name: 'alice',
        gateway: AppwriteSyncGateway(api: cloud, userId: userId),
        userId: userId,
        nowUtc: () => clock,
      );
      bob = await _Device.create(
        name: 'bob',
        gateway: AppwriteSyncGateway(api: cloud, userId: userId),
        userId: userId,
        nowUtc: () => clock,
      );
    });

    /// Both rename the surah while the other is away, and Alice's edit — the
    /// earlier one — is pushed last. A blind upsert leaves the account holding
    /// it, so this is the shape that has to be survived without the server's
    /// help.
    Future<void> bothRenameOffline() async {
      await alice.addSurah('surah-a', 112);
      await bob.knowSurah('surah-a', 112);
      await alice.activateAndSync();
      await bob.activateAndSync();
      await alice.rename('surah-a', 'Alice', at: tick());
      await bob.rename('surah-a', 'Bob', at: tick());
      await bob.sync();
      await alice.sync();
      await bob.sync();
      await alice.sync();
    }

    test('a device never takes an older edit over its own', () async {
      await bothRenameOffline();

      expect(
        await bob.aliasOf('surah-a'),
        'Bob',
        reason:
            "her push overwrote the account's newer copy — nothing on that "
            'side compares anything — and he must not take it back from there',
      );
    });

    test('and the device that lost finds out', () async {
      await bothRenameOffline();

      expect(
        await alice.aliasOf('surah-a'),
        'Bob',
        reason:
            'her own older edit is in the account too, and a log keeps both — '
            'so what she applies is the last one she has not seen, which is his',
      );
    });

    test(
      'a row is written once, so a cursor cannot be stranded on it',
      () async {
        await bothRenameOffline();

        // The defect this replaced: one row per entity, rewritten on every
        // edit, ordered by the server's `$updatedAt`. A rewritten row moved to
        // the end of that order, and a device whose cursor *was* that row then
        // had nothing after it — the one thing it could never be handed again
        // being that row's own newer content.
        expect(
          cloud.rowCount,
          greaterThan(cloud.entityCount),
          reason:
              'two renames of one surah are two rows; if they were one, the '
              'second would have moved out from under both cursors',
        );
      },
    );

    test('a history reaches a second device through the real mapping', () async {
      await alice.addSurah('surah-a', 112);
      await bob.knowSurah('surah-a', 112);
      await alice.recite('r1', 'surah-a', at: tick());

      await alice.activateAndSync();
      await bob.activateAndSync();

      expect(await bob.recitationIds(), <String>{'r1'});
      expect(
        await bob.masteredSurahIds(),
        <String>{'surah-a'},
        reason:
            'every row crossed as an Appwrite row and came back as one, which '
            'is the only form these ever travel in',
      );
    });
  });
}

/// A server shaped like TablesDB: one row per id, blind upsert, and no opinion.
///
/// Deliberately stupid. The row-id rule is enforced because the real one
/// enforces it — a row id it would refuse must not quietly work here — and
/// nothing else is: no timestamp comparison, no append-only refusal, no audit
/// log. Anything this app needs to be true has to be true without help from it.
final class _DumbCloud implements AppwriteSyncApi {
  static final RegExp _rowId = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$');

  final Map<String, Map<String, Object?>> _rows =
      <String, Map<String, Object?>>{};
  final List<String> _order = <String>[];

  /// How many rows the account holds, and how many distinct records they are
  /// about. A log has more of the first than the second.
  int get rowCount => _rows.length;
  int get entityCount => _rows.values
      .map((row) => '${row['entityType']}:${row['entityId']}')
      .toSet()
      .length;

  @override
  Future<AppwriteSyncWriteOutcome> upsertRow({
    required String rowId,
    required Map<String, Object?> data,
    required List<String> permissions,
  }) async {
    if (!_rowId.hasMatch(rowId)) return AppwriteSyncWriteOutcome.rejected;
    // Creation order, and it never changes: the pull asks for
    // `orderAsc($createdAt)`, and a row written once keeps the place it was
    // given. A row rewritten under `$updatedAt` used to move to the end here,
    // which is exactly how a cursor was stranded.
    if (!_rows.containsKey(rowId)) _order.add(rowId);
    _rows[rowId] = <String, Object?>{...data, r'$id': rowId};
    return AppwriteSyncWriteOutcome.written;
  }

  @override
  Future<AppwriteSyncPage> listRowsAfter({
    required String cursor,
    required int limit,
  }) async {
    final start = cursor.isEmpty ? 0 : _order.indexOf(cursor) + 1;
    final ids = _order.skip(start).take(limit).toList();
    return AppwriteSyncPage(
      rows: <Map<String, Object?>>[for (final id in ids) _rows[id]!],
      lastRowId: ids.isEmpty ? null : ids.last,
      hasMore: _order.length > start + ids.length,
    );
  }
}

/// One phone: its own database, its own queue, its own view of the account.
final class _Device {
  _Device._({
    required this.name,
    required this.database,
    required this.store,
    required this.runner,
    required this.backfill,
    required this.nowUtc,
  }) : surahs = SurahRepository(database),
       recitations = RecitationRepository(database);

  static Future<_Device> create({
    required String name,
    required SyncGateway gateway,
    required String userId,
    required DateTime Function() nowUtc,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftSyncStore(database, owner: SyncOwnerKey.user(userId));
    var ids = 0;
    final backfill = DriftSyncBackfill(
      database: database,
      outbox: store.outbox,
      deviceId: () async => name,
      newId: () => '$name-${++ids}',
      schemaVersion: 1,
    );
    final device = _Device._(
      name: name,
      database: database,
      store: store,
      backfill: backfill,
      runner: SyncCycleRunner(
        database: database,
        store: store,
        gateway: gateway,
        nowUtc: nowUtc,
        scan: backfill,
      ),
      nowUtc: nowUtc,
    );
    await device.surahs.getRotationSnapshot();
    return device;
  }

  final String name;
  final AppDatabase database;
  final DriftSyncStore store;
  final SyncCycleRunner runner;
  final SyncBackfill backfill;
  final DateTime Function() nowUtc;
  final SurahRepository surahs;
  final RecitationRepository recitations;

  Future<void> close() => database.close();

  /// Puts a surah in this device's copy of the corpus.
  ///
  /// Every device has this before it ever signs in: the catalogue ships with
  /// the app and is refreshed by manifest, deliberately not by sync — a Quran
  /// is not user data to be merged. The appliers refuse a record whose surah
  /// they have never heard of, so a second device has to know the corpus before
  /// it can receive anything about it.
  Future<void> knowSurah(String id, int number) =>
      surahs.upsertCatalog(<SurahDescriptor>[
        SurahDescriptor(
          id: id,
          surahNumber: number,
          officialName: 'Surah $number',
          ayahCount: 4,
        ),
      ]);

  /// And puts it in the rotation, which *is* user data.
  Future<void> addSurah(String id, int number) async {
    await knowSurah(id, number);
    await surahs.addMastered(id);
  }

  Future<void> recite(String id, String surahId, {required DateTime at}) =>
      recitations.register(
        SurahRecitationEvent(
          id: id,
          surahId: surahId,
          prayerContext: PrayerContext(prayerType: PrayerType.fajr),
          createdAtUtc: at,
          localDate: LocalDate(at.year, at.month, at.day),
          rakaatSpanCount: 1,
        ),
      );

  Future<void> withdraw(String id, {required DateTime at}) =>
      recitations.deleteRecitation(id, deletedAtUtc: at);

  /// Renames a surah, which is a versioned change rather than a journal entry:
  /// the row is edited in place and dated by the v10 trigger.
  /// Renames it, and dates the edit.
  ///
  /// The stamp is not decoration: the touch trigger writes the wall clock, so
  /// two renames a test intends to be a day apart land in the same second and
  /// the merge rule sees a tie. `FakeSyncBackend` hid that by breaking ties on
  /// `deviceId` server-side; a real server breaks nothing, and the test that
  /// tied was passing for a reason it was not about.
  Future<void> rename(
    String surahId,
    String alias, {
    required DateTime at,
  }) async {
    await surahs.setAlias(surahId, alias);
    await SyncVersionedRows(
      database,
    ).stampAuthored(table: 'mastered_surahs', key: surahId, authoredAtUtc: at);
  }

  Future<String?> aliasOf(String surahId) async {
    final snapshot = await surahs.getRotationSnapshot();
    return snapshot.surahById(surahId).surah.alias;
  }

  Future<Set<String>> masteredSurahIds() async {
    final snapshot = await surahs.getRotationSnapshot();
    return <String>{for (final surah in snapshot.surahs) surah.id};
  }

  Future<Set<String>> recitationIds() async {
    final history = await recitations.getHistory(limit: 1000);
    return <String>{for (final entry in history) entry.event.id};
  }

  /// The rotation standing of one surah, as the screen would show it.
  ///
  /// Derived rather than carried: the projection is rebuilt from the journal
  /// on each side, which is the point — two devices holding the same history
  /// must compute the same standing, and a device that received the history
  /// but never rebuilt would quietly disagree.
  Future<int> scoreOf(String surahId) async {
    final snapshot = await surahs.getRotationSnapshot();
    return snapshot.surahById(surahId).rotationScheme.parts.first.rotationScore;
  }

  /// The owner says yes to the merge, and the first cycle carries the history.
  Future<void> activateAndSync() async {
    await store.recordActivationChoice(
      choice: SyncActivationChoice.merge,
      backupId: 'backup-$name',
      decidedAtUtc: nowUtc(),
    );
    await backfill.enqueueEverything(nowUtc: nowUtc());
    await sync();
  }

  Future<void> keepLocal() => store.recordActivationChoice(
    choice: SyncActivationChoice.keepDeviceLocalOnly,
    backupId: 'backup-$name',
    decidedAtUtc: nowUtc(),
  );

  /// One exchange, then another: the first pushes what is queued and pulls what
  /// was already there, and a second is what a real device would do on its next
  /// resume. Two because a page applied in one cycle can unblock a record that
  /// stalled in it.
  ///
  /// A failure is raised rather than swallowed. The app is right to keep quiet
  /// about an unreachable network, but a test that did the same would report
  /// "nothing arrived" for a stalled applier and say nothing about which one.
  Future<void> sync() async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      final outcome = await runner.runOnce();
      if (outcome.hasFailure) {
        throw StateError('$name: cycle failed with ${outcome.failureReason}');
      }
    }
  }
}

/// Binds one device to the shared backend under one account.
final class _BackendGateway implements SyncGateway {
  const _BackendGateway(this._cloud, this._userId);

  final FakeSyncBackend _cloud;
  final String _userId;

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) async =>
      _cloud.push(_userId, envelopes);

  @override
  Future<SyncPullPage> pull({
    required SyncCursor after,
    int limit = 100,
  }) async => _cloud.pull(_userId, after: after, limit: limit);
}
