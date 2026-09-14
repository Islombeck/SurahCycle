import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// The batch must stay put while surahs in it are marked, and must still be
/// there after the process dies. Both are asserted against real storage.
void main() {
  late AppDatabase database;

  final key = (context: _fajr, localDate: _today);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        for (var index = 0; index < 10; index += 1)
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
    for (var index = 0; index < 10; index += 1) {
      await surahs.addMastered('surah-$index');
    }
  });

  tearDown(() => database.close());

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        timeProviderProvider.overrideWithValue(
          _FixedTimeProvider(DateTime.utc(2026, 9, 14, 9)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<RecommendationBatch?> readBatch(ProviderContainer container) async {
    // The batch provider needs a resolved rotation snapshot before its first
    // build, otherwise it correctly answers "nothing to recommend yet".
    await container.read(rotationSnapshotProvider.future);
    final provider = currentRecommendationBatchProvider(key);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    await pumpEventQueue();
    return container.read(provider).valueOrNull;
  }

  test('a batch of eight is produced and then persisted', () async {
    final container = newContainer();

    final batch = await readBatch(container);

    expect(batch, isNotNull);
    expect(batch!.entries, hasLength(8));
    expect(batch.key.prayerType, PrayerType.fajr);
    expect(batch.key.localDate, _today);

    final stored = await RecommendationBatchRepository(
      AppSettingsRepository(database),
    ).load();
    expect(
      stored.batch,
      batch,
      reason: 'the visible batch is the one that was written down',
    );
    expect(stored.cycle.offeredSurahIds, hasLength(8));
  });

  test('reading it again returns the identical batch', () async {
    final container = newContainer();

    final first = await readBatch(container);
    final second = await readBatch(container);

    expect(second, first);
  });

  test('the batch survives a restart with the same order', () async {
    final first = await readBatch(newContainer());

    // A brand new container over the same storage is what a restart and a
    // process death look like from the app's point of view.
    final afterRestart = await readBatch(newContainer());

    expect(afterRestart, first);
    expect(
      afterRestart!.surahIds.toList(),
      first!.surahIds.toList(),
      reason: 'the order must not be reshuffled on restart',
    );
  });

  test('a surah leaving the eligible pool does not shrink the batch', () async {
    final container = newContainer();
    final first = await readBatch(container);
    final markedId = first!.entries.first.surahId;

    // Deactivating a surah removes it from the eligible pool exactly the way
    // marking it does: it stops being due.
    await SurahRepository(database).setActive(markedId, isActive: false);
    await pumpEventQueue();

    final second = await readBatch(newContainer());

    expect(second!.entries, hasLength(8));
    expect(
      second.surahIds,
      contains(markedId),
      reason: 'a completed surah keeps its position instead of vanishing',
    );
    expect(second, first);
  });
}

final _fajr = PrayerContext(prayerType: PrayerType.fajr);
final _today = LocalDate(2026, 9, 14);

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
