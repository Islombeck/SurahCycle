import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/mastered_surah_sync_applier.dart';
import 'package:murajaah/core/data/sync/recitation_sync_applier.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/mastered_surah_sync_payload.dart';
import 'package:murajaah/core/sync/recitation_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The roster arriving is what makes a recitation applicable at all, so the
/// test that matters most here is the last one: roster first, then the prayer,
/// and the prayer lands.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;
  late MasteredSurahSyncApplier applier;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    applier = MasteredSurahSyncApplier(database);
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
  });

  tearDown(() => database.close());

  MasteredSurahSyncRecord record({
    String surahId = 'surah-112',
    bool isCurrentlyMastered = true,
    bool isActive = true,
    String? alias,
  }) => MasteredSurahSyncRecord(
    surahId: surahId,
    isCurrentlyMastered: isCurrentlyMastered,
    isActive: isActive,
    hasEnteredRotation: true,
    activationBaselineScore: 0,
    alias: alias,
    displayOrder: 1,
  );

  SyncEnvelope upsertOf(MasteredSurahSyncRecord source, {int minute = 0}) =>
      MasteredSurahSyncPayload.upsert(
        source,
        envelopeId: 'envelope-${source.surahId}-$minute',
        deviceId: 'other-device',
        idempotencyKey: 'key-${source.surahId}-$minute',
        schemaVersion: 10,
        updatedAtUtc: DateTime.utc(2026, 9, 18, 9, minute),
      );

  Future<void> applyIn(Future<void> Function() body) =>
      database.transaction(body);

  test('a roster entry arrives with the owner\'s own choices', () async {
    await applyIn(() => applier.apply(upsertOf(record(alias: 'Ихлас'))));

    final stored = (await surahs.getRotationSnapshot()).surahById('surah-112');
    expect(stored.isActive, isTrue);
    expect(stored.hasEnteredRotation, isTrue);
    expect(stored.surah.alias, 'Ихлас');
    expect(stored.displayOrder, 1);
  });

  test('it arrives with a scheme, because everything assumes one', () async {
    await applyIn(() => applier.apply(upsertOf(record())));

    final schemes = await database.select(database.rotationSchemes).get();
    final parts = await database.select(database.rotationParts).get();
    expect(schemes, hasLength(1));
    expect(schemes.single.id, 'surah-112:scheme:1');
    expect(
      schemes.single.ayahCountSnapshot,
      4,
      reason: 'taken from the corpus, not guessed',
    );
    expect(parts.single.startAyah, 1);
    expect(
      parts.single.endAyah,
      4,
      reason: 'the default is the whole surah, exactly as addMastered makes it',
    );
  });

  test('a surah he has re-split still takes its roster entry', () async {
    // His Al-Baqara carries two schemes — one superseded, one in force. Asking
    // "does this surah have a scheme" with `getSingleOrNull` threw
    // `StateError: Too many elements`, out of the applier, out of the cycle,
    // caught by nothing. His own phone stopped receiving for a day over it and
    // reported success from the morning before.
    await surahs.addMastered('surah-112');
    await database.customStatement(
      'INSERT INTO rotation_schemes (id, surah_id, version, '
      'ayah_count_snapshot, baseline_score, baseline_total_recitations, '
      'resets_rotation_baseline, activated_journal_sequence, '
      'superseded_journal_sequence) '
      "VALUES ('surah-112:scheme:2', 'surah-112', 2, 4, 0, 0, 0, 7, 7)",
    );

    await expectLater(
      applyIn(() => applier.apply(upsertOf(record(alias: 'Ихлас')))),
      completes,
    );
    expect(
      (await surahs.getRotationSnapshot()).surahById('surah-112').surah.alias,
      'Ихлас',
    );
    expect(
      await database.select(database.rotationSchemes).get(),
      hasLength(2),
      reason: 'and no third scheme is invented on top of the two he has',
    );
  });

  test('the cached statistics are left to the journal', () async {
    await applyIn(() => applier.apply(upsertOf(record())));

    final row = await database.select(database.masteredSurahs).getSingle();
    expect(row.cachedTotalRecitations, 0);
    expect(row.cachedRotationScore, 0);
    expect(
      row.cachedLastUsedAtUtc,
      isNull,
      reason:
          'these are a projection; importing them would give the device two '
          'answers for one number',
    );
  });

  test('applying it twice changes nothing', () async {
    final envelope = upsertOf(record());
    await applyIn(() => applier.apply(envelope));

    await applyIn(() => applier.apply(envelope));

    expect(await database.select(database.masteredSurahs).get(), hasLength(1));
    expect(await database.select(database.rotationSchemes).get(), hasLength(1));
  });

  test('a later version updates the entry in place', () async {
    await applyIn(() => applier.apply(upsertOf(record(alias: 'Первое'))));

    await applyIn(
      () => applier.apply(upsertOf(record(alias: 'Второе'), minute: 30)),
    );

    final row = await database.select(database.masteredSurahs).getSingle();
    expect(row.alias, 'Второе');
    expect(await database.select(database.rotationSchemes).get(), hasLength(1));
  });

  test('a withdrawal unmasters rather than deletes', () async {
    await applyIn(() => applier.apply(upsertOf(record())));

    await applyIn(
      () => applier.apply(
        SyncEnvelope(
          id: 'envelope-gone',
          deviceId: 'other-device',
          entityType: SyncEntityType.masteredSurah,
          entityId: 'surah-112',
          operation: SyncOperation.delete,
          schemaVersion: 10,
          createdAtUtc: DateTime.utc(2026, 9, 18, 10),
          updatedAtUtc: DateTime.utc(2026, 9, 18, 10),
          idempotencyKey: 'key-gone',
        ),
      ),
    );

    final row = await database.select(database.masteredSurahs).getSingle();
    expect(
      row.isCurrentlyMastered,
      isFalse,
      reason:
          'deleting the row would cascade into every recitation that '
          'references it, and the schema forbids that outright',
    );
    expect(
      row.isActive,
      isFalse,
      reason: 'a surah that is not currently mastered cannot be active',
    );
  });

  test('a surah the catalog does not have yet is refused, retryably', () async {
    await expectLater(
      () => applyIn(() => applier.apply(upsertOf(record(surahId: 'surah-99')))),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.reason,
          'reason',
          'remote-roster-surah-not-in-catalog',
        ),
      ),
      reason:
          'the corpus is fetched by manifest rather than synced, so this is a '
          'device still setting itself up, not a broken payload',
    );
  });

  test('roster first, then the prayer, and the prayer lands', () async {
    // The whole point of doing the roster before anything else: this exact
    // sequence used to be impossible, because the recitation had nothing to
    // reference.
    final event = SurahRecitationEvent(
      id: 'incoming-1',
      surahId: 'surah-112',
      prayerContext: PrayerContext(prayerType: PrayerType.fajr),
      createdAtUtc: DateTime.utc(2026, 9, 18, 3),
      localDate: LocalDate(2026, 9, 18),
      rakaatSpanCount: 2,
      rotationSchemeId: 'surah-112:scheme:1',
      coveredPartIds: const <String>['surah-112:scheme:1:part:1'],
    );

    await applyIn(() => applier.apply(upsertOf(record())));
    await applyIn(
      () => RecitationSyncApplier(database).apply(
        RecitationSyncPayload.upsert(
          event,
          envelopeId: 'envelope-r',
          deviceId: 'other-device',
          idempotencyKey: 'key-r',
          schemaVersion: 10,
          updatedAtUtc: DateTime.utc(2026, 9, 18, 4),
        ),
      ),
    );

    final history = await recitations.getHistory();
    expect(history, hasLength(1));
    expect(history.single.event.surahId, 'surah-112');
    expect(
      (await surahs.getRotationSnapshot())
          .surahById('surah-112')
          .totalRecitations,
      1,
    );
  });
}
