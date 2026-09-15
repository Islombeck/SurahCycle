import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

import 'sync_fixtures.dart';

/// The envelope is the boundary contract, so its invariants are worth pinning:
/// a bad envelope on the wire is a bad row in someone's history.
void main() {
  group('identity', () {
    test('an entity key combines type and id', () {
      final envelope = envelopeOf(
        entityId: 'abc',
        entityType: SyncEntityType.recallAttempt,
      );

      expect(envelope.entityKey, 'recallAttempt:abc');
    });

    test('the same id under two types is two different records', () {
      final setting = envelopeOf(
        entityId: 'shared',
        entityType: SyncEntityType.appSetting,
      );
      final attempt = envelopeOf(
        entityId: 'shared',
        entityType: SyncEntityType.recallAttempt,
      );

      expect(setting.entityKey, isNot(attempt.entityKey));
    });

    test('an anonymous envelope has no user', () {
      expect(envelopeOf(entityId: 'a').userId, isNull);
    });

    test('adopting a user keeps everything else identical', () {
      final anonymous = envelopeOf(entityId: 'a');

      final owned = anonymous.withUserId('user-1');

      expect(owned.userId, 'user-1');
      expect(owned.id, anonymous.id);
      expect(owned.entityKey, anonymous.entityKey);
      expect(owned.createdAtUtc, anonymous.createdAtUtc);
      expect(owned.idempotencyKey, anonymous.idempotencyKey);
      expect(owned.payload, anonymous.payload);
    });

    test('an empty user id is refused', () {
      expect(
        () => envelopeOf(entityId: 'a').withUserId(''),
        throwsArgumentError,
      );
      expect(() => envelopeOf(entityId: 'a', userId: ''), throwsArgumentError);
    });
  });

  group('invariants', () {
    test('a tombstone carries no payload', () {
      expect(
        () => SyncEnvelope(
          id: 'e1',
          deviceId: 'device-a',
          entityType: SyncEntityType.appSetting,
          entityId: 'a',
          operation: SyncOperation.delete,
          schemaVersion: 6,
          createdAtUtc: at(0),
          updatedAtUtc: at(1),
          idempotencyKey: 'k',
          payload: const <String, Object?>{'value': 'x'},
        ),
        throwsArgumentError,
        reason: 'keeping last known values on a delete invites resurrection',
      );
    });

    test('a tombstone is recognisable', () {
      expect(tombstoneOf(entityId: 'a').isTombstone, isTrue);
      expect(envelopeOf(entityId: 'a').isTombstone, isFalse);
    });

    test('local timestamps are refused', () {
      expect(
        () => SyncEnvelope(
          id: 'e1',
          deviceId: 'device-a',
          entityType: SyncEntityType.appSetting,
          entityId: 'a',
          operation: SyncOperation.upsert,
          schemaVersion: 6,
          createdAtUtc: DateTime(2026, 9, 15),
          updatedAtUtc: at(1),
          idempotencyKey: 'k',
        ),
        throwsArgumentError,
      );
    });

    test('an update cannot predate its creation', () {
      expect(
        () => SyncEnvelope(
          id: 'e1',
          deviceId: 'device-a',
          entityType: SyncEntityType.appSetting,
          entityId: 'a',
          operation: SyncOperation.upsert,
          schemaVersion: 6,
          createdAtUtc: at(5),
          updatedAtUtc: at(1),
          idempotencyKey: 'k',
        ),
        throwsArgumentError,
      );
    });

    test('empty required identifiers are refused', () {
      expect(() => envelopeOf(entityId: ''), throwsArgumentError);
      expect(() => envelopeOf(entityId: 'a', id: ''), throwsArgumentError);
      expect(
        () => envelopeOf(entityId: 'a', deviceId: ''),
        throwsArgumentError,
      );
      expect(
        () => envelopeOf(entityId: 'a', idempotencyKey: ''),
        throwsArgumentError,
      );
    });

    test('a non-positive schema version is refused', () {
      expect(
        () => envelopeOf(entityId: 'a', schemaVersion: 0),
        throwsArgumentError,
      );
    });

    test('the payload is unmodifiable once wrapped', () {
      final envelope = envelopeOf(entityId: 'a');

      expect(() => envelope.payload['injected'] = 1, throwsUnsupportedError);
    });

    test('envelopes compare by value', () {
      expect(envelopeOf(entityId: 'a'), envelopeOf(entityId: 'a'));
      expect(
        envelopeOf(entityId: 'a'),
        isNot(envelopeOf(entityId: 'a', updatedMinute: 9)),
      );
    });
  });

  group('entity coverage', () {
    test('derived snapshots are deliberately absent', () {
      // Widget snapshots, the rotation projection and the recommendation batch
      // are rebuildable from these facts. Syncing them would create a second
      // source of truth that can disagree with the journal.
      final names = SyncEntityType.values.map((value) => value.name).toList();

      expect(names, isNot(contains('widgetSnapshot')));
      expect(names, isNot(contains('rotationProjection')));
      expect(names, isNot(contains('recommendationBatch')));
      expect(names, isNot(contains('quranContent')));
      expect(names, isNot(contains('audioCache')));
    });

    test('every user-owned kind the architecture lists is representable', () {
      expect(SyncEntityType.values, contains(SyncEntityType.recitationEvent));
      expect(SyncEntityType.values, contains(SyncEntityType.learningState));
      expect(SyncEntityType.values, contains(SyncEntityType.recallAttempt));
      expect(
        SyncEntityType.values,
        contains(SyncEntityType.prayerRoutineTemplate),
      );
      expect(SyncEntityType.values, contains(SyncEntityType.appSetting));
    });
  });
}
