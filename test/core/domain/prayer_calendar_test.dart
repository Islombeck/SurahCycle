import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

/// The owner asked for the calendar in these words: green when he simply
/// forgot to mark and entered it later, orange when it was Qada. Everything
/// here exists to keep those two apart, and to keep "no record" from reading
/// as "missed".
void main() {
  const service = PrayerCalendarService();
  final day = LocalDate(2026, 9, 16);

  PrayerCalendarFact fact({
    PrayerType prayerType = PrayerType.dhuhr,
    bool isQada = false,
    bool hasSession = true,
    int totalParts = 3,
    int completedParts = 3,
    int recitations = 2,
    LocalDate? date,
  }) => PrayerCalendarFact(
    date: date ?? day,
    prayerType: prayerType,
    isQada: isQada,
    hasSession: hasSession,
    totalPartCount: totalParts,
    completedPartCount: completedParts,
    recitationCount: recitations,
  );

  PrayerCalendarDay buildOne(List<PrayerCalendarFact> facts) =>
      service.build(days: <LocalDate>[day], facts: facts).single;

  test('a day with nothing is "no record", not a missed prayer', () {
    final result = buildOne(const <PrayerCalendarFact>[]);

    expect(result.hasNoRecord, isTrue);
    expect(result.hasOrdinary, isFalse);
    expect(result.hasQada, isFalse);
    expect(
      result.hasPartial,
      isFalse,
      reason:
          'the app records what the user entered; it does not rule on '
          'whether a prayer was performed',
    );
  });

  test('an ordinary completed prayer is green', () {
    final result = buildOne(<PrayerCalendarFact>[fact()]);

    expect(result.hasOrdinary, isTrue);
    expect(result.hasQada, isFalse);
    expect(result.hasPartial, isFalse);
    expect(result.ordinaryCount, 1);
  });

  test('a Qada prayer is counted separately', () {
    final result = buildOne(<PrayerCalendarFact>[fact(isQada: true)]);

    expect(result.hasQada, isTrue);
    expect(result.hasOrdinary, isFalse);
    expect(result.qadaCount, 1);
  });

  test('a mixed day carries both markers', () {
    final result = buildOne(<PrayerCalendarFact>[
      fact(prayerType: PrayerType.fajr),
      fact(prayerType: PrayerType.isha, isQada: true),
    ]);

    expect(result.hasOrdinary, isTrue);
    expect(result.hasQada, isTrue);
    expect(
      result.entries.map((entry) => entry.isQada),
      <bool>[false, true],
      reason: 'ordinary first, so one colour never hides the other',
    );
  });

  test('one surah does not paint a whole prayer as done', () {
    final result = buildOne(<PrayerCalendarFact>[
      fact(totalParts: 3, completedParts: 1, recitations: 1),
    ]);

    expect(result.hasOrdinary, isTrue);
    expect(result.hasPartial, isTrue);
    expect(result.entries.single.isComplete, isFalse);
  });

  test(
    'a prayer completed by following the imam counts, with no recitations',
    () {
      final result = buildOne(<PrayerCalendarFact>[
        fact(totalParts: 2, completedParts: 2, recitations: 0),
      ]);

      expect(
        result.hasOrdinary,
        isTrue,
        reason: 'a recitation count alone would have called this day empty',
      );
      expect(result.hasPartial, isFalse);
    },
  );

  test('an empty session colours nothing', () {
    // Opening the app during a prayer window creates the snapshot. That is not
    // a record of anything.
    final result = buildOne(<PrayerCalendarFact>[
      fact(totalParts: 3, completedParts: 0, recitations: 0),
    ]);

    expect(result.hasNoRecord, isTrue);
  });

  test('a recitation without a routine session is recorded, not partial', () {
    final result = buildOne(<PrayerCalendarFact>[
      fact(hasSession: false, totalParts: 0, completedParts: 0, recitations: 1),
    ]);

    expect(result.hasOrdinary, isTrue);
    expect(
      result.hasPartial,
      isFalse,
      reason:
          'with no session there is nothing to be partial against, and '
          'guessing would be an invented claim about the user',
    );
  });

  test('every requested day gets a cell, in order', () {
    final days = <LocalDate>[
      LocalDate(2026, 9, 15),
      LocalDate(2026, 9, 16),
      LocalDate(2026, 9, 17),
    ];

    final result = service.build(
      days: days,
      facts: <PrayerCalendarFact>[fact(date: days[1])],
    );

    expect(result.map((entry) => entry.date), days);
    expect(result[0].hasNoRecord, isTrue);
    expect(result[1].hasOrdinary, isTrue);
    expect(result[2].hasNoRecord, isTrue);
  });

  test('a facts list for another day never leaks into this one', () {
    final result = buildOne(<PrayerCalendarFact>[
      fact(date: LocalDate(2026, 9, 15)),
    ]);

    expect(result.hasNoRecord, isTrue);
  });

  test('the entries list cannot be mutated by its caller', () {
    final result = buildOne(<PrayerCalendarFact>[fact()]);

    expect(
      () => result.entries.add(
        const PrayerCalendarEntry(
          prayerType: PrayerType.asr,
          isQada: false,
          hasSession: true,
          isComplete: true,
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
