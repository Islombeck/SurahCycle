import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  group('current mastery invariant', () {
    test('a surah outside current mastery cannot be active', () {
      final descriptor = _surah();

      expect(
        () => MasteredSurah(
          surah: descriptor,
          isCurrentlyMastered: false,
          isActive: true,
          hasEnteredRotation: true,
        ),
        throwsArgumentError,
      );

      final archived = MasteredSurah(
        surah: descriptor,
        isCurrentlyMastered: false,
        isActive: false,
        hasEnteredRotation: true,
      );
      final snapshot = RotationSnapshot(surahs: <MasteredSurah>[archived]);
      expect(snapshot.activeSurahs, isEmpty);
      expect(
        () => const RotationEngine().setSurahActive(
          snapshot,
          descriptor.id,
          isActive: true,
        ),
        throwsStateError,
      );
    });

    test(
      'leaving current mastery requires deactivation in the same change',
      () {
        final active = MasteredSurah(
          surah: _surah(),
          isCurrentlyMastered: true,
          isActive: true,
          hasEnteredRotation: true,
        );

        expect(
          () => active.copyWith(isCurrentlyMastered: false),
          throwsArgumentError,
        );
        final archived = active.copyWith(
          isCurrentlyMastered: false,
          isActive: false,
        );
        expect(archived.isCurrentlyMastered, isFalse);
        expect(archived.isActive, isFalse);
        expect(archived.hasEnteredRotation, isTrue);
      },
    );
  });

  group('re-mastery', () {
    test('activation creates a fresh scheme one step behind without debt', () {
      final lastUsedAt = DateTime.utc(2026, 8, 20, 5);
      final previousScheme = _historicalScheme(lastUsedAt: lastUsedAt);
      final archived = MasteredSurah(
        surah: _surah(),
        isCurrentlyMastered: false,
        isActive: false,
        hasEnteredRotation: true,
        displayOrder: 7,
        rotationScheme: previousScheme,
      );
      final snapshot = RotationSnapshot(
        rotationTarget: 50,
        surahs: <MasteredSurah>[archived],
      );
      final clock = _FixedTimeProvider(DateTime.utc(2026, 8, 27, 9));
      final plan = LearningPlan.classicCumulative(
        targetStartAyah: 1,
        targetEndAyah: 10,
      );
      final learning = LearningSurahState(
        id: 'learning-test-surah',
        surahId: archived.id,
        ayahCount: 10,
        plan: plan,
        stage: plan.stages.last,
        learningCycle: 2,
        lastLearningActivityAtUtc: DateTime.utc(2026, 8, 27, 8),
      );

      final outcome =
          LearningCompletionService(
            learningStateMachine: LearningStateMachine(timeProvider: clock),
          ).completeAndAddToRotation(
            learningState: learning,
            surah: archived.surah,
            rotationSnapshot: snapshot,
            completionEventId: 'complete-cycle-2',
            addToRotation: true,
            rotationSchemeId: 'test-surah:scheme:4:remastered',
          );

      final remastered = outcome.masteredSurah;
      expect(outcome.learning.state.status, LearningStatus.completed);
      expect(outcome.learning.state.learningCycle, 2);
      expect(outcome.rotationSnapshot.rotationTarget, 50);
      expect(remastered.isCurrentlyMastered, isTrue);
      expect(remastered.isActive, isTrue);
      expect(remastered.hasEnteredRotation, isTrue);
      expect(remastered.displayOrder, 7);
      expect(remastered.rotationScheme.id, 'test-surah:scheme:4:remastered');
      expect(remastered.rotationScheme.version, previousScheme.version + 1);
      expect(remastered.rotationScheme.resetsRotationBaseline, isTrue);
      expect(remastered.rotationScheme.baselineRotationScore, 49);
      expect(remastered.rotationScore, 49);
      expect(remastered.rotationScheme.baselineTotalRecitations, 12);
      expect(remastered.totalRecitations, 12);
      expect(remastered.lastUsedAtUtc, lastUsedAt);
      expect(
        remastered.rotationScheme.parts.map((part) => part.ayahRange),
        previousScheme.parts.map((part) => part.ayahRange),
      );
      expect(
        remastered.rotationScheme.parts.map((part) => part.rotationScore),
        everyElement(49),
      );
      expect(
        remastered.rotationScheme.parts.map((part) => part.recitationCount),
        everyElement(12),
      );

      expect(archived.isCurrentlyMastered, isFalse);
      expect(archived.rotationScheme, previousScheme);
      expect(archived.rotationScore, 7);
      expect(archived.totalRecitations, 12);
    });

    test(
      'declining rotation prepares a debt-free scheme for later activation',
      () {
        final previousScheme = _historicalScheme(
          lastUsedAt: DateTime.utc(2026, 8, 20, 5),
        );
        final archived = MasteredSurah(
          surah: _surah(),
          isCurrentlyMastered: false,
          isActive: false,
          hasEnteredRotation: true,
          rotationScheme: previousScheme,
        );
        final plan = LearningPlan.classicCumulative(
          targetStartAyah: 1,
          targetEndAyah: 10,
        );
        final learning = LearningSurahState(
          id: 'learning-test-surah',
          surahId: archived.id,
          ayahCount: 10,
          plan: plan,
          stage: plan.stages.last,
        );

        final outcome =
            LearningCompletionService(
              learningStateMachine: LearningStateMachine(
                timeProvider: _FixedTimeProvider(DateTime.utc(2026, 8, 27, 9)),
              ),
            ).completeAndAddToRotation(
              learningState: learning,
              surah: archived.surah,
              rotationSnapshot: RotationSnapshot(
                rotationTarget: 50,
                surahs: <MasteredSurah>[archived],
              ),
              completionEventId: 'complete-without-rotation',
              addToRotation: false,
            );

        expect(outcome.masteredSurah.isCurrentlyMastered, isTrue);
        expect(outcome.masteredSurah.isActive, isFalse);
        expect(outcome.masteredSurah.hasEnteredRotation, isFalse);
        expect(outcome.masteredSurah.rotationScheme, isNot(previousScheme));
        expect(
          outcome.masteredSurah.rotationScheme.version,
          previousScheme.version + 1,
        );
        expect(
          outcome.masteredSurah.rotationScheme.resetsRotationBaseline,
          isTrue,
        );
        expect(outcome.masteredSurah.rotationScore, 49);
        expect(outcome.masteredSurah.totalRecitations, 12);
        expect(outcome.rotationSnapshot.rotationTarget, 50);
      },
    );

    test('a completed partial range cannot restore whole-surah mastery', () {
      final descriptor = _surah();
      final plan = LearningPlan.chunked(
        targetStartAyah: 1,
        targetEndAyah: 5,
        blockSize: 5,
      );
      final learning = LearningSurahState(
        id: 'learning-partial',
        surahId: descriptor.id,
        ayahCount: descriptor.ayahCount,
        plan: plan,
        stage: plan.stages.last,
      );

      expect(
        () =>
            LearningCompletionService(
              learningStateMachine: LearningStateMachine(
                timeProvider: _FixedTimeProvider(DateTime.utc(2026, 8, 27, 9)),
              ),
            ).completeAndAddToRotation(
              learningState: learning,
              surah: descriptor,
              rotationSnapshot: RotationSnapshot(),
              completionEventId: 'invalid-partial-mastery',
            ),
        throwsStateError,
      );
    });
  });
}

SurahDescriptor _surah() => SurahDescriptor(
  id: 'test-surah',
  surahNumber: 2,
  officialName: 'Test Surah',
  ayahCount: 10,
);

SurahRotationScheme _historicalScheme({required DateTime lastUsedAt}) =>
    SurahRotationScheme.fromRanges(
      id: 'test-surah:scheme:3',
      surahId: 'test-surah',
      version: 3,
      ayahCount: 10,
      ranges: <AyahRange>[
        AyahRange(startAyah: 1, endAyah: 4),
        AyahRange(startAyah: 5, endAyah: 10),
      ],
      baselineRotationScore: 7,
      baselineTotalRecitations: 12,
      baselineLastUsedAtUtc: lastUsedAt,
    );

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
