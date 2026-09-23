import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';

/// A second phone taking a full account down **one page at a time**, the way
/// the app does it, rather than in one heap the way a test can afford to.
///
/// `real_two_device_merge_test.dart` hands the router every envelope at once,
/// so it can always place a prerequisite before its dependant. A device pulls
/// pages of a hundred, in the order the account happens to hold them, and a
/// page cannot be sorted into containing something that is not in it.
///
///     $env:MURAJAAH_SOURCE_DB = '<path>\main-phone.sqlite'
///     $env:MURAJAAH_TARGET_DB = '<path>\second-phone.sqlite'
///     flutter test test/tool/real_pull_pagination_test.dart
///
/// Both are copied before use, so neither is written to.
void main() {
  final sourcePath = Platform.environment['MURAJAAH_SOURCE_DB'];
  final targetPath = Platform.environment['MURAJAAH_TARGET_DB'];
  final skipReason = sourcePath == null || targetPath == null
      ? 'Set MURAJAAH_SOURCE_DB and MURAJAAH_TARGET_DB.'
      : null;

  /// Opened on a copy: a tool test that mutates the owner's pulled database
  /// makes its own second run mean something different from its first.
  AppDatabase openCopy(String path, String label) {
    final copy = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'murajaah-pagination-$label.sqlite',
    );
    if (copy.existsSync()) copy.deleteSync();
    File(path).copySync(copy.path);
    final database = AppDatabase(NativeDatabase(copy));
    addTearDown(() async {
      await database.close();
      if (copy.existsSync()) copy.deleteSync();
    });
    return database;
  }

  /// Everything his phone would offer an account, in backfill order.
  Future<List<SyncEnvelope>> hisHistory(AppDatabase source) async {
    final outbox = InMemorySyncOutbox();
    var ids = 0;
    await DriftSyncBackfill(
      database: source,
      outbox: outbox,
      deviceId: () async => 'main-phone',
      newId: () => 'first-${++ids}',
    ).enqueueEverything(nowUtc: DateTime.now().toUtc());
    return <SyncEnvelope>[
      for (final entry in await outbox.peek(limit: 100000)) entry.envelope,
    ];
  }

  /// One full cycle of the real runner against an account holding [account].
  Future<SyncCycleOutcome> runCycleOver(
    List<SyncEnvelope> account,
    AppDatabase target,
    String label,
  ) async {
    final owner = SyncOwnerKey.user('pagination-$label');
    final cloud = _OrderedRowStore();
    final pushed = await AppwriteSyncGateway(
      api: cloud,
      userId: owner.value,
    ).push(account);
    expect(pushed.rejectedEnvelopeIds, isEmpty);

    final store = DriftSyncStore(target, owner: owner);
    await store.recordActivationChoice(
      choice: SyncActivationChoice.merge,
      backupId: 'pagination-probe',
      decidedAtUtc: DateTime.now().toUtc(),
    );
    var ids = 0;
    return SyncCycleRunner(
      database: target,
      store: store,
      gateway: AppwriteSyncGateway(api: cloud, userId: owner.value),
      nowUtc: () => DateTime.now().toUtc(),
      scan: DriftSyncBackfill(
        database: target,
        outbox: store.outbox,
        deviceId: () async => 'second-phone',
        newId: () => 'second-${++ids}',
      ),
    ).runOnce();
  }

  Future<int> countIn(AppDatabase database, String table) async =>
      (await database.customSelect('SELECT count(*) AS n FROM $table')
              .getSingle())
          .read<int>('n');

  test('a real account arrives on a real second phone, page by page', () async {
    final source = openCopy(sourcePath!, 'source-a');
    final target = openCopy(targetPath!, 'target-a');

    final outcome = await runCycleOver(await hisHistory(source), target, 'a');

    expect(
      outcome.failureReason,
      isNull,
      reason:
          'a pull that stalls on its own page boundary never recovers: the '
          'cursor stays, the same page is fetched again, and nothing arrives',
    );
    expect(await countIn(target, 'recitation_events'), greaterThan(0));
  }, skip: skipReason, timeout: const Timeout(Duration(minutes: 10)));

  test('and in the order his account really holds them', () async {
    final source = openCopy(sourcePath!, 'source-b');
    final target = openCopy(targetPath!, 'target-b');

    // His account is not in backfill order and cannot be. On 2026-09-22 a
    // build addressed each row by the record's own id, so every id carrying a
    // colon came back 400: **all** his prayer sessions, rotation schemes and
    // routine templates were refused and sat in quarantine. They were
    // recovered and pushed on 2026-09-23 — a day after the 842 recitations
    // that point at them. `$createdAt` is the order the account hands rows
    // back in, so the dependants now come first and always will.
    const recoveredLater = <SyncEntityType>{
      SyncEntityType.prayerSession,
      SyncEntityType.rotationScheme,
      SyncEntityType.prayerRoutineTemplate,
    };
    final history = await hisHistory(source);
    final asTheAccountHoldsThem = <SyncEnvelope>[
      for (final envelope in history)
        if (!recoveredLater.contains(envelope.entityType)) envelope,
      for (final envelope in history)
        if (recoveredLater.contains(envelope.entityType)) envelope,
    ];

    final outcome = await runCycleOver(asTheAccountHoldsThem, target, 'b');

    expect(
      outcome.failureReason,
      isNull,
      reason:
          'a prerequisite on a later page is the ordinary case, not a fault: '
          'the appliers call these refusals retryable, and until now there was '
          'nothing anywhere that retried them',
    );
    expect(
      await countIn(target, 'recitation_events'),
      (await source.customSelect(
        'SELECT count(*) AS n FROM recitation_events '
        'WHERE deleted_at_utc IS NULL',
      ).getSingle()).read<int>('n'),
      reason: 'every prayer he still holds, whatever order it arrived in',
    );
    expect(
      await countIn(target, 'prayer_sessions'),
      await countIn(source, 'prayer_sessions'),
    );
    expect(
      await countIn(target, 'rotation_schemes'),
      greaterThanOrEqualTo(await countIn(source, 'rotation_schemes')),
    );
  }, skip: skipReason, timeout: const Timeout(Duration(minutes: 10)));
}

/// Hands pages back in the order rows were created, which is what
/// `Query.orderAsc($createdAt)` does against the live table.
final class _OrderedRowStore implements AppwriteSyncApi {
  final Map<String, Map<String, Object?>> _rows =
      <String, Map<String, Object?>>{};
  final List<String> _order = <String>[];

  @override
  Future<AppwriteSyncWriteOutcome> upsertRow({
    required String rowId,
    required Map<String, Object?> data,
    required List<String> permissions,
  }) async {
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
