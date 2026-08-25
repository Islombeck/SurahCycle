import 'package:flutter_test/flutter_test.dart';

import 'package:murajaah/core/domain/domain.dart';
import 'test_fixtures.dart';

void main() {
  const service = SurahSuggestionService();

  test('largest remaining debt is suggested first', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[
        mastered(id: 'one-behind', score: 9, order: 0),
        mastered(id: 'two-behind', score: 8, order: 1),
        mastered(id: 'ahead', score: 11, order: 2),
      ],
    );

    final suggestions = service.suggest(snapshot);

    expect(suggestions.map((suggestion) => suggestion.surah.id), <String>[
      'two-behind',
      'one-behind',
    ]);
    expect(suggestions.first.remaining, 2);
  });

  test('never-recited comes before timestamped surah for equal debt', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 4,
      surahs: <MasteredSurah>[
        mastered(
          id: 'used',
          score: 3,
          order: 0,
          lastUsedAtUtc: DateTime.utc(2020),
        ),
        mastered(id: 'never', score: 3, order: 99),
      ],
    );

    expect(service.suggest(snapshot).map((item) => item.surah.id), <String>[
      'never',
      'used',
    ]);
  });

  test('older last-used wins, then display order, then stable id', () {
    final old = DateTime.utc(2025, 1, 1);
    final recent = DateTime.utc(2025, 2, 1);
    final snapshot = RotationSnapshot(
      rotationTarget: 4,
      surahs: <MasteredSurah>[
        mastered(id: 'recent', score: 3, order: 0, lastUsedAtUtc: recent),
        mastered(id: 'z', score: 3, order: 2, lastUsedAtUtc: old),
        mastered(id: 'b', score: 3, order: 1, lastUsedAtUtc: old),
        mastered(id: 'a', score: 3, order: 1, lastUsedAtUtc: old),
      ],
    );

    expect(
      service.suggest(snapshot, limit: 4).map((item) => item.surah.id),
      <String>['a', 'b', 'z', 'recent'],
    );
  });

  test('inactive surahs are excluded and limit is applied', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 4,
      surahs: <MasteredSurah>[
        mastered(id: 'inactive', score: 0, active: false),
        mastered(id: 'a', score: 1),
        mastered(id: 'b', score: 2),
      ],
    );

    final suggestions = service.suggest(snapshot, limit: 1);

    expect(suggestions, hasLength(1));
    expect(suggestions.single.surah.id, 'a');
  });

  test('recommendations are ranked zero through seven and capped at eight', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 20,
      surahs: <MasteredSurah>[
        for (var index = 0; index < 10; index += 1)
          mastered(
            id: 'surah-$index',
            score: index,
            order: index,
            number: index + 2,
          ),
      ],
    );

    final suggestions = service.suggest(snapshot, limit: 100);

    expect(suggestions, hasLength(maxRecommendationCount));
    expect(suggestions.map((item) => item.recommendationRank), <int>[
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
    expect(suggestions.map((item) => item.surah.id), <String>[
      'surah-0',
      'surah-1',
      'surah-2',
      'surah-3',
      'surah-4',
      'surah-5',
      'surah-6',
      'surah-7',
    ]);
  });

  test('legacy-active Al-Fatiha is never recommended', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[
        MasteredSurah(
          surah: testSurah(id: 'fatiha', number: 1, ayahCount: 7),
          isActive: true,
          hasEnteredRotation: true,
          rotationScore: 0,
        ),
        mastered(id: 'eligible', score: 9, number: 2),
      ],
    );

    expect(service.suggest(snapshot).map((item) => item.surah.id), <String>[
      'eligible',
    ]);
  });

  test('completed and ahead surahs are excluded even below the limit', () {
    final snapshot = RotationSnapshot(
      rotationTarget: 5,
      surahs: <MasteredSurah>[
        mastered(id: 'due', score: 4),
        mastered(id: 'done', score: 5),
        mastered(id: 'ahead', score: 7),
      ],
    );

    expect(
      service.suggest(snapshot, limit: 3).map((item) => item.surah.id),
      <String>['due'],
    );
  });

  test('most indebted split parts use oldest time then part order', () {
    final recent = DateTime.utc(2026, 1, 3);
    final old = DateTime.utc(2026, 1, 1);
    final ranges = suggestEvenRanges(ayahCount: 8, partCount: 4);
    final scheme = SurahRotationScheme(
      id: 'split-v1',
      surahId: 'split',
      version: 1,
      ayahCount: 8,
      parts: <SurahRotationPart>[
        SurahRotationPart(
          id: 'p1',
          schemeId: 'split-v1',
          partNumber: 1,
          ayahRange: ranges[0],
          rotationScore: 9,
          lastUsedAtUtc: recent,
        ),
        SurahRotationPart(
          id: 'p2',
          schemeId: 'split-v1',
          partNumber: 2,
          ayahRange: ranges[1],
          rotationScore: 8,
          lastUsedAtUtc: recent,
        ),
        SurahRotationPart(
          id: 'p3',
          schemeId: 'split-v1',
          partNumber: 3,
          ayahRange: ranges[2],
          rotationScore: 8,
          lastUsedAtUtc: old,
        ),
        SurahRotationPart(
          id: 'p4',
          schemeId: 'split-v1',
          partNumber: 4,
          ayahRange: ranges[3],
          rotationScore: 10,
        ),
      ],
    );
    final snapshot = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[
        MasteredSurah(
          surah: testSurah(id: 'split', number: 2, ayahCount: 8),
          isActive: true,
          hasEnteredRotation: true,
          rotationScheme: scheme,
        ),
      ],
    );

    final suggestion = service.suggest(snapshot).single;

    expect(suggestion.remaining, 2);
    expect(suggestion.recommendedParts.map((part) => part.id), <String>[
      'p3',
      'p2',
    ]);
    expect(suggestion.recommendedPart?.id, 'p3');
  });

  test(
    'operational order is rank, debt, oldest use, display, number, then id',
    () {
      final old = DateTime.utc(2025);
      final newer = DateTime.utc(2026);
      final snapshot = RotationSnapshot(
        rotationTarget: 10,
        surahs: <MasteredSurah>[
          mastered(id: 'ahead-3', score: 13, order: 0, number: 13),
          mastered(id: 'ahead-1', score: 11, order: 0, number: 11),
          mastered(id: 'done', score: 10, order: 0, number: 10),
          mastered(id: 'due-1', score: 9, order: 0, number: 9),
          mastered(id: 'due-2', score: 8, order: 0, number: 8),
          mastered(id: 'due-3', score: 7, order: 0, number: 7),
          mastered(id: 'ahead-2', score: 12, order: 0, number: 12),
          mastered(
            id: 'tie-newer',
            score: 9,
            order: 0,
            number: 20,
            lastUsedAtUtc: newer,
          ),
          mastered(
            id: 'tie-old-order',
            score: 9,
            order: 2,
            number: 20,
            lastUsedAtUtc: old,
          ),
          mastered(
            id: 'tie-old-number-z',
            score: 9,
            order: 1,
            number: 22,
            lastUsedAtUtc: old,
          ),
          mastered(
            id: 'tie-old-number-b',
            score: 9,
            order: 1,
            number: 21,
            lastUsedAtUtc: old,
          ),
          mastered(
            id: 'tie-old-number-a',
            score: 9,
            order: 1,
            number: 21,
            lastUsedAtUtc: old,
          ),
          mastered(id: 'recommended-second', score: 9, number: 30),
          mastered(id: 'recommended-first', score: 9, number: 31),
        ],
      );
      final recommendations = <SurahSuggestion>[
        SurahSuggestion(
          surah: snapshot.surahById('recommended-first'),
          remaining: 1,
          recommendationRank: 0,
        ),
        SurahSuggestion(
          surah: snapshot.surahById('recommended-second'),
          remaining: 1,
          recommendationRank: 1,
        ),
      ];

      final ordered = const SurahOperationalOrderService().order(
        snapshot,
        recommendations: recommendations,
      );

      expect(ordered.map((surah) => surah.id), <String>[
        'recommended-first',
        'recommended-second',
        'due-3',
        'due-2',
        'due-1',
        'tie-old-number-a',
        'tie-old-number-b',
        'tie-old-number-z',
        'tie-old-order',
        'tie-newer',
        'done',
        'ahead-1',
        'ahead-2',
        'ahead-3',
      ]);
    },
  );

  test('operational order changes immediately after recitation', () {
    const ordering = SurahOperationalOrderService();
    const engine = RotationEngine();
    final before = RotationSnapshot(
      rotationTarget: 5,
      surahs: <MasteredSurah>[
        mastered(id: 'moving', score: 4, order: 0, number: 2),
        mastered(id: 'still-due', score: 4, order: 1, number: 3),
      ],
    );
    expect(ordering.order(before).map((surah) => surah.id), <String>[
      'moving',
      'still-due',
    ]);

    final after = engine.registerRecitation(
      before,
      recitation('move-event', 'moving'),
    );

    expect(after.rotationTarget, 5);
    expect(ordering.order(after).map((surah) => surah.id), <String>[
      'still-due',
      'moving',
    ]);
  });
}
