import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

import 'test_fixtures.dart';

/// Reported by the owner during acceptance: the eight-item block works, "но
/// когда уже по 2× количество уменьшается". The batch pool was the due-only
/// ranking, so every surah that reached the rotation target left the pool —
/// and by the time repeats appear, most of them have.
void main() {
  const service = ContextualSurahSuggestionService();
  const batches = RecommendationBatchService();

  RotationSnapshot snapshotOf({
    required int total,
    required int satisfied,
  }) => RotationSnapshot(
    rotationTarget: 10,
    surahs: <MasteredSurah>[
      for (var index = 0; index < total; index += 1)
        mastered(
          id: 'surah-$index',
          // A "satisfied" surah has reached the target and is no longer due.
          score: index < satisfied ? 10 : 5,
          order: index,
        ),
    ],
  );

  RecommendationBatchKey keyOf(PrayerType prayerType) => RecommendationBatchKey(
    localDate: LocalDate(2026, 9, 15),
    prayerType: prayerType,
    isQada: false,
    partStableKey: 'fard',
  );

  test('the pool keeps satisfied surahs, ranked after the due ones', () {
    final pool = service.rankedCandidateIdsWith(
      snapshotOf(total: 4, satisfied: 2),
      ContextualRecommendationInputs.empty,
    );

    expect(pool, hasLength(4));
    expect(pool.take(2), <String>[
      'surah-2',
      'surah-3',
    ], reason: 'still-due surahs must come first');
    expect(pool.skip(2).toSet(), <String>{'surah-0', 'surah-1'});
  });

  test('a batch still reaches eight when most surahs are satisfied', () {
    // Ten eligible surahs, nine already at the target — exactly the state the
    // owner was in when the block shrank.
    final pool = service.rankedCandidateIdsWith(
      snapshotOf(total: 10, satisfied: 9),
      ContextualRecommendationInputs.empty,
    );

    final plan = batches.plan(
      key: keyOf(PrayerType.fajr),
      rankedEligibleSurahIds: pool,
      cycle: RecommendationCycleState.empty,
    );

    expect(
      plan.batch.entries,
      hasLength(8),
      reason: 'the visible block must not shrink as the cycle completes',
    );
  });

  test('a second round still fills eight and marks the repeats', () {
    final pool = service.rankedCandidateIdsWith(
      snapshotOf(total: 10, satisfied: 10),
      ContextualRecommendationInputs.empty,
    );
    // Everything has already been offered this cycle.
    final exhausted = RecommendationCycleState(
      offeredSurahIds: pool,
      cycleNumber: 1,
    );

    final plan = batches.plan(
      key: keyOf(PrayerType.dhuhr),
      rankedEligibleSurahIds: pool,
      cycle: exhausted,
    );

    expect(plan.batch.entries, hasLength(8));
    expect(
      plan.batch.entries.every((entry) => entry.occurrence == 2),
      isTrue,
      reason: 'a fresh round is honestly marked as a repeat',
    );
    expect(plan.cycle.cycleNumber, 2);
  });

  test('suggest keeps its due-only meaning', () {
    // The product ranking must not start proposing surahs that are not due.
    final suggestions = service.suggest(snapshotOf(total: 10, satisfied: 9));

    expect(
      suggestions.map((suggestion) => suggestion.surah.id),
      <String>['surah-9'],
      reason: 'only the one surah still behind the target is due',
    );
  });

  test('a fully satisfied rotation suggests nothing', () {
    expect(service.suggest(snapshotOf(total: 5, satisfied: 5)), isEmpty);
  });
}
