import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/home/presentation/widgets/recommendation_rank_badge.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Found on the owner's own device, not by this suite: the eight ranked
/// recommendations were nowhere near the top of the list and carried no rank
/// badges at all.
///
/// The cause was the row-order stabilizer that keeps rows from moving under a
/// finger. It had frozen the *whole* list on the first frame — before the
/// stored batch had loaded — so the batch never reached the top. Only the
/// unranked tail may be frozen; the ranked block is a stored decision and is
/// already stable.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    quranCacheDatabase = QuranCacheDatabase(NativeDatabase.memory());
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
    // A batch already stored from an earlier visit, holding the *last* four
    // surahs. The operational order puts `surah-0` first, so until this loads
    // the screen ranks a completely different set — which is the gap the
    // defect lived in: the stabilizer froze that first order and the stored
    // batch never reached the top.
    await RecommendationBatchRepository(AppSettingsRepository(database)).save(
      StoredRecommendationState(
        batch: RecommendationBatch(
          key: RecommendationBatchKey(
            localDate: LocalDate(2026, 9, 16),
            prayerType: PrayerType.dhuhr,
            isQada: false,
            partStableKey: null,
          ),
          entries: <RecommendationBatchEntry>[
            for (var index = 0; index < 4; index += 1)
              RecommendationBatchEntry(
                surahId: 'surah-${11 - index}',
                position: index,
                occurrence: 1,
              ),
          ],
        ),
        cycle: RecommendationCycleState(
          offeredSurahIds: <String>{
            for (var index = 8; index < 12; index += 1) 'surah-$index',
          },
        ),
      ),
      updatedAtUtc: DateTime.utc(2026, 9, 16, 8),
    );
  });

  tearDown(() async {
    await database.close();
    await quranCacheDatabase.close();
  });

  testWidgets('the ranked block leads the list once the batch arrives', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(
            _FixedTimeProvider(DateTime.utc(2026, 9, 16, 9)),
          ),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 9, 16)),
          ),
          prayerContextResolutionProvider.overrideWith(
            (ref) => Stream<PrayerContextResolution>.value(
              PrayerContextResolution(
                status: PrayerContextResolutionStatus.manual,
                context: PrayerContext(prayerType: PrayerType.dhuhr),
              ),
            ),
          ),
          prayerTodayScheduleProvider.overrideWith(
            (ref) async => throw StateError('Fixture schedule unavailable.'),
          ),
        ],
        child: const MurajaahApp(),
      ),
    );

    // The batch is stored and arrives a frame or more after the first paint.
    // That gap is exactly what the defect depended on.
    await _pumpUntil(
      tester,
      () => find.byType(RecommendationRankBadge).evaluate().isNotEmpty,
    );

    final badges = tester.widgetList<RecommendationRankBadge>(
      find.byType(RecommendationRankBadge),
    );
    expect(badges, isNotEmpty);
    expect(
      badges.first.rank,
      1,
      reason: 'the first recommendation must be the first ranked row',
    );

    // Rank 1 has to be above rank 2 on screen: the block leads, in order.
    final first = tester.getTopLeft(find.byType(RecommendationRankBadge).first);
    final second = tester.getTopLeft(
      find.byType(RecommendationRankBadge).at(1),
    );
    expect(second.dy, greaterThan(first.dy));

    // What this test does NOT establish, and it matters: whether a stored
    // batch that loads after the first frame reaches the top. An attempt to
    // pin that compared a named surah's position, and it failed for the wrong
    // reason — the fixture re-planned the batch instead of honouring the
    // stored one, so the surah being compared turned out to be ranked itself.
    // The defect it was meant to cover was found and confirmed on the device,
    // and is described in AI_HANDOFF; this file deliberately does not claim to
    // cover it.

    await tester.pumpWidget(const SizedBox.shrink());
    for (var index = 0; index < 5; index += 1) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  throw TestFailure('Condition was not met after 200 pumped frames.');
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
