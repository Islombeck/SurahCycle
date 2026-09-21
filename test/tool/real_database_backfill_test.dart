import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_envelope_router.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Runs the backfill against a **copy** of a real device database and says what
/// would travel, what would not, and why.
///
/// Every other test here builds the history it examines, which means every
/// other test examines a history this project knows how to build. A phone that
/// has been in use for a year holds rows written by older versions of the app,
/// under invariants that have since been tightened — and the only way to learn
/// whether those still express is to try them. This is how the prayer-session
/// refusal was confirmed against real data rather than argued about.
///
/// Skipped unless pointed at a file, so it costs nothing in an ordinary run:
///
///     $env:MURAJAAH_DRY_RUN_DB = '<path>\copy.sqlite'
///     flutter test test/tool/real_database_backfill_test.dart
///
/// It **writes** — an outbox is a table — so it refuses a path that looks like
/// a live device file. Pull a copy first; `docs/AI_HANDOFF.md` has the command.
void main() {
  final path = Platform.environment['MURAJAAH_DRY_RUN_DB'];
  final skipReason = path == null
      ? 'Set MURAJAAH_DRY_RUN_DB to a pulled copy of a device database.'
      : null;

  /// Everything the backfill would send from the copy, in queue order.
  Future<List<SyncEnvelope>> whatWouldTravel(AppDatabase database) async {
    final outbox = InMemorySyncOutbox();
    var ids = 0;
    final report = await DriftSyncBackfill(
      database: database,
      outbox: outbox,
      deviceId: () async => 'dry-run',
      newId: () => 'dry-${++ids}',
    ).enqueueEverything(nowUtc: DateTime.now().toUtc());
    expect(report.skippedCount, 0, reason: 'nothing may be left behind');
    return <SyncEnvelope>[
      for (final entry in await outbox.peek(limit: 100000)) entry.envelope,
    ];
  }

  test('a real history reaches the account in full', () async {
    expect(
      path!.contains('/data/data/') || path.contains(r'\data\data\'),
      isFalse,
      reason: 'this writes; point it at a pulled copy, never at the phone',
    );
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'no such file: $path');

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final outbox = InMemorySyncOutbox();
    var ids = 0;
    final backfill = DriftSyncBackfill(
      database: database,
      outbox: outbox,
      deviceId: () async => 'dry-run',
      newId: () => 'dry-${++ids}',
    );

    final report = await backfill.enqueueEverything(
      nowUtc: DateTime.now().toUtc(),
    );

    final summary = <String>[
      for (final type in SyncEntityType.values)
        if ((report.enqueuedByType[type] ?? 0) > 0 ||
            (report.skippedByType[type] ?? 0) > 0)
          '${type.name}: sent ${report.enqueuedByType[type] ?? 0}'
              '${(report.skippedByType[type] ?? 0) == 0 ? '' : ', LEFT BEHIND ${report.skippedByType[type]} '
                        '(${report.skippedFields[type]?.join(', ')})'}',
    ];
    // Printed either way: the counts are the point of running this at all.
    // ignore: avoid_print
    print(summary.join('\n'));

    expect(
      report.skippedCount,
      0,
      reason:
          'a backfill that sends most of a history is the one failure this '
          'feature cannot recover from on its own — the fields named above '
          'are where it refused',
    );
    expect(
      report.enqueuedCount,
      greaterThan(0),
      reason: 'a real database that offered nothing would mean a broken walk',
    );
  }, skip: skipReason);

  test('and a second device can apply every one of them', () async {
    // The other half, and the one that models his next phone. The backfill
    // producing an envelope proves this device can describe a record; it
    // proves nothing about whether another device can write it down. These
    // are real rows, so the payloads carry whatever a year of use actually
    // put in them rather than whatever a test would have thought to.
    final source = AppDatabase(NativeDatabase(File(path!)));
    addTearDown(source.close);
    final envelopes = await whatWouldTravel(source);

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    // A new phone ships with the corpus and refreshes it by manifest. Sync
    // never carries it — a Quran is not user data to be merged — and the
    // appliers refuse a record about a surah they have never heard of, which
    // is the correct refusal rather than an obstacle to work around.
    await SurahRepository(fresh).getRotationSnapshot();
    final catalogue = await source.select(source.surahMetadata).get();
    await fresh.batch(
      (batch) => batch.insertAll(fresh.surahMetadata, catalogue),
    );

    // Through the real cloud mapping on the way, because that is the only form
    // these ever reach another device in. `AppwriteSyncGateway` turns an
    // envelope into a row and back, and that layer had never seen a payload a
    // year of real use produced — only ones a test wrote for it.
    const owner = 'user-dry-run';
    final api = _RowStore();
    final gateway = AppwriteSyncGateway(api: api, userId: owner);
    final pushed = await gateway.push(envelopes);
    expect(
      pushed.rejectedEnvelopeIds,
      isEmpty,
      reason: 'the account refuses nothing it will later be asked to return',
    );

    final overTheWire = <SyncEnvelope>[];
    var cursor = SyncCursor.beginning;
    while (true) {
      final page = await gateway.pull(after: cursor, limit: 200);
      overTheWire.addAll(page.envelopes);
      if (!page.hasMore) break;
      cursor = page.cursor;
    }
    expect(
      overTheWire.map((one) => one.entityKey).toSet(),
      envelopes.map((one) => one.entityKey).toSet(),
      reason: 'nothing may be lost or renamed in the crossing',
    );

    final router = SyncEnvelopeRouter(fresh);
    final ordered = router.inDependencyOrder(overTheWire);
    final refusals = <String>[];
    for (final envelope in ordered) {
      try {
        await fresh.transaction(() => router.apply(envelope));
      } on Object catch (error) {
        // Collected rather than thrown on the first one: the useful output
        // is every kind of refusal at once, not the earliest.
        refusals.add('${envelope.entityType.name}: $error');
      }
    }
    // The router batches the rotation rebuild, so the caller settles it. A
    // real pull does this once per page, inside the page's transaction.
    await fresh.transaction(router.settleProjection);

    if (refusals.isNotEmpty) {
      // ignore: avoid_print
      print(refusals.toSet().join('\n'));
      final diagnosis = await fresh
          .customSelect(
            'SELECT e.surah_id AS s, COUNT(*) AS n, '
            'SUM(CASE WHEN e.deleted_at_utc IS NULL THEN 1 ELSE 0 END) AS alive, '
            '(SELECT COUNT(*) FROM recitation_event_parts p '
            'WHERE p.event_id = e.id) AS covered '
            'FROM recitation_events e GROUP BY e.surah_id '
            'ORDER BY e.surah_id LIMIT 5',
          )
          .get();
      // ignore: avoid_print
      print('fresh device: ${diagnosis.map((r) => '${r.data}').join(' | ')}');
    }
    expect(
      refusals,
      isEmpty,
      reason: 'a record his phone can send is a record his next one must take',
    );

    expect(
      (await RecitationRepository(fresh).getHistory(limit: 100000)).length,
      (await RecitationRepository(source).getHistory(limit: 100000)).length,
      reason: 'and the same number of them, not most of them',
    );
    expect(
      (await RecitationRepository(
        fresh,
      ).getHistory(limit: 100000, includeDeleted: true)).length,
      lessThan(
        (await RecitationRepository(
          source,
        ).getHistory(limit: 100000, includeDeleted: true)).length,
      ),
      reason:
          'a withdrawn recitation the new device never held is not recreated '
          'so it can be marked gone — there is nothing there to mark, and a '
          'row whose only purpose is to be deleted is not history',
    );
  }, skip: skipReason);
}

/// The account's table, as far as the gateway can tell.
///
/// One row per entity, replaced on write and handed back oldest change first,
/// which is what the real one does. It exists so the *gateway's* own mapping —
/// dates to strings, payload to JSON, enums to names — is exercised by real
/// payloads rather than by rows a test wrote to match it.
final class _RowStore implements AppwriteSyncApi {
  final Map<String, Map<String, Object?>> _rowsById =
      <String, Map<String, Object?>>{};
  final List<String> _order = <String>[];

  @override
  Future<AppwriteSyncWriteOutcome> upsertRow({
    required String rowId,
    required Map<String, Object?> data,
    required List<String> permissions,
  }) async {
    if (!_rowsById.containsKey(rowId)) _order.add(rowId);
    _rowsById[rowId] = <String, Object?>{...data, r'$id': rowId};
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
      rows: <Map<String, Object?>>[for (final id in ids) _rowsById[id]!],
      lastRowId: ids.isEmpty ? null : ids.last,
      hasMore: start + ids.length < _order.length,
    );
  }
}
