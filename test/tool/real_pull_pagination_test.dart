import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The second phone taking a full account down, **one page at a time** — the
/// way the app does it, rather than in one heap the way a test can afford to.
///
/// `real_two_device_merge_test.dart` hands the router every envelope at once,
/// so it can always put a prerequisite before its dependant. A device pulls
/// pages of a hundred, in the order the account happens to hold them, and a
/// page cannot be sorted into containing something that is not in it.
///
///     $env:MURAJAAH_SOURCE_DB = '<path>\main-phone.sqlite'
///     $env:MURAJAAH_TARGET_DB = '<path>\second-phone.sqlite'
///     flutter test test/tool/real_pull_pagination_test.dart
///
/// Both are written to, so both must be pulled copies.
void main() {
  final sourcePath = Platform.environment['MURAJAAH_SOURCE_DB'];
  final targetPath = Platform.environment['MURAJAAH_TARGET_DB'];
  final skipReason = sourcePath == null || targetPath == null
      ? 'Set MURAJAAH_SOURCE_DB and MURAJAAH_TARGET_DB.'
      : null;

  test('a real account arrives on a real second phone, page by page', () async {
    final source = AppDatabase(NativeDatabase(File(sourcePath!)));
    addTearDown(source.close);
    final target = AppDatabase(NativeDatabase(File(targetPath!)));
    addTearDown(target.close);

    final owner = SyncOwnerKey.user('two-device-pagination');
    final cloud = _OrderedRowStore();

    // The account, as his first phone filled it.
    final sourceOutbox = InMemorySyncOutbox();
    var ids = 0;
    await DriftSyncBackfill(
      database: source,
      outbox: sourceOutbox,
      deviceId: () async => 'main-phone',
      newId: () => 'first-${++ids}',
    ).enqueueEverything(nowUtc: DateTime.now().toUtc());
    final pushed = await AppwriteSyncGateway(
      api: cloud,
      userId: owner.value,
    ).push(<SyncEnvelope>[
      for (final entry in await sourceOutbox.peek(limit: 100000)) entry.envelope,
    ]);
    expect(pushed.rejectedEnvelopeIds, isEmpty);
    // ignore: avoid_print
    print('account holds ${cloud.length} records');

    // The second phone, exactly as the app drives it.
    final store = DriftSyncStore(target, owner: owner);
    await store.recordActivationChoice(
      choice: SyncActivationChoice.merge,
      backupId: 'pagination-probe',
      decidedAtUtc: DateTime.now().toUtc(),
    );
    final cycle = SyncCycleRunner(
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
    );

    final outcome = await cycle.runOnce();
    // ignore: avoid_print
    print(
      'pushed ${outcome.pushedCount}, pages ${outcome.pulledPageCount}, '
      'failure ${outcome.failureReason}',
    );

    expect(
      outcome.failureReason,
      isNull,
      reason:
          'a pull that stalls on its own page boundary never recovers: the '
          'cursor stays, the same page is fetched again, and the owner is told '
          'nothing at all',
    );

    Future<int> countIn(String table) async =>
        (await target.customSelect('SELECT count(*) AS n FROM $table')
                .getSingle())
            .read<int>('n');
    // ignore: avoid_print
    print(
      'second phone now holds: recitations ${await countIn('recitation_events')}'
      ', sessions ${await countIn('prayer_sessions')}'
      ', surahs ${await countIn('mastered_surahs')}',
    );
    expect(await countIn('recitation_events'), greaterThan(0));
  }, skip: skipReason, timeout: const Timeout(Duration(minutes: 10)));
}

/// Hands pages back in the order rows were created, which is what
/// `Query.orderAsc($createdAt)` does against the live table.
final class _OrderedRowStore implements AppwriteSyncApi {
  final Map<String, Map<String, Object?>> _rows =
      <String, Map<String, Object?>>{};
  final List<String> _order = <String>[];

  int get length => _order.length;

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
