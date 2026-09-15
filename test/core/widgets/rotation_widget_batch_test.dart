import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/widgets/widgets.dart';

import '../domain/test_fixtures.dart';

/// Home and the Rotation widget must rank from the same stored batch, so a
/// completed entry keeps its place in the widget too instead of dropping out
/// as it stops being due.
void main() {
  const labels = WidgetProjectionLabels(
    part: 'Part',
    ayah: 'Ayah',
    ayahs: 'Ayahs',
    openAppToLoadText: 'Open the app',
  );
  const factory = RotationWidgetProjectionFactory(labels: labels);

  RotationSnapshot snapshotOf(int count, {Set<String> completed = const {}}) =>
      RotationSnapshot(
        rotationTarget: 10,
        surahs: <MasteredSurah>[
          for (var index = 0; index < count; index += 1)
            mastered(
              id: 'surah-$index',
              // A completed surah is no longer behind the target.
              score: completed.contains('surah-$index') ? 10 : 9,
              order: index,
            ),
        ],
      );

  RecommendationBatch batchOf(List<String> ids) => RecommendationBatch(
    key: RecommendationBatchKey(
      localDate: LocalDate(2026, 9, 15),
      prayerType: PrayerType.fajr,
      isQada: false,
      partStableKey: 'fard',
    ),
    entries: <RecommendationBatchEntry>[
      for (var index = 0; index < ids.length; index += 1)
        RecommendationBatchEntry(surahId: ids[index], position: index),
    ],
  );

  RotationWidgetProjection buildWith({
    required RotationSnapshot rotation,
    RecommendationBatch? batch,
  }) {
    var token = 0;
    return factory.build(
      rotation: rotation,
      contextLabel: 'Fajr',
      createActionToken: () {
        token += 1;
        return '00000000-0000-4000-8000-${token.toString().padLeft(12, '0')}';
      },
      actionsEnabled: true,
      batch: batch,
    );
  }

  Map<String, int?> ranksOf(
    RotationWidgetProjection projection,
  ) => <String, int?>{
    for (final item in projection.items) item.surahId: item.recommendationRank,
  };

  test('the batch order drives the widget ranks', () {
    final batch = batchOf(<String>['surah-3', 'surah-1', 'surah-2', 'surah-0']);

    final projection = buildWith(rotation: snapshotOf(4), batch: batch);

    expect(ranksOf(projection), <String, int?>{
      'surah-3': 0,
      'surah-1': 1,
      'surah-2': 2,
      'surah-0': 3,
    });
    expect(
      projection.items.map((item) => item.surahId).take(4),
      <String>['surah-3', 'surah-1', 'surah-2', 'surah-0'],
      reason: 'rows are ordered by the stored batch, not recomputed',
    );
  });

  test('a completed entry keeps its rank and stays visible', () {
    final batch = batchOf(<String>['surah-0', 'surah-1', 'surah-2']);

    final projection = buildWith(
      rotation: snapshotOf(3, completed: <String>{'surah-0'}),
      batch: batch,
    );

    final ranks = ranksOf(projection);
    expect(
      ranks.containsKey('surah-0'),
      isTrue,
      reason: 'a completed surah must not vanish from the widget',
    );
    expect(ranks['surah-0'], 0);
    expect(
      projection.items
          .firstWhere((item) => item.surahId == 'surah-0')
          .remaining,
      0,
    );
  });

  test('without a batch the previous ranking is unchanged', () {
    final withoutBatch = buildWith(rotation: snapshotOf(3));

    expect(ranksOf(withoutBatch), <String, int?>{
      'surah-0': 0,
      'surah-1': 1,
      'surah-2': 2,
    });
  });

  test('an empty batch falls back to the computed ranking', () {
    final empty = RecommendationBatch(
      key: RecommendationBatchKey(
        localDate: LocalDate(2026, 9, 15),
        prayerType: PrayerType.fajr,
        isQada: false,
      ),
      entries: const <RecommendationBatchEntry>[],
    );

    final projection = buildWith(rotation: snapshotOf(2), batch: empty);

    expect(ranksOf(projection), <String, int?>{'surah-0': 0, 'surah-1': 1});
  });
}
