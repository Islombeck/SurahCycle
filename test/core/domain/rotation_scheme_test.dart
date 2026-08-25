import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  group('SurahRotationScheme partitions verified ayah metadata', () {
    test('unsplit is one logical part spanning the complete surah', () {
      final scheme = SurahRotationScheme.unsplit(
        id: 's-v1',
        surahId: 's',
        version: 1,
        ayahCount: 20,
        baselineRotationScore: 7,
        baselineTotalRecitations: 4,
      );

      expect(scheme.isSplit, isFalse);
      expect(scheme.parts, hasLength(1));
      expect(scheme.parts.single.partNumber, 1);
      expect(
        scheme.parts.single.ayahRange,
        AyahRange(startAyah: 1, endAyah: 20),
      );
      expect(scheme.effectiveRotationScore, 7);
      expect(scheme.fullEquivalentRecitations, 4);
    });

    test('balanced proposal distributes remainder without empty parts', () {
      expect(suggestEvenRanges(ayahCount: 20, partCount: 4), <AyahRange>[
        AyahRange(startAyah: 1, endAyah: 5),
        AyahRange(startAyah: 6, endAyah: 10),
        AyahRange(startAyah: 11, endAyah: 15),
        AyahRange(startAyah: 16, endAyah: 20),
      ]);
      expect(suggestEvenRanges(ayahCount: 10, partCount: 3), <AyahRange>[
        AyahRange(startAyah: 1, endAyah: 4),
        AyahRange(startAyah: 5, endAyah: 7),
        AyahRange(startAyah: 8, endAyah: 10),
      ]);
      expect(
        () => suggestEvenRanges(ayahCount: 3, partCount: 4),
        throwsArgumentError,
      );
      expect(suggestEvenRanges(ayahCount: 20, partCount: 5), hasLength(5));
      expect(suggestEvenRanges(ayahCount: 20, partCount: 8), hasLength(8));
      expect(suggestEvenRanges(ayahCount: 20, partCount: 10), hasLength(10));
      expect(suggestEvenRanges(ayahCount: 20, partCount: 20), hasLength(20));
      expect(
        suggestEvenRanges(
          ayahCount: 20,
          partCount: 20,
        ).every((range) => range.ayahCount == 1),
        isTrue,
      );
      expect(
        () => suggestEvenRanges(ayahCount: 20, partCount: 0),
        throwsArgumentError,
      );
      expect(
        () => suggestEvenRanges(ayahCount: 20, partCount: 21),
        throwsArgumentError,
      );
    });

    test('manual ranges may differ from the balanced proposal', () {
      final scheme = SurahRotationScheme.fromRanges(
        id: 's-v2',
        surahId: 's',
        version: 2,
        ayahCount: 20,
        ranges: <AyahRange>[
          AyahRange(startAyah: 1, endAyah: 3),
          AyahRange(startAyah: 4, endAyah: 12),
          AyahRange(startAyah: 13, endAyah: 20),
        ],
      );

      expect(scheme.parts.map((part) => part.ayahRange), <AyahRange>[
        AyahRange(startAyah: 1, endAyah: 3),
        AyahRange(startAyah: 4, endAyah: 12),
        AyahRange(startAyah: 13, endAyah: 20),
      ]);
    });

    test('gaps, overlap, incomplete coverage and out-of-range end fail', () {
      SurahRotationScheme build(List<AyahRange> ranges) =>
          SurahRotationScheme.fromRanges(
            id: 'invalid',
            surahId: 's',
            version: 1,
            ayahCount: 10,
            ranges: ranges,
          );

      expect(
        () => build(<AyahRange>[
          AyahRange(startAyah: 1, endAyah: 4),
          AyahRange(startAyah: 6, endAyah: 10),
        ]),
        throwsArgumentError,
      );
      expect(
        () => build(<AyahRange>[
          AyahRange(startAyah: 1, endAyah: 5),
          AyahRange(startAyah: 5, endAyah: 10),
        ]),
        throwsArgumentError,
      );
      expect(
        () => build(<AyahRange>[AyahRange(startAyah: 1, endAyah: 9)]),
        throwsArgumentError,
      );
      expect(
        () => build(<AyahRange>[AyahRange(startAyah: 1, endAyah: 11)]),
        throwsArgumentError,
      );
      expect(
        () => build(<AyahRange>[AyahRange(startAyah: 2, endAyah: 10)]),
        throwsArgumentError,
      );
    });

    test('part IDs, ownership and sequential numbers are validated', () {
      SurahRotationPart part({
        required String id,
        required String schemeId,
        required int number,
        required int start,
        required int end,
      }) => SurahRotationPart(
        id: id,
        schemeId: schemeId,
        partNumber: number,
        ayahRange: AyahRange(startAyah: start, endAyah: end),
      );

      expect(
        () => SurahRotationScheme(
          id: 'scheme',
          surahId: 's',
          version: 1,
          ayahCount: 4,
          parts: <SurahRotationPart>[
            part(id: 'same', schemeId: 'scheme', number: 1, start: 1, end: 2),
            part(id: 'same', schemeId: 'scheme', number: 2, start: 3, end: 4),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => SurahRotationScheme(
          id: 'scheme',
          surahId: 's',
          version: 1,
          ayahCount: 4,
          parts: <SurahRotationPart>[
            part(id: 'p1', schemeId: 'other', number: 1, start: 1, end: 2),
            part(id: 'p2', schemeId: 'scheme', number: 2, start: 3, end: 4),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => SurahRotationScheme(
          id: 'scheme',
          surahId: 's',
          version: 1,
          ayahCount: 4,
          parts: <SurahRotationPart>[
            part(id: 'p1', schemeId: 'scheme', number: 2, start: 1, end: 2),
            part(id: 'p2', schemeId: 'scheme', number: 1, start: 3, end: 4),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  test('effective score and full-equivalent total are independent minima', () {
    final scheme = _statefulScheme(
      scores: const <int>[30, 29, 29, 30],
      counts: const <int>[8, 7, 7, 9],
    );

    expect(scheme.effectiveRotationScore, 29);
    expect(scheme.fullEquivalentRecitations, 7);
    expect(scheme.remainingForPart('scheme:part:2', 30), 1);
    expect(scheme.remainingForPart('scheme:part:1', 30), 0);
  });

  test('ten-part effective state still uses independent minima', () {
    final scheme = _statefulScheme(
      scores: const <int>[30, 30, 29, 30, 31, 30, 30, 30, 30, 30],
      counts: const <int>[8, 8, 8, 8, 8, 7, 8, 9, 8, 8],
    );

    expect(scheme.parts, hasLength(10));
    expect(scheme.effectiveRotationScore, 29);
    expect(scheme.fullEquivalentRecitations, 7);
  });

  test('scheme collections are immutable', () {
    final scheme = SurahRotationScheme.evenlySplit(
      id: 'scheme',
      surahId: 's',
      version: 1,
      ayahCount: 8,
      partCount: 2,
    );

    expect(() => scheme.parts.add(scheme.parts.first), throwsUnsupportedError);
  });
}

SurahRotationScheme _statefulScheme({
  required List<int> scores,
  required List<int> counts,
}) {
  final ranges = suggestEvenRanges(ayahCount: 20, partCount: scores.length);
  return SurahRotationScheme(
    id: 'scheme',
    surahId: 's',
    version: 1,
    ayahCount: 20,
    parts: <SurahRotationPart>[
      for (var index = 0; index < scores.length; index += 1)
        SurahRotationPart(
          id: 'scheme:part:${index + 1}',
          schemeId: 'scheme',
          partNumber: index + 1,
          ayahRange: ranges[index],
          rotationScore: scores[index],
          recitationCount: counts[index],
        ),
    ],
  );
}
