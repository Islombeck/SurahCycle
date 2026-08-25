import 'package:flutter_test/flutter_test.dart';

import 'package:murajaah/core/domain/domain.dart';
import 'test_fixtures.dart';

void main() {
  const engine = RotationEngine();

  group('RotationEngine balances immutable snapshots', () {
    test('starts with target one', () {
      final snapshot = RotationSnapshot();

      expect(snapshot.rotationTarget, 1);
    });

    test('several surahs with equal score remain independently counted', () {
      final before = RotationSnapshot(
        rotationTarget: 8,
        surahs: <MasteredSurah>[
          mastered(id: 'a', score: 7),
          mastered(id: 'b', score: 7),
          mastered(id: 'c', score: 7),
        ],
      );

      final after = engine.registerRecitation(before, recitation('e1', 'a'));

      expect(after.surahById('a').rotationScore, 8);
      expect(after.surahById('b').rotationScore, 7);
      expect(after.surahById('c').rotationScore, 7);
      expect(after.rotationTarget, 8);
      expect(before.surahById('a').rotationScore, 7);
    });

    test('remaining exposes one-step debt', () {
      final snapshot = RotationSnapshot(
        rotationTarget: 31,
        surahs: <MasteredSurah>[mastered(id: 'a', score: 30)],
      );

      expect(snapshot.remainingFor('a'), 1);
    });

    test('remaining exposes two-step debt', () {
      final snapshot = RotationSnapshot(
        rotationTarget: 31,
        surahs: <MasteredSurah>[mastered(id: 'a', score: 29)],
      );

      expect(snapshot.remainingFor('a'), 2);
    });

    test('a surah may remain ahead without score normalization', () {
      final snapshot = RotationSnapshot(
        rotationTarget: 31,
        surahs: <MasteredSurah>[
          mastered(id: 'a', score: 32, total: 44),
          mastered(id: 'b', score: 30),
        ],
      );

      expect(snapshot.remainingFor('a'), -1);
      expect(snapshot.surahById('a').totalRecitations, 44);
    });

    test('all active surahs reaching target advances it', () {
      final before = RotationSnapshot(
        rotationTarget: 5,
        surahs: <MasteredSurah>[
          mastered(id: 'a', score: 4),
          mastered(id: 'b', score: 5),
        ],
      );

      final after = engine.registerRecitation(before, recitation('e1', 'a'));

      expect(after.rotationTarget, 6);
      expect(after.surahById('a').rotationScore, 5);
      expect(after.surahById('a').totalRecitations, 1);
    });

    test('target advances at most once for one recitation', () {
      final before = RotationSnapshot(
        rotationTarget: 5,
        surahs: <MasteredSurah>[
          mastered(id: 'a', score: 12),
          mastered(id: 'b', score: 5),
        ],
      );

      final after = engine.registerRecitation(before, recitation('e1', 'b'));

      expect(after.rotationTarget, 6);
    });

    test('an empty active list never advances', () {
      final before = RotationSnapshot(
        rotationTarget: 9,
        surahs: <MasteredSurah>[mastered(id: 'a', score: 20, active: false)],
      );

      final replayed = engine.replay(before, const <SurahRecitationEvent>[]);

      expect(replayed.rotationTarget, 9);
    });

    test('new surah joins a large cycle one step behind with zero history', () {
      final before = RotationSnapshot(
        rotationTarget: 47,
        surahs: <MasteredSurah>[mastered(id: 'a', score: 46, total: 70)],
      );

      final after = engine.addMasteredSurah(
        before,
        testSurah(id: 'new', number: 9),
      );
      final added = after.surahById('new');

      expect(after.rotationTarget, 47);
      expect(added.rotationScore, 46);
      expect(added.totalRecitations, 0);
      expect(added.isActive, isTrue);
      expect(added.hasEnteredRotation, isTrue);
    });

    test(
      'first activation starts target minus one and does not move target',
      () {
        final withInactive = engine.addMasteredSurah(
          RotationSnapshot(rotationTarget: 20),
          testSurah(id: 'a', number: 2),
          activate: false,
        );

        final active = engine.setSurahActive(withInactive, 'a', isActive: true);

        expect(active.rotationTarget, 20);
        expect(active.surahById('a').rotationScore, 19);
        expect(active.surahById('a').totalRecitations, 0);
      },
    );

    test('temporary disable and re-enable preserve score and total', () {
      final before = RotationSnapshot(
        rotationTarget: 10,
        surahs: <MasteredSurah>[
          mastered(id: 'a', score: 12, total: 25),
          mastered(id: 'b', score: 10),
        ],
      );

      final disabled = engine.setSurahActive(before, 'a', isActive: false);
      final enabled = engine.setSurahActive(disabled, 'a', isActive: true);

      expect(disabled.rotationTarget, 10);
      expect(enabled.rotationTarget, 10);
      expect(enabled.surahById('a').rotationScore, 12);
      expect(enabled.surahById('a').totalRecitations, 25);
    });

    test(
      'deactivation does not advance target when remaining active are done',
      () {
        final before = RotationSnapshot(
          rotationTarget: 10,
          surahs: <MasteredSurah>[
            mastered(id: 'lagging', score: 9),
            mastered(id: 'done', score: 10),
          ],
        );

        final after = engine.setSurahActive(before, 'lagging', isActive: false);

        expect(after.rotationTarget, 10);
      },
    );

    test('recitation updates both counters and last-used time', () {
      final at = DateTime.utc(2026, 5, 1, 9);
      final before = RotationSnapshot(
        rotationTarget: 2,
        surahs: <MasteredSurah>[mastered(id: 'a', score: 0, total: 3)],
      );

      final after = engine.registerRecitation(
        before,
        recitation('e1', 'a', at: at),
      );

      final surah = after.surahById('a');
      expect(surah.rotationScore, 1);
      expect(surah.totalRecitations, 4);
      expect(surah.lastUsedAtUtc, at);
    });

    test('inactive surah cannot receive a rotation recitation', () {
      final snapshot = RotationSnapshot(
        surahs: <MasteredSurah>[mastered(id: 'a', score: 0, active: false)],
      );

      expect(
        () => engine.registerRecitation(snapshot, recitation('e1', 'a')),
        throwsStateError,
      );
    });

    test('Al-Fatiha is mastered but cannot enter active rotation', () {
      final descriptor = testSurah(id: 'fatiha', number: 1, ayahCount: 7);
      expect(descriptor.isAlFatiha, isTrue);
      expect(descriptor.isRotationEligible, isFalse);

      final added = engine.addMasteredSurah(
        RotationSnapshot(rotationTarget: 20),
        descriptor,
      );
      expect(added.surahById('fatiha').isActive, isFalse);
      expect(added.surahById('fatiha').hasEnteredRotation, isFalse);
      expect(added.activeSurahs, isEmpty);

      final activationAttempt = engine.setSurahActive(
        added,
        'fatiha',
        isActive: true,
      );
      expect(activationAttempt.surahById('fatiha').isActive, isFalse);
      expect(
        () => engine.registerRecitation(
          activationAttempt,
          recitation('fatiha-event', 'fatiha'),
        ),
        throwsStateError,
      );
    });

    test('snapshot excludes legacy-active Al-Fatiha defensively', () {
      final legacyFatiha = MasteredSurah(
        surah: testSurah(id: 'fatiha', number: 1, ayahCount: 7),
        isActive: true,
        hasEnteredRotation: true,
        rotationScore: 50,
      );
      final eligible = mastered(id: 'eligible', score: 4, number: 2);
      final snapshot = RotationSnapshot(
        rotationTarget: 5,
        surahs: <MasteredSurah>[legacyFatiha, eligible],
      );

      expect(snapshot.activeSurahs.map((surah) => surah.id), <String>[
        'eligible',
      ]);
      final after = engine.registerRecitation(
        snapshot,
        recitation('eligible-event', 'eligible'),
      );
      expect(after.rotationTarget, 6);
      expect(
        () => engine.registerRecitation(
          snapshot,
          recitation('legacy-fatiha-event', 'fatiha'),
        ),
        throwsStateError,
      );
    });
  });

  group('RotationEngine applies versioned part coverage', () {
    test(
      'only selected part receives credit and minimum drives surah score',
      () {
        final before = RotationSnapshot(
          rotationTarget: 30,
          surahs: <MasteredSurah>[
            _splitMastered(scores: const <int>[30, 29, 29, 30]),
          ],
        );

        final afterPart2 = engine.registerRecitation(
          before,
          _coveredRecitation('e2', const <int>[2]),
        );
        final afterPart3 = engine.registerRecitation(
          afterPart2,
          _coveredRecitation('e3', const <int>[3]),
        );

        expect(
          afterPart2
              .surahById('split')
              .rotationScheme
              .parts
              .map((part) => part.rotationScore),
          <int>[30, 30, 29, 30],
        );
        expect(afterPart2.surahById('split').rotationScore, 29);
        expect(afterPart2.rotationTarget, 30);
        expect(
          afterPart3
              .surahById('split')
              .rotationScheme
              .parts
              .map((part) => part.rotationScore),
          <int>[30, 30, 30, 30],
        );
        expect(afterPart3.surahById('split').rotationScore, 30);
        expect(afterPart3.rotationTarget, 31);
      },
    );

    test('one action can atomically cover several or every part', () {
      final before = RotationSnapshot(
        rotationTarget: 10,
        surahs: <MasteredSurah>[
          _splitMastered(
            scores: const <int>[9, 9, 9, 9],
            counts: const <int>[7, 7, 7, 7],
          ),
        ],
      );
      final partial = engine.registerRecitation(
        before,
        _coveredRecitation('multi', const <int>[1, 2], rakaats: 2),
      );
      final whole = engine.registerRecitation(
        partial,
        _coveredRecitation('whole', const <int>[1, 2, 3, 4], rakaats: 3),
      );

      expect(
        partial
            .surahById('split')
            .rotationScheme
            .parts
            .map((part) => part.recitationCount),
        <int>[8, 8, 7, 7],
      );
      expect(partial.surahById('split').totalRecitations, 7);
      expect(
        whole
            .surahById('split')
            .rotationScheme
            .parts
            .map((part) => part.recitationCount),
        <int>[9, 9, 8, 8],
      );
      expect(whole.surahById('split').totalRecitations, 8);
    });

    test('legacy coverage resolves to every current part', () {
      final before = RotationSnapshot(
        rotationTarget: 5,
        surahs: <MasteredSurah>[
          _splitMastered(scores: const <int>[4, 4, 4, 4]),
        ],
      );

      final after = engine.registerRecitation(
        before,
        recitation('legacy-whole', 'split'),
      );

      expect(
        after
            .surahById('split')
            .rotationScheme
            .parts
            .map((part) => part.rotationScore),
        everyElement(5),
      );
      expect(after.rotationTarget, 6);
    });

    test('empty, foreign, and stale coverage cannot receive credit', () {
      final before = RotationSnapshot(
        surahs: <MasteredSurah>[
          _splitMastered(scores: const <int>[0, 0, 0, 0]),
        ],
      );

      expect(
        () => RecitationCoverage(
          rotationSchemeId: 'scheme-v1',
          coveredPartIds: const <String>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => engine.registerRecitation(
          before,
          _coveredRecitation(
            'foreign',
            const <int>[1],
            partIds: const <String>['other-part'],
          ),
        ),
        throwsStateError,
      );
      expect(
        () => engine.registerRecitation(
          before,
          SurahRecitationEvent(
            id: 'stale',
            surahId: 'split',
            prayerContext: PrayerContext(prayerType: PrayerType.asr),
            createdAtUtc: DateTime.utc(2026),
            localDate: LocalDate(2026, 1, 1),
            rotationSchemeId: 'old-scheme',
            coveredPartIds: const <String>['old-part'],
          ),
        ),
        throwsStateError,
      );
    });

    test('adjustment shifts every part equally and never changes total', () {
      final before = RotationSnapshot(
        rotationTarget: 30,
        surahs: <MasteredSurah>[
          _splitMastered(
            scores: const <int>[30, 29, 29, 30],
            counts: const <int>[8, 7, 7, 9],
          ),
        ],
      );
      final after = engine.applyAdjustment(
        before,
        RotationAdjustmentEvent(
          id: 'adjust',
          surahId: 'split',
          delta: 2,
          reason: 'Confirmed correction',
          createdAtUtc: DateTime.utc(2026),
          rotationSchemeId: 'scheme-v1',
        ),
      );

      expect(
        after
            .surahById('split')
            .rotationScheme
            .parts
            .map((part) => part.rotationScore),
        <int>[32, 31, 31, 32],
      );
      expect(after.surahById('split').rotationScore, 31);
      expect(after.surahById('split').totalRecitations, 7);
      expect(after.rotationTarget, 30);
      expect(
        () => engine.applyAdjustment(
          before,
          RotationAdjustmentEvent(
            id: 'bad',
            surahId: 'split',
            delta: -30,
            reason: 'Too large',
            createdAtUtc: DateTime.utc(2026),
          ),
        ),
        throwsStateError,
      );
    });

    test('scheme change rebases all new parts and leaves old value intact', () {
      final oldMastered = mastered(id: 'split', score: 12, total: 8);
      final before = RotationSnapshot(
        rotationTarget: 15,
        surahs: <MasteredSurah>[oldMastered],
      );
      final proposed = SurahRotationScheme.evenlySplit(
        id: 'scheme-v2',
        surahId: 'split',
        version: 2,
        ayahCount: oldMastered.surah.ayahCount,
        partCount: 3,
      );

      final after = engine.changeRotationScheme(
        before,
        RotationSchemeChangedEvent(
          id: 'change-v2',
          surahId: 'split',
          scheme: proposed,
          createdAtUtc: DateTime.utc(2026),
        ),
      );

      expect(before.surahById('split').rotationScheme.version, 1);
      expect(before.surahById('split').rotationScore, 12);
      expect(after.surahById('split').rotationScheme.id, 'scheme-v2');
      expect(after.surahById('split').rotationScheme.version, 2);
      expect(
        after
            .surahById('split')
            .rotationScheme
            .parts
            .map((part) => part.rotationScore),
        everyElement(12),
      );
      expect(
        after
            .surahById('split')
            .rotationScheme
            .parts
            .map((part) => part.recitationCount),
        everyElement(8),
      );
      expect(after.rotationTarget, 15);
    });
  });
}

MasteredSurah _splitMastered({required List<int> scores, List<int>? counts}) {
  final resolvedCounts = counts ?? List<int>.filled(scores.length, 0);
  final ranges = suggestEvenRanges(ayahCount: 20, partCount: scores.length);
  final scheme = SurahRotationScheme(
    id: 'scheme-v1',
    surahId: 'split',
    version: 1,
    ayahCount: 20,
    parts: <SurahRotationPart>[
      for (var index = 0; index < scores.length; index += 1)
        SurahRotationPart(
          id: 'scheme-v1:part:${index + 1}',
          schemeId: 'scheme-v1',
          partNumber: index + 1,
          ayahRange: ranges[index],
          rotationScore: scores[index],
          recitationCount: resolvedCounts[index],
        ),
    ],
  );
  return MasteredSurah(
    surah: testSurah(id: 'split', number: 2, ayahCount: 20),
    isActive: true,
    hasEnteredRotation: true,
    rotationScheme: scheme,
  );
}

SurahRecitationEvent _coveredRecitation(
  String id,
  List<int> partNumbers, {
  int rakaats = 1,
  List<String>? partIds,
}) => SurahRecitationEvent(
  id: id,
  surahId: 'split',
  prayerContext: PrayerContext(prayerType: PrayerType.asr),
  createdAtUtc: DateTime.utc(2026),
  localDate: LocalDate(2026, 1, 1),
  rotationSchemeId: 'scheme-v1',
  coveredPartIds:
      partIds ?? partNumbers.map((number) => 'scheme-v1:part:$number').toList(),
  rakaatSpanCount: rakaats,
);
