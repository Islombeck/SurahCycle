import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  late AppDatabase database;
  late RecitationRepository recitations;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    recitations = RecitationRepository(database);
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-a',
          surahNumber: 2,
          officialName: 'Test Surah A',
          ayahCount: 3,
        ),
        SurahDescriptor(
          id: 'surah-b',
          surahNumber: 3,
          officialName: 'Test Surah B',
          ayahCount: 3,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-a');
    await surahs.addMastered('surah-b');
  });

  tearDown(() => database.close());

  test(
    'reads by the same stable key correlate across different sessions',
    () async {
      final sessionOneId = await _insertSession(
        database,
        prayerType: PrayerType.dhuhr,
        localDate: '2026-09-01',
      );
      final fardOneId = await _insertPart(
        database,
        sessionId: sessionOneId,
        stableKey: 'fard',
        orderIndex: 0,
      );
      final sessionTwoId = await _insertSession(
        database,
        prayerType: PrayerType.dhuhr,
        localDate: '2026-09-02',
      );
      final fardTwoId = await _insertPart(
        database,
        sessionId: sessionTwoId,
        stableKey: 'fard',
        orderIndex: 0,
      );
      final earlier = DateTime.utc(2026, 9, 1, 12);
      final later = DateTime.utc(2026, 9, 2, 12);
      await _insertEvent(
        database,
        id: 'event-a-day1',
        surahId: 'surah-a',
        journalSequence: 1,
        prayerType: PrayerType.dhuhr,
        createdAtUtc: earlier,
        localDate: '2026-09-01',
        prayerSessionId: sessionOneId,
        prayerSessionPartId: fardOneId,
      );
      await _insertEvent(
        database,
        id: 'event-b-day2',
        surahId: 'surah-b',
        journalSequence: 2,
        prayerType: PrayerType.dhuhr,
        createdAtUtc: later,
        localDate: '2026-09-02',
        prayerSessionId: sessionTwoId,
        prayerSessionPartId: fardTwoId,
      );

      final result = await recitations.getLastUsedByRoutinePart(
        prayerType: PrayerType.dhuhr,
        isQada: false,
        stableKey: 'fard',
      );

      expect(result, <String, DateTime>{'surah-a': earlier, 'surah-b': later});
    },
  );

  test('a different stable key in the same prayer is not conflated', () async {
    final sessionId = await _insertSession(
      database,
      prayerType: PrayerType.isha,
      localDate: '2026-09-01',
    );
    final fardId = await _insertPart(
      database,
      sessionId: sessionId,
      stableKey: 'fard',
      orderIndex: 0,
    );
    final sunnahId = await _insertPart(
      database,
      sessionId: sessionId,
      stableKey: 'sunnah',
      orderIndex: 1,
    );
    await _insertEvent(
      database,
      id: 'event-fard',
      surahId: 'surah-a',
      journalSequence: 1,
      prayerType: PrayerType.isha,
      createdAtUtc: DateTime.utc(2026, 9, 1, 19),
      localDate: '2026-09-01',
      prayerSessionId: sessionId,
      prayerSessionPartId: fardId,
    );
    await _insertEvent(
      database,
      id: 'event-sunnah',
      surahId: 'surah-b',
      journalSequence: 2,
      prayerType: PrayerType.isha,
      createdAtUtc: DateTime.utc(2026, 9, 1, 19, 5),
      localDate: '2026-09-01',
      prayerSessionId: sessionId,
      prayerSessionPartId: sunnahId,
    );

    final fardResult = await recitations.getLastUsedByRoutinePart(
      prayerType: PrayerType.isha,
      isQada: false,
      stableKey: 'fard',
    );
    final sunnahResult = await recitations.getLastUsedByRoutinePart(
      prayerType: PrayerType.isha,
      isQada: false,
      stableKey: 'sunnah',
    );

    expect(fardResult.keys, <String>['surah-a']);
    expect(sunnahResult.keys, <String>['surah-b']);
  });

  test('Qada events never contaminate ordinary contextual stats', () async {
    final ordinarySessionId = await _insertSession(
      database,
      prayerType: PrayerType.fajr,
      localDate: '2026-09-01',
    );
    final ordinaryPartId = await _insertPart(
      database,
      sessionId: ordinarySessionId,
      stableKey: 'fard',
      orderIndex: 0,
    );
    final qadaSessionId = await _insertSession(
      database,
      prayerType: PrayerType.fajr,
      isQada: true,
      localDate: '2026-09-02',
    );
    final qadaPartId = await _insertPart(
      database,
      sessionId: qadaSessionId,
      stableKey: 'fard',
      orderIndex: 0,
    );
    await _insertEvent(
      database,
      id: 'event-ordinary',
      surahId: 'surah-a',
      journalSequence: 1,
      prayerType: PrayerType.fajr,
      createdAtUtc: DateTime.utc(2026, 9, 1, 5),
      localDate: '2026-09-01',
      prayerSessionId: ordinarySessionId,
      prayerSessionPartId: ordinaryPartId,
    );
    await _insertEvent(
      database,
      id: 'event-qada',
      surahId: 'surah-b',
      journalSequence: 2,
      prayerType: PrayerType.fajr,
      isQada: true,
      createdAtUtc: DateTime.utc(2026, 9, 2, 8),
      localDate: '2026-09-02',
      prayerSessionId: qadaSessionId,
      prayerSessionPartId: qadaPartId,
    );

    final ordinary = await recitations.getLastUsedByRoutinePart(
      prayerType: PrayerType.fajr,
      isQada: false,
      stableKey: 'fard',
    );
    final qada = await recitations.getLastUsedByRoutinePart(
      prayerType: PrayerType.fajr,
      isQada: true,
      stableKey: 'fard',
    );

    expect(ordinary.keys, <String>['surah-a']);
    expect(qada.keys, <String>['surah-b']);
  });

  test('an unused stable key returns an empty map', () async {
    final result = await recitations.getLastUsedByRoutinePart(
      prayerType: PrayerType.maghrib,
      isQada: false,
      stableKey: 'never-used',
    );

    expect(result, isEmpty);
  });

  test('a later repeat read in the same part keeps the newest time', () async {
    final sessionOneId = await _insertSession(
      database,
      prayerType: PrayerType.asr,
      localDate: '2026-09-01',
    );
    final partOneId = await _insertPart(
      database,
      sessionId: sessionOneId,
      stableKey: 'fard',
      orderIndex: 0,
    );
    final sessionTwoId = await _insertSession(
      database,
      prayerType: PrayerType.asr,
      localDate: '2026-09-05',
    );
    final partTwoId = await _insertPart(
      database,
      sessionId: sessionTwoId,
      stableKey: 'fard',
      orderIndex: 0,
    );
    await _insertEvent(
      database,
      id: 'event-old',
      surahId: 'surah-a',
      journalSequence: 1,
      prayerType: PrayerType.asr,
      createdAtUtc: DateTime.utc(2026, 9, 1, 16),
      localDate: '2026-09-01',
      prayerSessionId: sessionOneId,
      prayerSessionPartId: partOneId,
    );
    final newest = DateTime.utc(2026, 9, 5, 16);
    await _insertEvent(
      database,
      id: 'event-new',
      surahId: 'surah-a',
      journalSequence: 2,
      prayerType: PrayerType.asr,
      createdAtUtc: newest,
      localDate: '2026-09-05',
      prayerSessionId: sessionTwoId,
      prayerSessionPartId: partTwoId,
    );

    final result = await recitations.getLastUsedByRoutinePart(
      prayerType: PrayerType.asr,
      isQada: false,
      stableKey: 'fard',
    );

    expect(result, <String, DateTime>{'surah-a': newest});
  });
}

Future<String> _insertSession(
  AppDatabase database, {
  required PrayerType prayerType,
  bool isQada = false,
  required String localDate,
}) async {
  final id = 'session-${prayerType.name}-$localDate-$isQada';
  await database
      .into(database.prayerSessions)
      .insert(
        PrayerSessionsCompanion.insert(
          id: id,
          prayerType: prayerType.name,
          isQada: Value<bool>(isQada),
          startedAtUtc: DateTime.utc(2026, 1, 1),
          localDate: Value<String?>(localDate),
        ),
      );
  return id;
}

Future<String> _insertPart(
  AppDatabase database, {
  required String sessionId,
  required String stableKey,
  required int orderIndex,
}) async {
  final id = '$sessionId:$stableKey';
  await database
      .into(database.prayerSessionParts)
      .insert(
        PrayerSessionPartsCompanion.insert(
          id: id,
          prayerSessionId: sessionId,
          stableKey: stableKey,
          orderIndex: orderIndex,
          label: stableKey,
          kind: 'fard',
          rakaatCount: 2,
          requiredSurahSlots: 1,
          allowsFollowingImam: false,
        ),
      );
  return id;
}

Future<void> _insertEvent(
  AppDatabase database, {
  required String id,
  required String surahId,
  required int journalSequence,
  required PrayerType prayerType,
  bool isQada = false,
  required DateTime createdAtUtc,
  required String localDate,
  required String prayerSessionId,
  required String prayerSessionPartId,
}) => database
    .into(database.recitationEvents)
    .insert(
      RecitationEventsCompanion.insert(
        id: id,
        journalSequence: journalSequence,
        surahId: surahId,
        rotationSchemeId: '$surahId:scheme:1',
        rakaatSpanCount: 1,
        prayerSessionId: Value<String?>(prayerSessionId),
        prayerSessionPartId: Value<String?>(prayerSessionPartId),
        slotIndex: const Value<int?>(0),
        createdAtUtc: createdAtUtc,
        localDate: localDate,
        prayerType: prayerType.name,
        isQada: Value<bool>(isQada),
      ),
    );
