import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

const _fiveDailyPrayers = <PrayerType>[
  PrayerType.fajr,
  PrayerType.dhuhr,
  PrayerType.asr,
  PrayerType.maghrib,
  PrayerType.isha,
];

void main() {
  group('Qada is available for the five Fard prayers and Witr', () {
    for (final type in _fiveDailyPrayers) {
      test('${type.name} supports Qada through its Fard part', () {
        expect(type.supportsQada, isTrue);
        expect(
          PrayerQadaPolicy.obligatoryPartKind(type),
          PrayerRoutinePartKind.fard,
        );
        expect(
          PrayerQadaPolicy.allowsPart(
            prayerType: type,
            isQada: true,
            kind: PrayerRoutinePartKind.fard,
          ),
          isTrue,
        );
      });
    }

    test('Witr is a separate Wajib prayer with its own Qada part', () {
      expect(PrayerType.witr.supportsQada, isTrue);
      expect(
        PrayerQadaPolicy.obligatoryPartKind(PrayerType.witr),
        PrayerRoutinePartKind.witr,
        reason: 'Witr keeps its own kind instead of being modelled as Fard',
      );
      expect(
        PrayerQadaPolicy.allowsPart(
          prayerType: PrayerType.witr,
          isQada: true,
          kind: PrayerRoutinePartKind.witr,
        ),
        isTrue,
      );
      expect(
        PrayerQadaPolicy.allowsPart(
          prayerType: PrayerType.witr,
          isQada: true,
          kind: PrayerRoutinePartKind.fard,
        ),
        isFalse,
      );
    });
  });

  group('voluntary parts never become Qada', () {
    for (final kind in <PrayerRoutinePartKind>[
      PrayerRoutinePartKind.sunnah,
      PrayerRoutinePartKind.nafl,
      PrayerRoutinePartKind.custom,
      PrayerRoutinePartKind.witr,
    ]) {
      test('a ${kind.name} part is rejected in a Qada Dhuhr', () {
        expect(
          PrayerQadaPolicy.allowsPart(
            prayerType: PrayerType.dhuhr,
            isQada: true,
            kind: kind,
          ),
          isFalse,
        );
      });
    }

    test('Jumuah and Nafl have no make-up obligation at all', () {
      expect(PrayerType.jumuah.supportsQada, isFalse);
      expect(PrayerType.nafl.supportsQada, isFalse);
      expect(PrayerQadaPolicy.obligatoryPartKind(PrayerType.jumuah), isNull);
      expect(PrayerQadaPolicy.obligatoryPartKind(PrayerType.nafl), isNull);
      for (final kind in PrayerRoutinePartKind.values) {
        expect(
          PrayerQadaPolicy.allowsPart(
            prayerType: PrayerType.jumuah,
            isQada: true,
            kind: kind,
          ),
          isFalse,
        );
      }
    });

    test('a missed Jumuah cannot be registered as Jumuah Qada', () {
      expect(
        () => PrayerContext(prayerType: PrayerType.jumuah, isQada: true),
        throwsArgumentError,
        reason: 'no hidden conversion to Dhuhr either',
      );
    });
  });

  test('an ordinary context keeps every configured part kind', () {
    for (final type in PrayerType.values) {
      for (final kind in PrayerRoutinePartKind.values) {
        expect(
          PrayerQadaPolicy.allowsPart(
            prayerType: type,
            isQada: false,
            kind: kind,
          ),
          isTrue,
          reason: '${type.name}/${kind.name} must stay available normally',
        );
      }
    }
  });
}
