import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;
  late PrayerRepository prayers;
  var idSequence = 0;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    prayers = PrayerRepository(database);
    idSequence = 0;
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'test-a',
          surahNumber: 1,
          officialName: 'Test A',
          ayahCount: 12,
        ),
        SurahDescriptor(
          id: 'test-b',
          surahNumber: 2,
          officialName: 'Test B',
          ayahCount: 8,
        ),
      ],
      sourceId: 'test-source',
      sourceVersion: 'v2',
    );
    await surahs.addMastered('test-a');
    await surahs.addMastered('test-b');
  });

  tearDown(() => database.close());

  for (final partCount in <int>[1, 2, 3, 4]) {
    test(
      'whole-surah registration credits every part in a $partCount-part scheme',
      () async {
        final scheme = await _schemeWithParts(
          surahs,
          surahId: 'test-a',
          partCount: partCount,
        );
        final result = await recitations.register(
          _event(
            id: _nextId(++idSequence),
            surahId: 'test-a',
            atMinute: partCount,
            rakaatSpanCount: partCount,
          ),
        );

        expect(result.event.rotationSchemeId, scheme.id);
        expect(
          result.event.coveredPartIds,
          scheme.parts.map((part) => part.id).toList(),
        );
        expect(result.event.rakaatSpanCount, partCount);
        final persistedCoverage = await (database.select(
          database.recitationEventParts,
        )..where((row) => row.eventId.equals(result.event.id))).get();
        expect(persistedCoverage, hasLength(partCount));
        expect(
          persistedCoverage.map((row) => row.partId).toSet(),
          scheme.parts.map((part) => part.id).toSet(),
        );
        final updated = result.snapshot.surahById('test-a');
        expect(
          updated.rotationScheme.parts.map((part) => part.rotationScore),
          everyElement(1),
        );
        expect(
          updated.rotationScheme.parts.map((part) => part.recitationCount),
          everyElement(1),
        );
        expect(updated.rotationScore, 1);
        expect(updated.totalRecitations, 1);
        final stats = await recitations.getStats();
        expect(stats.total, 1);
        expect(stats.actionCount, 1);
        expect(
          stats.bySurah.singleWhere((item) => item.surah.id == 'test-a').count,
          1,
        );
        expect(
          stats.bySurah.singleWhere((item) => item.surah.id == 'test-a').byPart,
          <String, int>{for (final part in scheme.parts) part.id: 1},
        );
      },
    );
  }

  test(
    'partial, multi-part, and whole actions keep action and full-equivalent totals distinct',
    () async {
      final scheme = await _schemeWithParts(
        surahs,
        surahId: 'test-a',
        partCount: 4,
      );
      await recitations.register(
        _event(
          id: _nextId(++idSequence),
          surahId: 'test-a',
          atMinute: 1,
          scheme: scheme,
          partIds: <String>[scheme.parts[0].id],
          rakaatSpanCount: 2,
        ),
      );
      await recitations.register(
        _event(
          id: _nextId(++idSequence),
          surahId: 'test-a',
          atMinute: 2,
          scheme: scheme,
          partIds: <String>[scheme.parts[1].id, scheme.parts[2].id],
          rakaatSpanCount: 4,
        ),
      );

      var stats = await recitations.getStats();
      var surahStats = stats.bySurah.singleWhere(
        (item) => item.surah.id == 'test-a',
      );
      expect(stats.total, 0);
      expect(stats.actionCount, 2);
      expect(surahStats.count, 0);
      expect(surahStats.actionCount, 2);
      expect(surahStats.byPart, <String, int>{
        scheme.parts[0].id: 1,
        scheme.parts[1].id: 1,
        scheme.parts[2].id: 1,
      });

      await recitations.register(
        _event(id: _nextId(++idSequence), surahId: 'test-a', atMinute: 3),
      );
      stats = await recitations.getStats();
      surahStats = stats.bySurah.singleWhere(
        (item) => item.surah.id == 'test-a',
      );
      expect(stats.total, 1);
      expect(stats.actionCount, 3);
      expect(surahStats.count, 1);
      expect(surahStats.actionCount, 3);
      expect(surahStats.byPart, <String, int>{
        scheme.parts[0].id: 2,
        scheme.parts[1].id: 2,
        scheme.parts[2].id: 2,
        scheme.parts[3].id: 1,
      });
      expect(
        (await surahs.getRotationSnapshot())
            .surahById('test-a')
            .rotationScheme
            .parts
            .map((part) => part.recitationCount),
        <int>[2, 2, 2, 1],
      );
    },
  );

  test('multi-part Undo and whole-event deletion are atomic', () async {
    final scheme = await _schemeWithParts(
      surahs,
      surahId: 'test-a',
      partCount: 3,
    );
    final before = await surahs.getRotationSnapshot();
    final multi = await recitations.register(
      _event(
        id: _nextId(++idSequence),
        surahId: 'test-a',
        atMinute: 1,
        scheme: scheme,
        partIds: <String>[scheme.parts[0].id, scheme.parts[2].id],
      ),
    );
    expect(
      await (database.select(
        database.recitationEventParts,
      )..where((row) => row.eventId.equals(multi.event.id))).get(),
      hasLength(2),
    );

    final undone = await recitations.undo(multi.undoToken);
    expect(undone.didUndo, isTrue);
    expect(undone.snapshot, before);
    expect(
      await (database.select(
        database.recitationEvents,
      )..where((row) => row.id.equals(multi.event.id))).get(),
      isEmpty,
    );
    expect(
      await (database.select(
        database.recitationEventParts,
      )..where((row) => row.eventId.equals(multi.event.id))).get(),
      isEmpty,
    );

    final whole = await recitations.register(
      _event(id: _nextId(++idSequence), surahId: 'test-a', atMinute: 2),
    );
    expect(
      await (database.select(
        database.recitationEventParts,
      )..where((row) => row.eventId.equals(whole.event.id))).get(),
      hasLength(3),
    );
    final deletion = await recitations.deleteRecitation(
      whole.event.id,
      deletedAtUtc: _at(3),
    );
    expect(deletion.didDelete, isTrue);
    expect(deletion.snapshot, before);
    expect(await recitations.getHistory(), isEmpty);
    expect((await recitations.getStats()).actionCount, 0);
    final tombstone = await (database.select(
      database.recitationEvents,
    )..where((row) => row.id.equals(whole.event.id))).getSingle();
    expect(tombstone.deletedAtUtc?.toUtc(), _at(3));
    expect(
      await (database.select(
        database.recitationEventParts,
      )..where((row) => row.eventId.equals(whole.event.id))).get(),
      hasLength(3),
    );
  });

  test(
    'scheme change preserves old coverage and deleting an old event rebases its successor',
    () async {
      final oldRegistration = await recitations.register(
        _event(id: _nextId(++idSequence), surahId: 'test-a', atMinute: 1),
      );
      final oldScheme = oldRegistration.snapshot
          .surahById('test-a')
          .rotationScheme;
      final newScheme = await _schemeWithParts(
        surahs,
        surahId: 'test-a',
        partCount: 2,
      );
      expect(newScheme.parts.map((part) => part.rotationScore), <int>[1, 1]);
      expect(newScheme.parts.map((part) => part.recitationCount), <int>[1, 1]);
      final newRegistration = await recitations.register(
        _event(
          id: _nextId(++idSequence),
          surahId: 'test-a',
          atMinute: 2,
          scheme: newScheme,
          partIds: <String>[newScheme.parts.first.id],
        ),
      );
      expect(
        newRegistration.snapshot
            .surahById('test-a')
            .rotationScheme
            .parts
            .map((part) => part.rotationScore),
        <int>[2, 1],
      );

      final deletion = await recitations.deleteRecitation(
        oldRegistration.event.id,
        deletedAtUtc: _at(3),
      );
      final current = deletion.snapshot.surahById('test-a');
      expect(current.rotationScheme.id, newScheme.id);
      expect(
        current.rotationScheme.parts.map((part) => part.rotationScore),
        <int>[1, 0],
      );
      expect(
        current.rotationScheme.parts.map((part) => part.recitationCount),
        <int>[1, 0],
      );
      expect(current.rotationScore, 0);
      expect(current.totalRecitations, 0);
      expect((await recitations.getStats()).actionCount, 1);
      expect((await recitations.getStats()).total, 0);

      final schemes = await (database.select(
        database.rotationSchemes,
      )..where((row) => row.surahId.equals('test-a'))).get();
      schemes.sort((left, right) => left.version.compareTo(right.version));
      expect(schemes, hasLength(2));
      expect(schemes.first.id, oldScheme.id);
      expect(schemes.first.supersededJournalSequence, isNotNull);
      expect(schemes.last.id, newScheme.id);
      expect(schemes.last.supersededJournalSequence, isNull);
      final oldCoverage = await (database.select(
        database.recitationEventParts,
      )..where((row) => row.eventId.equals(oldRegistration.event.id))).get();
      expect(oldCoverage, hasLength(1));
      expect(oldCoverage.single.schemeId, oldScheme.id);
      expect(oldCoverage.single.partId, oldScheme.parts.single.id);
      final history = await recitations.getHistory();
      expect(history.map((entry) => entry.event.id), <String>[
        newRegistration.event.id,
      ]);
    },
  );

  test(
    'adjustments apply to and rebuild every part in the active scheme',
    () async {
      final scheme = await _schemeWithParts(
        surahs,
        surahId: 'test-a',
        partCount: 4,
      );
      final adjusted = await recitations.applyAdjustment(
        RotationAdjustmentEvent(
          id: 'adjust-all-parts',
          surahId: 'test-a',
          delta: 2,
          reason: 'Audited correction',
          createdAtUtc: _at(1),
        ),
      );
      expect(
        adjusted
            .surahById('test-a')
            .rotationScheme
            .parts
            .map((part) => part.rotationScore),
        <int>[2, 2, 2, 2],
      );
      expect(
        adjusted
            .surahById('test-a')
            .rotationScheme
            .parts
            .map((part) => part.recitationCount),
        everyElement(0),
      );
      final stored = await database
          .select(database.rotationAdjustments)
          .getSingle();
      expect(stored.rotationSchemeId, scheme.id);

      final deletion = await recitations.deleteAdjustment(
        stored.id,
        deletedAtUtc: _at(2),
      );
      expect(deletion.didDelete, isTrue);
      expect(
        deletion.snapshot
            .surahById('test-a')
            .rotationScheme
            .parts
            .map((part) => part.rotationScore),
        everyElement(0),
      );
      expect(
        (await database.select(database.rotationAdjustments).getSingle())
            .deletedAtUtc
            ?.toUtc(),
        _at(2),
      );
    },
  );

  test(
    'stale scheme, stale part, and invalid rakaat are rejected atomically',
    () async {
      final oldScheme = (await surahs.getRotationSnapshot())
          .surahById('test-a')
          .rotationScheme;
      final current = await _schemeWithParts(
        surahs,
        surahId: 'test-a',
        partCount: 2,
      );
      final before = await surahs.getRotationSnapshot();

      await expectLater(
        recitations.register(
          _event(
            id: 'stale-scheme',
            surahId: 'test-a',
            atMinute: 1,
            scheme: oldScheme,
            partIds: <String>[oldScheme.parts.single.id],
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        recitations.register(
          _event(
            id: 'stale-part',
            surahId: 'test-a',
            atMinute: 2,
            scheme: current,
            partIds: <String>[oldScheme.parts.single.id],
          ),
        ),
        throwsStateError,
      );
      expect(
        () => _event(
          id: 'invalid-rakaat',
          surahId: 'test-a',
          atMinute: 3,
          rakaatSpanCount: 0,
        ),
        throwsArgumentError,
      );
      expect(await surahs.getRotationSnapshot(), before);
      expect(await database.select(database.recitationEvents).get(), isEmpty);
      expect(
        await database.select(database.recitationEventParts).get(),
        isEmpty,
      );
    },
  );

  test(
    'Witr supports Qada in sessions and events while Nafl rejects it',
    () async {
      final witrQada = PrayerContext(prayerType: PrayerType.witr, isQada: true);
      await prayers.saveSession(
        PrayerSession(
          id: 'witr-qada-session',
          context: witrQada,
          startedAtUtc: _at(1),
        ),
        localDate: LocalDate(2026, 8, 24),
      );
      final registration = await recitations.register(
        SurahRecitationEvent(
          id: 'witr-qada-recitation',
          surahId: 'test-a',
          prayerContext: witrQada,
          prayerSessionId: 'witr-qada-session',
          createdAtUtc: _at(2),
          localDate: LocalDate(2026, 8, 24),
          rakaatSpanCount: 3,
        ),
      );
      expect(registration.event.prayerType, PrayerType.witr);
      expect(registration.event.isQada, isTrue);
      expect(registration.event.rakaatSpanCount, 3);
      final storedSession = await prayers.getSession('witr-qada-session');
      expect(storedSession?.session.context, witrQada);
      final storedEvent = await database
          .select(database.recitationEvents)
          .getSingle();
      expect(storedEvent.prayerType, 'witr');
      expect(storedEvent.isQada, isTrue);
      expect(storedEvent.rakaatSpanCount, 3);

      expect(
        () => PrayerContext(prayerType: PrayerType.nafl, isQada: true),
        throwsArgumentError,
      );
    },
  );
}

Future<SurahRotationScheme> _schemeWithParts(
  SurahRepository repository, {
  required String surahId,
  required int partCount,
}) async {
  final current = (await repository.getRotationSnapshot())
      .surahById(surahId)
      .rotationScheme;
  if (current.parts.length == partCount) return current;
  final snapshot = await repository.changeRotationScheme(
    surahId: surahId,
    proposedScheme: SurahRotationScheme.evenlySplit(
      id: '$surahId:scheme:${current.version + 1}:parts:$partCount',
      surahId: surahId,
      version: current.version + 1,
      ayahCount: current.ayahCount,
      partCount: partCount,
    ),
    createdAtUtc: _at(0),
  );
  return snapshot.surahById(surahId).rotationScheme;
}

SurahRecitationEvent _event({
  required String id,
  required String surahId,
  required int atMinute,
  SurahRotationScheme? scheme,
  List<String>? partIds,
  int rakaatSpanCount = 1,
}) => SurahRecitationEvent(
  id: id,
  surahId: surahId,
  prayerContext: PrayerContext(prayerType: PrayerType.asr),
  createdAtUtc: _at(atMinute),
  localDate: LocalDate(2026, 8, 24),
  coverage: scheme == null
      ? null
      : RecitationCoverage(
          rotationSchemeId: scheme.id,
          coveredPartIds: partIds!,
        ),
  rakaatSpanCount: rakaatSpanCount,
);

DateTime _at(int minute) => DateTime.utc(2026, 8, 24, 12, minute);

String _nextId(int value) => 'recitation-$value';
