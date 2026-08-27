import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  group('chunked learning plan', () {
    test('range 1..20 with blocks of 5 follows the required progression', () {
      final plan = LearningPlan.chunked(
        targetStartAyah: 1,
        targetEndAyah: 20,
        blockSize: 5,
      );
      final stages = plan.stages;

      _expectStage(
        stages[0],
        kind: LearningStageKind.newAyah,
        start: 1,
        end: 1,
        block: 1,
        sequence: 0,
      );
      _expectStage(
        stages[1],
        kind: LearningStageKind.newAyah,
        start: 2,
        end: 2,
        block: 1,
        sequence: 1,
      );
      _expectStage(
        stages[2],
        kind: LearningStageKind.reviewRange,
        start: 1,
        end: 2,
        block: 1,
        sequence: 2,
      );

      final completedFirstBlock = _indexOf(
        stages,
        kind: LearningStageKind.reviewRange,
        start: 1,
        end: 5,
        block: 1,
      );
      _expectStage(
        stages[completedFirstBlock + 1],
        kind: LearningStageKind.newAyah,
        start: 6,
        end: 6,
        block: 2,
      );
      _expectStage(
        stages[completedFirstBlock + 2],
        kind: LearningStageKind.newAyah,
        start: 7,
        end: 7,
        block: 2,
      );
      _expectStage(
        stages[completedFirstBlock + 3],
        kind: LearningStageKind.reviewRange,
        start: 6,
        end: 7,
        block: 2,
      );
      _expectStage(
        stages[completedFirstBlock + 4],
        kind: LearningStageKind.bridge,
        start: 4,
        end: 7,
        block: 2,
      );

      final sectionReview = stages.singleWhere(
        (stage) => stage.kind == LearningStageKind.sectionReview,
      );
      _expectStage(
        sectionReview,
        kind: LearningStageKind.sectionReview,
        start: 1,
        end: 20,
        block: 4,
      );
      expect(stages[stages.length - 2], sectionReview);
      _expectStage(
        stages.last,
        kind: LearningStageKind.finalReview,
        start: 1,
        end: 20,
        sequence: stages.length - 1,
      );

      final clock = _MutableTimeProvider(DateTime.utc(2026, 8, 27, 8));
      final machine = LearningStateMachine(timeProvider: clock);
      var state = machine.start(
        id: 'learning-al-baqarah',
        surahId: 'al-baqarah',
        ayahCount: 286,
        plan: plan,
      );
      expect(state.stage, stages.first);

      for (var index = 1; index < stages.length; index += 1) {
        final outcome = machine.markLearned(state, eventId: 'learn-$index');
        expect(outcome.completionRequired, isFalse);
        expect(outcome.state.stage, stages[index]);
        state = outcome.state;
      }

      final finalReview = machine.markLearned(
        state,
        eventId: 'learn-final-review',
      );
      expect(finalReview.completionRequired, isTrue);
      expect(finalReview.state.stage, stages.last);

      final completed = machine.complete(
        finalReview.state,
        eventId: 'complete-range',
      );
      expect(completed.state.status, LearningStatus.completed);
      expect(completed.state.isFullSurahTarget, isFalse);
      expect(completed.event?.type, LearningEventType.completed);
    });

    test(
      'rollback moves bridge, section, and final review by one stage only',
      () {
        final plan = LearningPlan.chunked(
          targetStartAyah: 1,
          targetEndAyah: 20,
          blockSize: 5,
        );
        final stages = plan.stages;
        final lastActivity = DateTime.utc(2026, 8, 24, 8);
        final clock = _MutableTimeProvider(DateTime.utc(2026, 8, 27, 8));
        final machine = LearningStateMachine(timeProvider: clock);

        for (final kind in <LearningStageKind>[
          LearningStageKind.bridge,
          LearningStageKind.sectionReview,
          LearningStageKind.finalReview,
        ]) {
          final index = stages.indexWhere((stage) => stage.kind == kind);
          expect(index, greaterThan(0));
          final state = LearningSurahState(
            id: 'learning-${kind.name}',
            surahId: 'al-baqarah',
            ayahCount: 286,
            plan: plan,
            stage: stages[index],
            lastLearningActivityAtUtc: lastActivity,
          );

          final outcome = machine.applyInactivityRollback(
            state,
            rollbackEventId: 'rollback-${kind.name}',
          );

          expect(outcome.didRollback, isTrue);
          expect(outcome.state.stage, stages[index - 1]);
          expect(plan.indexOf(outcome.state.stage), index - 1);
          expect(
            outcome.state.inactivityRollbackForActivityAtUtc,
            lastActivity,
          );

          clock.value = DateTime.utc(2026, 9, 27, 8);
          final sameIdlePeriod = machine.applyInactivityRollback(
            outcome.state,
            rollbackEventId: 'rollback-${kind.name}-again',
          );
          expect(sameIdlePeriod.didRollback, isFalse);
          expect(sameIdlePeriod.state.stage, stages[index - 1]);
          clock.value = DateTime.utc(2026, 8, 27, 8);
        }
      },
    );

    test('last chunk is clipped to the selected target range', () {
      final plan = LearningPlan.chunked(
        targetStartAyah: 3,
        targetEndAyah: 11,
        blockSize: 5,
      );
      final stages = plan.stages;

      expect(
        stages.every((stage) => stage.startAyah >= 3 && stage.endAyah <= 11),
        isTrue,
      );
      expect(
        stages.where((stage) => stage.kind == LearningStageKind.sectionReview),
        isEmpty,
      );

      final secondBlockStart = _indexOf(
        stages,
        kind: LearningStageKind.newAyah,
        start: 8,
        end: 8,
        block: 2,
      );
      _expectStage(
        stages[secondBlockStart + 2],
        kind: LearningStageKind.reviewRange,
        start: 8,
        end: 9,
        block: 2,
      );
      _expectStage(
        stages[secondBlockStart + 3],
        kind: LearningStageKind.bridge,
        start: 6,
        end: 9,
        block: 2,
      );
      _expectStage(
        stages[stages.length - 2],
        kind: LearningStageKind.reviewRange,
        start: 8,
        end: 11,
        block: 2,
      );
      _expectStage(
        stages.last,
        kind: LearningStageKind.finalReview,
        start: 3,
        end: 11,
      );
    });
  });
}

int _indexOf(
  List<LearningStage> stages, {
  required LearningStageKind kind,
  required int start,
  required int end,
  required int block,
}) {
  final index = stages.indexWhere(
    (stage) =>
        stage.kind == kind &&
        stage.startAyah == start &&
        stage.endAyah == end &&
        stage.blockIndex == block,
  );
  expect(index, isNonNegative);
  return index;
}

void _expectStage(
  LearningStage stage, {
  required LearningStageKind kind,
  required int start,
  required int end,
  int? block,
  int? sequence,
}) {
  expect(stage.kind, kind);
  expect(stage.startAyah, start);
  expect(stage.endAyah, end);
  if (block != null) expect(stage.blockIndex, block);
  if (sequence != null) expect(stage.sequenceIndex, sequence);
}

final class _MutableTimeProvider implements TimeProvider {
  _MutableTimeProvider(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}
