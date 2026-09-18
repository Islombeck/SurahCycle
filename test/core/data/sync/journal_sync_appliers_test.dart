import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/journal_sync_appliers.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/journal_sync_payloads.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Two append-only journals. An adjustment is the owner correcting a surah's
/// standing by hand and it moves the rotation balance; a recall attempt is a
/// statement about whether he remembered a passage and moves nothing but
/// itself.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RotationAdjustmentSyncApplier adjustments;
  late RecallAttemptSyncApplier recalls;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    adjustments = RotationAdjustmentSyncApplier(database);
    recalls = RecallAttemptSyncApplier(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlas',
          ayahCount: 4,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-112');
  });

  tearDown(() => database.close());

  Future<void> applyIn(Future<void> Function() body) =>
      database.transaction(body);

  Matcher refuses(String reason) => throwsA(
    isA<SyncTransportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  group('a rotation adjustment', () {
    RotationAdjustmentSyncRecord record({
      String id = 'adj-1',
      int delta = 3,
      String schemeId = 'surah-112:scheme:1',
    }) => RotationAdjustmentSyncRecord(
      id: id,
      surahId: 'surah-112',
      rotationSchemeId: schemeId,
      delta: delta,
      reason: 'Читал вне приложения',
      createdAtUtc: DateTime.utc(2026, 9, 17, 10),
    );

    SyncEnvelope upsertOf(RotationAdjustmentSyncRecord source) =>
        RotationAdjustmentSyncPayload.upsert(
          source,
          envelopeId: 'envelope-${source.id}',
          deviceId: 'other-device',
          idempotencyKey: 'key-${source.id}',
          schemaVersion: 10,
          updatedAtUtc: DateTime.utc(2026, 9, 17, 11),
        );

    test('arrives with the owner\'s own words for why', () async {
      await applyIn(() => adjustments.apply(upsertOf(record())));

      final stored = await database
          .select(database.rotationAdjustments)
          .getSingle();
      expect(stored.id, 'adj-1');
      expect(stored.delta, 3);
      expect(
        stored.reason,
        'Читал вне приложения',
        reason: 'it is his note, not a category this app gets to normalise',
      );
      expect(stored.createdAtUtc.toUtc(), DateTime.utc(2026, 9, 17, 10));
    });

    test('it moves the rotation balance here too', () async {
      final before = (await surahs.getRotationSnapshot())
          .surahById('surah-112')
          .rotationScore;

      await applyIn(() => adjustments.apply(upsertOf(record())));

      expect(
        (await surahs.getRotationSnapshot())
            .surahById('surah-112')
            .rotationScore,
        before + 3,
      );
    });

    test('it takes this journal sequence, not the sending one', () async {
      await applyIn(() => adjustments.apply(upsertOf(record())));
      await applyIn(() => adjustments.apply(upsertOf(record(id: 'adj-2'))));

      final stored = await database.select(database.rotationAdjustments).get()
        ..sort((a, b) => a.journalSequence.compareTo(b.journalSequence));
      expect(<int>[for (final row in stored) row.journalSequence], <int>[1, 2]);
    });

    test('a withdrawal takes its effect back out of the balance', () async {
      await applyIn(() => adjustments.apply(upsertOf(record())));
      final withAdjustment = (await surahs.getRotationSnapshot())
          .surahById('surah-112')
          .rotationScore;

      await applyIn(
        () => adjustments.apply(
          RotationAdjustmentSyncPayload.tombstone(
            entityId: 'adj-1',
            envelopeId: 'envelope-gone',
            deviceId: 'other-device',
            idempotencyKey: 'key-gone',
            schemaVersion: 10,
            originalCreatedAtUtc: DateTime.utc(2026, 9, 17, 10),
            deletedAtUtc: DateTime.utc(2026, 9, 17, 12),
          ),
        ),
      );

      expect(
        (await surahs.getRotationSnapshot())
            .surahById('surah-112')
            .rotationScore,
        withAdjustment - 3,
      );
      final stored = await database
          .select(database.rotationAdjustments)
          .getSingle();
      expect(
        stored.deletedAtUtc?.toUtc(),
        DateTime.utc(2026, 9, 17, 12),
        reason: 'a tombstone, so an offline device learns of the withdrawal',
      );
    });

    test('an upsert after a withdrawal brings it back', () async {
      await applyIn(() => adjustments.apply(upsertOf(record())));
      await applyIn(
        () => adjustments.apply(
          RotationAdjustmentSyncPayload.tombstone(
            entityId: 'adj-1',
            envelopeId: 'envelope-gone',
            deviceId: 'other-device',
            idempotencyKey: 'key-gone',
            schemaVersion: 10,
            originalCreatedAtUtc: DateTime.utc(2026, 9, 17, 10),
            deletedAtUtc: DateTime.utc(2026, 9, 17, 12),
          ),
        ),
      );

      await applyIn(() => adjustments.apply(upsertOf(record())));

      final stored = await database
          .select(database.rotationAdjustments)
          .getSingle();
      expect(stored.deletedAtUtc, isNull);
    });

    test('one whose scheme is not here is refused, retryably', () async {
      await expectLater(
        () => applyIn(
          () => adjustments.apply(
            upsertOf(record(schemeId: 'surah-112:scheme:never')),
          ),
        ),
        refuses('remote-adjustment-scheme-missing'),
      );
    });

    test('a correction of zero is not a correction', () {
      expect(() => record(delta: 0), throwsA(isA<ArgumentError>()));
    });
  });

  group('a recall attempt', () {
    RecallAttemptSyncRecord record({
      String id = 'recall-1',
      String result = 'recalledWithMistake',
    }) => RecallAttemptSyncRecord(
      id: id,
      surahId: 'surah-112',
      ayahStart: 1,
      ayahEnd: 4,
      learningCycle: 2,
      result: result,
      createdAtUtc: DateTime.utc(2026, 9, 17, 20),
      localDate: '2026-09-17',
      source: 'learning',
    );

    SyncEnvelope upsertOf(RecallAttemptSyncRecord source) =>
        RecallAttemptSyncPayload.upsert(
          source,
          envelopeId: 'envelope-${source.id}',
          deviceId: 'other-device',
          idempotencyKey: 'key-${source.id}',
          schemaVersion: 10,
          updatedAtUtc: DateTime.utc(2026, 9, 17, 21),
        );

    test('arrives with the result exactly as it was recorded', () async {
      await applyIn(() => recalls.apply(upsertOf(record())));

      final stored = await database.select(database.recallAttempts).getSingle();
      expect(stored.id, 'recall-1');
      expect(stored.result, 'recalledWithMistake');
      expect(stored.ayahStart, 1);
      expect(stored.ayahEnd, 4);
      expect(stored.learningCycle, 2);
      expect(stored.localDate, '2026-09-17');
      expect(stored.source, 'learning');
    });

    test('a missing result is refused, because nothing may invent one', () {
      final payload = RecallAttemptSyncPayload.encode(record())
        ..remove('result');

      expect(
        () => RecallAttemptSyncPayload.decode(payload, entityId: 'recall-1'),
        throwsA(
          isA<JournalPayloadException>().having(
            (error) => error.reason,
            'reason',
            'missing-result',
          ),
        ),
        reason:
            'it would have to become one of three statements about whether the '
            'owner remembered a passage, and this app does not get to decide '
            'that on his behalf',
      );
    });

    test('a result this build does not know is refused', () {
      final payload = RecallAttemptSyncPayload.encode(record())
        ..['result'] = 'almost';

      expect(
        () => RecallAttemptSyncPayload.decode(payload, entityId: 'recall-1'),
        throwsA(isA<JournalPayloadException>()),
      );
    });

    test('a local date carrying a time is refused, not truncated', () {
      final payload = RecallAttemptSyncPayload.encode(record())
        ..['localDate'] = '2026-09-17T23:30:00.000Z';

      expect(
        () => RecallAttemptSyncPayload.decode(payload, entityId: 'recall-1'),
        throwsA(
          isA<JournalPayloadException>().having(
            (error) => error.reason,
            'reason',
            'malformed-localDate',
          ),
        ),
      );
    });

    test('applying it twice changes nothing', () async {
      final envelope = upsertOf(record());
      await applyIn(() => recalls.apply(envelope));

      await applyIn(() => recalls.apply(envelope));

      expect(
        await database.select(database.recallAttempts).get(),
        hasLength(1),
      );
    });

    test('it is never deleted', () async {
      await expectLater(
        () => applyIn(
          () => recalls.apply(
            SyncEnvelope(
              id: 'envelope-gone',
              deviceId: 'other-device',
              entityType: SyncEntityType.recallAttempt,
              entityId: 'recall-1',
              operation: SyncOperation.delete,
              schemaVersion: 10,
              createdAtUtc: DateTime.utc(2026, 9, 17, 20),
              updatedAtUtc: DateTime.utc(2026, 9, 17, 22),
              idempotencyKey: 'key-gone',
            ),
          ),
        ),
        refuses('remote-recall-cannot-be-deleted'),
        reason:
            'nothing in the app deletes one, and the table has no deleted_at '
            'column, so there is no local operation a tombstone could mean',
      );
    });

    test('one for a surah the catalog lacks is refused, retryably', () async {
      final payload = RecallAttemptSyncPayload.encode(record())
        ..['surahId'] = 'surah-999';

      await expectLater(
        () => applyIn(
          () => recalls.apply(
            SyncEnvelope(
              id: 'envelope-x',
              deviceId: 'other-device',
              entityType: SyncEntityType.recallAttempt,
              entityId: 'recall-x',
              operation: SyncOperation.upsert,
              schemaVersion: 10,
              createdAtUtc: DateTime.utc(2026, 9, 17, 20),
              updatedAtUtc: DateTime.utc(2026, 9, 17, 21),
              idempotencyKey: 'key-x',
              payload: payload,
            ),
          ),
        ),
        refuses('remote-recall-surah-not-in-catalog'),
      );
    });
  });
}
