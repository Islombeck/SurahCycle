import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  test(
    'manual widget attribution reads only the persisted manual context',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final prayers = PrayerRepository(database);
      await prayers.saveSelectedContext(
        PrayerContext(prayerType: PrayerType.witr),
        updatedAtUtc: DateTime.utc(2026, 8, 26),
      );
      final cache = _TrackingCache();
      final time = FixedPrayerTimeProvider(DateTime.utc(2026, 8, 25, 13));
      final resolver = CachedRecitationPrayerContextResolver(
        settings: PrayerTimeSettings(
          location: testTashkentLocation(),
          contextSelectionMode: PrayerContextSelectionMode.manual,
        ),
        manualContexts: prayers,
        cache: cache,
        calculator: AdhanPrayerTimeCalculator(timeProvider: time),
        timeProvider: time,
      );

      final details = await resolver.resolveDetails();

      expect(details.context?.prayerType, PrayerType.witr);
      expect(details.isAutomatic, isFalse);
      expect(cache.reads, 0);
      expect(cache.writes, 0);
    },
  );

  test(
    'automatic local fallback is cached by method and Asr settings',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final prayers = PrayerRepository(database);
      final cache = _TrackingCache();
      final time = FixedPrayerTimeProvider(DateTime.utc(2026, 8, 25, 13));

      CachedRecitationPrayerContextResolver create(
        PrayerCalculationMethod method,
      ) => CachedRecitationPrayerContextResolver(
        settings: PrayerTimeSettings(
          location: testTashkentLocation(),
          contextSelectionMode: PrayerContextSelectionMode.automatic,
          calculationSettings: PrayerCalculationSettings(
            method: method,
            asrSchool: PrayerAsrSchool.hanafi,
          ),
          allowCalculatedFallback: true,
        ),
        manualContexts: prayers,
        cache: cache,
        calculator: AdhanPrayerTimeCalculator(timeProvider: time),
        timeProvider: time,
      );

      final karachi = create(PrayerCalculationMethod.karachi);
      final first = await karachi.resolveDetails();
      final writesAfterFirst = cache.writes;
      final second = await karachi.resolveDetails();

      expect(first.isAutomatic, isTrue);
      expect(first.context, isNotNull);
      expect(second.context, first.context);
      expect(writesAfterFirst, 3);
      expect(cache.writes, writesAfterFirst);
      expect(cache.values.keys, everyElement(contains('karachi|hanafi')));

      await create(PrayerCalculationMethod.muslimWorldLeague).resolveDetails();

      expect(cache.writes, 6);
      expect(
        cache.values.keys.any(
          (key) => key.contains('muslimWorldLeague|hanafi'),
        ),
        isTrue,
      );
    },
  );

  test(
    'missing coordinates fail closed instead of breaking widget refresh',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final cache = _TrackingCache();
      final time = FixedPrayerTimeProvider(DateTime.utc(2026, 8, 25, 13));
      final resolver = CachedRecitationPrayerContextResolver(
        settings: PrayerTimeSettings(
          location: UzbekistanPrayerLocations.bySlug('olmazor')!,
          contextSelectionMode: PrayerContextSelectionMode.automatic,
          allowCalculatedFallback: true,
        ),
        manualContexts: PrayerRepository(database),
        cache: cache,
        calculator: AdhanPrayerTimeCalculator(timeProvider: time),
        timeProvider: time,
      );

      final details = await resolver.resolveDetails();

      expect(details.isAutomatic, isTrue);
      expect(details.context, isNull);
      expect(cache.writes, 0);
    },
  );
}

final class _TrackingCache implements PrayerScheduleCacheStore {
  final Map<String, CachedPrayerMonthSchedule> values =
      <String, CachedPrayerMonthSchedule>{};
  int reads = 0;
  int writes = 0;

  @override
  Future<CachedPrayerMonthSchedule?> read(String cacheKey) async {
    reads += 1;
    return values[cacheKey];
  }

  @override
  Future<void> write(CachedPrayerMonthSchedule value) async {
    writes += 1;
    values[value.cacheKey] = value;
  }
}
