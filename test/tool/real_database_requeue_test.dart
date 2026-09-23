import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';

import '../../tool/appwrite_provisioning.dart';

/// Runs the recovery the owner is being asked to press, on a **copy** of his
/// database, against a server double as strict as the real one.
///
/// He activated sync on a build whose row ids the server refused for every
/// record with a colon in its identifier, so 112 of his prayer sessions,
/// schemes and routines sit in quarantine. The fix shipped; the button that
/// releases them shipped; asking him to press it without knowing whether it
/// works would be asking him to run the experiment.
///
///     $env:MURAJAAH_REQUEUE_DB = '<path>\copy.sqlite'
///     $env:MURAJAAH_REQUEUE_OWNER = '<his user id>'
///     flutter test test/tool/real_database_requeue_test.dart
///
/// It writes, so it refuses a device path. Pull a copy first.
void main() {
  final path = Platform.environment['MURAJAAH_REQUEUE_DB'];
  final ownerId = Platform.environment['MURAJAAH_REQUEUE_OWNER'];
  final skipReason = path == null || ownerId == null
      ? 'Set MURAJAAH_REQUEUE_DB and MURAJAAH_REQUEUE_OWNER.'
      : null;

  test('every refused record is accepted the second time', () async {
    expect(
      path!.contains('/data/data/') || path.contains(r'\data\data\'),
      isFalse,
      reason: 'this writes; point it at a pulled copy, never at the phone',
    );
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'no such file: $path');

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final store = DriftSyncStore(database, owner: SyncOwnerKey.user(ownerId!));

    final refusedBefore = await store.outbox.quarantined(limit: 10000);
    // ignore: avoid_print
    print('quarantined before: ${refusedBefore.length}');
    expect(
      refusedBefore,
      isNotEmpty,
      reason: 'nothing to recover in this copy; point it at one that has some',
    );

    final requeued = await store.outbox.requeueQuarantined();
    // ignore: avoid_print
    print('requeued: $requeued');
    expect(await store.outbox.quarantined(), isEmpty);

    final pending = await store.outbox.peek(limit: 10000);
    final api = _StrictRowStore();
    final gateway = AppwriteSyncGateway(api: api, userId: ownerId);
    final result = await gateway.push(<SyncEnvelope>[
      for (final entry in pending) entry.envelope,
    ]);

    final byType = <String, int>{};
    for (final entry in pending) {
      final type = entry.envelope.entityType.name;
      byType[type] = (byType[type] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('pushed: $byType');

    expect(
      result.rejectedEnvelopeIds,
      isEmpty,
      reason:
          'these are the records the server refused the first time; if it '
          'would refuse them again the button is asking him to watch it fail',
    );
    expect(result.acceptedEnvelopeIds, hasLength(pending.length));
  }, skip: skipReason);
}

/// Accepts exactly what the live table accepts, and nothing more.
final class _StrictRowStore implements AppwriteSyncApi {
  static final RegExp _rowId = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$');
  static final List<AppwriteColumn> _columns = AppwriteDesiredState.syncColumns;

  final Map<String, Map<String, Object?>> rows =
      <String, Map<String, Object?>>{};

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
    rows[rowId] = <String, Object?>{...data, r'$id': rowId};
    return AppwriteSyncWriteOutcome.written;
  }

  @override
  Future<AppwriteSyncPage> listRowsAfter({
    required String cursor,
    required int limit,
  }) async => AppwriteSyncPage(
    rows: const <Map<String, Object?>>[],
    lastRowId: null,
    hasMore: false,
  );
}
