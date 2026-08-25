import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/widgets/widget_projection_builder.dart';

void main() {
  const builder = WidgetProjectionBuilder(
    WidgetProjectionLabels(
      part: 'Часть',
      ayah: 'Аят',
      ayahs: 'аяты',
      openAppToLoadText: 'Откройте приложение для загрузки текста',
    ),
  );

  test('rotation contains due only and puts recommendations first', () {
    final result = builder.buildRotation(<RotationWidgetCandidate>[
      _whole(id: 'done', remaining: 0),
      _whole(id: 'ahead', remaining: -2),
      _whole(id: 'due-3', remaining: 3, displayOrder: 1),
      _whole(
        id: 'recommended',
        remaining: 1,
        isRecommended: true,
        displayOrder: 99,
      ),
      _whole(id: 'due-2', remaining: 2, displayOrder: 2),
    ]);

    expect(result.items.map((item) => item.id), <String>[
      'recommended',
      'due-3',
      'due-2',
    ]);
  });

  test('equal debt uses never/oldest use then display order', () {
    final result = builder.buildRotation(<RotationWidgetCandidate>[
      _whole(id: 'newer', remaining: 1, lastUsedAtUtc: DateTime.utc(2026, 2)),
      _whole(id: 'never-order-2', remaining: 1, displayOrder: 2),
      _whole(id: 'never-order-1', remaining: 1, displayOrder: 1),
      _whole(id: 'older', remaining: 1, lastUsedAtUtc: DateTime.utc(2026)),
    ]);

    expect(result.items.map((item) => item.id), <String>[
      'never-order-1',
      'never-order-2',
      'older',
      'newer',
    ]);
  });

  test('whole item uses alias and formats debt', () {
    final result = builder.buildRotation(<RotationWidgetCandidate>[
      _whole(id: 'whole', remaining: 2, displayName: 'Мой алиас'),
    ]);

    final item = result.items.single;
    expect(item.title, '102. Мой алиас · 8');
    expect(item.debtLabel, '2×');
    expect(item.deepLink.toString(), 'murajaah://app/surah/102');
  });

  test('split item displays part range and part-specific deep link', () {
    final result = builder.buildRotation(<RotationWidgetCandidate>[
      RotationWidgetCandidate.part(
        id: 'scheme:part-2',
        surahId: '2',
        surahNumber: 2,
        displayName: 'Бакара',
        partId: 'part-2',
        partIndex: 2,
        partCount: 4,
        startAyah: 72,
        endAyah: 141,
        remaining: 2,
        isRecommended: false,
        displayOrder: 0,
      ),
    ]);

    final item = result.items.single;
    expect(item.title, '2. Бакара');
    expect(item.subtitle, 'Часть 2/4 · аяты 72–141');
    expect(item.debtLabel, '2×');
    expect(item.deepLink.toString(), 'murajaah://app/surah/2?part=part-2');
  });

  test('rotation empty state is represented by an empty due list', () {
    expect(
      builder.buildRotation(<RotationWidgetCandidate>[
        _whole(id: 'done', remaining: 0),
      ]).items,
      isEmpty,
    );
  });

  test('learning cumulative range and exact verified text are projected', () {
    const exact = ' قُلْ هُوَ ٱللَّهُ أَحَدٌ ';
    final result = builder.buildLearning(
      LearningWidgetCandidate(
        surahId: '112',
        surahNumber: 112,
        displayName: 'Ихлас',
        stageLabel: 'Накопительно',
        startAyah: 1,
        endAyah: 3,
        verifiedTextLines: const <String>[exact],
      ),
    );

    expect(result.item!.title, '112. Ихлас');
    expect(result.item!.rangeLabel, 'аяты 1–3');
    expect(result.item!.verifiedTextLines.single, exact);
    expect(result.item!.deepLink.toString(), 'murajaah://app/learning/112');
  });

  test('learning without cached Quran has metadata and safe fallback only', () {
    final result = builder.buildLearning(
      LearningWidgetCandidate(
        surahId: '112',
        surahNumber: 112,
        displayName: 'Ихлас',
        stageLabel: 'Новый аят',
        startAyah: 3,
        endAyah: 3,
      ),
    );

    expect(result.item!.rangeLabel, 'Аят 3');
    expect(result.item!.verifiedTextLines, isEmpty);
    expect(
      result.item!.unavailableTextLabel,
      'Откройте приложение для загрузки текста',
    );
  });

  test('no selected learning surah produces empty projection', () {
    expect(builder.buildLearning(null).item, isNull);
  });
}

RotationWidgetCandidate _whole({
  required String id,
  required int remaining,
  String displayName = 'Такасур',
  bool isRecommended = false,
  int displayOrder = 0,
  DateTime? lastUsedAtUtc,
}) => RotationWidgetCandidate.whole(
  id: id,
  surahId: '102',
  surahNumber: 102,
  displayName: displayName,
  ayahCount: 8,
  remaining: remaining,
  isRecommended: isRecommended,
  displayOrder: displayOrder,
  lastUsedAtUtc: lastUsedAtUtc,
);
