import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  const service = RecommendationBatchService();

  RecommendationBatchKey keyFor({
    PrayerType prayerType = PrayerType.fajr,
    String? part = 'fard',
    int day = 14,
  }) => RecommendationBatchKey(
    localDate: LocalDate(2026, 9, day),
    prayerType: prayerType,
    isQada: false,
    partStableKey: part,
  );

  List<String> pool(int count) => <String>[
    for (var index = 0; index < count; index += 1) 'surah-$index',
  ];

  group('batch size follows the available pool', () {
    for (final count in <int>[1, 7, 8, 9, 24]) {
      test('$count eligible candidates', () {
        final plan = service.plan(
          key: keyFor(),
          rankedEligibleSurahIds: pool(count),
        );

        expect(plan.batch.entries, hasLength(count < 8 ? count : 8));
        expect(
          plan.batch.entries.map((entry) => entry.occurrence).toSet(),
          <int>{1},
          reason: 'a first cycle never repeats while the pool allows',
        );
        expect(
          plan.batch.surahIds.toSet().length,
          plan.batch.entries.length,
          reason: 'no surah may appear twice in one batch',
        );
      });
    }
  });

  test('the batch keeps the ranked order it was given', () {
    final plan = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(24));

    expect(plan.batch.surahIds.toList(), pool(24).take(8).toList());
  });

  test('an existing batch is reused untouched after a mark', () {
    final first = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(24));

    // The first surah was marked, so it is no longer an eligible candidate.
    final remaining = pool(24).skip(1).toList();
    final second = service.plan(
      key: keyFor(),
      rankedEligibleSurahIds: remaining,
      cycle: first.cycle,
      existing: first.batch,
    );

    expect(
      second.batch,
      first.batch,
      reason: 'marking must not recompute or reorder the visible batch',
    );
    expect(second.batch.entries, hasLength(8));
    expect(
      second.batch.surahIds,
      contains('surah-0'),
      reason: 'a completed surah stays in place instead of disappearing',
    );
  });

  test('marking every entry still leaves the batch intact', () {
    final first = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(24));

    final second = service.plan(
      key: keyFor(),
      rankedEligibleSurahIds: pool(24).skip(8).toList(),
      cycle: first.cycle,
      existing: first.batch,
    );

    expect(second.batch, first.batch);
  });

  test('a new prayer part starts a new batch with unoffered surahs', () {
    final fard = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(24));

    final sunnah = service.plan(
      key: keyFor(part: 'sunnah'),
      rankedEligibleSurahIds: pool(24),
      cycle: fard.cycle,
      existing: fard.batch,
    );

    expect(sunnah.batch.key.partStableKey, 'sunnah');
    expect(
      sunnah.batch.surahIds.toSet().intersection(fard.batch.surahIds.toSet()),
      isEmpty,
      reason: 'different parts get different surahs until the pool runs out',
    );
  });

  test('a different prayer also gets different surahs', () {
    final fajr = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(24));

    final asr = service.plan(
      key: keyFor(prayerType: PrayerType.asr),
      rankedEligibleSurahIds: pool(24),
      cycle: fajr.cycle,
      existing: fajr.batch,
    );

    expect(
      asr.batch.surahIds.toSet().intersection(fajr.batch.surahIds.toSet()),
      isEmpty,
      reason: 'Fajr and Asr must not coincide just because of one global list',
    );
  });

  test('the cycle wraps and marks the topped-up tail as a repeat', () {
    // Nine candidates: the first batch takes eight, one is left for the next.
    final first = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(9));
    expect(first.batch.entries, hasLength(8));

    final second = service.plan(
      key: keyFor(part: 'sunnah'),
      rankedEligibleSurahIds: pool(9),
      cycle: first.cycle,
      existing: first.batch,
    );

    expect(second.batch.entries, hasLength(8));
    expect(
      second.batch.entries.first.surahId,
      'surah-8',
      reason: 'the last unoffered surah is shown before a new round starts',
    );
    expect(second.batch.entries.first.occurrence, 1);
    expect(second.batch.entries.first.isRepeat, isFalse);
    expect(
      second.batch.entries.skip(1).every((entry) => entry.occurrence == 2),
      isTrue,
      reason: 'the new round is honestly marked as a second appearance',
    );
    expect(second.cycle.cycleNumber, 2);
  });

  test('a repeat never duplicates a surah inside one batch', () {
    final first = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(9));
    final second = service.plan(
      key: keyFor(part: 'sunnah'),
      rankedEligibleSurahIds: pool(9),
      cycle: first.cycle,
      existing: first.batch,
    );

    expect(second.batch.surahIds.toSet().length, second.batch.entries.length);
  });

  test('a pool smaller than the batch never invents repeats', () {
    final plan = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(3));

    expect(plan.batch.entries, hasLength(3));
    expect(plan.batch.entries.every((entry) => entry.occurrence == 1), isTrue);
  });

  test('an empty pool yields an empty batch', () {
    final plan = service.plan(
      key: keyFor(),
      rankedEligibleSurahIds: const <String>[],
    );

    expect(plan.batch.isEmpty, isTrue);
  });

  test('a bumped algorithm version rebuilds the batch', () {
    final first = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(24));

    final upgradedKey = RecommendationBatchKey(
      localDate: LocalDate(2026, 9, 14),
      prayerType: PrayerType.fajr,
      isQada: false,
      partStableKey: 'fard',
      algorithmVersion: recommendationBatchAlgorithmVersion + 1,
    );
    final second = service.plan(
      key: upgradedKey,
      rankedEligibleSurahIds: pool(24),
      cycle: first.cycle,
      existing: first.batch,
    );

    expect(second.batch.key, upgradedKey);
    expect(second.batch, isNot(first.batch));
  });

  test('a new day starts a new batch', () {
    final today = service.plan(key: keyFor(), rankedEligibleSurahIds: pool(24));

    final tomorrow = service.plan(
      key: keyFor(day: 15),
      rankedEligibleSurahIds: pool(24),
      cycle: today.cycle,
      existing: today.batch,
    );

    expect(tomorrow.batch.key.localDate, LocalDate(2026, 9, 15));
    expect(tomorrow.batch, isNot(today.batch));
  });

  group('invariants', () {
    test('positions must be contiguous', () {
      expect(
        () => RecommendationBatch(
          key: keyFor(),
          entries: <RecommendationBatchEntry>[
            RecommendationBatchEntry(surahId: 'a', position: 1),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a surah may not appear twice', () {
      expect(
        () => RecommendationBatch(
          key: keyFor(),
          entries: <RecommendationBatchEntry>[
            RecommendationBatchEntry(surahId: 'a', position: 0),
            RecommendationBatchEntry(surahId: 'a', position: 1, occurrence: 2),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a position outside the product ceiling is rejected', () {
      expect(
        () => RecommendationBatchEntry(surahId: 'a', position: 8),
        throwsArgumentError,
      );
    });
  });
}
