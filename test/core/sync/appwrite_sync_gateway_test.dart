import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Stage J §6.4: the gateway that moves envelopes to and from an account.
///
/// Nothing here touches a network. Every rule that matters — what an envelope
/// becomes on the wire, what counts as already-applied, what may be retried,
/// and what must stall rather than be skipped — is decided in the gateway, so
/// it can be pinned here instead of discovered against a live project.
void main() {
  const owner = 'user-1';
  final createdAt = DateTime.utc(2026, 9, 18, 6);
  final updatedAt = DateTime.utc(2026, 9, 18, 7);

  SyncEnvelope envelopeOf({
    String id = 'envelope-1',
    String entityId = 'entity-1',
    SyncOperation operation = SyncOperation.upsert,
    Map<String, Object?> payload = const <String, Object?>{'surahId': 's-112'},
    String? userId,
  }) => SyncEnvelope(
    id: id,
    deviceId: 'device-1',
    entityType: SyncEntityType.recitationEvent,
    entityId: entityId,
    operation: operation,
    schemaVersion: 9,
    createdAtUtc: createdAt,
    updatedAtUtc: updatedAt,
    idempotencyKey: 'key-$id',
    userId: userId,
    payload: operation == SyncOperation.delete
        ? const <String, Object?>{}
        : payload,
  );

  Map<String, Object?> rowOf({
    String id = 'entity-1',
    String entityType = 'recitationEvent',
    String operation = 'upsert',
    Object? payload = '{"surahId":"s-112"}',
    Object? schemaVersion = 9,
  }) => <String, Object?>{
    r'$id': id,
    'userId': owner,
    'deviceId': 'device-1',
    'entityType': entityType,
    'entityId': id,
    'operation': operation,
    'schemaVersion': schemaVersion,
    'createdAtUtc': createdAt.toIso8601String(),
    'updatedAtUtc': updatedAt.toIso8601String(),
    'idempotencyKey': 'key-1',
    'payload': payload,
  };

  group('the row an envelope is written to', () {
    // TablesDB states the rule on `rowId` itself: «Valid chars are a-z, A-Z,
    // 0-9, period, hyphen, and underscore. Can't start with a special char.
    // Max length is 36 chars.» A row id that breaks it comes back 400, which
    // this client reads — correctly — as a permanent refusal and quarantines.
    final valid = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$');

    test('an identifier this app uses would not have been accepted', () {
      // Not a hypothetical: these two are his, read off his device. The first
      // carries colons, the second is 42 characters long.
      expect(valid.hasMatch('routine-session:2026-09-22:witr:qada'), isFalse);
      expect(
        valid.hasMatch('routine-session:2026-09-22:jumuah:ordinary'),
        isFalse,
      );
    });

    test('every entity type this app can send produces a legal row id', () {
      for (final type in SyncEntityType.values) {
        final id = AppwriteSyncGateway.rowIdFor(
          userId: 'a-very-long-account-identifier-0123456789',
          envelope: SyncEnvelope(
            id: 'envelope-1',
            deviceId: 'device-1',
            entityType: type,
            entityId: 'routine-session:2026-09-22:jumuah:ordinary',
            operation: SyncOperation.upsert,
            schemaVersion: 9,
            createdAtUtc: createdAt,
            updatedAtUtc: updatedAt,
            idempotencyKey: 'key-1',
            payload: const <String, Object?>{'a': 1},
          ),
        );
        expect(valid.hasMatch(id), isTrue, reason: '${type.name} → $id');
      }
    });

    test('the same entity always names the same row', () {
      expect(
        AppwriteSyncGateway.rowIdFor(userId: owner, envelope: envelopeOf()),
        AppwriteSyncGateway.rowIdFor(
          userId: owner,
          envelope: envelopeOf(id: 'envelope-2'),
        ),
        reason:
            'a second push of one entity must replace the first row, not add '
            'another — the envelope id and the idempotency key differ between '
            'those two pushes and must not reach the row id',
      );
    });

    test('two accounts never contend for one row', () {
      expect(
        AppwriteSyncGateway.rowIdFor(userId: 'user-a', envelope: envelopeOf()),
        isNot(
          AppwriteSyncGateway.rowIdFor(
            userId: 'user-b',
            envelope: envelopeOf(),
          ),
        ),
        reason:
            'row ids are unique across the whole table, and «surah-112» is the '
            "same string in everyone's database",
      );
    });

    test('two entity types with one id are two rows', () {
      String idFor(SyncEntityType type) => AppwriteSyncGateway.rowIdFor(
        userId: owner,
        envelope: SyncEnvelope(
          id: 'envelope-1',
          deviceId: 'device-1',
          entityType: type,
          entityId: 'surah-112',
          operation: SyncOperation.upsert,
          schemaVersion: 9,
          createdAtUtc: createdAt,
          updatedAtUtc: updatedAt,
          idempotencyKey: 'key-1',
          payload: const <String, Object?>{'a': 1},
        ),
      );

      expect(
        idFor(SyncEntityType.masteredSurah),
        isNot(idFor(SyncEntityType.rotationScheme)),
        reason: 'a surah is mastered and also has a scheme, under one id',
      );
    });

    test('the parts cannot be run together into the same id', () {
      expect(
        AppwriteSyncGateway.rowIdFor(
          userId: 'ab',
          envelope: envelopeOf(entityId: 'c'),
        ),
        isNot(
          AppwriteSyncGateway.rowIdFor(
            userId: 'a',
            envelope: envelopeOf(entityId: 'bc'),
          ),
        ),
      );
    });
  });

  group('pushing', () {
    test('one row per entity, carrying the whole envelope', () async {
      final api = _FakeSyncApi();
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      final result = await gateway.push(<SyncEnvelope>[envelopeOf()]);

      expect(result.acceptedEnvelopeIds, <String>['envelope-1']);
      expect(result.rejectedEnvelopeIds, isEmpty);
      final write = api.writes.single;
      expect(
        write.rowId,
        AppwriteSyncGateway.rowIdFor(userId: owner, envelope: envelopeOf()),
        reason:
            'addressing one entity by one row is what makes a retry a '
            'replacement rather than a duplicate',
      );
      expect(write.data['userId'], owner);
      expect(write.data['entityType'], 'recitationEvent');
      expect(write.data['schemaVersion'], 9);
      expect(write.data['idempotencyKey'], 'key-envelope-1');
      expect(jsonDecode(write.data['payload']! as String), <String, Object?>{
        'surahId': 's-112',
      });
    });

    test('a tombstone carries no payload at all', () async {
      final api = _FakeSyncApi();
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      await gateway.push(<SyncEnvelope>[
        envelopeOf(operation: SyncOperation.delete),
      ]);

      expect(
        api.writes.single.data['payload'],
        isNull,
        reason:
            'writing an empty object instead would make "deleted" and '
            '"deleted with empty content" indistinguishable',
      );
    });

    test('rows are permitted to their owner and to nobody else', () async {
      final api = _FakeSyncApi();
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      await gateway.push(<SyncEnvelope>[envelopeOf()]);

      expect(api.writes.single.permissions, <String>[
        'read("user:$owner")',
        'update("user:$owner")',
        'delete("user:$owner")',
      ]);
      for (final permission in api.writes.single.permissions) {
        expect(permission, isNot(contains('any')));
        expect(permission, isNot(contains('users')));
      }
    });

    test(
      'an already-applied replay is accepted, not retried forever',
      () async {
        final api = _FakeSyncApi(
          outcome: AppwriteSyncWriteOutcome.alreadyApplied,
        );
        final gateway = AppwriteSyncGateway(api: api, userId: owner);

        final result = await gateway.push(<SyncEnvelope>[envelopeOf()]);

        expect(
          result.acceptedEnvelopeIds,
          <String>['envelope-1'],
          reason:
              'the server already holds it; treating that as a failure is '
              'how a queue gets stuck on work that is already done',
        );
        expect(result.rejectedEnvelopeIds, isEmpty);
      },
    );

    test(
      'a permanent refusal is reported for quarantine, not acceptance',
      () async {
        final api = _FakeSyncApi(outcome: AppwriteSyncWriteOutcome.rejected);
        final gateway = AppwriteSyncGateway(api: api, userId: owner);

        final result = await gateway.push(<SyncEnvelope>[envelopeOf()]);

        expect(result.acceptedEnvelopeIds, isEmpty);
        expect(result.rejectedEnvelopeIds, <String>['envelope-1']);
        expect(result.rejectionReason, isNotNull);
      },
    );

    test('a transport failure propagates rather than being called success', () {
      final api = _FakeSyncApi(
        failure: const SyncTransportException('offline'),
      );
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      expect(
        () => gateway.push(<SyncEnvelope>[envelopeOf()]),
        throwsA(isA<SyncTransportException>()),
      );
    });

    test('an envelope owned by another account is refused outright', () {
      final api = _FakeSyncApi();
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      expect(
        () => gateway.push(<SyncEnvelope>[envelopeOf(userId: 'someone-else')]),
        throwsStateError,
        reason:
            'signing out of A and into B must never push A\'s history '
            'under B\'s permissions',
      );
      expect(api.writes, isEmpty);
    });
  });

  group('pulling', () {
    test(
      'rows become envelopes, and the cursor follows the last one',
      () async {
        final api = _FakeSyncApi(
          page: AppwriteSyncPage(
            rows: <Map<String, Object?>>[
              rowOf(),
              rowOf(id: 'entity-2'),
            ],
            lastRowId: 'entity-2',
            hasMore: true,
          ),
        );
        final gateway = AppwriteSyncGateway(api: api, userId: owner);

        final page = await gateway.pull(after: SyncCursor.beginning);

        expect(page.envelopes.map((envelope) => envelope.entityId), <String>[
          'entity-1',
          'entity-2',
        ]);
        expect(page.envelopes.first.payload, <String, Object?>{
          'surahId': 's-112',
        });
        expect(page.envelopes.first.createdAtUtc.isUtc, isTrue);
        expect(page.cursor.value, 'entity-2');
        expect(page.hasMore, isTrue);
      },
    );

    test('an empty page leaves the cursor exactly where it was', () async {
      final api = _FakeSyncApi(
        page: AppwriteSyncPage(
          rows: const <Map<String, Object?>>[],
          lastRowId: null,
          hasMore: false,
        ),
      );
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      final page = await gateway.pull(after: const SyncCursor('entity-9'));

      expect(page.envelopes, isEmpty);
      expect(
        page.cursor.value,
        'entity-9',
        reason:
            'advancing past nothing is harmless today and a silent skip '
            'the moment the server starts filtering rows',
      );
    });

    test('a row from a newer app stalls the pull instead of being skipped', () {
      final api = _FakeSyncApi(
        page: AppwriteSyncPage(
          rows: <Map<String, Object?>>[rowOf(entityType: 'somethingNewer')],
          lastRowId: 'entity-1',
          hasMore: false,
        ),
      );
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      expect(
        () => gateway.pull(after: SyncCursor.beginning),
        throwsA(isA<SyncTransportException>()),
        reason:
            'skipping it would advance the cursor past data that is then '
            'never fetched again — a change lost silently and for good',
      );
    });

    test('a malformed payload is a broken row, and says so', () {
      final api = _FakeSyncApi(
        page: AppwriteSyncPage(
          rows: <Map<String, Object?>>[rowOf(payload: 'not json')],
          lastRowId: 'entity-1',
          hasMore: false,
        ),
      );
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      expect(
        () => gateway.pull(after: SyncCursor.beginning),
        throwsA(isA<SyncTransportException>()),
      );
    });

    test('a tombstone pulls back with no payload', () async {
      final api = _FakeSyncApi(
        page: AppwriteSyncPage(
          rows: <Map<String, Object?>>[
            rowOf(operation: 'delete', payload: null),
          ],
          lastRowId: 'entity-1',
          hasMore: false,
        ),
      );
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      final page = await gateway.pull(after: SyncCursor.beginning);

      expect(page.envelopes.single.operation, SyncOperation.delete);
      expect(page.envelopes.single.payload, isEmpty);
    });

    test('a missing field never becomes a silently empty envelope', () {
      final api = _FakeSyncApi(
        page: AppwriteSyncPage(
          rows: <Map<String, Object?>>[rowOf()..remove('deviceId')],
          lastRowId: 'entity-1',
          hasMore: false,
        ),
      );
      final gateway = AppwriteSyncGateway(api: api, userId: owner);

      expect(
        () => gateway.pull(after: SyncCursor.beginning),
        throwsA(isA<SyncTransportException>()),
      );
    });

    test('a non-positive page size is refused', () {
      final gateway = AppwriteSyncGateway(api: _FakeSyncApi(), userId: owner);

      expect(
        () => gateway.pull(after: SyncCursor.beginning, limit: 0),
        throwsArgumentError,
      );
    });
  });

  test('a failure reason never carries user content', () async {
    final api = _FakeSyncApi(
      page: AppwriteSyncPage(
        rows: <Map<String, Object?>>[rowOf(payload: 'not json')],
        lastRowId: 'entity-1',
        hasMore: false,
      ),
    );
    final gateway = AppwriteSyncGateway(api: api, userId: owner);

    try {
      await gateway.pull(after: SyncCursor.beginning);
      fail('expected the malformed row to be reported');
    } on SyncTransportException catch (error) {
      expect(error.reason, isNot(contains('not json')));
      expect(error.reason, isNot(contains('s-112')));
      expect(RegExp(r'^[a-z-]+$').hasMatch(error.reason), isTrue);
    }
  });
}

final class _RecordedWrite {
  const _RecordedWrite({
    required this.rowId,
    required this.data,
    required this.permissions,
  });

  final String rowId;
  final Map<String, Object?> data;
  final List<String> permissions;
}

final class _FakeSyncApi implements AppwriteSyncApi {
  _FakeSyncApi({
    this.outcome = AppwriteSyncWriteOutcome.written,
    this.failure,
    AppwriteSyncPage? page,
  }) : page =
           page ??
           AppwriteSyncPage(
             rows: const <Map<String, Object?>>[],
             lastRowId: null,
             hasMore: false,
           );

  final AppwriteSyncWriteOutcome outcome;
  final Object? failure;
  final AppwriteSyncPage page;
  final List<_RecordedWrite> writes = <_RecordedWrite>[];

  @override
  Future<AppwriteSyncWriteOutcome> upsertRow({
    required String rowId,
    required Map<String, Object?> data,
    required List<String> permissions,
  }) async {
    if (failure != null) throw failure!;
    writes.add(
      _RecordedWrite(rowId: rowId, data: data, permissions: permissions),
    );
    return outcome;
  }

  @override
  Future<AppwriteSyncPage> listRowsAfter({
    required String cursor,
    required int limit,
  }) async {
    if (failure != null) throw failure!;
    return page;
  }
}
