import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/application/application.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late LearningRepository learning;
  late RecitationRepository recitations;
  late _MutableTimeProvider clock;
  late AppActions actions;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    learning = LearningRepository(database);
    recitations = RecitationRepository(database);
    clock = _MutableTimeProvider(DateTime.utc(2026, 8, 27, 8));
    const uuid = Uuid();
    const localDates = _FixedLocalDateProvider();
    final recitationService = RecitationApplicationService(
      surahs: surahs,
      recitations: recitations,
      prayerContextResolver: const _FixedPrayerResolver(),
      timeProvider: clock,
      localDates: localDates,
      createEventId: uuid.v4,
    );
    actions = AppActions(
      database: database,
      surahs: surahs,
      recitations: recitations,
      recitationService: recitationService,
      learning: learning,
      timeProvider: clock,
      localDates: localDates,
      uuid: uuid,
    );
  });

  tearDown(() => database.close());

  test(
    'return, restart, and remastery preserve history and avoid old debt',
    () async {
      final target = _surah(id: 'target-surah', number: 2, ayahCount: 10);
      final other = _surah(id: 'other-surah', number: 3, ayahCount: 5);
      await surahs.upsertCatalog(<SurahDescriptor>[target, other]);
      await surahs.addMastered(target.id);
      await surahs.addMastered(other.id);
      await surahs.setAlias(target.id, 'Preserved alias');

      final initialTarget = (await surahs.getRotationSnapshot()).surahById(
        target.id,
      );
      final splitScheme = SurahRotationScheme.fromRanges(
        id: '${target.id}:scheme:2',
        surahId: target.id,
        version: initialTarget.rotationScheme.version + 1,
        ayahCount: target.ayahCount,
        ranges: <AyahRange>[
          AyahRange(startAyah: 1, endAyah: 4),
          AyahRange(startAyah: 5, endAyah: 10),
        ],
      );
      await surahs.changeRotationScheme(
        surahId: target.id,
        proposedScheme: splitScheme,
        createdAtUtc: DateTime.utc(2026, 8, 27, 8, 1),
      );

      await _registerWhole(
        recitations,
        surahs,
        id: 'target-read-1',
        surahId: target.id,
        minute: 2,
      );
      await _registerWhole(
        recitations,
        surahs,
        id: 'other-read-1',
        surahId: other.id,
        minute: 3,
      );
      await _registerWhole(
        recitations,
        surahs,
        id: 'target-read-2',
        surahId: target.id,
        minute: 4,
      );
      await _registerWhole(
        recitations,
        surahs,
        id: 'other-read-2',
        surahId: other.id,
        minute: 5,
      );

      final beforeReturn = await surahs.getRotationSnapshot();
      expect(beforeReturn.rotationTarget, 3);
      expect(beforeReturn.surahById(target.id).rotationScore, 2);
      expect(beforeReturn.surahById(target.id).totalRecitations, 2);

      final completedCycleOne = await _seedCompletedLearning(
        learning: learning,
        clock: clock,
        descriptor: target,
        id: 'stable-learning-row',
      );
      final historyBefore = await _historyFingerprint(recitations, target.id);
      final statsBefore = await _statsFingerprint(recitations, target.id);
      final schemesBefore = await _schemeFingerprint(database, target.id);
      final partsBefore = await _partFingerprint(database, target.id);

      clock.value = DateTime.utc(2026, 8, 27, 9);
      await actions.returnToLearning(target.id);

      final returned = await surahs.getRotationSnapshot();
      expect(returned.surahById(target.id).isCurrentlyMastered, isFalse);
      expect(returned.surahById(target.id).isActive, isFalse);
      expect(returned.activeSurahs.map((item) => item.id), <String>[other.id]);
      final targetCatalog = (await surahs.getCatalog()).singleWhere(
        (item) => item.surah.id == target.id,
      );
      expect(targetCatalog.isMastered, isFalse);
      expect(targetCatalog.isActive, isFalse);
      expect(targetCatalog.surah.alias, 'Preserved alias');
      expect(await _historyFingerprint(recitations, target.id), historyBefore);
      expect(await _statsFingerprint(recitations, target.id), statsBefore);
      expect(await _schemeFingerprint(database, target.id), schemesBefore);
      expect(await _partFingerprint(database, target.id), partsBefore);

      await surahs.reorder(<String>[other.id]);
      final reorderedOther = await (database.select(
        database.masteredSurahs,
      )..where((row) => row.surahId.equals(other.id))).getSingle();
      expect(reorderedOther.displayOrder, 0);

      final restarted = await actions.startLearning(
        target,
        plan: LearningPlan.chunked(
          targetStartAyah: 1,
          targetEndAyah: target.ayahCount,
          blockSize: 5,
        ),
      );
      expect(restarted.id, completedCycleOne.id);
      expect(restarted.learningCycle, completedCycleOne.learningCycle + 1);
      expect(restarted.status, LearningStatus.active);
      expect(restarted.stage, restarted.plan.stages.first);
      final eventsAfterRestart = await learning.getEvents(restarted.id);
      expect(eventsAfterRestart.map((event) => event.type), <LearningEventType>[
        LearningEventType.repeated,
        LearningEventType.completed,
        LearningEventType.restarted,
      ]);
      expect(eventsAfterRestart.last.learningCycle, 2);
      expect(eventsAfterRestart.last.reason, 'returned_to_learning');

      for (var index = 0; index < 3; index += 1) {
        await _registerWhole(
          recitations,
          surahs,
          id: 'other-while-target-archived-$index',
          surahId: other.id,
          minute: 10 + index,
        );
      }
      final beforeRemastery = await surahs.getRotationSnapshot();
      expect(beforeRemastery.rotationTarget, 6);
      expect(beforeRemastery.surahById(target.id).rotationScore, 2);
      expect(beforeRemastery.remainingFor(target.id), 4);

      clock.value = DateTime.utc(2026, 8, 27, 10);
      await actions.completeLearning(
        state: restarted.copyWith(stage: restarted.plan.stages.last),
        surah: target,
        addToRotation: true,
      );

      final afterRemastery = await surahs.getRotationSnapshot();
      final remastered = afterRemastery.surahById(target.id);
      expect(afterRemastery.rotationTarget, 6);
      expect(remastered.isCurrentlyMastered, isTrue);
      expect(remastered.isActive, isTrue);
      expect(remastered.rotationScheme.version, splitScheme.version + 1);
      expect(remastered.rotationScheme.id, isNot(splitScheme.id));
      expect(remastered.rotationScheme.baselineRotationScore, 5);
      expect(remastered.rotationScore, 5);
      expect(afterRemastery.remainingFor(target.id), 1);
      expect(remastered.rotationScheme.baselineTotalRecitations, 2);
      expect(remastered.totalRecitations, 2);
      expect(
        remastered.rotationScheme.parts.map((part) => part.ayahRange),
        splitScheme.parts.map((part) => part.ayahRange),
      );
      expect(
        remastered.rotationScheme.parts.map((part) => part.rotationScore),
        everyElement(5),
      );
      expect(
        remastered.rotationScheme.parts.map((part) => part.recitationCount),
        everyElement(2),
      );
      expect(remastered.surah.alias, 'Preserved alias');
      expect(await _historyFingerprint(recitations, target.id), historyBefore);
      expect(await _statsFingerprint(recitations, target.id), statsBefore);

      final allTargetSchemes = await (database.select(
        database.rotationSchemes,
      )..where((row) => row.surahId.equals(target.id))).get();
      allTargetSchemes.sort(
        (left, right) => left.version.compareTo(right.version),
      );
      expect(allTargetSchemes.map((row) => row.version), <int>[1, 2, 3]);
      expect(allTargetSchemes[1].id, splitScheme.id);
      expect(allTargetSchemes[1].supersededJournalSequence, isNotNull);

      final restoredLearning = await learning.getBySurahId(target.id);
      expect(restoredLearning?.id, completedCycleOne.id);
      expect(restoredLearning?.learningCycle, 2);
      expect(restoredLearning?.status, LearningStatus.completed);
      expect(
        (await learning.getEvents(
          completedCycleOne.id,
        )).map((event) => event.type),
        <LearningEventType>[
          LearningEventType.repeated,
          LearningEventType.completed,
          LearningEventType.restarted,
          LearningEventType.completed,
        ],
      );
    },
  );

  test(
    'complete without rotation rebases the first later activation',
    () async {
      final target = _surah(id: 'delayed-target', number: 4, ayahCount: 8);
      final other = _surah(id: 'delayed-other', number: 5, ayahCount: 6);
      await surahs.upsertCatalog(<SurahDescriptor>[target, other]);
      await surahs.addMastered(target.id);
      await surahs.addMastered(other.id);

      await _registerWhole(
        recitations,
        surahs,
        id: 'delayed-target-old-read',
        surahId: target.id,
        minute: 1,
      );
      await _registerWhole(
        recitations,
        surahs,
        id: 'delayed-other-cycle-read',
        surahId: other.id,
        minute: 2,
      );
      expect((await surahs.getRotationSnapshot()).rotationTarget, 2);

      await actions.returnToLearning(target.id);
      for (var index = 0; index < 5; index += 1) {
        await _registerWhole(
          recitations,
          surahs,
          id: 'delayed-other-before-completion-$index',
          surahId: other.id,
          minute: 3 + index,
        );
      }
      final beforeCompletion = await surahs.getRotationSnapshot();
      expect(beforeCompletion.rotationTarget, 7);

      final learningState = await actions.startLearning(target);
      await actions.completeLearning(
        state: learningState.copyWith(stage: learningState.plan.stages.last),
        surah: target,
        addToRotation: false,
      );

      final completedOnly = (await surahs.getRotationSnapshot()).surahById(
        target.id,
      );
      expect(completedOnly.isCurrentlyMastered, isTrue);
      expect(completedOnly.isActive, isFalse);
      expect(completedOnly.hasEnteredRotation, isFalse);
      expect(completedOnly.rotationScheme.version, 2);
      expect(completedOnly.rotationScheme.resetsRotationBaseline, isTrue);
      expect(completedOnly.rotationScore, 6);
      expect(completedOnly.totalRecitations, 1);

      for (var index = 0; index < 3; index += 1) {
        await _registerWhole(
          recitations,
          surahs,
          id: 'delayed-other-before-activation-$index',
          surahId: other.id,
          minute: 10 + index,
        );
      }
      expect((await surahs.getRotationSnapshot()).rotationTarget, 10);

      await surahs.setActive(target.id, isActive: true);
      final activatedSnapshot = await surahs.getRotationSnapshot();
      final activated = activatedSnapshot.surahById(target.id);
      expect(activated.isActive, isTrue);
      expect(activated.hasEnteredRotation, isTrue);
      expect(activated.rotationScheme.version, 2);
      expect(activated.rotationScheme.resetsRotationBaseline, isTrue);
      expect(activated.rotationScheme.baselineRotationScore, 9);
      expect(activated.rotationScore, 9);
      expect(activatedSnapshot.remainingFor(target.id), 1);

      final deletion = await recitations.deleteRecitation(
        'delayed-target-old-read',
        deletedAtUtc: DateTime.utc(2026, 8, 27, 12),
      );
      expect(deletion.didDelete, isTrue);
      final rebuilt = deletion.snapshot.surahById(target.id);
      expect(deletion.snapshot.rotationTarget, 10);
      expect(rebuilt.rotationScheme.resetsRotationBaseline, isTrue);
      expect(rebuilt.rotationScore, 9);
      expect(rebuilt.totalRecitations, 0);
      expect(deletion.snapshot.remainingFor(target.id), 1);
    },
  );

  test('Al-Fatiha return and relearn never activate rotation', () async {
    final fatiha = _surah(id: 'al-fatiha', number: 1, ayahCount: 7);
    await surahs.upsertCatalog(<SurahDescriptor>[fatiha]);
    await surahs.addMastered(fatiha.id);
    final original = (await surahs.getRotationSnapshot()).surahById(fatiha.id);
    expect(original.isCurrentlyMastered, isTrue);
    expect(original.isActive, isFalse);
    expect(original.hasEnteredRotation, isFalse);
    final completed = await _seedCompletedLearning(
      learning: learning,
      clock: clock,
      descriptor: fatiha,
      id: 'fatiha-learning-row',
    );
    final schemesBefore = await _schemeFingerprint(database, fatiha.id);

    await actions.returnToLearning(fatiha.id);
    final returned = (await surahs.getRotationSnapshot()).surahById(fatiha.id);
    expect(returned.isCurrentlyMastered, isFalse);
    expect(returned.isActive, isFalse);

    clock.value = DateTime.utc(2026, 8, 27, 9);
    final restarted = await actions.startLearning(fatiha);
    expect(restarted.id, completed.id);
    expect(restarted.learningCycle, 2);
    expect(
      (await learning.getEvents(restarted.id)).last.type,
      LearningEventType.restarted,
    );

    await actions.completeLearning(
      state: restarted.copyWith(stage: restarted.plan.stages.last),
      surah: fatiha,
      addToRotation: true,
    );

    final snapshot = await surahs.getRotationSnapshot();
    final relearned = snapshot.surahById(fatiha.id);
    expect(relearned.isCurrentlyMastered, isTrue);
    expect(relearned.isActive, isFalse);
    expect(relearned.hasEnteredRotation, isFalse);
    expect(snapshot.activeSurahs, isEmpty);
    expect(await _schemeFingerprint(database, fatiha.id), schemesBefore);
    expect(
      (await learning.getBySurahId(fatiha.id))?.status,
      LearningStatus.completed,
    );
  });
}

Future<LearningSurahState> _seedCompletedLearning({
  required LearningRepository learning,
  required TimeProvider clock,
  required SurahDescriptor descriptor,
  required String id,
}) async {
  final plan = LearningPlan.classicCumulative(
    targetStartAyah: 1,
    targetEndAyah: descriptor.ayahCount,
  );
  final machine = LearningStateMachine(timeProvider: clock);
  final started = machine.start(
    id: id,
    surahId: descriptor.id,
    ayahCount: descriptor.ayahCount,
    plan: plan,
  );
  await learning.saveState(started);
  final repeated = machine.markRepeated(started, eventId: '$id:repeated');
  await learning.saveOutcome(repeated);
  final completed = machine.complete(
    repeated.state.copyWith(stage: plan.stages.last),
    eventId: '$id:completed',
  );
  await learning.saveOutcome(completed);
  return completed.state;
}

Future<void> _registerWhole(
  RecitationRepository recitations,
  SurahRepository surahs, {
  required String id,
  required String surahId,
  required int minute,
}) async {
  final current = (await surahs.getRotationSnapshot()).surahById(surahId);
  await recitations.register(
    SurahRecitationEvent(
      id: id,
      surahId: surahId,
      prayerContext: PrayerContext(prayerType: PrayerType.asr),
      createdAtUtc: DateTime.utc(2026, 8, 27, 8, minute),
      localDate: LocalDate(2026, 8, 27),
      coverage: RecitationCoverage(
        rotationSchemeId: current.rotationScheme.id,
        coveredPartIds: current.rotationScheme.parts.map((part) => part.id),
      ),
    ),
  );
}

Future<List<Object?>> _historyFingerprint(
  RecitationRepository repository,
  String surahId,
) async => (await repository.getHistory())
    .where((entry) => entry.event.surahId == surahId)
    .map<Object?>(
      (entry) => <Object?>[
        entry.event.id,
        entry.journalSequence,
        entry.event.rotationSchemeId,
        entry.event.coveredPartIds,
        entry.event.createdAtUtc,
        entry.event.localDate,
        entry.event.prayerContext,
        entry.coveredParts.map((part) => part.id).toList(growable: false),
        entry.isWholeSurah,
      ],
    )
    .toList(growable: false);

Future<List<Object?>> _statsFingerprint(
  RecitationRepository repository,
  String surahId,
) async {
  final stats = await repository.getStats();
  final entry = stats.bySurah.singleWhere((item) => item.surah.id == surahId);
  return <Object?>[
    entry.count,
    entry.actionCount,
    entry.lastUsedAtUtc,
    entry.byPrayer,
    entry.byPart,
  ];
}

Future<List<Object?>> _schemeFingerprint(
  AppDatabase database,
  String surahId,
) async {
  final rows = await (database.select(
    database.rotationSchemes,
  )..where((row) => row.surahId.equals(surahId))).get();
  rows.sort((left, right) => left.version.compareTo(right.version));
  return rows
      .map<Object?>(
        (row) => <Object?>[
          row.id,
          row.version,
          row.ayahCountSnapshot,
          row.baselineScore,
          row.baselineTotalRecitations,
          row.baselineLastUsedAtUtc,
          row.activatedJournalSequence,
          row.supersededJournalSequence,
        ],
      )
      .toList(growable: false);
}

Future<List<Object?>> _partFingerprint(
  AppDatabase database,
  String surahId,
) async {
  final schemeRows = await (database.select(
    database.rotationSchemes,
  )..where((row) => row.surahId.equals(surahId))).get();
  final schemeIds = schemeRows.map((row) => row.id).toSet();
  final rows =
      (await database.select(database.rotationParts).get())
          .where((row) => schemeIds.contains(row.schemeId))
          .toList(growable: false)
        ..sort((left, right) {
          final scheme = left.schemeId.compareTo(right.schemeId);
          return scheme != 0 ? scheme : left.ordinal.compareTo(right.ordinal);
        });
  return rows
      .map<Object?>(
        (row) => <Object?>[
          row.id,
          row.schemeId,
          row.ordinal,
          row.startAyah,
          row.endAyah,
          row.cachedScore,
          row.cachedRecitationCount,
          row.cachedLastUsedAtUtc,
        ],
      )
      .toList(growable: false);
}

SurahDescriptor _surah({
  required String id,
  required int number,
  required int ayahCount,
}) => SurahDescriptor(
  id: id,
  surahNumber: number,
  officialName: 'Test Surah $number',
  ayahCount: ayahCount,
);

final class _MutableTimeProvider implements TimeProvider {
  _MutableTimeProvider(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider();

  @override
  LocalDate today() => LocalDate(2026, 8, 27);
}

final class _FixedPrayerResolver implements RecitationPrayerContextResolver {
  const _FixedPrayerResolver();

  @override
  Future<PrayerContext?> resolve() async =>
      PrayerContext(prayerType: PrayerType.asr);
}
