import 'package:flutter_test/flutter_test.dart';

import 'package:murajaah/core/domain/domain.dart';
import 'test_fixtures.dart';

void main() {
  late FakeTimeProvider clock;
  late LearningStateMachine machine;

  setUp(() {
    clock = FakeTimeProvider(DateTime.utc(2026, 1, 1, 8));
    machine = LearningStateMachine(timeProvider: clock);
  });

  LearningSurahState atStage(
    LearningStage stage, {
    int ayahCount = 3,
    LearningStatus status = LearningStatus.active,
    DateTime? lastActivity,
    DateTime? marker,
  }) => LearningSurahState(
    id: 'learning-a',
    surahId: 'a',
    ayahCount: ayahCount,
    stage: stage,
    status: status,
    lastLearningActivityAtUtc: lastActivity ?? DateTime.utc(2026, 1, 1, 8),
    inactivityRollbackForActivityAtUtc: marker,
  );

  group('learning sequence', () {
    test('starts at the first ayah', () {
      final state = machine.start(id: 'learning-a', surahId: 'a', ayahCount: 3);

      expect(state.stage, LearningStage.newAyah(1));
      expect(state.status, LearningStatus.active);
      expect(state.lastLearningActivityAtUtc, clock.value);
    });

    test('first ayah advances directly to the second ayah', () {
      final outcome = machine.markLearned(
        atStage(LearningStage.newAyah(1)),
        eventId: 'learn-1',
      );

      expect(outcome.state.stage, LearningStage.newAyah(2));
      expect(outcome.completionRequired, isFalse);
    });

    test('second ayah advances to cumulative 1 through 2', () {
      final outcome = machine.markLearned(
        atStage(LearningStage.newAyah(2)),
        eventId: 'learn-2',
      );

      expect(outcome.state.stage, LearningStage.cumulative(2));
    });

    test('cumulative 1 through 2 advances to the third ayah', () {
      final outcome = machine.markLearned(
        atStage(LearningStage.cumulative(2)),
        eventId: 'learn-c2',
      );

      expect(outcome.state.stage, LearningStage.newAyah(3));
    });

    test('third and last ayah advances to cumulative 1 through 3', () {
      final outcome = machine.markLearned(
        atStage(LearningStage.newAyah(3)),
        eventId: 'learn-3',
      );

      expect(outcome.state.stage, LearningStage.cumulative(3));
      expect(outcome.completionRequired, isFalse);
    });

    test('learning the final cumulative stage requests completion', () {
      final state = atStage(LearningStage.cumulative(3));

      final outcome = machine.markLearned(state, eventId: 'learn-final');

      expect(outcome.completionRequired, isTrue);
      expect(outcome.state.stage, LearningStage.cumulative(3));
      expect(outcome.state.status, LearningStatus.active);
    });

    test('accepting completion marks progress completed', () {
      final outcome = machine.complete(
        atStage(LearningStage.cumulative(3)),
        eventId: 'complete',
      );

      expect(outcome.state.status, LearningStatus.completed);
      expect(outcome.event?.type, LearningEventType.completed);
    });

    test('one-ayah surah has cumulative stage before completion', () {
      final initial = atStage(LearningStage.newAyah(1), ayahCount: 1);

      final cumulative = machine.markLearned(initial, eventId: 'learn-1');
      final prompt = machine.markLearned(
        cumulative.state,
        eventId: 'learn-cumulative',
      );

      expect(cumulative.state.stage, LearningStage.cumulative(1));
      expect(cumulative.completionRequired, isFalse);
      expect(prompt.completionRequired, isTrue);
      expect(prompt.state.stage, LearningStage.cumulative(1));
    });

    test('Repeated updates activity without changing the stage', () {
      final state = atStage(LearningStage.cumulative(2));
      clock.value = DateTime.utc(2026, 1, 2, 10);

      final outcome = machine.markRepeated(state, eventId: 'repeat');

      expect(outcome.state.stage, state.stage);
      expect(outcome.state.lastLearningActivityAtUtc, clock.value);
      expect(outcome.event?.type, LearningEventType.repeated);
    });
  });

  group('inactivity rollback', () {
    test('71 hours 59 minutes does not roll back', () {
      final state = atStage(LearningStage.cumulative(3));
      clock.value = DateTime.utc(2026, 1, 4, 7, 59);

      final outcome = machine.applyInactivityRollback(
        state,
        rollbackEventId: 'rollback',
      );

      expect(outcome.didRollback, isFalse);
      expect(outcome.state, state);
      expect(outcome.event, isNull);
    });

    test('exactly 72 hours rolls back one stage and emits an event', () {
      final state = atStage(LearningStage.cumulative(3));
      clock.value = DateTime.utc(2026, 1, 4, 8);

      final outcome = machine.applyInactivityRollback(
        state,
        rollbackEventId: 'rollback',
      );

      expect(outcome.didRollback, isTrue);
      expect(outcome.state.stage, LearningStage.newAyah(3));
      expect(outcome.event?.type, LearningEventType.inactivityRollback);
      expect(
        outcome.state.inactivityRollbackForActivityAtUtc,
        state.lastLearningActivityAtUtc,
      );
    });

    test('one long inactivity period causes only one rollback', () {
      final state = atStage(LearningStage.cumulative(3));
      clock.value = DateTime.utc(2026, 1, 4, 8);
      final first = machine.applyInactivityRollback(
        state,
        rollbackEventId: 'rollback-1',
      );
      clock.value = DateTime.utc(2026, 2, 1, 8);

      final second = machine.applyInactivityRollback(
        first.state,
        rollbackEventId: 'rollback-2',
      );

      expect(first.didRollback, isTrue);
      expect(second.didRollback, isFalse);
      expect(second.state.stage, LearningStage.newAyah(3));
    });

    test('new user activity starts a new inactivity period', () {
      final state = atStage(LearningStage.cumulative(3));
      clock.value = DateTime.utc(2026, 1, 4, 8);
      final first = machine.applyInactivityRollback(
        state,
        rollbackEventId: 'rollback-1',
      );
      clock.value = DateTime.utc(2026, 1, 4, 9);
      final repeated = machine.markRepeated(first.state, eventId: 'repeat');
      clock.value = DateTime.utc(2026, 1, 7, 9);

      final second = machine.applyInactivityRollback(
        repeated.state,
        rollbackEventId: 'rollback-2',
      );

      expect(repeated.state.inactivityRollbackForActivityAtUtc, isNull);
      expect(second.didRollback, isTrue);
      expect(second.state.stage, LearningStage.cumulative(2));
    });

    test('never rolls back before the first stage', () {
      final state = atStage(LearningStage.newAyah(1));
      clock.value = DateTime.utc(2026, 1, 20);

      final outcome = machine.applyInactivityRollback(
        state,
        rollbackEventId: 'rollback',
      );

      expect(outcome.didRollback, isFalse);
      expect(outcome.state.stage, LearningStage.newAyah(1));
    });

    test('never rolls back completed learning', () {
      final state = atStage(
        LearningStage.cumulative(3),
        status: LearningStatus.completed,
      );
      clock.value = DateTime.utc(2026, 1, 20);

      final outcome = machine.applyInactivityRollback(
        state,
        rollbackEventId: 'rollback',
      );

      expect(outcome.didRollback, isFalse);
      expect(outcome.state, state);
    });

    test('undo restores the stage but keeps the one-period marker', () {
      final state = atStage(LearningStage.cumulative(3));
      clock.value = DateTime.utc(2026, 1, 4, 8);
      final rollback = machine.applyInactivityRollback(
        state,
        rollbackEventId: 'rollback',
      );

      final undo = machine.undo(rollback);
      final repeatedCheck = machine.applyInactivityRollback(
        undo.value,
        rollbackEventId: 'rollback-again',
      );

      expect(undo.didUndo, isTrue);
      expect(undo.value.stage, LearningStage.cumulative(3));
      expect(
        undo.value.inactivityRollbackForActivityAtUtc,
        state.lastLearningActivityAtUtc,
      );
      expect(repeatedCheck.didRollback, isFalse);
    });
  });

  test(
    'completion atomically creates active mastered state one step behind',
    () {
      final completionService = LearningCompletionService(
        learningStateMachine: machine,
      );
      final learning = atStage(LearningStage.cumulative(3));
      final rotation = RotationSnapshot(rotationTarget: 41);
      final descriptor = testSurah(id: 'a', number: 7, ayahCount: 3);

      final outcome = completionService.completeAndAddToRotation(
        learningState: learning,
        surah: descriptor,
        rotationSnapshot: rotation,
        completionEventId: 'complete',
      );

      expect(outcome.learning.state.status, LearningStatus.completed);
      expect(outcome.rotationSnapshot.rotationTarget, 41);
      expect(outcome.masteredSurah.isActive, isTrue);
      expect(outcome.masteredSurah.rotationScore, 40);
      expect(outcome.masteredSurah.totalRecitations, 0);
    },
  );
}
