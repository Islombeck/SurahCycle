import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

import 'test_fixtures.dart';

/// A memory check may nudge the review order, and nothing else. These tests
/// pin both halves of that promise: it does break ties, and it never beats
/// urgency.
void main() {
  const service = ContextualSurahSuggestionService();

  RotationSnapshot snapshotOf(Map<String, int> scoresById) => RotationSnapshot(
    rotationTarget: 10,
    surahs: <MasteredSurah>[
      for (final (index, entry) in scoresById.entries.indexed)
        mastered(id: entry.key, score: entry.value, order: index),
    ],
  );

  List<String> rank(
    RotationSnapshot snapshot, {
    Set<String> needsReview = const <String>{},
  }) => service
      .rankedCandidateIdsWith(
        snapshot,
        ContextualRecommendationInputs(recallNeedsReviewSurahIds: needsReview),
      )
      .toList();

  test('an imperfect last check breaks a tie', () {
    final snapshot = snapshotOf(<String, int>{'a': 5, 'b': 5, 'c': 5});

    expect(rank(snapshot), <String>['a', 'b', 'c']);
    expect(
      rank(snapshot, needsReview: <String>{'c'}),
      <String>['c', 'a', 'b'],
      reason: 'the surah that was just missed should come up sooner',
    );
  });

  test('order among equally missed surahs stays the previous one', () {
    final snapshot = snapshotOf(<String, int>{'a': 5, 'b': 5, 'c': 5});

    expect(rank(snapshot, needsReview: <String>{'a', 'b', 'c'}), <String>[
      'a',
      'b',
      'c',
    ]);
  });

  test('a missed surah still cannot overtake a more overdue one', () {
    // 'a' is further behind the target, so it stays first no matter what the
    // memory check said about 'b'.
    final snapshot = snapshotOf(<String, int>{'a': 1, 'b': 8});

    expect(
      rank(snapshot, needsReview: <String>{'b'}),
      <String>['a', 'b'],
      reason: 'urgency is the primary key and recall must not override it',
    );
  });

  test('with no checks at all the ranking is untouched', () {
    final snapshot = snapshotOf(<String, int>{'a': 5, 'b': 3, 'c': 7});

    expect(rank(snapshot), rank(snapshot, needsReview: const <String>{}));
  });

  test('a clean check clears the nudge', () {
    final snapshot = snapshotOf(<String, int>{'a': 5, 'b': 5});

    // The set is derived from the latest attempt only, so a surah that was
    // missed and then recalled is simply absent from it.
    expect(rank(snapshot, needsReview: <String>{'b'}), <String>['b', 'a']);
    expect(rank(snapshot, needsReview: const <String>{}), <String>['a', 'b']);
  });

  test('the recall set participates in value equality', () {
    const withoutRecall = ContextualRecommendationInputs();
    const withRecall = ContextualRecommendationInputs(
      recallNeedsReviewSurahIds: <String>{'a'},
    );

    expect(withRecall, isNot(withoutRecall));
    expect(
      withRecall,
      const ContextualRecommendationInputs(
        recallNeedsReviewSurahIds: <String>{'a'},
      ),
    );
  });

  test('suggest applies the same tier as the candidate pool', () {
    final snapshot = snapshotOf(<String, int>{'a': 5, 'b': 5, 'c': 5});

    final suggestions = service.suggest(
      snapshot,
      recallNeedsReviewSurahIds: <String>{'c'},
    );

    expect(
      suggestions.map((suggestion) => suggestion.surah.id).take(3),
      <String>['c', 'a', 'b'],
    );
  });
}
