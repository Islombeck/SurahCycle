import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/prayer_session_sync_applier.dart';
import 'package:murajaah/core/data/sync/recitation_sync_applier.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/prayer_session_sync_payload.dart';
import 'package:murajaah/core/sync/recitation_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// A recitation points at the prayer it was recited in and at the slot it
/// filled, so a session has to arrive before those recitations can. The last
/// test here is that whole chain: session, then prayer, with the link intact.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late PrayerSessionSyncApplier applier;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    applier = PrayerSessionSyncApplier(database);
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

  PrayerSessionSyncPart part({
    required String id,
    required int orderIndex,
    String kind = 'fard',
    String completionMode = 'recitations',
    DateTime? completedAtUtc,
    int requiredSurahSlots = 1,
  }) => PrayerSessionSyncPart(
    id: id,
    stableKey: kind,
    orderIndex: orderIndex,
    label: kind,
    kind: kind,
    rakaatCount: 2,
    requiredSurahSlots: requiredSurahSlots,
    allowsFollowingImam: true,
    completionMode: completionMode,
    completedAtUtc: completedAtUtc,
  );

  PrayerSessionSyncRecord session({
    String id = 'session-1',
    String prayerType = 'fajr',
    bool isQada = false,
    List<PrayerSessionSyncPart>? parts,
  }) => PrayerSessionSyncRecord(
    id: id,
    prayerType: prayerType,
    isQada: isQada,
    startedAtUtc: DateTime.utc(2026, 9, 18, 3),
    localDate: '2026-09-18',
    parts:
        parts ??
        <PrayerSessionSyncPart>[
          part(id: 'part-sunnah', orderIndex: 0, kind: 'sunnah'),
          part(id: 'part-fard', orderIndex: 1),
        ],
  );

  SyncEnvelope upsertOf(PrayerSessionSyncRecord source, {int minute = 0}) =>
      PrayerSessionSyncPayload.upsert(
        source,
        envelopeId: 'envelope-${source.id}-$minute',
        deviceId: 'other-device',
        idempotencyKey: 'key-${source.id}-$minute',
        schemaVersion: 10,
        updatedAtUtc: DateTime.utc(2026, 9, 18, 4, minute),
      );

  Future<void> applyIn(Future<void> Function() body) =>
      database.transaction(body);

  Matcher refuses(String reason) => throwsA(
    isA<SyncTransportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  test('a session arrives with its parts', () async {
    await applyIn(() => applier.apply(upsertOf(session())));

    final stored = await database.select(database.prayerSessions).getSingle();
    expect(stored.prayerType, 'fajr');
    expect(stored.localDate, '2026-09-18');
    expect(stored.startedAtUtc.toUtc(), DateTime.utc(2026, 9, 18, 3));

    final parts = await database.select(database.prayerSessionParts).get();
    expect(parts, hasLength(2));
    expect(<String>[for (final p in parts) p.kind]..sort(), <String>[
      'fard',
      'sunnah',
    ]);
  });

  test('"followed the imam" travels, because nothing can infer it', () async {
    await applyIn(
      () => applier.apply(
        upsertOf(
          session(
            parts: <PrayerSessionSyncPart>[
              part(
                id: 'part-fard',
                orderIndex: 0,
                completionMode: 'followedImam',
                completedAtUtc: DateTime.utc(2026, 9, 18, 3, 20),
                requiredSurahSlots: 2,
              ),
            ],
          ),
        ),
      ),
    );

    final stored = await database
        .select(database.prayerSessionParts)
        .getSingle();
    expect(stored.completionMode, 'followedImam');
    expect(stored.completedAtUtc?.toUtc(), DateTime.utc(2026, 9, 18, 3, 20));
    expect(
      stored.requiredSurahSlots,
      2,
      reason:
          'following the imam creates no recitation, so the slots stay unfilled '
          'and the fact that the part is finished cannot be derived from them',
    );
  });

  test('the envelope is dated by the prayer, not by the edit', () {
    final envelope = upsertOf(session(), minute: 30);

    expect(
      envelope.createdAtUtc,
      DateTime.utc(2026, 9, 18, 3),
      reason: 'the prayer began when it began; a later edit does not move it',
    );
    expect(envelope.updatedAtUtc, DateTime.utc(2026, 9, 18, 4, 30));
  });

  test('applying it twice changes nothing', () async {
    final envelope = upsertOf(session());
    await applyIn(() => applier.apply(envelope));

    await applyIn(() => applier.apply(envelope));

    expect(await database.select(database.prayerSessions).get(), hasLength(1));
    expect(
      await database.select(database.prayerSessionParts).get(),
      hasLength(2),
    );
  });

  test('parts that swap places do not collide on the way', () async {
    await applyIn(() => applier.apply(upsertOf(session())));

    // The same two parts, order reversed. The unique key on
    // (session, order_index) would refuse this if one were written while the
    // other still held the position.
    await applyIn(
      () => applier.apply(
        upsertOf(
          session(
            parts: <PrayerSessionSyncPart>[
              part(id: 'part-fard', orderIndex: 0),
              part(id: 'part-sunnah', orderIndex: 1, kind: 'sunnah'),
            ],
          ),
          minute: 30,
        ),
      ),
    );

    final parts = await database.select(database.prayerSessionParts).get()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(
      <String>[for (final p in parts) p.id],
      <String>['part-fard', 'part-sunnah'],
    );
    expect(<int>[for (final p in parts) p.orderIndex], <int>[0, 1]);
  });

  test('a part that a recitation filled is never dropped', () async {
    await applyIn(() => applier.apply(upsertOf(session())));
    await applyIn(
      () => RecitationSyncApplier(database).apply(
        RecitationSyncPayload.upsert(
          SurahRecitationEvent(
            id: 'event-1',
            surahId: 'surah-112',
            prayerContext: PrayerContext(prayerType: PrayerType.fajr),
            createdAtUtc: DateTime.utc(2026, 9, 18, 3, 10),
            localDate: LocalDate(2026, 9, 18),
            rakaatSpanCount: 2,
            prayerSessionId: 'session-1',
            prayerSessionPartId: 'part-fard',
            slotIndex: 0,
            rotationSchemeId: 'surah-112:scheme:1',
            coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
          ),
          envelopeId: 'envelope-r',
          deviceId: 'other-device',
          idempotencyKey: 'key-r',
          schemaVersion: 10,
          updatedAtUtc: DateTime.utc(2026, 9, 18, 4),
        ),
      ),
    );

    await expectLater(
      () => applyIn(
        () => applier.apply(
          upsertOf(
            session(
              parts: <PrayerSessionSyncPart>[
                part(id: 'part-sunnah', orderIndex: 0, kind: 'sunnah'),
              ],
            ),
            minute: 30,
          ),
        ),
      ),
      refuses('remote-session-drops-a-used-part'),
      reason:
          'the database would null the reference rather than refuse, quietly '
          'detaching the surah from the slot it filled',
    );
  });

  test('a session with prayers in it is not deleted', () async {
    await applyIn(() => applier.apply(upsertOf(session())));
    await applyIn(
      () => RecitationSyncApplier(database).apply(
        RecitationSyncPayload.upsert(
          SurahRecitationEvent(
            id: 'event-1',
            surahId: 'surah-112',
            prayerContext: PrayerContext(prayerType: PrayerType.fajr),
            createdAtUtc: DateTime.utc(2026, 9, 18, 3, 10),
            localDate: LocalDate(2026, 9, 18),
            rakaatSpanCount: 2,
            prayerSessionId: 'session-1',
            rotationSchemeId: 'surah-112:scheme:1',
            coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
          ),
          envelopeId: 'envelope-r',
          deviceId: 'other-device',
          idempotencyKey: 'key-r',
          schemaVersion: 10,
          updatedAtUtc: DateTime.utc(2026, 9, 18, 4),
        ),
      ),
    );

    await expectLater(
      () => applyIn(
        () => applier.apply(
          SyncEnvelope(
            id: 'envelope-gone',
            deviceId: 'other-device',
            entityType: SyncEntityType.prayerSession,
            entityId: 'session-1',
            operation: SyncOperation.delete,
            schemaVersion: 10,
            createdAtUtc: DateTime.utc(2026, 9, 18, 3),
            updatedAtUtc: DateTime.utc(2026, 9, 18, 5),
            idempotencyKey: 'key-gone',
          ),
        ),
      ),
      refuses('remote-session-still-has-prayers'),
    );
  });

  test('an empty session is deleted cleanly', () async {
    await applyIn(() => applier.apply(upsertOf(session())));

    await applyIn(
      () => applier.apply(
        SyncEnvelope(
          id: 'envelope-gone',
          deviceId: 'other-device',
          entityType: SyncEntityType.prayerSession,
          entityId: 'session-1',
          operation: SyncOperation.delete,
          schemaVersion: 10,
          createdAtUtc: DateTime.utc(2026, 9, 18, 3),
          updatedAtUtc: DateTime.utc(2026, 9, 18, 5),
          idempotencyKey: 'key-gone',
        ),
      ),
    );

    expect(await database.select(database.prayerSessions).get(), isEmpty);
    expect(await database.select(database.prayerSessionParts).get(), isEmpty);
  });

  test('session first, then the prayer, with the link intact', () async {
    await applyIn(() => applier.apply(upsertOf(session())));
    await applyIn(
      () => RecitationSyncApplier(database).apply(
        RecitationSyncPayload.upsert(
          SurahRecitationEvent(
            id: 'event-1',
            surahId: 'surah-112',
            prayerContext: PrayerContext(prayerType: PrayerType.fajr),
            createdAtUtc: DateTime.utc(2026, 9, 18, 3, 10),
            localDate: LocalDate(2026, 9, 18),
            rakaatSpanCount: 2,
            prayerSessionId: 'session-1',
            prayerSessionPartId: 'part-fard',
            slotIndex: 0,
            rotationSchemeId: 'surah-112:scheme:1',
            coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
          ),
          envelopeId: 'envelope-r',
          deviceId: 'other-device',
          idempotencyKey: 'key-r',
          schemaVersion: 10,
          updatedAtUtc: DateTime.utc(2026, 9, 18, 4),
        ),
      ),
    );

    final stored = await RecitationRepository(database).getHistory();
    expect(stored.single.event.prayerSessionId, 'session-1');
    expect(
      stored.single.event.prayerSessionPartId,
      'part-fard',
      reason: 'which slot the surah filled is the basis of the routine screen',
    );
  });

  test('a prayer whose session is not here is refused, retryably', () async {
    await expectLater(
      () => applyIn(
        () => RecitationSyncApplier(database).apply(
          RecitationSyncPayload.upsert(
            SurahRecitationEvent(
              id: 'event-1',
              surahId: 'surah-112',
              prayerContext: PrayerContext(prayerType: PrayerType.fajr),
              createdAtUtc: DateTime.utc(2026, 9, 18, 3, 10),
              localDate: LocalDate(2026, 9, 18),
              rakaatSpanCount: 2,
              prayerSessionId: 'session-never-arrived',
              rotationSchemeId: 'surah-112:scheme:1',
              coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
            ),
            envelopeId: 'envelope-r',
            deviceId: 'other-device',
            idempotencyKey: 'key-r',
            schemaVersion: 10,
            updatedAtUtc: DateTime.utc(2026, 9, 18, 4),
          ),
        ),
      ),
      refuses('remote-recitation-session-missing'),
      reason:
          'the alternative was nulling the reference, which loses which prayer '
          'the surah was recited in',
    );
  });
}
