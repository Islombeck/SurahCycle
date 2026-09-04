import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  group('PrayerContextResolver automatic boundaries', () {
    for (final scenario
        in <
          ({
            String name,
            int hour,
            int minute,
            int second,
            PrayerContextResolutionStatus status,
            PrayerType? prayer,
            PrayerType? next,
          })
        >[
          (
            name: 'one second before Fajr without previous day',
            hour: 4,
            minute: 16,
            second: 59,
            status: PrayerContextResolutionStatus.betweenPrayers,
            prayer: null,
            next: PrayerType.fajr,
          ),
          (
            name: 'exactly Fajr',
            hour: 4,
            minute: 17,
            second: 0,
            status: PrayerContextResolutionStatus.automatic,
            prayer: PrayerType.fajr,
            next: PrayerType.dhuhr,
          ),
          (
            name: 'one second before sunrise',
            hour: 5,
            minute: 41,
            second: 59,
            status: PrayerContextResolutionStatus.automatic,
            prayer: PrayerType.fajr,
            next: PrayerType.dhuhr,
          ),
          (
            name: 'exact sunrise is a safe gap',
            hour: 5,
            minute: 42,
            second: 0,
            status: PrayerContextResolutionStatus.betweenPrayers,
            prayer: null,
            next: PrayerType.dhuhr,
          ),
          (
            name: 'one second before Dhuhr remains a gap',
            hour: 12,
            minute: 24,
            second: 59,
            status: PrayerContextResolutionStatus.betweenPrayers,
            prayer: null,
            next: PrayerType.dhuhr,
          ),
          (
            name: 'exactly Dhuhr',
            hour: 12,
            minute: 25,
            second: 0,
            status: PrayerContextResolutionStatus.automatic,
            prayer: PrayerType.dhuhr,
            next: PrayerType.asr,
          ),
          (
            name: 'exactly Asr',
            hour: 17,
            minute: 9,
            second: 0,
            status: PrayerContextResolutionStatus.automatic,
            prayer: PrayerType.asr,
            next: PrayerType.maghrib,
          ),
          (
            name: 'exactly Maghrib',
            hour: 19,
            minute: 11,
            second: 0,
            status: PrayerContextResolutionStatus.automatic,
            prayer: PrayerType.maghrib,
            next: PrayerType.isha,
          ),
          (
            name: 'exactly Isha',
            hour: 20,
            minute: 32,
            second: 0,
            status: PrayerContextResolutionStatus.automatic,
            prayer: PrayerType.isha,
            next: null,
          ),
          (
            name: 'after Isha',
            hour: 23,
            minute: 0,
            second: 0,
            status: PrayerContextResolutionStatus.automatic,
            prayer: PrayerType.isha,
            next: null,
          ),
        ]) {
      test(scenario.name, () {
        final resolver = PrayerContextResolver(
          FixedPrayerTimeProvider(
            _utcForTashkent(
              2026,
              8,
              25,
              scenario.hour,
              scenario.minute,
              scenario.second,
            ),
          ),
        );

        final result = resolver.resolve(
          mode: PrayerContextSelectionMode.automatic,
          automaticSchedule: testPrayerDay(25),
          automaticScheduleIsReliable: true,
        );

        expect(result.status, scenario.status);
        expect(result.context?.prayerType, scenario.prayer);
        expect(result.nextPrayerType, scenario.next);
        expect(result.canMarkDirectly, scenario.prayer != null);
      });
    }

    test('before Fajr is previous Isha only with a reliable adjacent day', () {
      final resolver = PrayerContextResolver(
        FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 25, 3, 0, 0)),
      );

      final reliable = resolver.resolve(
        mode: PrayerContextSelectionMode.automatic,
        automaticSchedule: testPrayerDay(25),
        automaticScheduleIsReliable: true,
        previousDaySchedule: testPrayerDay(24),
        previousDayScheduleIsReliable: true,
      );
      final wrongDate = resolver.resolve(
        mode: PrayerContextSelectionMode.automatic,
        automaticSchedule: testPrayerDay(25),
        automaticScheduleIsReliable: true,
        previousDaySchedule: testPrayerDay(23),
        previousDayScheduleIsReliable: true,
      );

      expect(reliable.context?.prayerType, PrayerType.isha);
      expect(reliable.nextPrayerType, PrayerType.fajr);
      expect(reliable.currentStartsAt, PrayerClockTime(20, 32));
      expect(reliable.currentEndsAt, PrayerClockTime(4, 17));
      expect(wrongDate.status, PrayerContextResolutionStatus.betweenPrayers);
      expect(wrongDate.context, isNull);
    });

    test('after Isha exposes next Fajr only from a reliable adjacent day', () {
      final resolver = PrayerContextResolver(
        FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 25, 21, 0, 0)),
      );

      final result = resolver.resolve(
        mode: PrayerContextSelectionMode.automatic,
        automaticSchedule: testPrayerDay(25),
        automaticScheduleIsReliable: true,
        nextDaySchedule: testPrayerDay(26),
        nextDayScheduleIsReliable: true,
      );

      expect(result.context?.prayerType, PrayerType.isha);
      expect(result.nextPrayerType, PrayerType.fajr);
      expect(result.nextPrayerAt, PrayerClockTime(4, 17));
      expect(result.currentEndsAt, PrayerClockTime(4, 17));
    });

    test('Friday Dhuhr stays Dhuhr and never becomes automatic Jumuah', () {
      final result =
          PrayerContextResolver(
            FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 28, 12, 25, 0)),
          ).resolve(
            mode: PrayerContextSelectionMode.automatic,
            automaticSchedule: testPrayerDay(28),
            automaticScheduleIsReliable: true,
          );

      expect(result.status, PrayerContextResolutionStatus.automatic);
      expect(result.context?.prayerType, PrayerType.dhuhr);
      expect(result.nextPrayerType, PrayerType.asr);
    });

    test('rejects a schedule for another local calendar date', () {
      final resolver = PrayerContextResolver(
        FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 26, 12, 30, 0)),
      );

      final result = resolver.resolve(
        mode: PrayerContextSelectionMode.automatic,
        automaticSchedule: testPrayerDay(25),
        automaticScheduleIsReliable: true,
      );

      expect(result.status, PrayerContextResolutionStatus.scheduleDateMismatch);
      expect(result.context, isNull);
    });
  });

  test('manual mode keeps Witr, Nafl, and Qada explicitly manual', () {
    for (final manual in <PrayerContext>[
      PrayerContext(prayerType: PrayerType.jumuah),
      PrayerContext(prayerType: PrayerType.witr),
      PrayerContext(prayerType: PrayerType.nafl),
      PrayerContext(prayerType: PrayerType.fajr, isQada: true),
    ]) {
      final result = PrayerContextResolver(
        FixedPrayerTimeProvider(DateTime.utc(2026, 8, 25)),
      ).resolve(mode: PrayerContextSelectionMode.manual, manualContext: manual);
      expect(result.status, PrayerContextResolutionStatus.manual);
      expect(result.context, manual);
    }
  });

  group('PrayerExecutionTimeResolver', () {
    test('manual mode requires no schedule cache', () {
      final manual = PrayerContext(prayerType: PrayerType.witr);
      final settings = PrayerTimeSettings(
        location: testTashkentLocation(),
        contextSelectionMode: PrayerContextSelectionMode.manual,
      );

      final result = PrayerExecutionTimeResolver(
        timeProvider: FixedPrayerTimeProvider(DateTime.utc(2026, 8, 25)),
      ).resolve(settings: settings, manualContext: manual);

      expect(result.context, manual);
    });

    test('automatic mode never guesses with missing or stale cache', () {
      final now = _utcForTashkent(2026, 8, 25, 17, 9, 0);
      final settings = PrayerTimeSettings(
        location: testTashkentLocation(),
        locationConfirmed: true,
        contextSelectionMode: PrayerContextSelectionMode.automatic,
      );
      final resolver = PrayerExecutionTimeResolver(
        timeProvider: FixedPrayerTimeProvider(now),
      );
      final staleMonth = testPrayerMonth(
        fetchedAtUtc: DateTime.utc(2026, 6, 1),
      );

      expect(
        resolver.resolve(settings: settings).status,
        PrayerContextResolutionStatus.missingSchedule,
      );
      expect(
        resolver
            .resolve(
              settings: settings,
              currentMonth: CachedPrayerMonthSchedule(
                cacheKey: 'stale',
                schedule: staleMonth,
                cachedAtUtc: DateTime.utc(2026, 6, 1),
              ),
            )
            .status,
        PrayerContextResolutionStatus.unreliableSchedule,
      );
    });

    test('resolves at tap time and applies explicit minute adjustments', () {
      final now = _utcForTashkent(2026, 8, 25, 17, 9, 0);
      final fetched = DateTime.utc(2026, 8, 25);
      final current = CachedPrayerMonthSchedule(
        cacheKey: 'fresh',
        schedule: testPrayerMonth(fetchedAtUtc: fetched),
        cachedAtUtc: fetched,
      );
      final settings = PrayerTimeSettings(
        location: testTashkentLocation(),
        locationConfirmed: true,
        contextSelectionMode: PrayerContextSelectionMode.automatic,
        adjustments: PrayerTimeAdjustments(asrMinutes: 1),
      );

      final result = PrayerExecutionTimeResolver(
        timeProvider: FixedPrayerTimeProvider(now),
      ).resolve(settings: settings, currentMonth: current);

      expect(result.context?.prayerType, PrayerType.dhuhr);
      expect(result.nextPrayerType, PrayerType.asr);
      expect(result.nextPrayerAt, PrayerClockTime(17, 10));
    });
  });
}

DateTime _utcForTashkent(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
) => DateTime.utc(
  year,
  month,
  day,
  hour,
  minute,
  second,
).subtract(const Duration(hours: 5));
