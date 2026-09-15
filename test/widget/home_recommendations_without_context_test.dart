import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/home/presentation/widgets/recommendation_rank_badge.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Between prayers there is no resolved context, so there is no stable batch
/// to keep — but the recommendations themselves must not disappear. This was
/// found on a real device during the sunrise gap.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    quranCacheDatabase = QuranCacheDatabase(NativeDatabase.memory());
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        for (var index = 0; index < 3; index += 1)
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
    for (var index = 0; index < 3; index += 1) {
      await surahs.addMastered('surah-$index');
    }
  });

  tearDown(() async {
    await database.close();
    await quranCacheDatabase.close();
  });

  testWidgets('recommendations stay visible with no prayer context', (
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
            _FixedTimeProvider(DateTime.utc(2026, 9, 15, 4)),
          ),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 9, 15)),
          ),
          // The sunrise gap: a resolution with no context at all.
          prayerContextResolutionProvider.overrideWith(
            (ref) => Stream<PrayerContextResolution>.value(
              const PrayerContextResolution(
                status: PrayerContextResolutionStatus.betweenPrayers,
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

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(RecommendationRankBadge).evaluate().isNotEmpty) break;
    }

    expect(
      find.byType(RecommendationRankBadge),
      findsWidgets,
      reason: 'the ranked list must survive the gap between prayers',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    for (var index = 0; index < 5; index += 1) {
      await tester.pump(const Duration(milliseconds: 1));
    }
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
