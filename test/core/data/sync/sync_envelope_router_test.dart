import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_envelope_router.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/mastered_surah_sync_payload.dart';
import 'package:murajaah/core/sync/recitation_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The router's real job is the order. Every applier refuses retryably when a
/// prerequisite is missing, and a page is one transaction — so a page carrying
/// a recitation ahead of its roster entry would fail, roll back, and be fetched
/// again in the same order. A permanent stall over a page that contains
/// everything it needs.
void main() {
  late AppDatabase database;
  late SyncEnvelopeRouter router;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    router = SyncEnvelopeRouter(database);
    await SurahRepository(database).upsertCatalog(
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
  });

  tearDown(() => database.close());

  SyncEnvelope rosterEnvelope() => MasteredSurahSyncPayload.upsert(
    MasteredSurahSyncRecord(
      surahId: 'surah-112',
      isCurrentlyMastered: true,
      isActive: true,
      hasEnteredRotation: true,
      displayOrder: 0,
    ),
    envelopeId: 'envelope-roster',
    deviceId: 'other-device',
    idempotencyKey: 'key-roster',
    schemaVersion: 10,
    updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
  );

  SyncEnvelope recitationEnvelope() => RecitationSyncPayload.upsert(
    SurahRecitationEvent(
      id: 'event-1',
      surahId: 'surah-112',
      prayerContext: PrayerContext(prayerType: PrayerType.asr),
      createdAtUtc: DateTime.utc(2026, 9, 18, 13),
      localDate: LocalDate(2026, 9, 18),
      rakaatSpanCount: 1,
      rotationSchemeId: 'surah-112:scheme:1',
      coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
    ),
    envelopeId: 'envelope-recitation',
    deviceId: 'other-device',
    idempotencyKey: 'key-recitation',
    schemaVersion: 10,
    updatedAtUtc: DateTime.utc(2026, 9, 18, 14),
  );

  test('a page carrying a prayer before its surah still applies', () async {
    // The server sends oldest change first, and the recitation happened after
    // the roster entry — but nothing guarantees that, and a page in the wrong
    // order would stall on itself forever.
    final page = SyncPullPage(
      envelopes: <SyncEnvelope>[recitationEnvelope(), rosterEnvelope()],
      cursor: SyncCursor('1'),
      hasMore: false,
    );

    final ordered = router.ordered(page);
    await database.transaction(() async {
      for (final envelope in ordered.envelopes) {
        await router.apply(envelope);
      }
    });

    expect(await RecitationRepository(database).getHistory(), hasLength(1));
  });

  test(
    'the same page unsorted does stall, which is why sorting exists',
    () async {
      await expectLater(
        () => database.transaction(() async {
          for (final envelope in <SyncEnvelope>[
            recitationEnvelope(),
            rosterEnvelope(),
          ]) {
            await router.apply(envelope);
          }
        }),
        throwsA(
          isA<SyncTransportException>().having(
            (error) => error.reason,
            'reason',
            'remote-recitation-surah-missing',
          ),
        ),
        reason:
            'this is the failure the ordering prevents, asserted rather than '
            'assumed — otherwise the sort could be removed and nothing would '
            'notice',
      );
    },
  );

  test('order within one rank is the order the server sent', () {
    final first = rosterEnvelope();
    final second = MasteredSurahSyncPayload.upsert(
      MasteredSurahSyncRecord(
        surahId: 'surah-108',
        isCurrentlyMastered: true,
        isActive: false,
        hasEnteredRotation: false,
        displayOrder: 1,
      ),
      envelopeId: 'envelope-roster-2',
      deviceId: 'other-device',
      idempotencyKey: 'key-roster-2',
      schemaVersion: 10,
      updatedAtUtc: DateTime.utc(2026, 9, 18, 10),
    );

    final ordered = router.inDependencyOrder(<SyncEnvelope>[first, second]);

    expect(
      <String>[for (final envelope in ordered) envelope.id],
      <String>['envelope-roster', 'envelope-roster-2'],
      reason:
          'the server sends updatedAtUtc ascending, so a later version must '
          'still land after the earlier one it replaces',
    );
  });

  test('every entity type is routed, or deliberately is not', () {
    for (final type in SyncEntityType.values) {
      expect(
        SyncEnvelopeRouter.handlesType(type) ||
            SyncEnvelopeRouter.deliberatelyUnrouted.contains(type),
        isTrue,
        reason:
            '$type has no route and no recorded reason for not having one; a '
            'new entity type must not fall through silently',
      );
    }
  });

  test('the rotation projection is refused rather than applied', () async {
    await expectLater(
      () => database.transaction(
        () => router.apply(
          SyncEnvelope(
            id: 'envelope-state',
            deviceId: 'other-device',
            entityType: SyncEntityType.rotationState,
            entityId: '1',
            operation: SyncOperation.upsert,
            schemaVersion: 10,
            createdAtUtc: DateTime.utc(2026, 9, 18, 9),
            updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
            idempotencyKey: 'key-state',
            payload: const <String, Object?>{'rotationTarget': 3},
          ),
        ),
      ),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.reason,
          'reason',
          'remote-entity-type-unhandled-rotationstate',
        ),
      ),
      reason:
          'it is the rotation projection, rebuilt from the journal; accepting '
          'it would give the projection a second source of truth',
    );
  });
}
