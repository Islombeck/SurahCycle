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
          surah: testSurah(id: 'split', number: 1, ayahCount: 8),
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
}
