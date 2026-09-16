import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Asked for by the owner: someone closing very old debts, from before he
/// began praying regularly, cannot name the day a missed prayer belongs to.
/// The app must record that honestly instead of inventing a date.
void main() {
  final day = LocalDate(2026, 9, 16);

  SurahRecitationEvent eventOf({
    required bool isQada,
    bool qadaOriginIsUnknown = false,
  }) => SurahRecitationEvent(
    id: 'event-1',
    surahId: 'surah-1',
    prayerContext: PrayerContext(prayerType: PrayerType.fajr, isQada: isQada),
    createdAtUtc: DateTime.utc(2026, 9, 16, 5),
    localDate: day,
    qadaOriginIsUnknown: qadaOriginIsUnknown,
  );

  group('only a Qada can have an unknown day', () {
    test('a Qada may say its original day is unknown', () {
      final event = eventOf(isQada: true, qadaOriginIsUnknown: true);

      expect(event.qadaOriginIsUnknown, isTrue);
      expect(
        event.localDate,
        day,
        reason:
            'the date kept is the day of the make-up — the only one there '
            'is — and the flag is what stops it reading as the debt\'s day',
      );
    });

    test('an ordinary record cannot', () {
      expect(
        () => eventOf(isQada: false, qadaOriginIsUnknown: true),
        throwsArgumentError,
        reason: 'an ordinary record always knows its day: the user picked it',
      );
    });

    test('the default is a known day', () {
      expect(eventOf(isQada: true).qadaOriginIsUnknown, isFalse);
      expect(eventOf(isQada: false).qadaOriginIsUnknown, isFalse);
    });

    test('the flag is part of the event identity', () {
      expect(
        eventOf(isQada: true, qadaOriginIsUnknown: true),
        isNot(eventOf(isQada: true)),
      );
    });

    test('coverage does not quietly drop it', () {
      final withCoverage = eventOf(isQada: true, qadaOriginIsUnknown: true)
          .withCoverage(
            RecitationCoverage(
              rotationSchemeId: 'scheme-1',
              coveredPartIds: const <String>['part-1'],
            ),
          );

      expect(withCoverage.qadaOriginIsUnknown, isTrue);
    });
  });

  group('the calendar says so instead of implying a date', () {
    const service = PrayerCalendarService();

    PrayerCalendarDay dayWith({
      required bool isQada,
      required bool unknownOrigin,
    }) => service
        .build(
          days: <LocalDate>[day],
          facts: <PrayerCalendarFact>[
            PrayerCalendarFact(
              date: day,
              prayerType: PrayerType.fajr,
              isQada: isQada,
              hasSession: false,
              totalPartCount: 0,
              completedPartCount: 0,
              recitationCount: 1,
              hasUnknownQadaOrigin: unknownOrigin,
            ),
          ],
        )
        .single;

    test('an unknown-origin Qada is flagged on the day it was made up', () {
      final entry = dayWith(isQada: true, unknownOrigin: true).entries.single;

      expect(entry.isQada, isTrue);
      expect(entry.hasUnknownOrigin, isTrue);
    });

    test('an ordinary record is never flagged, whatever storage says', () {
      // Defensive: a stale or mis-migrated row must not make an ordinary
      // record claim its day is unknown.
      final entry = dayWith(isQada: false, unknownOrigin: true).entries.single;

      expect(entry.hasUnknownOrigin, isFalse);
    });

    test('a Qada with a known day carries no such claim', () {
      final entry = dayWith(isQada: true, unknownOrigin: false).entries.single;

      expect(entry.hasUnknownOrigin, isFalse);
    });
  });
}
