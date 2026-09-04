import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/application/widget_recitation_action.dart';
import 'package:murajaah/core/widgets/widget_snapshot.dart';

void main() {
  const codec = WidgetSnapshotCodec();

  test('schema 6 snapshot round-trips routine labels and item state', () {
    const exactArabic = '  بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ  ';
    const exactTransliteration = 'Bismi All<u>a</u>hi  ';
    const exactTranslation = '  Во имя Аллаха';
    final original = _snapshot(
      line: LearningWidgetAyahLine(
        surahNumber: 112,
        ayahNumber: 1,
        arabic: exactArabic,
        transliteration: exactTransliteration,
        translation: exactTranslation,
      ),
    );

    final encoded = codec.encode(original);
    final result = codec.decode(encoded);

    expect(result, isA<WidgetSnapshotDecoded>());
    final decoded = (result as WidgetSnapshotDecoded).snapshot;
    expect(decoded.sameProjectionAs(original), isTrue);
    expect(decoded.generatedAtUtc, original.generatedAtUtc);
    expect(decoded.snapshotRevision, original.snapshotRevision);
    expect(decoded.rotation.currentPartLabel, 'Asr · Fard');
    expect(decoded.rotation.slotProgressLabel, 'Surahs 1/2');
    final line = decoded.learning.item!.ayahLines.single;
    expect(line.arabic, exactArabic);
    expect(line.transliteration, exactTransliteration);
    expect(line.translation, exactTranslation);

    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final learning =
        (json['learning'] as Map<String, dynamic>)['item']
            as Map<String, dynamic>;
    expect(learning, containsPair('surahNumber', 112));
    expect(learning, isNot(contains('verifiedTextLines')));
    expect(learning['ayahLines'], <Object?>[
      <String, Object?>{
        'surah': 112,
        'ayah': 1,
        'arabic': exactArabic,
        'transliteration': exactTransliteration,
        'translation': exactTranslation,
      },
    ]);
  });

  test('missing and malformed snapshots produce safe rejection results', () {
    expect(
      (codec.decode(null) as WidgetSnapshotRejected).error,
      WidgetSnapshotDecodeError.missing,
    );
    for (final source in <String>[
      '{',
      '[]',
      '{"schemaVersion":6}',
      '{"schemaVersion":"6"}',
    ]) {
      expect(
        (codec.decode(source) as WidgetSnapshotRejected).error,
        WidgetSnapshotDecodeError.malformed,
      );
    }
  });

  test('unknown and previous schema versions are rejected safely in Dart', () {
    for (final version in <int>[2, 3, 4, 5, 99]) {
      final result = codec.decode('{"schemaVersion":$version}');

      expect(result, isA<WidgetSnapshotRejected>());
      final rejected = result as WidgetSnapshotRejected;
      expect(rejected.error, WidgetSnapshotDecodeError.unsupportedVersion);
      expect(rejected.actualVersion, version);
    }
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

  test('snapshot rejects duplicate row IDs, ranks, and action tokens', () {
    final first = _snapshot().rotation.items.single;
    final duplicateId = RotationWidgetItem(
      id: first.id,
      surahId: '3',
      title: '3. Fixture',
      remaining: 1,
      deepLink: Uri.parse('murajaah://app/surah/3'),
    );
    final duplicateRank = RotationWidgetItem(
      id: 'second',
      surahId: '3',
      title: '3. Fixture',
      remaining: 1,
      recommendationRank: 0,
      deepLink: Uri.parse('murajaah://app/surah/3'),
    );
    final duplicateAction = RotationWidgetItem(
      id: 'third',
      surahId: '2',
      partId: 'part-2',
      title: '2. Fixture',
      remaining: 1,
      deepLink: Uri.parse('murajaah://app/surah/2?part=part-2'),
      action: first.action,
    );

    expect(
      () => RotationWidgetProjection(
        items: <RotationWidgetItem>[first, duplicateId],
      ),
      throwsArgumentError,
    );
    expect(
      () => RotationWidgetProjection(
        items: <RotationWidgetItem>[first, duplicateRank],
      ),
      throwsArgumentError,
    );
    expect(
      () => RotationWidgetProjection(
        items: <RotationWidgetItem>[first, duplicateAction],
      ),
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
        surahNumber: 2,
        startAyah: 1,
        endAyah: 4,
        title: 'Fixture',
        stageLabel: 'Fixture',
        rangeLabel: 'Fixture',
        unavailableTextLabel: 'Fixture',
        ayahLines: <LearningWidgetAyahLine>[
          for (var ayah = 1; ayah <= 4; ayah += 1)
            LearningWidgetAyahLine(
              surahNumber: 2,
              ayahNumber: ayah,
              arabic: '$ayah',
            ),
        ],
        deepLink: Uri.parse('murajaah://app/learning/2'),
      ),
      throwsArgumentError,
    );
  });

  test(
    'structured learning lines reject mismatched or unordered coordinates',
    () {
      LearningWidgetItem itemWith(Iterable<LearningWidgetAyahLine> lines) =>
          LearningWidgetItem(
            surahId: '112',
            surahNumber: 112,
            startAyah: 1,
            endAyah: 3,
            title: '112. Ихлас',
            stageLabel: 'Накопительно',
            rangeLabel: 'Аяты 1–3',
            unavailableTextLabel: 'Откройте приложение',
            ayahLines: lines,
            deepLink: Uri.parse('murajaah://app/learning/112'),
          );

      expect(
        () => itemWith(<LearningWidgetAyahLine>[_line(2), _line(1)]),
        throwsArgumentError,
      );
      expect(
        () => itemWith(<LearningWidgetAyahLine>[
          LearningWidgetAyahLine(
            surahNumber: 113,
            ayahNumber: 1,
            arabic: 'fixture',
          ),
        ]),
        throwsArgumentError,
      );
      expect(
        () => itemWith(<LearningWidgetAyahLine>[_line(4)]),
        throwsArgumentError,
      );
    },
  );

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

  test('global debt and current-prayer checked state are independent', () {
    final dueButMarked = RotationWidgetItem(
      id: 'marked',
      surahId: '2',
      title: '2. Fixture',
      remaining: 3,
      isMarkedInCurrentPart: true,
      canMark: false,
      disabledReason: 'alreadyMarked',
      deepLink: Uri.parse('murajaah://app/surah/2'),
    );
    final completeButUnmarked = RotationWidgetItem(
      id: 'complete',
      surahId: '3',
      title: '3. Fixture',
      remaining: 0,
      deepLink: Uri.parse('murajaah://app/surah/3'),
    );

    expect(dueButMarked.remaining, 3);
    expect(dueButMarked.isMarkedInCurrentPart, isTrue);
    expect(completeButUnmarked.remaining, 0);
    expect(completeButUnmarked.isMarkedInCurrentPart, isFalse);
  });
}

LearningWidgetAyahLine _line(int ayah) => LearningWidgetAyahLine(
  surahNumber: 112,
  ayahNumber: ayah,
  arabic: 'Arabic $ayah',
);

WidgetSnapshot _snapshot({LearningWidgetAyahLine? line}) => WidgetSnapshot(
  generatedAtUtc: DateTime.utc(2026, 8, 25, 10),
  snapshotRevision: 7,
  locale: 'ru',
  rotation: RotationWidgetProjection(
    currentPartLabel: 'Asr · Fard',
    slotProgressLabel: 'Surahs 1/2',
    contextLabel: 'Аср · Ротация',
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
        action: WidgetRecitationAction(
          actionToken: '00000000-0000-4000-8000-000000000001',
          surahId: '2',
          rotationSchemeId: 'scheme-1',
          partId: 'part-2',
        ),
      ),
    ],
  ),
  learning: LearningWidgetProjection.selected(
    LearningWidgetItem(
      surahId: '112',
      surahNumber: 112,
      startAyah: 1,
      endAyah: 3,
      title: '112. Ихлас',
      stageLabel: 'Накопительно',
      rangeLabel: 'Аяты 1–3',
      unavailableTextLabel: 'Откройте приложение',
      ayahLines: <LearningWidgetAyahLine>[line ?? _line(1)],
      deepLink: Uri.parse('murajaah://app/learning/112'),
    ),
  ),
  prayer: PrayerWidgetProjection.unavailable(messageLabel: 'Open app'),
);
