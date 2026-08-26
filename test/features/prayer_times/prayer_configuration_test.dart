import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  group('audited Uzbekistan provider locations', () {
    test(
      'contains every published city and district with unique stable slugs',
      () {
        final slugs = UzbekistanPrayerLocations.all
            .map((location) => location.providerSlug)
            .toList(growable: false);

        expect(UzbekistanPrayerLocations.primaryRegions, hasLength(14));
        expect(UzbekistanPrayerLocations.publishedSubregions, hasLength(195));
        expect(UzbekistanPrayerLocations.all, hasLength(209));
        expect(slugs.toSet(), hasLength(slugs.length));
        expect(UzbekistanPrayerLocations.bySlug('olmaliq'), isNotNull);
        expect(UzbekistanPrayerLocations.bySlug('olmazor'), isNotNull);
        expect(UzbekistanPrayerLocations.bySlug('tuproqqala'), isNotNull);

        final parentSlugs = UzbekistanPrayerLocations.primaryRegions
            .map((location) => location.providerSlug)
            .toSet();
        for (final location in UzbekistanPrayerLocations.all) {
          expect(location.timeZoneId, UzbekistanPrayerLocations.timeZoneId);
          expect(
            location.utcOffsetMinutes,
            UzbekistanPrayerLocations.utcOffsetMinutes,
          );
          expect(location.parentProviderSlug, isIn(parentSlugs));
        }
      },
    );

    test('keeps coordinates only on separately audited major city entries', () {
      expect(
        UzbekistanPrayerLocations.bySlug('chirchiq')!.coordinates,
        isNotNull,
      );
      expect(UzbekistanPrayerLocations.bySlug('olmazor')!.coordinates, isNull);
      expect(
        UzbekistanPrayerLocations.selectorLabel(
          UzbekistanPrayerLocations.bySlug('olmazor')!,
        ),
        'Olmazor — Toshkent shahri',
      );
    });
  });

  group('PrayerTimeSettingsRepository', () {
    test(
      'defaults to explicit manual Tashkent without calculated fallback',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = PrayerTimeSettingsRepository(
          AppSettingsRepository(database),
        );

        final value = await repository.load();

        expect(database.schemaVersion, 3);
        expect(value.location.providerSlug, 'toshkent-shahri');
        expect(
          value.locationSelectionMode,
          PrayerLocationSelectionMode.manualRegion,
        );
        expect(value.contextSelectionMode, PrayerContextSelectionMode.manual);
        expect(value.allowCalculatedFallback, isFalse);
        expect(value.calculationSettings.asrSchool, PrayerAsrSchool.hanafi);
      },
    );

    test(
      'round-trips modes, calculation settings, coordinates, and offsets',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = PrayerTimeSettingsRepository(
          AppSettingsRepository(database),
        );
        final expected = PrayerTimeSettings(
          location: UzbekistanPrayerLocations.bySlug('chirchiq')!,
          locationSelectionMode: PrayerLocationSelectionMode.userCoordinates,
          contextSelectionMode: PrayerContextSelectionMode.automatic,
          adjustments: PrayerTimeAdjustments(
            fajrMinutes: -2,
            dhuhrMinutes: 1,
            asrMinutes: 3,
            maghribMinutes: -1,
            ishaMinutes: 2,
          ),
          calculationSettings: const PrayerCalculationSettings(
            method: PrayerCalculationMethod.muslimWorldLeague,
            asrSchool: PrayerAsrSchool.shafi,
            highLatitudeRule: PrayerHighLatitudeRule.seventhOfTheNight,
          ),
          allowCalculatedFallback: true,
        );

        await repository.save(
          expected,
          updatedAtUtc: DateTime.utc(2026, 8, 26),
        );

        expect(await repository.load(), expected);
        expect(await repository.watch().first, expected);
        expect(database.schemaVersion, 3);
      },
    );

    test('rejects incomplete coordinates and unknown schemas', () {
      final encoded = PrayerTimeSettingsRepository.encode(
        PrayerTimeSettings(location: testTashkentLocation()),
      );
      final incomplete =
          jsonDecode(jsonEncode(encoded)) as Map<String, Object?>;
      (incomplete['location']! as Map<String, Object?>)['longitude'] = null;
      expect(
        () => PrayerTimeSettingsRepository.decode(jsonEncode(incomplete)),
        throwsStateError,
      );

      final unknown = jsonDecode(jsonEncode(encoded)) as Map<String, Object?>;
      unknown['schemaVersion'] = 2;
      expect(
        () => PrayerTimeSettingsRepository.decode(jsonEncode(unknown)),
        throwsStateError,
      );
    });
  });

  group('AdhanPrayerTimeCalculator', () {
    test(
      'calculates a complete local month with truthful provenance',
      () async {
        final calculatedAt = DateTime.utc(2026, 8, 26, 8);
        final calculator = AdhanPrayerTimeCalculator(
          timeProvider: FixedPrayerTimeProvider(calculatedAt),
        );
        final settings = const PrayerCalculationSettings.uzbekistanFallback();

        final month = await calculator.loadMonth(
          PrayerScheduleRequest(
            location: testTashkentLocation(),
            year: 2026,
            month: 8,
            calculationSettings: settings,
          ),
        );

        expect(month.days, hasLength(31));
        expect(month.provenance.source.kind, PrayerTimeSourceKind.calculated);
        expect(month.provenance.fetchedAtUtc, calculatedAt);
        expect(month.provenance.calculatorVersion, 'adhan_dart 2.0.1');
        expect(month.provenance.calculationSettings, settings);
        expect(month.location.timeZoneId, 'Asia/Tashkent');
        for (final day in month.days) {
          final times = day.times;
          expect(
            <int>[
              times.fajr.raw.minutesSinceMidnight,
              times.sunrise.raw.minutesSinceMidnight,
              times.dhuhr.raw.minutesSinceMidnight,
              times.asr.raw.minutesSinceMidnight,
              times.maghrib.raw.minutesSinceMidnight,
              times.isha.raw.minutesSinceMidnight,
            ],
            orderedEquals(
              <int>[
                times.fajr.raw.minutesSinceMidnight,
                times.sunrise.raw.minutesSinceMidnight,
                times.dhuhr.raw.minutesSinceMidnight,
                times.asr.raw.minutesSinceMidnight,
                times.maghrib.raw.minutesSinceMidnight,
                times.isha.raw.minutesSinceMidnight,
              ]..sort(),
            ),
          );
        }
      },
    );

    test('supports every library preset and an explicit Hanafi Asr', () async {
      final calculator = AdhanPrayerTimeCalculator(
        timeProvider: const FixedPrayerTimeProviderForConfiguration(),
      );
      for (final method in PrayerCalculationMethod.values) {
        final schedule = await calculator.loadMonth(
          PrayerScheduleRequest(
            location: testTashkentLocation(),
            year: 2026,
            month: 2,
            calculationSettings: PrayerCalculationSettings(
              method: method,
              asrSchool: PrayerAsrSchool.hanafi,
            ),
          ),
        );
        expect(schedule.days, hasLength(28));
        expect(schedule.provenance.calculationSettings!.method, method);
      }

      Future<PrayerDaySchedule> calculate(PrayerAsrSchool school) async =>
          (await calculator.loadMonth(
            PrayerScheduleRequest(
              location: testTashkentLocation(),
              year: 2026,
              month: 8,
              calculationSettings: PrayerCalculationSettings(
                method: PrayerCalculationMethod.karachi,
                asrSchool: school,
              ),
            ),
          )).day(LocalDate(2026, 8, 25))!;

      final shafi = await calculate(PrayerAsrSchool.shafi);
      final hanafi = await calculate(PrayerAsrSchool.hanafi);
      expect(
        hanafi.times.asr.raw.minutesSinceMidnight,
        greaterThan(shafi.times.asr.raw.minutesSinceMidnight),
      );
    });

    test('does not calculate a region without explicit coordinates', () async {
      final calculator = AdhanPrayerTimeCalculator(
        timeProvider: const FixedPrayerTimeProviderForConfiguration(),
      );

      await expectLater(
        calculator.loadMonth(
          PrayerScheduleRequest(
            location: UzbekistanPrayerLocations.bySlug('olmazor')!,
            year: 2026,
            month: 8,
          ),
        ),
        throwsA(
          isA<PrayerScheduleProviderException>().having(
            (error) => error.code,
            'code',
            'calculation_coordinates_missing',
          ),
        ),
      );
    });
  });

  test(
    'Tashkent 2026-08-25 reference fixtures remain intentionally distinct',
    () {
      const muslimUz = <String>[
        '04:17',
        '05:42',
        '12:25',
        '17:10',
        '19:12',
        '20:32',
      ];
      const namozVaqti = <String>[
        '04:17',
        '05:42',
        '12:25',
        '17:09',
        '19:11',
        '20:32',
      ];
      const sajda = <String>[
        '04:20',
        '05:42',
        '12:25',
        '17:10',
        '19:13',
        '20:29',
      ];
      final actual = testPrayerTimes();

      expect(<String>[
        actual.fajr.raw.toString(),
        actual.sunrise.raw.toString(),
        actual.dhuhr.raw.toString(),
        actual.asr.raw.toString(),
        actual.maghrib.raw.toString(),
        actual.isha.raw.toString(),
      ], namozVaqti);
      expect(namozVaqti, isNot(muslimUz));
      expect(namozVaqti, isNot(sajda));
    },
  );
}

final class FixedPrayerTimeProviderForConfiguration implements TimeProvider {
  const FixedPrayerTimeProviderForConfiguration();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 8, 26, 8);
}
