import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  late AppDatabase database;
  late PrayerRoutineRepository routines;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    routines = PrayerRoutineRepository(database);
  });

  tearDown(() => database.close());

  PrayerRoutinePartTemplate part({
    required String id,
    required int orderIndex,
    required PrayerRoutinePartKind kind,
  }) => PrayerRoutinePartTemplate(
    id: id,
    stableKey: 'key:$id',
    orderIndex: orderIndex,
    kind: kind,
    rakaatCount: 2,
    requiredSurahSlots: 2,
  );

  Future<void> configure(
    PrayerType prayerType,
    List<PrayerRoutinePartKind> kinds,
  ) async {
    var template = await routines.getTemplate(prayerType);
    for (var index = 0; index < kinds.length; index += 1) {
      template = await routines.addPart(
        prayerType: prayerType,
        expectedRevision: template.revision,
        part: part(
          id: '${prayerType.name}-${kinds[index].name}',
          orderIndex: index,
          kind: kinds[index],
        ),
      );
    }
  }

  Future<PrayerRoutineSessionSnapshot?> session(
    PrayerContext context, {
    LocalDate? localDate,
  }) => routines.ensureCurrentSession(
    context: context,
    localDate: localDate ?? LocalDate(2026, 9, 14),
    startedAtUtc: DateTime.utc(2026, 9, 14, 12),
  );

  test('a Qada Fard session keeps only the Fard part', () async {
    await configure(PrayerType.fajr, <PrayerRoutinePartKind>[
      PrayerRoutinePartKind.sunnah,
      PrayerRoutinePartKind.fard,
    ]);

    final snapshot = await session(
      PrayerContext(prayerType: PrayerType.fajr, isQada: true),
    );

    expect(snapshot, isNotNull);
    expect(
      snapshot!.parts.map((progress) => progress.part.kind),
      <PrayerRoutinePartKind>[PrayerRoutinePartKind.fard],
    );
  });

  test('the same routine keeps every part in an ordinary session', () async {
    await configure(PrayerType.fajr, <PrayerRoutinePartKind>[
      PrayerRoutinePartKind.sunnah,
      PrayerRoutinePartKind.fard,
    ]);

    final snapshot = await session(PrayerContext(prayerType: PrayerType.fajr));

    expect(
      snapshot!.parts.map((progress) => progress.part.kind),
      <PrayerRoutinePartKind>[
        PrayerRoutinePartKind.sunnah,
        PrayerRoutinePartKind.fard,
      ],
    );
  });

  test('a Qada Witr session keeps only its own Witr part', () async {
    await configure(PrayerType.witr, <PrayerRoutinePartKind>[
      PrayerRoutinePartKind.witr,
      PrayerRoutinePartKind.nafl,
    ]);

    final snapshot = await session(
      PrayerContext(prayerType: PrayerType.witr, isQada: true),
    );

    expect(
      snapshot!.parts.map((progress) => progress.part.kind),
      <PrayerRoutinePartKind>[PrayerRoutinePartKind.witr],
    );
  });

  test(
    'a Qada context with no obligatory part keeps the slotless flow',
    () async {
      await configure(PrayerType.dhuhr, <PrayerRoutinePartKind>[
        PrayerRoutinePartKind.sunnah,
        PrayerRoutinePartKind.nafl,
      ]);

      final snapshot = await session(
        PrayerContext(prayerType: PrayerType.dhuhr, isQada: true),
      );

      expect(
        snapshot,
        isNull,
        reason: 'no routine means an ordinary mark, never a forced Qada slot',
      );
    },
  );

  test('a past date alone does not make a session Qada', () async {
    await configure(PrayerType.asr, <PrayerRoutinePartKind>[
      PrayerRoutinePartKind.sunnah,
      PrayerRoutinePartKind.fard,
    ]);

    final snapshot = await session(
      PrayerContext(prayerType: PrayerType.asr),
      localDate: LocalDate(2026, 9, 1),
    );

    expect(snapshot!.session.context.isQada, isFalse);
    expect(snapshot.parts, hasLength(2));
  });

  test('a legacy Qada session with a voluntary part stays readable', () async {
    const sessionId = 'legacy-qada-session';
    await database
        .into(database.prayerSessions)
        .insert(
          PrayerSessionsCompanion.insert(
            id: sessionId,
            prayerType: PrayerType.dhuhr.name,
            isQada: const Value<bool>(true),
            startedAtUtc: DateTime.utc(2026, 9, 1, 12),
            localDate: const Value<String?>('2026-09-01'),
          ),
        );
    await database
        .into(database.prayerSessionParts)
        .insert(
          PrayerSessionPartsCompanion.insert(
            id: '$sessionId:part:sunnah',
            prayerSessionId: sessionId,
            stableKey: 'sunnah',
            orderIndex: 0,
            label: 'Sunnah',
            kind: PrayerRoutinePartKind.sunnah.name,
            rakaatCount: 2,
            requiredSurahSlots: 2,
            allowsFollowingImam: false,
          ),
        );

    final stored = await routines.getRoutineSession(sessionId);

    expect(stored, isNotNull);
    expect(stored!.parts.single.part.kind, PrayerRoutinePartKind.sunnah);
  });

  group('the write boundary re-checks the rule', () {
    late RecitationRepository recitations;

    setUp(() async {
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
        ],
        sourceId: 'verified-test-source',
        sourceVersion: 'test-v1',
      );
      await surahs.addMastered('surah-a');
    });

    test('a new Qada recitation on a voluntary part is rejected', () async {
      const sessionId = 'legacy-qada-session';
      await database
          .into(database.prayerSessions)
          .insert(
            PrayerSessionsCompanion.insert(
              id: sessionId,
              prayerType: PrayerType.dhuhr.name,
              isQada: const Value<bool>(true),
              startedAtUtc: DateTime.utc(2026, 9, 14, 12),
              localDate: const Value<String?>('2026-09-14'),
            ),
          );
      await database
          .into(database.prayerSessionParts)
          .insert(
            PrayerSessionPartsCompanion.insert(
              id: '$sessionId:part:sunnah',
              prayerSessionId: sessionId,
              stableKey: 'sunnah',
              orderIndex: 0,
              label: 'Sunnah',
              kind: PrayerRoutinePartKind.sunnah.name,
              rakaatCount: 2,
              requiredSurahSlots: 2,
              allowsFollowingImam: false,
            ),
          );

      await expectLater(
        recitations.register(
          SurahRecitationEvent(
            id: 'forged-event',
            surahId: 'surah-a',
            prayerContext: PrayerContext(
              prayerType: PrayerType.dhuhr,
              isQada: true,
            ),
            createdAtUtc: DateTime.utc(2026, 9, 14, 12, 30),
            localDate: LocalDate(2026, 9, 14),
            prayerSessionId: sessionId,
            prayerSessionPartId: '$sessionId:part:sunnah',
            slotIndex: 0,
          ),
        ),
        throwsA(
          isA<PrayerSessionSlotUnavailableException>().having(
            (error) => error.reason,
            'reason',
            PrayerSessionSlotUnavailableReason.qadaPartNotEligible,
          ),
        ),
      );
    });

    test('the same recitation is accepted on the Fard part', () async {
      await configure(PrayerType.dhuhr, <PrayerRoutinePartKind>[
        PrayerRoutinePartKind.fard,
      ]);
      final snapshot = await session(
        PrayerContext(prayerType: PrayerType.dhuhr, isQada: true),
      );
      final target = snapshot!.parts.single.part;

      final registration = await recitations.register(
        SurahRecitationEvent(
          id: 'valid-event',
          surahId: 'surah-a',
          prayerContext: PrayerContext(
            prayerType: PrayerType.dhuhr,
            isQada: true,
          ),
          createdAtUtc: DateTime.utc(2026, 9, 14, 12, 30),
          localDate: LocalDate(2026, 9, 14),
          prayerSessionId: snapshot.session.id,
          prayerSessionPartId: target.id,
          slotIndex: 0,
        ),
      );

      expect(registration, isNotNull);
    });
  });
}
