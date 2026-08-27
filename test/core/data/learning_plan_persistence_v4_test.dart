import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  test(
    'chunked event snapshots restore canonical block and sequence metadata',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = LearningRepository(database);
      await SurahRepository(database).upsertCatalog(<SurahDescriptor>[
        SurahDescriptor(
          id: 'al-baqarah',
          surahNumber: 2,
          officialName: 'Al-Baqarah',
          ayahCount: 286,
        ),
      ]);
      final clock = _MutableTimeProvider(DateTime.utc(2026, 8, 27, 8));
      final machine = LearningStateMachine(timeProvider: clock);
      final chunked = LearningPlan.chunked(
        targetStartAyah: 1,
        targetEndAyah: 20,
        blockSize: 5,
      );
      final started = machine.start(
        id: 'learning-persistence-v4',
        surahId: 'al-baqarah',
        ayahCount: 286,
        plan: chunked,
      );
      await repository.saveState(started);

      clock.value = DateTime.utc(2026, 8, 27, 8, 1);
      final learned = machine.markLearned(started, eventId: 'learned-v4');
      await repository.saveOutcome(learned);

      clock.value = DateTime.utc(2026, 8, 27, 8, 2);
      final classic = LearningPlan.classicCumulative(
        targetStartAyah: 21,
        targetEndAyah: 40,
      );
      final changed = machine.restart(
        learned.state,
        plan: classic,
        eventId: 'plan-changed-v4',
        reason: 'confirmed_by_user',
        planChanged: true,
      );
      await repository.saveOutcome(changed);

      clock.value = DateTime.utc(2026, 8, 27, 8, 3);
      final restartedPlan = LearningPlan.chunked(
        targetStartAyah: 3,
        targetEndAyah: 11,
        blockSize: 3,
      );
      final restarted = machine.restart(
        changed.state,
        plan: restartedPlan,
        eventId: 'restarted-v4',
        reason: 'returned_to_learning',
      );
      await repository.saveOutcome(restarted);

      final restored = await repository.getById(started.id);
      expect(restored?.learningCycle, 3);
      expect(restored?.plan, restartedPlan);
      expect(restored?.stage.kind, LearningStageKind.newAyah);
      expect(restored?.stage.blockIndex, 1);
      expect(restored?.stage.sequenceIndex, 0);

      final events = await repository.getEvents(started.id);
      expect(events.map((event) => event.type), <LearningEventType>[
        LearningEventType.learned,
        LearningEventType.planChanged,
        LearningEventType.restarted,
      ]);

      final learnedEvent = events[0];
      expect(learnedEvent.learningCycle, 1);
      expect(learnedEvent.fromStage.blockIndex, 1);
      expect(learnedEvent.fromStage.sequenceIndex, 0);
      expect(learnedEvent.toStage.blockIndex, 1);
      expect(learnedEvent.toStage.sequenceIndex, 1);

      final changedEvent = events[1];
      expect(changedEvent.learningCycle, 2);
      expect(changedEvent.fromPlan, chunked);
      expect(changedEvent.fromStage.blockIndex, 1);
      expect(changedEvent.fromStage.sequenceIndex, 1);
      expect(changedEvent.toPlan, classic);
      expect(changedEvent.toStage.blockIndex, isNull);
      expect(changedEvent.toStage.sequenceIndex, 0);
      expect(changedEvent.reason, 'confirmed_by_user');

      final restartedEvent = events[2];
      expect(restartedEvent.learningCycle, 3);
      expect(restartedEvent.fromPlan, classic);
      expect(restartedEvent.fromStage.sequenceIndex, 0);
      expect(restartedEvent.toPlan, restartedPlan);
      expect(restartedEvent.toStage.blockIndex, 1);
      expect(restartedEvent.toStage.sequenceIndex, 0);
      expect(restartedEvent.reason, 'returned_to_learning');
    },
  );
}

final class _MutableTimeProvider implements TimeProvider {
  _MutableTimeProvider(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}
