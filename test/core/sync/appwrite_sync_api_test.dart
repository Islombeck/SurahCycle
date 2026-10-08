import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';
// Imported directly, not through `sync.dart`: the barrel deliberately keeps
// `package:appwrite` out of everything that only wanted an envelope.
import 'package:murajaah/core/sync/appwrite_sync_api.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The adapter holds one decision, and it is the whole file: which server
/// answers are permanent and which are worth retrying.
///
/// Getting it wrong is expensive in both directions. Calling a retryable
/// failure permanent quarantines work the user already watched succeed
/// locally; calling a permanent refusal retryable wedges every later change
/// behind it forever. So each code is pinned here rather than left to be
/// discovered against a live project.
///
/// The classifier is a pure function on purpose. Constructing Appwrite's
/// `Client` drags in a platform channel and a Flutter binding, and a decision
/// this important should not need either to be examined.
void main() {
  Matcher transportReason(String reason) => throwsA(
    isA<SyncTransportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  group('a failed write: what the server meant', () {
    test('a conflict is the idempotency index doing its job', () {
      expect(
        LiveAppwriteSyncApi.classifyWriteFailure(
          AppwriteException('conflict', 409),
        ),
        AppwriteSyncWriteOutcome.alreadyApplied,
        reason:
            'the account already holds this change; a replay must be '
            'acknowledged, not retried',
      );
    });

    test('a bad request is a row this server will never accept', () {
      expect(
        LiveAppwriteSyncApi.classifyWriteFailure(AppwriteException('bad', 400)),
        AppwriteSyncWriteOutcome.rejected,
      );
    });

    test('a missing table is retryable, though it looks permanent', () {
      // The tempting mistake: quarantine everything because the table is not
      // there. But it means "not provisioned yet", and every queued change
      // succeeds the moment it is.
      expect(
        () => LiveAppwriteSyncApi.classifyWriteFailure(
          AppwriteException('missing', 404),
        ),
        transportReason('sync-table-missing'),
      );
    });

    test('an expired session never discards the change', () {
      for (final code in <int>[401, 403]) {
        expect(
          () => LiveAppwriteSyncApi.classifyWriteFailure(
            AppwriteException('denied', code),
          ),
          transportReason('sync-unauthorized'),
          reason: '$code is resolved by signing in again',
        );
      }
    });

    test('a paused project is not an authorization problem', () {
      // Read off his phone on 2026-10-08: 38 entries stuck since 1 October,
      // every one `sync-unauthorized` — which says "sign in again", and
      // signing in could not have helped. Appwrite Cloud pauses a project for
      // inactivity and then answers **every** request with 403
      // `project_paused`, including the ones that establish a session.
      //
      // Retryable, like a missing table and for the same reason: the project
      // comes back and every queued change succeeds the moment it does.
      expect(
        () => LiveAppwriteSyncApi.classifyWriteFailure(
          AppwriteException('paused', 403, 'project_paused'),
        ),
        transportReason('sync-project-paused'),
      );
    });

    test('an unrecognised code is retried, not assumed permanent', () {
      expect(
        () => LiveAppwriteSyncApi.classifyWriteFailure(
          AppwriteException('boom', 500),
        ),
        transportReason('sync-push-failed-500'),
      );
    });

    test('being offline is unknown, so the entry stays queued', () {
      expect(
        () => LiveAppwriteSyncApi.classifyWriteFailure(
          const SocketException('no route'),
        ),
        transportReason('sync-unreachable'),
      );
    });
  });

  group('a failed read has no successful reading', () {
    test('a missing table is retryable here too', () {
      expect(
        () => LiveAppwriteSyncApi.classifyReadFailure(
          AppwriteException('missing', 404),
        ),
        transportReason('sync-table-missing'),
      );
    });

    test('an expired session is retryable', () {
      expect(
        () => LiveAppwriteSyncApi.classifyReadFailure(
          AppwriteException('denied', 401),
        ),
        transportReason('sync-unauthorized'),
      );
    });

    test('a paused project is told apart here too', () {
      expect(
        () => LiveAppwriteSyncApi.classifyReadFailure(
          AppwriteException('paused', 403, 'project_paused'),
        ),
        transportReason('sync-project-paused'),
      );
    });

    test('anything else keeps its code for the journal', () {
      expect(
        () => LiveAppwriteSyncApi.classifyReadFailure(
          AppwriteException('boom', 503),
        ),
        transportReason('sync-pull-failed-503'),
      );
    });

    test('being offline is unknown', () {
      expect(
        () => LiveAppwriteSyncApi.classifyReadFailure(
          const SocketException('no route'),
        ),
        transportReason('sync-unreachable'),
      );
    });
  });

  group('turning rows into a page', () {
    test('the row id joins its columns, and the cursor is the last row', () {
      final page = LiveAppwriteSyncApi.pageOf(<models.Row>[
        _row('a'),
        _row('b'),
      ], 10);

      expect(page.rows, hasLength(2));
      expect(page.rows.first[r'$id'], 'a');
      expect(page.rows.first['userId'], 'user-1');
      expect(page.lastRowId, 'b');
    });

    test('a full page is assumed to have more behind it', () {
      expect(
        LiveAppwriteSyncApi.pageOf(<models.Row>[
          _row('a'),
          _row('b'),
        ], 2).hasMore,
        isTrue,
        reason:
            'guessing "no more" would end a pull early and leave changes '
            'unfetched until something else happened to start another',
      );
      expect(
        LiveAppwriteSyncApi.pageOf(<models.Row>[
          _row('a'),
          _row('b'),
        ], 5).hasMore,
        isFalse,
      );
    });

    test('an empty page reports no cursor rather than an invented one', () {
      final page = LiveAppwriteSyncApi.pageOf(const <models.Row>[], 10);

      expect(page.rows, isEmpty);
      expect(page.lastRowId, isNull);
      expect(page.hasMore, isFalse);
    });
  });

  test('no failure reason carries anything but a category', () {
    for (final error in <Object>[
      AppwriteException('user history leaked here', 500),
      const SocketException('10.0.0.1 unreachable'),
    ]) {
      try {
        LiveAppwriteSyncApi.classifyWriteFailure(error);
        fail('expected a transport exception');
      } on SyncTransportException catch (thrown) {
        expect(RegExp(r'^[a-z0-9-]+$').hasMatch(thrown.reason), isTrue);
        expect(thrown.reason, isNot(contains('leaked')));
        expect(thrown.reason, isNot(contains('10.0.0.1')));
      }
    }
  });
}

models.Row _row(String id) => models.Row(
  $id: id,
  $sequence: '1',
  $tableId: 'sync_log',
  $databaseId: 'surahcycle',
  $createdAt: '2026-09-18T06:00:00.000Z',
  $updatedAt: '2026-09-18T07:00:00.000Z',
  $permissions: const <String>[],
  data: <String, dynamic>{'userId': 'user-1', 'entityId': id},
);
