import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/recitation_sync_applier.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/recitation_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The receiving end. A recitation that left one device has to arrive on
/// another as the same prayer — same day, same namaz, same Qada flags — and
/// anything that cannot be written has to stay on the server rather than be
/// dropped on the floor.
///
/// The applier never re-decides the *record*: a recitation is append-only, so
/// two devices produce different prayers rather than two versions of one, and
/// what arrives is written as sent.
///
/// Whether the prayer **stands** is the one thing both devices can touch, and
/// that is decided here — by the state stamp, the same comparison the local
/// withdrawal and restore paths use. It has to be: the account's log is ordered
/// by when a change reached it, not by when it was made, so arrival order would
/// let a withdrawal made offline on Monday undo a restore made on Tuesday.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;
  late RecitationSyncApplier applier;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    applier = RecitationSyncApplier(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlas',
          ayahCount: 4,
        ),
        SurahDescriptor(
          id: 'surah-108',
          surahNumber: 108,
          officialName: 'Al-Kawthar',
          ayahCount: 3,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-112');
  });

  tearDown(() => database.close());

  SurahRecitationEvent event({
    String id = 'incoming-1',
    String surahId = 'surah-112',
    bool isQada = false,
    bool qadaOriginIsUnknown = false,
    LocalDate? qadaFulfilledLocalDate,
  }) => SurahRecitationEvent(
    id: id,
    surahId: surahId,
    prayerContext: PrayerContext(
      prayerType: PrayerType.maghrib,
      isQada: isQada,
    ),
    createdAtUtc: DateTime.utc(2026, 9, 16, 15, 30),
    localDate: LocalDate(2026, 9, 16),
    rakaatSpanCount: 2,
    qadaOriginIsUnknown: qadaOriginIsUnknown,
    qadaFulfilledLocalDate: qadaFulfilledLocalDate,
    rotationSchemeId: '$surahId:scheme:1',
    coveredPartIds: <String>['$surahId:scheme:1:part:1'],
  );

  SyncEnvelope upsertOf(
    SurahRecitationEvent source, {
    int hour = 16,
    int minute = 0,
  }) => RecitationSyncPayload.upsert(
    source,
    envelopeId: 'envelope-${source.id}-$hour-$minute',
    deviceId: 'other-device',
    idempotencyKey: 'key-${source.id}-$hour-$minute',
    schemaVersion: 10,
    updatedAtUtc: DateTime.utc(2026, 9, 16, hour, minute),
  );

  Future<void> applyIn(SyncEnvelope envelope) =>
      database.transaction(() => applier.apply(envelope));

  Matcher refuses(String reason) => throwsA(
    isA<SyncTransportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  group('a recitation from another device', () {
    test('arrives as the same prayer on the same day', () async {
      await applyIn(upsertOf(event()));

      final entry = (await recitations.getHistory()).single;
      expect(entry.event.id, 'incoming-1');
      expect(entry.event.surahId, 'surah-112');
      expect(entry.event.prayerType, PrayerType.maghrib);
      expect(entry.event.localDate, LocalDate(2026, 9, 16));
      expect(entry.event.createdAtUtc, DateTime.utc(2026, 9, 16, 15, 30));
      expect(entry.event.rakaatSpanCount, 2);
      expect(entry.coveredParts, hasLength(1));
    });

    test('a Qada keeps every flag that makes it one', () async {
      await applyIn(upsertOf(event(isQada: true, qadaOriginIsUnknown: true)));

      final stored = (await recitations.getHistory()).single.event;
      expect(stored.isQada, isTrue);
      expect(
        stored.qadaOriginIsUnknown,
        isTrue,
        reason: 'the receiving device must not claim he named a day',
      );
    });

    test('it counts towards the rotation balance here too', () async {
      final before = (await surahs.getRotationSnapshot())
          .surahById('surah-112')
          .totalRecitations;

      await applyIn(upsertOf(event()));

      expect(
        (await surahs.getRotationSnapshot())
            .surahById('surah-112')
            .totalRecitations,
        before + 1,
        reason:
            'a prayer that arrived is a prayer that happened, and the balance '
            'is what the app is for',
      );
    });

    test('it takes this journal sequence, not the sending one', () async {
      await recitations.register(event(id: 'local-1'));

      await applyIn(upsertOf(event(id: 'incoming-1')));

      final sequences = <int>[
        for (final entry in await recitations.getHistory())
          entry.journalSequence,
      ]..sort();
      expect(
        sequences,
        <int>[1, 2],
        reason:
            'two devices number their journals independently, so importing a '
            'number would collide with one already used here',
      );
    });
  });

  group('applying twice', () {
    test('the same envelope again changes nothing', () async {
      final envelope = upsertOf(event());
      await applyIn(envelope);

      await applyIn(envelope);

      expect(await recitations.getHistory(), hasLength(1));
      expect((await recitations.getStats()).total, 1);
    });

    test('a later version replaces the earlier one', () async {
      await applyIn(upsertOf(event()));

      await applyIn(
        upsertOf(
          SurahRecitationEvent(
            id: 'incoming-1',
            surahId: 'surah-112',
            prayerContext: PrayerContext(prayerType: PrayerType.isha),
            createdAtUtc: DateTime.utc(2026, 9, 16, 15, 30),
            localDate: LocalDate(2026, 9, 16),
            rakaatSpanCount: 4,
            rotationSchemeId: 'surah-112:scheme:1',
            coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
          ),
          minute: 30,
        ),
      );

      final stored = (await recitations.getHistory()).single.event;
      expect(stored.prayerType, PrayerType.isha);
      expect(stored.rakaatSpanCount, 4);
    });
  });

  group('a withdrawal', () {
    test('marks a local recitation deleted', () async {
      await applyIn(upsertOf(event()));

      await applyIn(
        RecitationSyncPayload.tombstone(
          entityId: 'incoming-1',
          envelopeId: 'envelope-gone',
          deviceId: 'other-device',
          idempotencyKey: 'key-gone',
          schemaVersion: 10,
          originalCreatedAtUtc: DateTime.utc(2026, 9, 16, 15, 30),
          deletedAtUtc: DateTime.utc(2026, 9, 16, 18),
        ),
      );

      expect(await recitations.getHistory(), isEmpty);
      final withDeleted = await recitations.getHistory(includeDeleted: true);
      expect(withDeleted.single.deletedAtUtc, DateTime.utc(2026, 9, 16, 18));
    });

    test('for something never seen here invents nothing', () async {
      await applyIn(
        RecitationSyncPayload.tombstone(
          entityId: 'never-here',
          envelopeId: 'envelope-gone',
          deviceId: 'other-device',
          idempotencyKey: 'key-gone',
          schemaVersion: 10,
          originalCreatedAtUtc: DateTime.utc(2026, 9, 16, 15, 30),
          deletedAtUtc: DateTime.utc(2026, 9, 16, 18),
        ),
      );

      expect(
        await recitations.getHistory(includeDeleted: true),
        isEmpty,
        reason:
            'creating a row so it can be marked deleted would put a prayer in '
            'the journal that never happened here',
      );
    });

    test('a later upsert revives the recitation', () async {
      await applyIn(upsertOf(event()));
      await applyIn(
        RecitationSyncPayload.tombstone(
          entityId: 'incoming-1',
          envelopeId: 'envelope-gone',
          deviceId: 'other-device',
          idempotencyKey: 'key-gone',
          schemaVersion: 10,
          originalCreatedAtUtc: DateTime.utc(2026, 9, 16, 15, 30),
          deletedAtUtc: DateTime.utc(2026, 9, 16, 18),
        ),
      );

      await applyIn(upsertOf(event(), hour: 18, minute: 30));

      expect(
        await recitations.getHistory(),
        hasLength(1),
        reason:
            'this is what a restore on the other device looks like from here, '
            'and it was made after the withdrawal it undoes',
      );
    });

    test('an earlier upsert does not revive the recitation', () async {
      await applyIn(upsertOf(event()));
      await applyIn(
        RecitationSyncPayload.tombstone(
          entityId: 'incoming-1',
          envelopeId: 'envelope-gone',
          deviceId: 'other-device',
          idempotencyKey: 'key-gone',
          schemaVersion: 10,
          originalCreatedAtUtc: DateTime.utc(2026, 9, 16, 15, 30),
          deletedAtUtc: DateTime.utc(2026, 9, 16, 18),
        ),
      );

      await applyIn(upsertOf(event(), minute: 45));

      expect(
        await recitations.getHistory(),
        isEmpty,
        reason:
            'an edit made before the withdrawal reached the account after it, '
            'and arriving last is not the same as being the newer decision',
      );
      final withDeleted = await recitations.getHistory(includeDeleted: true);
      expect(
        withDeleted.single.deletedAtUtc,
        DateTime.utc(2026, 9, 16, 18),
        reason: 'the record is still updated; only its standing is not',
      );
    });
  });

  group('what cannot be written stays on the server', () {
    test('a recitation whose surah is not here is refused', () async {
      // surah-108 is in the catalog but was never mastered, so no roster entry
      // and no scheme exist for it.
      await expectLater(
        () => applyIn(upsertOf(event(id: 'x', surahId: 'surah-108'))),
        refuses('remote-recitation-surah-missing'),
        reason:
            'retryable on purpose: the roster entry is itself an entity that '
            'syncs, so the ordinary case is that it arrives and this applies',
      );
      expect(await recitations.getHistory(includeDeleted: true), isEmpty);
    });

    test('a refusal leaves the database untouched', () async {
      await applyIn(upsertOf(event()));

      await expectLater(
        () => applyIn(upsertOf(event(id: 'x', surahId: 'surah-108'))),
        refuses('remote-recitation-surah-missing'),
      );

      expect(
        await recitations.getHistory(),
        hasLength(1),
        reason: 'the page rolls back whole, and the cursor with it',
      );
    });

    test('an envelope of another kind is a programming error', () async {
      final foreign = SyncEnvelope(
        id: 'envelope-1',
        deviceId: 'other-device',
        entityType: SyncEntityType.appSetting,
        entityId: 'theme',
        operation: SyncOperation.upsert,
        schemaVersion: 10,
        createdAtUtc: DateTime.utc(2026, 9, 16),
        updatedAtUtc: DateTime.utc(2026, 9, 16),
        idempotencyKey: 'key-1',
        payload: const <String, Object?>{'value': 'dark'},
      );

      expect(applier.handles(foreign), isFalse);
      await expectLater(
        () => applyIn(foreign),
        throwsA(isA<StateError>()),
        reason: 'routing is the caller\'s job and a mistake in it is a bug',
      );
    });
  });
}
