import 'package:flutter_test/flutter_test.dart';

import 'package:murajaah/core/domain/domain.dart';
import 'test_fixtures.dart';

void main() {
  const contextual = ContextualSurahSuggestionService();
  const global = SurahSuggestionService();

  test(
    'with no contextual data the result is identical to the global order',
    () {
      final snapshot = RotationSnapshot(
        rotationTarget: 10,
        surahs: <MasteredSurah>[
          mastered(id: 'one-behind', score: 9, order: 0),
          mastered(id: 'two-behind', score: 8, order: 1),
          mastered(id: 'ahead', score: 11, order: 2),
        ],
      );

      final globalResult = global.suggest(snapshot);
      final contextualResult = contextual.suggest(snapshot);

      expect(
        contextualResult.map((s) => s.surah.id),
        globalResult.map((s) => s.surah.id),
      );
      expect(
        contextualResult.map((s) => s.recommendationRank),
        globalResult.map((s) => s.recommendationRank),
      );
      expect(
        contextualResult.map((s) => s.remaining),
        globalResult.map((s) => s.remaining),
      );
    },
  );

  test('urgency always outranks contextual recency: a more overdue surah wins '
      'even if it was just read in this exact part', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[
        mastered(id: 'more-overdue', score: 7, order: 0),
        mastered(id: 'less-overdue', score: 9, order: 1),
      ],
    );
    final now = DateTime.utc(2026, 9, 4);

    final result = contextual.suggest(
      snapshot,
      lastUsedInExactPart: <String, DateTime>{'more-overdue': now},
    );

    expect(result.map((s) => s.surah.id), <String>[
      'more-overdue',
      'less-overdue',
    ]);
  });

  test('within a tied urgency tier, never-read-in-this-exact-part rises above '
      'recently-read-in-this-exact-part', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[
        mastered(id: 'read-here-recently', score: 8, order: 0),
        mastered(id: 'never-read-here', score: 8, order: 1),
        mastered(id: 'read-here-long-ago', score: 8, order: 2),
      ],
    );

    final result = contextual.suggest(
      snapshot,
      lastUsedInExactPart: <String, DateTime>{
        'read-here-recently': DateTime.utc(2026, 9, 4),
        'read-here-long-ago': DateTime.utc(2020, 1, 1),
      },
    );

    expect(result.map((s) => s.surah.id), <String>[
      'never-read-here',
      'read-here-long-ago',
      'read-here-recently',
    ]);
  });

  test('when exact-part recency ties, prayer-type recency breaks the tie', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[
        mastered(id: 'never-in-prayer-type', score: 8, order: 0),
        mastered(id: 'used-in-prayer-type', score: 8, order: 1),
      ],
    );

    final result = contextual.suggest(
      snapshot,
      lastUsedInPrayerType: <String, DateTime>{
        'used-in-prayer-type': DateTime.utc(2026, 9, 4),
      },
    );

    expect(result.map((s) => s.surah.id), <String>[
      'never-in-prayer-type',
      'used-in-prayer-type',
    ]);
  });

  test(
    'when both contextual tiers tie, the existing global tie-break decides',
    () {
      final old = DateTime.utc(2025, 1, 1);
      final recent = DateTime.utc(2025, 2, 1);
      final snapshot = RotationSnapshot(
        rotationTarget: 4,
        surahs: <MasteredSurah>[
          mastered(id: 'recent', score: 3, order: 0, lastUsedAtUtc: recent),
          mastered(id: 'older', score: 3, order: 1, lastUsedAtUtc: old),
        ],
      );

      final result = contextual.suggest(snapshot);

      expect(result.map((s) => s.surah.id), <String>['older', 'recent']);
    },
  );

  test('a surah already filling a slot in the current part is excluded from '
      'a new recommendation for that same part', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[
        mastered(id: 'just-used', score: 7, order: 0),
        mastered(id: 'next-best', score: 8, order: 1),
      ],
    );

    final result = contextual.suggest(
      snapshot,
      alreadyFilledInCurrentPartSurahIds: const <String>{'just-used'},
    );

    expect(result.map((s) => s.surah.id), <String>['next-best']);
  });

  test('limit and the product ceiling still apply through the wrapper', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 20,
      surahs: <MasteredSurah>[
        for (var index = 0; index < 10; index += 1)
          mastered(id: 'surah-$index', score: index, order: index),
      ],
    );

    expect(contextual.suggest(snapshot, limit: 100), hasLength(8));
    expect(contextual.suggest(snapshot, limit: 2), hasLength(2));
  });
}
