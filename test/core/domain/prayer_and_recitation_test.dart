import 'package:flutter_test/flutter_test.dart';

import 'package:murajaah/core/domain/domain.dart';

void main() {
  group('PrayerContext', () {
    test('qada identifies a concrete prayer with that capability', () {
      final context = PrayerContext(prayerType: PrayerType.dhuhr, isQada: true);

      expect(context.prayerType, PrayerType.dhuhr);
      expect(context.isQada, isTrue);
      expect(PrayerType.dhuhr.supportsQada, isTrue);
    });

    test('nafl cannot be represented as qada', () {
      expect(
        () => PrayerContext(prayerType: PrayerType.nafl, isQada: true),
        throwsArgumentError,
      );
    });

    test('Jumuah is distinct from Dhuhr and has no invented Qada mode', () {
      final jumuah = PrayerContext(prayerType: PrayerType.jumuah);

      expect(jumuah.prayerType, isNot(PrayerType.dhuhr));
      expect(PrayerType.jumuah.supportsQada, isFalse);
      expect(
        () => PrayerContext(prayerType: PrayerType.jumuah, isQada: true),
        throwsArgumentError,
      );
    });

    test('witr is distinct and supports Qada without theological flags', () {
      final context = PrayerContext(prayerType: PrayerType.witr, isQada: true);

      expect(context.prayerType, PrayerType.witr);
      expect(context.isQada, isTrue);
      expect(PrayerType.witr.supportsQada, isTrue);
      expect(PrayerType.nafl.supportsQada, isFalse);
    });
  });

  test(
    'recitation retains UTC, local date and prayer context independently',
    () {
      final event = SurahRecitationEvent(
        id: 'event-id',
        surahId: 'surah-a',
        prayerSessionId: 'session-id',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr, isQada: true),
        createdAtUtc: DateTime.utc(2026, 2, 3, 22, 15),
        localDate: LocalDate(2026, 2, 4),
      );

      expect(event.prayerType, PrayerType.fajr);
      expect(event.isQada, isTrue);
      expect(event.createdAtUtc.isUtc, isTrue);
      expect(event.localDate.toString(), '2026-02-04');
      expect(event.prayerSessionId, 'session-id');
      expect(event.rakaatSpanCount, 1);
    },
  );

  test('recitation validates immutable coverage and rakaat span', () {
    final coverage = RecitationCoverage(
      rotationSchemeId: 'scheme-2',
      coveredPartIds: const <String>['p1', 'p2'],
    );
    final event = SurahRecitationEvent(
      id: 'event-id',
      surahId: 'surah-a',
      prayerContext: PrayerContext(prayerType: PrayerType.witr),
      createdAtUtc: DateTime.utc(2026, 2, 3),
      localDate: LocalDate(2026, 2, 3),
      coverage: coverage,
      rakaatSpanCount: 3,
    );

    expect(event.rotationSchemeId, 'scheme-2');
    expect(event.coveredPartIds, <String>['p1', 'p2']);
    expect(event.rakaatSpanCount, 3);
    expect(() => event.coveredPartIds.add('p3'), throwsUnsupportedError);
    expect(
      () => RecitationCoverage(
        rotationSchemeId: 'scheme-2',
        coveredPartIds: const <String>['p1', 'p1'],
      ),
      throwsArgumentError,
    );
    expect(
      () => SurahRecitationEvent(
        id: 'bad',
        surahId: 'surah-a',
        prayerContext: PrayerContext(prayerType: PrayerType.asr),
        createdAtUtc: DateTime.utc(2026, 2, 3),
        localDate: LocalDate(2026, 2, 3),
        rakaatSpanCount: 0,
      ),
      throwsArgumentError,
    );
  });

  test('invalid local dates are rejected rather than normalized', () {
    expect(() => LocalDate(2026, 2, 30), throwsArgumentError);
  });
}
