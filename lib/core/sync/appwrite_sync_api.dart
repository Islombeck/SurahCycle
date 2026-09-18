/// The only file in the sync path that talks to `package:appwrite`.
///
/// It holds no rules, exactly like [LiveAppwriteAccountApi]. Its single job is
/// to turn one call into one request and to map the server's answer onto the
/// three outcomes [AppwriteSyncApi] promises — written, already applied, or
/// permanently refused — throwing [SyncTransportException] whenever the answer
/// is simply unknown.
///
/// The classification below is the whole file. Getting it wrong in either
/// direction is expensive: calling a retryable failure permanent quarantines
/// work the user already saw succeed locally, and calling a permanent refusal
/// retryable wedges every later change behind it forever.
library;

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import 'appwrite_sync_gateway.dart';
import 'sync_ports.dart';

final class LiveAppwriteSyncApi implements AppwriteSyncApi {
  LiveAppwriteSyncApi(Client client, {this.databaseId = 'surahcycle'})
    : _tables = TablesDB(client);

  /// Visible for tests that supply their own [TablesDB].
  LiveAppwriteSyncApi.withTables(
    this._tables, {
    this.databaseId = 'surahcycle',
  });

  final TablesDB _tables;

  /// Matches `AppwriteDesiredState.databaseId` in `tool/appwrite_provisioning`.
  final String databaseId;

  static const String tableId = 'sync_log';

  static const int _badRequest = 400;
  static const int _unauthorized = 401;
  static const int _forbidden = 403;
  static const int _notFound = 404;
  static const int _conflict = 409;

  @override
  Future<AppwriteSyncWriteOutcome> upsertRow({
    required String rowId,
    required Map<String, Object?> data,
    required List<String> permissions,
  }) async {
    try {
      await _tables.upsertRow(
        databaseId: databaseId,
        tableId: tableId,
        rowId: rowId,
        data: data,
        permissions: permissions,
      );
      return AppwriteSyncWriteOutcome.written;
    } on Object catch (error) {
      return classifyWriteFailure(error);
    }
  }

  /// What one failed write means. Pure, and deliberately so: the decision is
  /// the valuable part of this file, and it must be testable without a client,
  /// a binding or a network.
  static AppwriteSyncWriteOutcome classifyWriteFailure(Object error) {
    if (error is! AppwriteException) {
      // Offline, DNS, TLS. Unknown, so the entry stays queued.
      throw const SyncTransportException('sync-unreachable');
    }
    switch (error.code) {
      // The unique index on (userId, idempotencyKey) refused a key the account
      // already holds. The change is on the server; this push is a replay and
      // must be acknowledged, not retried.
      case _conflict:
        return AppwriteSyncWriteOutcome.alreadyApplied;
      // A row this server will never accept — a column it does not have, a
      // value outside an enum. No amount of retrying changes that.
      case _badRequest:
        return AppwriteSyncWriteOutcome.rejected;
      // Deliberately retryable, though it is tempting to quarantine: a missing
      // table means the project is not provisioned **yet**, and every queued
      // change would succeed the moment it is. Quarantining here would empty
      // the queue into a corner over a temporary gap.
      case _notFound:
        throw const SyncTransportException('sync-table-missing');
      // The session expired or the row belongs to someone else. Both are
      // resolved by signing in again, never by discarding the change.
      case _unauthorized:
      case _forbidden:
        throw const SyncTransportException('sync-unauthorized');
      default:
        throw SyncTransportException('sync-push-failed-${error.code ?? 0}');
    }
  }

  @override
  Future<AppwriteSyncPage> listRowsAfter({
    required String cursor,
    required int limit,
  }) async {
    try {
      final result = await _tables.listRows(
        databaseId: databaseId,
        tableId: tableId,
        queries: <String>[
          // Server time, not the client's: two devices with skewed clocks
          // would otherwise interleave badly and a page could be skipped.
          Query.orderAsc(r'$updatedAt'),
          Query.limit(limit),
          if (cursor.isNotEmpty) Query.cursorAfter(cursor),
        ],
      );
      return pageOf(result.rows, limit);
    } on Object catch (error) {
      classifyReadFailure(error);
    }
  }

  /// Turns rows into a page. Pure, for the same reason as the classifier.
  static AppwriteSyncPage pageOf(List<models.Row> rows, int limit) =>
      AppwriteSyncPage(
        rows: <Map<String, Object?>>[for (final row in rows) _flatten(row)],
        lastRowId: rows.isEmpty ? null : rows.last.$id,
        // A full page is assumed to have more behind it. Guessing "no more"
        // would end a pull early and leave changes unfetched until something
        // else happened to trigger another.
        hasMore: rows.length >= limit,
      );

  /// Always throws: a failed read has no successful reading.
  static Never classifyReadFailure(Object error) {
    if (error is! AppwriteException) {
      throw const SyncTransportException('sync-unreachable');
    }
    switch (error.code) {
      case _notFound:
        throw const SyncTransportException('sync-table-missing');
      case _unauthorized:
      case _forbidden:
        throw const SyncTransportException('sync-unauthorized');
      default:
        throw SyncTransportException('sync-pull-failed-${error.code ?? 0}');
    }
  }

  /// The gateway reads one flat map, so the row's own `$id` joins its columns.
  ///
  /// `$id` cannot collide with a column: Appwrite reserves the `$` prefix, and
  /// the provisioning declaration uses none.
  static Map<String, Object?> _flatten(models.Row row) => <String, Object?>{
    ...row.data,
    r'$id': row.$id,
  };
}
