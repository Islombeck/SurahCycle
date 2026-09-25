import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_envelope_router.dart';
import 'package:murajaah/core/data/sync/sync_versioned_rows.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/recitation_sync_payload.dart';
import 'package:murajaah/core/sync/rotation_scheme_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The three defects the independent audit of 2026-09-24 found by reading the
/// source. Each is reproduced here on its own, before anything was changed, and
/// each was watched failing against the implementation of that date.
///
/// They are kept in one file because they share a cause worth seeing together:
/// **the pull had no durable memory.** What it could not place it held in RAM,
/// what it absorbed it forgot the name of, and what it withdrew it recorded
/// nowhere. Everything below follows from that.
void main() {
  late AppDatabase database;

  final now = DateTime.utc(2026, 9, 24, 12);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
  });

  Future<void> seedSurah(String surahId, int number, int ayahCount) async {
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(<SurahDescriptor>[
      SurahDescriptor(
        id: surahId,
        surahNumber: number,
        officialName: 'Surah $number',
        ayahCount: ayahCount,
      ),
    ], sourceId: 'verified-test-source', sourceVersion: 'test-v1');
  }

  group('a record this build cannot place holds the cursor for good', () {
    /// `rotationState` is the rotation projection, which is rebuilt rather than
    /// synced; the router refuses it by name. It stands here for any record a
    /// build cannot place — a type from a newer client, a payload it cannot
    /// read — because the account is a log and such a row stays in it forever.
    SyncEnvelope unplaceable() => SyncEnvelope(
      id: 'envelope-unplaceable',
      deviceId: 'other-device',
      entityType: SyncEntityType.rotationState,
      entityId: 'rotation-state',
      operation: SyncOperation.upsert,
      schemaVersion: 10,
      createdAtUtc: now,
      updatedAtUtc: now,
      idempotencyKey: 'key-unplaceable',
      payload: const <String, Object?>{},
    );

    SyncEnvelope setting(String key) => SyncEnvelope(
      id: 'envelope-$key',
      deviceId: 'other-device',
      entityType: SyncEntityType.appSetting,
      entityId: key,
      operation: SyncOperation.upsert,
      schemaVersion: 10,
      createdAtUtc: now,
      updatedAtUtc: now,
      idempotencyKey: 'key-$key',
      payload: <String, Object?>{
        'value': 'dark',
        'valueType': 'string',
        'updatedAtUtc': now.toIso8601String(),
      },
    );

    test('the cursor moves past it and the account is not re-read', () async {
      final store = DriftSyncStore(database, owner: SyncOwnerKey.user('u'));
      await store.recordActivationChoice(
        choice: SyncActivationChoice.merge,
        backupId: 'backup',
        decidedAtUtc: now,
      );
      final cloud = _PagedCloud(<String, List<SyncEnvelope>>{
        '': <SyncEnvelope>[unplaceable()],
        'page-1': <SyncEnvelope>[setting('theme_preference')],
      }, order: const <String>['page-1', 'page-2']);
      final runner = SyncCycleRunner(
        database: database,
        store: store,
        gateway: cloud,
        nowUtc: () => now,
      );

      await runner.runOnce();
      final afterFirst = cloud.reads.length;

      expect(
        await store.pullCursor(),
        const SyncCursor('page-2'),
        reason:
            'the record it cannot place is durably held, so there is nothing '
            'left for the cursor to protect — leaving it behind makes every '
            'later cycle re-read the whole account from that point',
      );

      await runner.runOnce();

      expect(
        cloud.reads.skip(afterFirst).toList(),
        isNot(contains('')),
        reason: 'the second cycle must not start from the beginning again',
      );
      expect(
        (await database
                .customSelect(
                  'SELECT count(*) AS n FROM sync_inbox_entries '
                  "WHERE owner_key = 'user:u'",
                )
                .getSingle())
            .read<int>('n'),
        1,
        reason:
            'and the record is not dropped to achieve that: it is kept, '
            'counted, and retried',
      );
    });
  });

  group('a scheme absorbed under another name takes its records with it', () {
    setUp(() async {
      await seedSurah('surah-112', 112, 4);
      final surahs = SurahRepository(database);
      await surahs.addMastered('surah-112');
      await SyncVersionedRows(database).stampAuthored(
        table: 'rotation_schemes',
        key: 'surah-112:scheme:1',
        authoredAtUtc: DateTime.utc(2026, 9, 1),
      );
      // A recitation of his own against the local scheme. That is what makes
      // the local row un-removable, and so what makes the arriving one be
      // absorbed rather than replace it.
      await RecitationRepository(database).register(
        SurahRecitationEvent(
          id: 'local-recitation',
          surahId: 'surah-112',
          prayerContext: PrayerContext(prayerType: PrayerType.fajr),
          createdAtUtc: DateTime.utc(2026, 9, 2, 5),
          localDate: LocalDate(2026, 9, 2),
          rakaatSpanCount: 1,
        ),
      );
    });

    /// The same split this device already holds, under the name an older build
    /// gave it — which is exactly his Al-Humazah.
    SyncEnvelope arrivingScheme() => RotationSchemeSyncPayload.upsert(
      RotationSchemeSyncRecord(
        id: 'v1:surah-112:scheme:1',
        surahId: 'surah-112',
        version: 1,
        ayahCountSnapshot: 4,
        baselineScore: 0,
        baselineTotalRecitations: 0,
        isActive: true,
        parts: <RotationSchemeSyncPart>[
          RotationSchemeSyncPart(
            id: 'v1:surah-112:scheme:1:part:1',
            ordinal: 1,
            startAyah: 1,
            endAyah: 4,
          ),
        ],
      ),
      envelopeId: 'envelope-scheme',
      deviceId: 'other-device',
      idempotencyKey: 'key-scheme',
      schemaVersion: 10,
      updatedAtUtc: DateTime.utc(2026, 9, 20),
    );

    /// A prayer from the other device, naming the scheme and part ids that
    /// device knows. It has no prayer session on purpose: this is about the
    /// scheme, and a missing session is a different refusal.
    SyncEnvelope arrivingRecitation() => RecitationSyncPayload.upsert(
      SurahRecitationEvent(
        id: 'remote-recitation',
        surahId: 'surah-112',
        prayerContext: PrayerContext(prayerType: PrayerType.maghrib),
        createdAtUtc: DateTime.utc(2026, 9, 21, 17),
        localDate: LocalDate(2026, 9, 21),
        rakaatSpanCount: 1,
        coverage: RecitationCoverage(
          rotationSchemeId: 'v1:surah-112:scheme:1',
          coveredPartIds: const <String>['v1:surah-112:scheme:1:part:1'],
        ),
      ),
      envelopeId: 'envelope-recitation',
      deviceId: 'other-device',
      idempotencyKey: 'key-recitation',
      schemaVersion: 10,
      updatedAtUtc: DateTime.utc(2026, 9, 21, 17),
    );

    test('a prayer naming the absorbed id still lands', () async {
      final router = SyncEnvelopeRouter(database);
      await database.transaction(() => router.apply(arrivingScheme()));

      await expectLater(
        database.transaction(() => router.apply(arrivingRecitation())),
        completes,
        reason:
            'the arriving scheme was recognised as one this device already '
            'holds, so its id has to keep meaning something — every record '
            'the other device sends names it',
      );

      final stored = await (database.select(
        database.recitationEvents,
      )..where((RecitationEvents row) => row.id.equals('remote-recitation')))
          .getSingle();
      expect(stored.rotationSchemeId, 'surah-112:scheme:1');
      final covered = await (database.select(
        database.recitationEventParts,
      )..where((RecitationEventParts row) => row.eventId.equals(
            'remote-recitation',
          )))
          .get();
      expect(
        covered.map((row) => row.partId),
        <String>['surah-112:scheme:1:part:1'],
        reason: 'the coverage has to point at the parts that exist here',
      );
    });
  });

  group('a withdrawal and a restore settle by when each happened', () {
    late RecitationRepository recitations;
    late SyncEnvelopeRouter router;

    setUp(() async {
      await seedSurah('surah-112', 112, 4);
      await SurahRepository(database).addMastered('surah-112');
      recitations = RecitationRepository(database);
      router = SyncEnvelopeRouter(database);
      // A withdrawal for a record this device does not have is remembered per
      // account, and the account is read from the activation table the way
      // `SyncTombstones` already reads it. A device with no activation is not
      // syncing at all, so there is nobody for the mark to belong to.
      await DriftSyncStore(
        database,
        owner: SyncOwnerKey.user('u'),
      ).recordActivationChoice(
        choice: SyncActivationChoice.merge,
        backupId: 'backup',
        decidedAtUtc: now,
      );
    });

    Future<void> registerLocal(String id) => recitations.register(
      SurahRecitationEvent(
        id: id,
        surahId: 'surah-112',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr),
        createdAtUtc: DateTime.utc(2026, 9, 20, 5),
        localDate: LocalDate(2026, 9, 20),
        rakaatSpanCount: 1,
      ),
    );

    SyncEnvelope withdrawal(String id, DateTime at) =>
        RecitationSyncPayload.tombstone(
          entityId: id,
          envelopeId: 'envelope-withdraw-${at.millisecondsSinceEpoch}',
          deviceId: 'other-device',
          idempotencyKey: 'key-withdraw-${at.millisecondsSinceEpoch}',
          schemaVersion: 10,
          originalCreatedAtUtc: DateTime.utc(2026, 9, 20, 5),
          deletedAtUtc: at,
        );

    SyncEnvelope arrival(String id, DateTime at) =>
        RecitationSyncPayload.upsert(
          SurahRecitationEvent(
            id: id,
            surahId: 'surah-112',
            prayerContext: PrayerContext(prayerType: PrayerType.fajr),
            createdAtUtc: DateTime.utc(2026, 9, 20, 5),
            localDate: LocalDate(2026, 9, 20),
            rakaatSpanCount: 1,
            coverage: RecitationCoverage(
              rotationSchemeId: 'surah-112:scheme:1',
              coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
            ),
          ),
          envelopeId: 'envelope-restore-${at.millisecondsSinceEpoch}',
          deviceId: 'other-device',
          idempotencyKey: 'key-restore-${at.millisecondsSinceEpoch}',
          schemaVersion: 10,
          updatedAtUtc: at,
        );

    Future<DateTime?> deletedAtOf(String id) async =>
        (await (database.select(database.recitationEvents)
                  ..where((RecitationEvents row) => row.id.equals(id)))
                .getSingle())
            .deletedAtUtc;

    test('an older withdrawal does not undo a newer restore', () async {
      await registerLocal('r1');
      await recitations.deleteRecitation(
        'r1',
        deletedAtUtc: DateTime.utc(2026, 9, 21, 8),
      );
      await recitations.restoreRecitation(
        'r1',
        restoredAtUtc: DateTime.utc(2026, 9, 22, 8),
      );

      await database.transaction(
        () => router.apply(withdrawal('r1', DateTime.utc(2026, 9, 21, 8))),
      );

      expect(
        await deletedAtOf('r1'),
        isNull,
        reason:
            'he withdrew it on the other phone and brought it back here '
            'afterwards; the older withdrawal arriving late must not undo the '
            'newer decision',
      );
    });

    test('a newer withdrawal still lands on a restored record', () async {
      await registerLocal('r2');
      await recitations.restoreRecitation(
        'r2',
        restoredAtUtc: DateTime.utc(2026, 9, 21, 8),
      );

      await database.transaction(
        () => router.apply(withdrawal('r2', DateTime.utc(2026, 9, 22, 8))),
      );

      expect(
        await deletedAtOf('r2'),
        isNotNull,
        reason: 'the comparison has to work in both directions',
      );
    });

    test('a withdrawal arriving before the record it withdraws', () async {
      await database.transaction(
        () => router.apply(withdrawal('r3', DateTime.utc(2026, 9, 22, 8))),
      );
      // The record itself, recovered from quarantine and pushed after the
      // withdrawal — which is how his own account came to hold types out of
      // order. It is dated before the withdrawal, because it happened first.
      await database.transaction(
        () => router.apply(arrival('r3', DateTime.utc(2026, 9, 20, 5))),
      );

      expect(
        await deletedAtOf('r3'),
        isNotNull,
        reason:
            'the account says this prayer was withdrawn; arriving in the '
            'wrong order must not bring it back',
      );
    });
  });
}

/// Hands out fixed pages by cursor and records every cursor it was asked for.
final class _PagedCloud implements SyncGateway {
  _PagedCloud(this.pages, {required this.order});

  final Map<String, List<SyncEnvelope>> pages;
  final List<String> order;
  final List<String> reads = <String>[];

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) async =>
      SyncPushResult(acceptedEnvelopeIds: envelopes.map((one) => one.id));

  @override
  Future<SyncPullPage> pull({
    required SyncCursor after,
    int limit = 100,
  }) async {
    reads.add(after.value);
    final envelopes = pages[after.value] ?? const <SyncEnvelope>[];
    if (envelopes.isEmpty) {
      return SyncPullPage(
        envelopes: const <SyncEnvelope>[],
        cursor: after,
        hasMore: false,
      );
    }
    final index = after.value.isEmpty ? 0 : order.indexOf(after.value) + 1;
    final next = order[index];
    return SyncPullPage(
      envelopes: envelopes,
      cursor: SyncCursor(next),
      hasMore: pages.containsKey(next),
    );
  }
}
