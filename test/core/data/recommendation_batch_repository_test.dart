import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  late AppDatabase database;
  late RecommendationBatchRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = RecommendationBatchRepository(AppSettingsRepository(database));
  });

  tearDown(() => database.close());

  RecommendationBatch batchOf(List<String> ids, {String? part = 'fard'}) =>
      RecommendationBatch(
        key: RecommendationBatchKey(
          localDate: LocalDate(2026, 9, 14),
          prayerType: PrayerType.fajr,
          isQada: false,
          partStableKey: part,
        ),
        entries: <RecommendationBatchEntry>[
          for (var index = 0; index < ids.length; index += 1)
            RecommendationBatchEntry(surahId: ids[index], position: index),
        ],
      );

  test('a saved batch round-trips exactly', () async {
    final state = StoredRecommendationState(
      batch: batchOf(<String>['a', 'b', 'c']),
      cycle: RecommendationCycleState(
        offeredSurahIds: <String>['a', 'b', 'c'],
        cycleNumber: 2,
      ),
    );

    await repository.save(state, updatedAtUtc: DateTime.utc(2026, 9, 14));
    final loaded = await repository.load();

    expect(loaded.batch, state.batch);
    expect(loaded.cycle, state.cycle);
  });

  test('a repeat occurrence survives the round trip', () async {
    final batch = RecommendationBatch(
      key: RecommendationBatchKey(
        localDate: LocalDate(2026, 9, 14),
        prayerType: PrayerType.isha,
        isQada: false,
      ),
      entries: <RecommendationBatchEntry>[
        RecommendationBatchEntry(surahId: 'a', position: 0),
        RecommendationBatchEntry(surahId: 'b', position: 1, occurrence: 2),
      ],
    );

    await repository.save(
      StoredRecommendationState(
        batch: batch,
        cycle: RecommendationCycleState.empty,
      ),
      updatedAtUtc: DateTime.utc(2026, 9, 14),
    );
    final loaded = await repository.load();

    expect(loaded.batch!.entries[1].occurrence, 2);
    expect(loaded.batch!.entries[1].isRepeat, isTrue);
    expect(loaded.batch!.key.partStableKey, isNull);
  });

  test('nothing stored yields an empty cycle and no batch', () async {
    final loaded = await repository.load();

    expect(loaded.batch, isNull);
    expect(loaded.cycle, RecommendationCycleState.empty);
  });

  group('unreadable state is rebuilt, never guessed at', () {
    for (final raw in <String>[
      '',
      'not json at all',
      '[]',
      '{"schemaVersion": 99, "batch": {}}',
    ]) {
      test('"${raw.isEmpty ? '<empty>' : raw}" decodes as absent', () {
        final decoded = RecommendationBatchRepository.decode(raw);

        expect(decoded.batch, isNull);
        expect(decoded.cycle, RecommendationCycleState.empty);
      });
    }

    test('a malformed entry drops the batch but keeps the cycle', () {
      final decoded = RecommendationBatchRepository.decode(
        jsonEncode(<String, Object?>{
          'schemaVersion': RecommendationBatchRepository.schemaVersion,
          'cycle': <String, Object?>{
            'cycleNumber': 3,
            'offeredSurahIds': <String>['a'],
          },
          'batch': <String, Object?>{
            'localDate': '2026-09-14',
            'prayerType': 'fajr',
            'isQada': false,
            'algorithmVersion': 1,
            'entries': <Object>[
              <String, Object?>{'surahId': 'a', 'position': 'nope'},
            ],
          },
        }),
      );

      expect(decoded.batch, isNull);
      expect(decoded.cycle.cycleNumber, 3);
      expect(decoded.cycle.offeredSurahIds, <String>{'a'});
    });

    test('an unknown prayer type drops the batch', () {
      final decoded = RecommendationBatchRepository.decode(
        jsonEncode(<String, Object?>{
          'schemaVersion': RecommendationBatchRepository.schemaVersion,
          'cycle': <String, Object?>{
            'cycleNumber': 1,
            'offeredSurahIds': <String>[],
          },
          'batch': <String, Object?>{
            'localDate': '2026-09-14',
            'prayerType': 'tahajjud',
            'isQada': false,
            'algorithmVersion': 1,
            'entries': <Object>[],
          },
        }),
      );

      expect(decoded.batch, isNull);
    });

    test('an invalid stored date drops the batch', () {
      final decoded = RecommendationBatchRepository.decode(
        jsonEncode(<String, Object?>{
          'schemaVersion': RecommendationBatchRepository.schemaVersion,
          'cycle': <String, Object?>{
            'cycleNumber': 1,
            'offeredSurahIds': <String>[],
          },
          'batch': <String, Object?>{
            'localDate': '2026-02-31',
            'prayerType': 'fajr',
            'isQada': false,
            'algorithmVersion': 1,
            'entries': <Object>[],
          },
        }),
      );

      expect(decoded.batch, isNull);
    });
  });

  test('the batch and its order survive a simulated process death', () async {
    final saved = batchOf(<String>['x', 'y', 'z']);
    await repository.save(
      StoredRecommendationState(
        batch: saved,
        cycle: RecommendationCycleState(offeredSurahIds: <String>['x']),
      ),
      updatedAtUtc: DateTime.utc(2026, 9, 14),
    );

    // A fresh repository over the same storage is what a restart looks like.
    final reopened = RecommendationBatchRepository(
      AppSettingsRepository(database),
    );
    final loaded = await reopened.load();

    expect(loaded.batch!.surahIds.toList(), <String>['x', 'y', 'z']);
  });

  test('watch emits the stored state', () async {
    final seen = <StoredRecommendationState>[];
    final subscription = repository.watch().listen(seen.add);
    await pumpEventQueue();

    await repository.save(
      StoredRecommendationState(
        batch: batchOf(<String>['a']),
        cycle: RecommendationCycleState.empty,
      ),
      updatedAtUtc: DateTime.utc(2026, 9, 14),
    );
    await pumpEventQueue();

    expect(seen.last.batch!.surahIds, <String>['a']);
    await subscription.cancel();
  });
}
