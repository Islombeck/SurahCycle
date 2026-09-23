import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_envelope_router.dart';
import 'package:murajaah/core/sync/sync.dart';

import '../../tool/appwrite_provisioning.dart';

/// Two **real** device databases and one account: his phone's history arriving
/// on his second phone, which is not empty.
///
/// `two_device_sync_test.dart` builds both devices from fixtures. This uses the
/// two databases that actually exist — a year of use on one, an old install
/// with its own learning plans on the other — and the part that matters most to
/// the owner is the second assertion: **receiving a history does not cost him
/// what the receiving phone already had.**
///
///     $env:MURAJAAH_SOURCE_DB = '<path>\main-phone.sqlite'
///     $env:MURAJAAH_TARGET_DB = '<path>\second-phone.sqlite'
///     flutter test test/tool/real_two_device_merge_test.dart
///
/// Both are written to, so both must be pulled copies.
void main() {
  final sourcePath = Platform.environment['MURAJAAH_SOURCE_DB'];
  final targetPath = Platform.environment['MURAJAAH_TARGET_DB'];
  final skipReason = sourcePath == null || targetPath == null
      ? 'Set MURAJAAH_SOURCE_DB and MURAJAAH_TARGET_DB.'
      : null;

  test('his history arrives, and the second phone keeps its own', () async {
    for (final path in <String>[sourcePath!, targetPath!]) {
      expect(
        path.contains('/data/data/') || path.contains(r'\data\data\'),
        isFalse,
        reason: 'both are written to; point them at pulled copies',
      );
      expect(File(path).existsSync(), isTrue, reason: 'no such file: $path');
    }

    final source = AppDatabase(NativeDatabase(File(sourcePath)));
    addTearDown(source.close);
    final target = AppDatabase(NativeDatabase(File(targetPath)));
    addTearDown(target.close);

    Future<int> countIn(AppDatabase database, String table) async =>
        (await database
                .customSelect('SELECT count(*) AS n FROM $table')
                .getSingle())
            .read<int>('n');

    final plansBefore = await countIn(target, 'learning_surahs');
    final eventsBefore = await countIn(target, 'learning_events');
    final targetSurahsBefore = await countIn(target, 'mastered_surahs');
    expect(
      plansBefore,
      greaterThan(0),
      reason: 'the point of this test is a second phone that is not empty',
    );

    // Everything his phone would offer an account.
    final outbox = InMemorySyncOutbox();
    var ids = 0;
    final report = await DriftSyncBackfill(
      database: source,
      outbox: outbox,
      deviceId: () async => 'main-phone',
      newId: () => 'envelope-${++ids}',
    ).enqueueEverything(nowUtc: DateTime.now().toUtc());
    expect(report.skippedCount, 0);

    // Across the wire in the only form these ever travel in, and through a
    // server double that accepts exactly what the live table accepts.
    const owner = 'user-two-device';
    final api = _StrictRowStore();
    final gateway = AppwriteSyncGateway(api: api, userId: owner);
    final pushed = await gateway.push(<SyncEnvelope>[
      for (final entry in await outbox.peek(limit: 100000)) entry.envelope,
    ]);
    expect(pushed.rejectedEnvelopeIds, isEmpty);

    final received = <SyncEnvelope>[];
    var cursor = SyncCursor.beginning;
    while (true) {
      final page = await gateway.pull(after: cursor, limit: 200);
      received.addAll(page.envelopes);
      if (!page.hasMore) break;
      cursor = page.cursor;
    }

    final router = SyncEnvelopeRouter(target);
    final refusals = <String>[];
    for (final envelope in router.inDependencyOrder(received)) {
      try {
        await target.transaction(() => router.apply(envelope));
      } on Object catch (error) {
        refusals.add('${envelope.entityType.name}: $error');
      }
    }
    await target.transaction(router.settleProjection);
    if (refusals.isNotEmpty) {
      // ignore: avoid_print
      print(refusals.toSet().join('\n'));
    }
    expect(
      refusals,
      isEmpty,
      reason: 'a record his second phone cannot take is a record he loses',
    );

    final arrived = <String, int>{
      for (final table in <String>[
        'recitation_events',
        'prayer_sessions',
        'mastered_surahs',
        'rotation_schemes',
        'prayer_routine_part_templates',
      ])
        table: await countIn(target, table),
    };
    // ignore: avoid_print
    print('second phone after the merge: $arrived');

    final aliveOnSource =
        (await source
                .customSelect(
                  'SELECT count(*) AS n FROM recitation_events '
                  'WHERE deleted_at_utc IS NULL',
                )
                .getSingle())
            .read<int>('n');
    expect(
      arrived['recitation_events'],
      aliveOnSource,
      reason: 'every prayer he still holds has to be on the second phone too',
    );
    expect(
      await countIn(source, 'recitation_events'),
      greaterThan(aliveOnSource),
      reason:
          'his history contains withdrawals — 106 of 824 — so the next '
          'assertion is about something that really happens',
    );
    expect(
      await countIn(target, 'recitation_events'),
      aliveOnSource,
      reason:
          'a withdrawal for a record this phone never had creates nothing: '
          'inventing a row so it can be marked deleted would put a prayer in '
          'its journal that never happened here',
    );
    expect(
      arrived['prayer_sessions'],
      await countIn(source, 'prayer_sessions'),
    );
    expect(
      arrived['mastered_surahs'],
      greaterThanOrEqualTo(await countIn(source, 'mastered_surahs')),
    );

    expect(
      await countIn(target, 'learning_surahs'),
      plansBefore + await countIn(source, 'learning_surahs'),
      reason:
          'the second phone had learning plans of its own and keeps every one '
          'of them, gaining his — a merge that quietly dropped either side '
          'would be the loss this whole feature exists to prevent',
    );
    expect(
      await countIn(target, 'learning_events'),
      eventsBefore + await countIn(source, 'learning_events'),
    );
    expect(
      arrived['mastered_surahs'],
      greaterThanOrEqualTo(targetSurahsBefore),
      reason: 'and its own surahs are still there as well',
    );
  }, skip: skipReason);
}

/// Accepts exactly what the live table accepts, and nothing more.
final class _StrictRowStore implements AppwriteSyncApi {
  static final RegExp _rowId = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$');
  static final List<AppwriteColumn> _columns = AppwriteDesiredState.syncColumns;

  final Map<String, Map<String, Object?>> _rows =
      <String, Map<String, Object?>>{};
  final List<String> _order = <String>[];

  @override
  Future<AppwriteSyncWriteOutcome> upsertRow({
    required String rowId,
    required Map<String, Object?> data,
    required List<String> permissions,
  }) async {
    if (!_rowId.hasMatch(rowId)) return AppwriteSyncWriteOutcome.rejected;
    for (final column in _columns) {
      final value = data[column.key];
      if (column.required && value == null) {
        return AppwriteSyncWriteOutcome.rejected;
      }
      if (value is! String) continue;
      final size = column.size;
      if (size != null && value.length > size) {
        return AppwriteSyncWriteOutcome.rejected;
      }
      if (column.elements.isNotEmpty && !column.elements.contains(value)) {
        return AppwriteSyncWriteOutcome.rejected;
      }
    }
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
