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

  /// Appwrite Cloud pauses a project that has gone unused, and then answers
  /// every request to it with 403 and this type.
  ///
  /// Read by **type**, because the code it arrives with is also the code for an
  /// ordinary refusal — and the two need opposite words. His phone held 38
  /// entries stuck since 2026-10-01, every one filed as `sync-unauthorized`,
  /// whose whole meaning is "sign in again"; signing in could not have helped,
  /// because that is a request to the same paused project.
  static const String _projectPausedType = 'project_paused';

  static bool _isProjectPaused(AppwriteException error) =>
      error.type == _projectPausedType;

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
    // Before the codes, because this one arrives as a 403 and means something
    // else entirely. Retryable, exactly like a missing table: the project comes
    // back and every queued change succeeds the moment it does.
    if (_isProjectPaused(error)) {
      throw const SyncTransportException('sync-project-paused');
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
          //
          // **Creation, not update.** A row here is written once and never
          // rewritten, so the two are the same instant — but ordering by the
          // one that *can* move is what stranded a cursor when rows were
          // rewritten, and naming the immutable one keeps that impossible
          // rather than merely untrue today. See `AppwriteSyncGateway`.
          Query.orderAsc(r'$createdAt'),
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
    if (_isProjectPaused(error)) {
      throw const SyncTransportException('sync-project-paused');
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
