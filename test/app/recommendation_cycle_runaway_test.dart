import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Found by reading the owner's own database on 2026-09-16:
/// `recommendationBatch.cycle.cycleNumber` had reached **5392**. A cycle is one
/// pass over the eligible pool; with 27 mastered surahs and eight per batch a
/// pass is about four batches, so that counter implies tens of thousands of
/// re-plans against 638 recitations.
///
/// The structural hazard is visible in the code: planning saves into
/// `app_settings`, and the planner subscribes to `app_settings`. A save feeds
/// its own watch. That is harmless while the stored batch matches the key
/// being planned — the plan is then returned untouched — and is a loop as soon
/// as two different keys are live against the one stored slot.
void main() {
  late AppDatabase database;

  final localDate = LocalDate(2026, 9, 16);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        for (var index = 0; index < 12; index += 1)
          SurahDescriptor(
            id: 'surah-$index',
            surahNumber: 100 + index,
            officialName: 'Test Surah $index',
            ayahCount: 3,
          ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    for (var index = 0; index < 12; index += 1) {
      await surahs.addMastered('surah-$index');
    }
  });

  tearDown(() => database.close());

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        startupProvider.overrideWith((ref) async {}),
        timeProviderProvider.overrideWithValue(
          _FixedTimeProvider(DateTime.utc(2026, 9, 16, 9)),
        ),
        localDateProvider.overrideWithValue(_FixedLocalDateProvider(localDate)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle(int turns) async {
    for (var index = 0; index < turns; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<int> storedCycleNumber(ProviderContainer container) async =>
      (await container.read(recommendationBatchRepositoryProvider).load())
          .cycle
          .cycleNumber;

  test('one live context settles on a single plan', () async {
    final container = buildContainer();
    final subscription = container.listen(
      currentRecommendationBatchProvider((
        context: PrayerContext(prayerType: PrayerType.dhuhr),
        localDate: localDate,
      )),
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await settle(200);

    expect(
      await storedCycleNumber(container),
      lessThanOrEqualTo(2),
      reason:
          'planning writes into the table it watches, so a single context '
          'must reach a fixed point instead of re-planning forever',
    );
  });

  test('two live contexts do not fight over the one stored slot', () async {
    final container = buildContainer();
    // Exactly the shape the owner's device was in: a context change leaves the
    // previous family instance alive for a while, and both write to the same
    // stored batch.
    for (final prayerType in <PrayerType>[PrayerType.dhuhr, PrayerType.asr]) {
      final subscription = container.listen(
        currentRecommendationBatchProvider((
          context: PrayerContext(prayerType: prayerType),
          localDate: localDate,
        )),
        (previous, next) {},
      );
      addTearDown(subscription.close);
    }
    await settle(400);

    final first = await storedCycleNumber(container);
    await settle(400);
    final second = await storedCycleNumber(container);

    expect(
      second,
      first,
      reason:
          'the cycle counter must stop moving once nothing changes; a '
          'counter that keeps climbing is the batch being re-planned in a '
          'loop, which is what reached 5392 on the real device',
    );
  });
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this.value);

  final LocalDate value;

  @override
  LocalDate today() => value;
}
