import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  group('manual historical shortcuts', () {
    final resolver = PrayerRegistrationShortcutResolver(
      FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 26, 8, 0, 0)),
    );

    test('yesterday supports both Witr and non-Qada Fajr', () {
      final witr = resolver.resolveYesterday(
        prayerContext: PrayerContext(prayerType: PrayerType.witr),
        utcOffsetMinutes: 300,
      );
      final fajr = resolver.resolveYesterday(
        prayerContext: PrayerContext(prayerType: PrayerType.fajr),
        utcOffsetMinutes: 300,
      );

      expect(witr.status, PrayerRegistrationShortcutStatus.resolved);
      expect(witr.selection!.occurrenceLocalDate, LocalDate(2026, 8, 25));
      expect(witr.selection!.prayerContext.prayerType, PrayerType.witr);
      expect(witr.selection!.prayerContext.isQada, isFalse);
      expect(fajr.selection!.occurrenceLocalDate, LocalDate(2026, 8, 25));
      expect(fajr.selection!.prayerContext.prayerType, PrayerType.fajr);
      expect(fajr.selection!.prayerContext.isQada, isFalse);
    });

    test('custom date preserves an explicit Qada choice', () {
      final result = resolver.resolveCustom(
        occurrenceLocalDate: LocalDate(2026, 8, 20),
        prayerContext: PrayerContext(prayerType: PrayerType.fajr, isQada: true),
      );

      expect(result.selection!.occurrenceLocalDate, LocalDate(2026, 8, 20));
      expect(result.selection!.prayerContext.isQada, isTrue);
    });
  });

  group('schedule-backed shortcuts', () {
    test('previous prayer uses a reliable schedule and never invents Witr', () {
      final resolver = PrayerRegistrationShortcutResolver(
        FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 25, 18, 0, 0)),
      );

      final result = resolver.resolvePreviousPrayer(
        currentDaySchedule: testPrayerDay(25),
        currentDayScheduleIsReliable: true,
      );

      expect(result.canRegister, isTrue);
      expect(
        result.selection!.shortcut,
        PrayerRegistrationShortcut.previousPrayer,
      );
      expect(result.selection!.occurrenceLocalDate, LocalDate(2026, 8, 25));
      expect(result.selection!.prayerContext.prayerType, PrayerType.dhuhr);
      expect(result.selection!.prayerContext.isQada, isFalse);
    });

    test('previous Isha requires a reliable adjacent day', () {
      final resolver = PrayerRegistrationShortcutResolver(
        FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 25, 5, 0, 0)),
      );

      final unavailable = resolver.resolvePreviousPrayer(
        currentDaySchedule: testPrayerDay(25),
        currentDayScheduleIsReliable: true,
      );
      final resolved = resolver.resolvePreviousPrayer(
        currentDaySchedule: testPrayerDay(25),
        currentDayScheduleIsReliable: true,
        previousDaySchedule: testPrayerDay(24),
        previousDayScheduleIsReliable: true,
      );

      expect(
        unavailable.status,
        PrayerRegistrationShortcutStatus.previousDayScheduleUnavailable,
      );
      expect(resolved.selection!.occurrenceLocalDate, LocalDate(2026, 8, 24));
      expect(resolved.selection!.prayerContext.prayerType, PrayerType.isha);
    });

    test('before Fajr the previous prayer is yesterday Maghrib', () {
      final resolver = PrayerRegistrationShortcutResolver(
        FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 25, 3, 0, 0)),
      );

      final resolved = resolver.resolvePreviousPrayer(
        currentDaySchedule: testPrayerDay(25),
        currentDayScheduleIsReliable: true,
        previousDaySchedule: testPrayerDay(24),
        previousDayScheduleIsReliable: true,
      );

      expect(resolved.selection!.occurrenceLocalDate, LocalDate(2026, 8, 24));
      expect(resolved.selection!.prayerContext.prayerType, PrayerType.maghrib);
    });

    test('previous prayer fails closed for stale or wrong-date schedules', () {
      final resolver = PrayerRegistrationShortcutResolver(
        FixedPrayerTimeProvider(_utcForTashkent(2026, 8, 25, 18, 0, 0)),
      );

      final stale = resolver.resolvePreviousPrayer(
        currentDaySchedule: testPrayerDay(25),
      );
      final wrongDate = resolver.resolvePreviousPrayer(
        currentDaySchedule: testPrayerDay(24),
        currentDayScheduleIsReliable: true,
      );

      expect(stale.status, PrayerRegistrationShortcutStatus.unreliableSchedule);
      expect(
        wrongDate.status,
        PrayerRegistrationShortcutStatus.scheduleDateMismatch,
      );
      expect(stale.selection, isNull);
      expect(wrongDate.selection, isNull);
    });

    test('Now is unavailable in the sunrise gap', () {
      final timeProvider = FixedPrayerTimeProvider(
        _utcForTashkent(2026, 8, 25, 6, 0, 0),
      );
      final current = PrayerContextResolver(timeProvider).resolve(
        mode: PrayerContextSelectionMode.automatic,
        automaticSchedule: testPrayerDay(25),
        automaticScheduleIsReliable: true,
      );

      final result = PrayerRegistrationShortcutResolver(
        timeProvider,
      ).resolveNow(currentResolution: current, utcOffsetMinutes: 300);

      expect(current.status, PrayerContextResolutionStatus.betweenPrayers);
      expect(
        result.status,
        PrayerRegistrationShortcutStatus.currentPrayerUnavailable,
      );
      expect(result.selection, isNull);
    });

    test(
      'manual current Witr remains available without a fake schedule time',
      () {
        final timeProvider = FixedPrayerTimeProvider(
          _utcForTashkent(2026, 8, 25, 22, 0, 0),
        );
        final manual = PrayerContextResolver(timeProvider).resolve(
          mode: PrayerContextSelectionMode.manual,
          manualContext: PrayerContext(prayerType: PrayerType.witr),
        );

        final result = PrayerRegistrationShortcutResolver(
          timeProvider,
        ).resolveNow(currentResolution: manual, utcOffsetMinutes: 300);

        expect(result.selection!.occurrenceLocalDate, LocalDate(2026, 8, 25));
        expect(result.selection!.prayerContext.prayerType, PrayerType.witr);
      },
    );

    test('Jumuah Now requires an explicitly manual context', () {
      final timeProvider = FixedPrayerTimeProvider(
        _utcForTashkent(2026, 8, 28, 13, 0, 0),
      );
      final context = PrayerContext(prayerType: PrayerType.jumuah);
      final automatic = PrayerContextResolution(
        status: PrayerContextResolutionStatus.automatic,
        context: context,
      );
      final manual = PrayerContextResolution(
        status: PrayerContextResolutionStatus.manual,
        context: context,
      );
      final resolver = PrayerRegistrationShortcutResolver(timeProvider);

      final rejected = resolver.resolveNow(
        currentResolution: automatic,
        utcOffsetMinutes: 300,
      );
      final accepted = resolver.resolveNow(
        currentResolution: manual,
        utcOffsetMinutes: 300,
      );

      expect(
        rejected.status,
        PrayerRegistrationShortcutStatus.unsupportedAutomaticPrayer,
      );
      expect(rejected.selection, isNull);
      expect(accepted.selection!.prayerContext, context);
      expect(accepted.selection!.occurrenceLocalDate, LocalDate(2026, 8, 28));
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
