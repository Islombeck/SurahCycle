import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/widgets/widget_snapshot.dart';

void main() {
  const codec = WidgetSnapshotCodec();

  test('schema 2 snapshot round-trips without changing verified text', () {
    const exactText = '  بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ  ';
    final original = _snapshot(exactText: exactText);

    final result = codec.decode(codec.encode(original));

    expect(result, isA<WidgetSnapshotDecoded>());
    final decoded = (result as WidgetSnapshotDecoded).snapshot;
    expect(decoded.sameProjectionAs(original), isTrue);
    expect(decoded.generatedAtUtc, original.generatedAtUtc);
    expect(decoded.learning.item!.verifiedTextLines.single, exactText);
  });

  test('missing and malformed snapshots produce safe rejection results', () {
    expect(
      (codec.decode(null) as WidgetSnapshotRejected).error,
      WidgetSnapshotDecodeError.missing,
    );
    for (final source in <String>[
      '{',
      '[]',
      '{"schemaVersion":2}',
      '{"schemaVersion":"1"}',
    ]) {
      expect(
        (codec.decode(source) as WidgetSnapshotRejected).error,
        WidgetSnapshotDecodeError.malformed,
      );
    }
  });

  test('unknown schema version is distinguishable and never parsed', () {
    final result = codec.decode('{"schemaVersion":99}');

    expect(result, isA<WidgetSnapshotRejected>());
    final rejected = result as WidgetSnapshotRejected;
    expect(rejected.error, WidgetSnapshotDecodeError.unsupportedVersion);
    expect(rejected.actualVersion, 99);
  });

  test('schema 1 snapshot is rejected safely after the rank upgrade', () {
    final result = codec.decode('{"schemaVersion":1}');

    expect(result, isA<WidgetSnapshotRejected>());
    final rejected = result as WidgetSnapshotRejected;
    expect(rejected.error, WidgetSnapshotDecodeError.unsupportedVersion);
    expect(rejected.actualVersion, 1);
  });

  test('tampered derived debt label rejects the entire snapshot', () {
    final encoded = codec
        .encode(_snapshot())
        .replaceFirst('"debtLabel":"2×"', '"debtLabel":"9×"');

    expect(
      (codec.decode(encoded) as WidgetSnapshotRejected).error,
      WidgetSnapshotDecodeError.malformed,
    );
  });

  test('snapshot rejects duplicate rotation item IDs', () {
    final item = _snapshot().rotation.items.single;

    expect(
      () => RotationWidgetProjection(items: <RotationWidgetItem>[item, item]),
      throwsArgumentError,
    );
  });

  test('snapshot rejects duplicate recommendation ranks', () {
    final first = _snapshot().rotation.items.single;
    final second = RotationWidgetItem(
      id: 'second',
      surahId: '3',
      title: '3. Fixture',
      remaining: 1,
      recommendationRank: 0,
      deepLink: Uri.parse('murajaah://app/surah/3'),
    );

    expect(
      () =>
          RotationWidgetProjection(items: <RotationWidgetItem>[first, second]),
      throwsArgumentError,
    );
  });

  test('snapshot mirrors native collection limits', () {
    expect(
      () => RotationWidgetProjection(
        items: <RotationWidgetItem>[
          for (var index = 0; index <= maxRotationWidgetItems; index += 1)
            RotationWidgetItem(
              id: 'item-$index',
              surahId: '$index',
              title: 'Fixture $index',
              remaining: 1,
              deepLink: Uri.parse('murajaah://app/surah/$index'),
            ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => LearningWidgetItem(
        surahId: '2',
        title: 'Fixture',
        stageLabel: 'Fixture',
        rangeLabel: 'Fixture',
        unavailableTextLabel: 'Fixture',
        verifiedTextLines: const <String>['1', '2', '3', '4'],
        deepLink: Uri.parse('murajaah://app/learning/2'),
      ),
      throwsArgumentError,
    );
  });

  test('snapshot rejects native stable-id collisions', () {
    expect(stableWidgetItemId('Aa'), stableWidgetItemId('BB'));
    final first = RotationWidgetItem(
      id: 'Aa',
      surahId: '2',
      title: 'First',
      remaining: 1,
      deepLink: Uri.parse('murajaah://app/surah/2'),
    );
    final second = RotationWidgetItem(
      id: 'BB',
      surahId: '3',
      title: 'Second',
      remaining: 1,
      deepLink: Uri.parse('murajaah://app/surah/3'),
    );

    expect(
      () =>
          RotationWidgetProjection(items: <RotationWidgetItem>[first, second]),
      throwsArgumentError,
    );
  });

  test('explicit null recommendation rank is malformed', () {
    final encoded = codec
        .encode(_snapshot())
        .replaceFirst('"recommendationRank":0', '"recommendationRank":null');

    expect(
      (codec.decode(encoded) as WidgetSnapshotRejected).error,
      WidgetSnapshotDecodeError.malformed,
    );
  });
}

WidgetSnapshot _snapshot({String exactText = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ'}) =>
    WidgetSnapshot(
      generatedAtUtc: DateTime.utc(2026, 8, 25, 10),
      locale: 'ru',
      rotation: RotationWidgetProjection(
        items: <RotationWidgetItem>[
          RotationWidgetItem(
            id: 'scheme-1:part-2',
            surahId: '2',
            partId: 'part-2',
            title: '2. Бакара',
            subtitle: 'Часть 2/4 · аяты 72–141',
            remaining: 2,
            recommendationRank: 0,
            deepLink: Uri.parse('murajaah://app/surah/2?part=part-2'),
          ),
        ],
      ),
      learning: LearningWidgetProjection.selected(
        LearningWidgetItem(
          surahId: '112',
          title: '112. Ихлас',
          stageLabel: 'Накопительно',
          rangeLabel: 'Аяты 1–3',
          unavailableTextLabel: 'Откройте приложение',
          verifiedTextLines: <String>[exactText],
          deepLink: Uri.parse('murajaah://app/learning/112'),
        ),
      ),
    );
