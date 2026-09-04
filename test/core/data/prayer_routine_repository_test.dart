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

  test(
    'fresh storage exposes an empty editable routine for every prayer',
    () async {
      final templates = await routines.getTemplates();

      expect(templates, hasLength(PrayerType.values.length));
      expect(
        templates.map((template) => template.prayerType).toSet(),
        PrayerType.values.toSet(),
      );
      expect(templates.every((template) => template.revision == 1), isTrue);
      expect(templates.every((template) => template.parts.isEmpty), isTrue);
    },
  );

  test(
    'manual CRUD and reorder preserve exact rakaat and slot values',
    () async {
      var isha = await routines.getTemplate(PrayerType.isha);
      isha = await routines.addPart(
        prayerType: PrayerType.isha,
        expectedRevision: isha.revision,
        part: _part(
          id: 'isha-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 4,
          requiredSurahSlots: 2,
        ),
      );
      isha = await routines.addPart(
        prayerType: PrayerType.isha,
        expectedRevision: isha.revision,
        part: _part(
          id: 'isha-sunnah',
          stableKey: 'sunnah-after',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.sunnah,
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
      );

      expect(isha.revision, 3);
      expect(
        isha.parts.map((part) => (part.rakaatCount, part.requiredSurahSlots)),
        <(int, int)>[(4, 2), (2, 2)],
      );

      isha = await routines.updatePart(
        prayerType: PrayerType.isha,
        expectedRevision: isha.revision,
        replacement: _part(
          id: 'isha-sunnah',
          stableKey: 'sunnah-after',
          orderIndex: 99,
          kind: PrayerRoutinePartKind.sunnah,
          rakaatCount: 2,
          requiredSurahSlots: 1,
        ),
      );
      expect(isha.parts.last.requiredSurahSlots, 1);

      isha = await routines.reorderParts(
        prayerType: PrayerType.isha,
        expectedRevision: isha.revision,
        orderedPartIds: const <String>['isha-sunnah', 'isha-fard'],
      );
      expect(isha.parts.map((part) => part.id), <String>[
        'isha-sunnah',
        'isha-fard',
      ]);
      expect(isha.parts.map((part) => part.orderIndex), <int>[0, 1]);

      isha = await routines.deletePart(
        prayerType: PrayerType.isha,
        expectedRevision: isha.revision,
        partId: 'isha-sunnah',
      );
      expect(isha.parts.single.id, 'isha-fard');
      expect(isha.parts.single.orderIndex, 0);
      expect(isha.revision, 6);
    },
  );

  test(
    'replace stores Dhuhr 4/4 plus a custom zero-slot part exactly',
    () async {
      final current = await routines.getTemplate(PrayerType.dhuhr);

      final dhuhr = await routines.replaceTemplate(
        prayerType: PrayerType.dhuhr,
        expectedRevision: current.revision,
        displayName: 'My Dhuhr',
        enabled: true,
        parts: <PrayerRoutinePartTemplate>[
          _part(
            id: 'dhuhr-sunnah',
            stableKey: 'sunnah-before',
            orderIndex: 0,
            kind: PrayerRoutinePartKind.sunnah,
            rakaatCount: 4,
            requiredSurahSlots: 4,
          ),
          _part(
            id: 'dhuhr-custom',
            stableKey: 'custom-dua',
            orderIndex: 1,
            kind: PrayerRoutinePartKind.custom,
            customLabel: 'Personal completion',
            rakaatCount: 1,
            requiredSurahSlots: 0,
          ),
        ],
      );

      expect(dhuhr.displayName, 'My Dhuhr');
      expect(dhuhr.revision, 2);
      expect(dhuhr.parts.first.rakaatCount, 4);
      expect(dhuhr.parts.first.requiredSurahSlots, 4);
      expect(dhuhr.parts.last.kind, PrayerRoutinePartKind.custom);
      expect(dhuhr.parts.last.customLabel, 'Personal completion');
      expect(dhuhr.parts.last.requiredSurahSlots, 0);
    },
  );

  test(
    'stale editor revision is rejected without overwriting newer data',
    () async {
      final original = await routines.getTemplate(PrayerType.asr);
      final saved = await routines.replaceTemplate(
        prayerType: PrayerType.asr,
        expectedRevision: original.revision,
        displayName: 'First editor',
        enabled: true,
        parts: const <PrayerRoutinePartTemplate>[],
      );

      await expectLater(
        routines.replaceTemplate(
          prayerType: PrayerType.asr,
          expectedRevision: original.revision,
          displayName: 'Stale editor',
          enabled: false,
          parts: const <PrayerRoutinePartTemplate>[],
        ),
        throwsA(
          isA<PrayerRoutineRevisionConflict>()
              .having(
                (error) => error.expectedRevision,
                'expectedRevision',
                original.revision,
              )
              .having(
                (error) => error.actualRevision,
                'actualRevision',
                saved.revision,
              ),
        ),
      );
      expect(
        (await routines.getTemplate(PrayerType.asr)).displayName,
        'First editor',
      );
    },
  );

  test('template edits never mutate a started session snapshot', () async {
    var template = await routines.getTemplate(PrayerType.isha);
    template = await routines.replaceTemplate(
      prayerType: PrayerType.isha,
      expectedRevision: template.revision,
      displayName: 'Isha',
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        _part(
          id: 'isha-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 4,
          requiredSurahSlots: 2,
        ),
        _part(
          id: 'isha-sunnah',
          stableKey: 'sunnah',
          orderIndex: 1,
          kind: PrayerRoutinePartKind.sunnah,
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
      ],
    );
    final session = PrayerSession(
      id: 'session-isha',
      context: PrayerContext(prayerType: PrayerType.isha),
      startedAtUtc: DateTime.utc(2026, 9, 3, 18),
    );

    final snapshot = await routines.startSession(
      session: session,
      localDate: LocalDate(2026, 9, 3),
      createPartId: (part) => 'session-isha:${part.stableKey}',
    );
    expect(snapshot.map((part) => part.templateRevision), <int?>[2, 2]);
    expect(snapshot.map((part) => part.rakaatCount), <int>[4, 2]);
    expect(snapshot.map((part) => part.requiredSurahSlots), <int>[2, 2]);

    template = await routines.updatePart(
      prayerType: PrayerType.isha,
      expectedRevision: template.revision,
      replacement: _part(
        id: 'isha-fard',
        stableKey: 'fard',
        orderIndex: 0,
        kind: PrayerRoutinePartKind.custom,
        customLabel: 'Edited later',
        rakaatCount: 8,
        requiredSurahSlots: 0,
      ),
    );
    await routines.deletePart(
      prayerType: PrayerType.isha,
      expectedRevision: template.revision,
      partId: 'isha-sunnah',
    );

    final reloaded = await routines.getSessionParts(session.id);
    expect(reloaded.map((part) => part.label), <String>['fard', 'sunnah']);
    expect(reloaded.map((part) => part.kind), <PrayerRoutinePartKind>[
      PrayerRoutinePartKind.fard,
      PrayerRoutinePartKind.sunnah,
    ]);
    expect(reloaded.map((part) => part.rakaatCount), <int>[4, 2]);
    expect(reloaded.map((part) => part.requiredSurahSlots), <int>[2, 2]);
    expect(reloaded.map((part) => part.templateRevision), <int?>[2, 2]);
  });

  test(
    'a zero-slot recitation part is complete without fabricated credit',
    () async {
      final original = await routines.getTemplate(PrayerType.nafl);
      await routines.replaceTemplate(
        prayerType: PrayerType.nafl,
        expectedRevision: original.revision,
        displayName: 'Manual Nafl',
        enabled: true,
        parts: <PrayerRoutinePartTemplate>[
          _part(
            id: 'nafl-zero',
            stableKey: 'no-surah-slot',
            orderIndex: 0,
            kind: PrayerRoutinePartKind.custom,
            customLabel: 'No tracked surah',
            rakaatCount: 2,
            requiredSurahSlots: 0,
          ),
        ],
      );
      final startedAt = DateTime.utc(2026, 9, 3, 20);

      final parts = await routines.startSession(
        session: PrayerSession(
          id: 'session-zero',
          context: PrayerContext(prayerType: PrayerType.nafl),
          startedAtUtc: startedAt,
        ),
        createPartId: (_) => 'session-zero:part',
      );

      expect(parts.single.completionMode, PrayerPartCompletionMode.recitations);
      expect(parts.single.completedAtUtc, startedAt);
      expect(await database.select(database.recitationEvents).get(), isEmpty);
      final rotation = await database
          .select(database.rotationStates)
          .getSingle();
      expect(rotation.lastJournalSequence, 0);
      expect(rotation.rotationTarget, 1);
    },
  );

  test(
    'Jumuah Fard defaults to offering explicit followed-imam completion',
    () {
      final jumuah = PrayerRoutineDefaults.newUserPart(
        prayerType: PrayerType.jumuah,
        id: 'jumuah-fard',
        stableKey: 'fard',
        orderIndex: 0,
        kind: PrayerRoutinePartKind.fard,
        rakaatCount: 2,
        requiredSurahSlots: 2,
      );
      final dhuhr = PrayerRoutineDefaults.newUserPart(
        prayerType: PrayerType.dhuhr,
        id: 'dhuhr-fard',
        stableKey: 'fard',
        orderIndex: 0,
        kind: PrayerRoutinePartKind.fard,
        rakaatCount: 4,
        requiredSurahSlots: 2,
      );

      expect(jumuah.allowsFollowingImam, isTrue);
      expect(
        jumuah.defaultCompletionMode,
        PrayerPartCompletionMode.recitations,
      );
      expect(dhuhr.allowsFollowingImam, isFalse);
    },
  );

  test(
    'followed imam completes and undoes without recitation or rotation credit',
    () async {
      final part = PrayerRoutineDefaults.newUserPart(
        prayerType: PrayerType.jumuah,
        id: 'jumuah-fard',
        stableKey: 'fard',
        orderIndex: 0,
        kind: PrayerRoutinePartKind.fard,
        rakaatCount: 2,
        requiredSurahSlots: 2,
      );
      final original = await routines.getTemplate(PrayerType.jumuah);
      await routines.replaceTemplate(
        prayerType: PrayerType.jumuah,
        expectedRevision: original.revision,
        displayName: 'Jumuah',
        enabled: true,
        parts: <PrayerRoutinePartTemplate>[part],
      );
      await routines.startSession(
        session: PrayerSession(
          id: 'session-jumuah',
          context: PrayerContext(prayerType: PrayerType.jumuah),
          startedAtUtc: DateTime.utc(2026, 9, 4, 8),
        ),
        localDate: LocalDate(2026, 9, 4),
        createPartId: (_) => 'session-jumuah:fard',
      );
      final completedAt = DateTime.utc(2026, 9, 4, 9);

      final completion = await routines.completeByFollowingImam(
        prayerSessionPartId: 'session-jumuah:fard',
        completedAtUtc: completedAt,
      );

      expect(completion.didComplete, isTrue);
      expect(completion.part.wasFollowedImam, isTrue);
      expect(completion.part.completedAtUtc, completedAt);
      expect(completion.undoToken, isNotNull);
      expect(await database.select(database.recitationEvents).get(), isEmpty);
      var rotation = await database.select(database.rotationStates).getSingle();
      expect(rotation.lastJournalSequence, 0);
      expect(rotation.rotationTarget, 1);

      final duplicate = await routines.completeByFollowingImam(
        prayerSessionPartId: 'session-jumuah:fard',
        completedAtUtc: completedAt.add(const Duration(minutes: 1)),
      );
      expect(duplicate.didComplete, isFalse);
      expect(duplicate.undoToken, isNull);

      expect(await routines.undoFollowedImam(completion.undoToken!), isTrue);
      final reopened = await routines.getSessionPart('session-jumuah:fard');
      expect(reopened?.isCompleted, isFalse);
      expect(reopened?.completionMode, PrayerPartCompletionMode.recitations);
      expect(await routines.undoFollowedImam(completion.undoToken!), isFalse);
      rotation = await database.select(database.rotationStates).getSingle();
      expect(rotation.lastJournalSequence, 0);
      expect(rotation.rotationTarget, 1);
    },
  );

  test('followed-imam Undo refuses to invalidate later part history', () async {
    final original = await routines.getTemplate(PrayerType.jumuah);
    await routines.replaceTemplate(
      prayerType: PrayerType.jumuah,
      expectedRevision: original.revision,
      displayName: 'Jumuah',
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutineDefaults.newUserPart(
          prayerType: PrayerType.jumuah,
          id: 'jumuah-first',
          stableKey: 'first',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 2,
          requiredSurahSlots: 1,
        ),
        PrayerRoutineDefaults.newUserPart(
          prayerType: PrayerType.jumuah,
          id: 'jumuah-second',
          stableKey: 'second',
          orderIndex: 1,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 2,
          requiredSurahSlots: 1,
        ),
      ],
    );
    await routines.startSession(
      session: PrayerSession(
        id: 'session-ordered',
        context: PrayerContext(prayerType: PrayerType.jumuah),
        startedAtUtc: DateTime.utc(2026, 9, 4, 8),
      ),
      createPartId: (part) => 'session-ordered:${part.stableKey}',
    );
    await expectLater(
      routines.completeByFollowingImam(
        prayerSessionPartId: 'session-ordered:second',
        completedAtUtc: DateTime.utc(2026, 9, 4, 8, 59),
      ),
      throwsStateError,
    );
    final first = await routines.completeByFollowingImam(
      prayerSessionPartId: 'session-ordered:first',
      completedAtUtc: DateTime.utc(2026, 9, 4, 9),
    );
    await routines.completeByFollowingImam(
      prayerSessionPartId: 'session-ordered:second',
      completedAtUtc: DateTime.utc(2026, 9, 4, 9, 1),
    );

    expect(await routines.undoFollowedImam(first.undoToken!), isFalse);
    expect(
      (await routines.getSessionPart('session-ordered:first'))?.wasFollowedImam,
      isTrue,
    );
  });

  test(
    'ensureCurrentSession does not create rows for an empty routine',
    () async {
      final result = await routines.ensureCurrentSession(
        context: PrayerContext(prayerType: PrayerType.fajr),
        localDate: LocalDate(2026, 9, 3),
        startedAtUtc: DateTime.utc(2026, 9, 3, 4),
      );

      expect(result, isNull);
      expect(await database.select(database.prayerSessions).get(), isEmpty);
      expect(await database.select(database.prayerSessionParts).get(), isEmpty);
    },
  );

  test(
    'ensureCurrentSession is idempotent and returns occupied slot progress',
    () async {
      final original = await routines.getTemplate(PrayerType.asr);
      await routines.replaceTemplate(
        prayerType: PrayerType.asr,
        expectedRevision: original.revision,
        displayName: 'Asr',
        enabled: true,
        parts: <PrayerRoutinePartTemplate>[
          _part(
            id: 'asr-fard',
            stableKey: 'fard',
            orderIndex: 0,
            kind: PrayerRoutinePartKind.fard,
            rakaatCount: 4,
            requiredSurahSlots: 2,
          ),
        ],
      );
      final context = PrayerContext(prayerType: PrayerType.asr);
      final localDate = LocalDate(2026, 9, 3);
      final startedAt = DateTime.utc(2026, 9, 3, 12);

      final concurrent =
          await Future.wait(<Future<PrayerRoutineSessionSnapshot?>>[
            routines.ensureCurrentSession(
              context: context,
              localDate: localDate,
              startedAtUtc: startedAt,
            ),
            routines.ensureCurrentSession(
              context: context,
              localDate: localDate,
              startedAtUtc: startedAt,
            ),
          ]);

      expect(concurrent.every((snapshot) => snapshot != null), isTrue);
      expect(concurrent[0]!.session.id, concurrent[1]!.session.id);
      expect(
        await database.select(database.prayerSessions).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.prayerSessionParts).get(),
        hasLength(1),
      );
      expect(concurrent.first!.currentPart?.nextSlotIndex, 0);
      expect(concurrent.first!.currentPart?.occupiedSlotIndexes, isEmpty);

      final surahs = SurahRepository(database);
      await _seedCatalog(surahs);
      await surahs.addMastered('test-a');
      final recitations = RecitationRepository(database);
      await recitations.register(
        SurahRecitationEvent(
          id: 'slot-event-0',
          surahId: 'test-a',
          prayerContext: context,
          createdAtUtc: DateTime.utc(2026, 9, 3, 12, 1),
          localDate: localDate,
          prayerSessionId: concurrent.first!.session.id,
          prayerSessionPartId: concurrent.first!.parts.single.part.id,
          slotIndex: 0,
        ),
      );

      final withOneSlot = await routines.ensureCurrentSession(
        context: context,
        localDate: localDate,
        startedAtUtc: startedAt.add(const Duration(hours: 1)),
      );
      expect(withOneSlot?.session.id, concurrent.first!.session.id);
      expect(withOneSlot?.currentPart?.occupiedSlotIndexes, <int>{0});
      expect(withOneSlot?.currentPart?.completedSlotCount, 1);
      expect(withOneSlot?.currentPart?.nextSlotIndex, 1);

      await recitations.register(
        SurahRecitationEvent(
          id: 'slot-event-1',
          surahId: 'test-a',
          prayerContext: context,
          createdAtUtc: DateTime.utc(2026, 9, 3, 12, 2),
          localDate: localDate,
          prayerSessionId: concurrent.first!.session.id,
          prayerSessionPartId: concurrent.first!.parts.single.part.id,
          slotIndex: 1,
        ),
      );
      final completed = await routines.ensureCurrentSession(
        context: context,
        localDate: localDate,
        startedAtUtc: startedAt.add(const Duration(hours: 2)),
      );
      expect(completed?.session.id, concurrent.first!.session.id);
      expect(completed?.parts.single.occupiedSlotIndexes, <int>{0, 1});
      expect(completed?.parts.single.part.isCompleted, isTrue);
      expect(completed?.currentPart, isNull);
      expect(completed?.isCompleted, isTrue);
      expect(
        await database.select(database.prayerSessions).get(),
        hasLength(1),
      );
    },
  );
}

PrayerRoutinePartTemplate _part({
  required String id,
  required String stableKey,
  required int orderIndex,
  required PrayerRoutinePartKind kind,
  String? customLabel,
  required int rakaatCount,
  required int requiredSurahSlots,
  bool allowsFollowingImam = false,
  PrayerPartCompletionMode defaultCompletionMode =
      PrayerPartCompletionMode.recitations,
}) => PrayerRoutinePartTemplate(
  id: id,
  stableKey: stableKey,
  orderIndex: orderIndex,
  kind: kind,
  customLabel: customLabel,
  rakaatCount: rakaatCount,
  requiredSurahSlots: requiredSurahSlots,
  allowsFollowingImam: allowsFollowingImam,
  defaultCompletionMode: defaultCompletionMode,
);

Future<void> _seedCatalog(SurahRepository repository) =>
    repository.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'test-a',
          surahNumber: 2,
          officialName: 'Test Surah A',
          ayahCount: 3,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
