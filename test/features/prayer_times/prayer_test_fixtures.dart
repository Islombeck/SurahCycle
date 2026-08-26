import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

final class FixedPrayerTimeProvider implements TimeProvider {
  const FixedPrayerTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

PrayerLocation testTashkentLocation() =>
    UzbekistanPrayerLocations.bySlug('toshkent-shahri')!;

PrayerTimeProvenance testPublishedProvenance({DateTime? fetchedAtUtc}) =>
    PrayerTimeProvenance.published(
      source: NamozVaqtiUzPrayerTimeProvider.providerSource,
      sourceUri: Uri.parse(
        'https://namoz-vaqti.uz/index.php?region=toshkent-shahri&format=json',
      ),
      fetchedAtUtc: fetchedAtUtc ?? DateTime.utc(2026, 8, 25),
      attribution: NamozVaqtiUzPrayerTimeProvider.attribution,
      providerRegionSlug: 'toshkent-shahri',
      providerRegionalOffsetMinutes: 0,
    );

PrayerTimes testPrayerTimes() => PrayerTimes(
  fajr: PrayerClockTime(4, 17),
  sunrise: PrayerClockTime(5, 42),
  dhuhr: PrayerClockTime(12, 25),
  asr: PrayerClockTime(17, 9),
  maghrib: PrayerClockTime(19, 11),
  isha: PrayerClockTime(20, 32),
);

PrayerDaySchedule testPrayerDay(int day, {DateTime? fetchedAtUtc}) =>
    PrayerDaySchedule(
      date: LocalDate(2026, 8, day),
      times: testPrayerTimes(),
      provenance: testPublishedProvenance(fetchedAtUtc: fetchedAtUtc),
      timeZoneId: 'Asia/Tashkent',
      utcOffsetMinutes: 300,
    );

PrayerMonthSchedule testPrayerMonth({DateTime? fetchedAtUtc}) {
  final provenance = testPublishedProvenance(fetchedAtUtc: fetchedAtUtc);
  return PrayerMonthSchedule(
    location: testTashkentLocation(),
    year: 2026,
    month: 8,
    provenance: provenance,
    days: List<PrayerDaySchedule>.generate(
      31,
      (index) => PrayerDaySchedule(
        date: LocalDate(2026, 8, index + 1),
        times: testPrayerTimes(),
        provenance: provenance,
        timeZoneId: 'Asia/Tashkent',
        utcOffsetMinutes: 300,
      ),
      growable: false,
    ),
  );
}

Map<String, Object?> namozVaqtiMonthPayload() => <String, Object?>{
  'meta': <String, Object?>{
    'region': <String, Object?>{
      'slug': 'toshkent-shahri',
      'name': 'Toshkent shahri',
      'parent': 'toshkent-shahri',
    },
    'lang': 'ru',
    'period': '2026-08',
    'ym': '2026-08',
    'offset_min': 0,
  },
  'period_table': List<Object?>.generate(31, (index) {
    final day = index + 1;
    return <String, Object?>{
      'date': '${day.toString().padLeft(2, '0')}.08.2026',
      'times': <String, Object?>{
        'bomdod': day == 25 ? '04:17' : '04:00',
        'quyosh': day == 25 ? '05:42' : '05:30',
        'peshin': day == 25 ? '12:25' : '12:30',
        'asr': day == 25 ? '17:09' : '17:20',
        'shom': day == 25 ? '19:11' : '19:30',
        'xufton': day == 25 ? '20:32' : '21:00',
      },
    };
  }, growable: false),
};
