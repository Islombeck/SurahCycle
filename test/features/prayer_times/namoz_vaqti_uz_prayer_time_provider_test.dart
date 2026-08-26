import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import 'prayer_test_fixtures.dart';

void main() {
  final fetchedAt = DateTime.utc(2026, 8, 25, 12);
  late PrayerScheduleRequest request;

  setUp(() {
    request = PrayerScheduleRequest(
      location: testTashkentLocation(),
      year: 2026,
      month: 8,
    );
  });

  test('loads and validates the full Tashkent August 2026 fixture', () async {
    final provider = NamozVaqtiUzPrayerTimeProvider(
      client: MockClient((http.Request actual) async {
        expect(actual.method, 'GET');
        expect(actual.url.scheme, 'https');
        expect(actual.url.host, 'namoz-vaqti.uz');
        expect(actual.url.path, '/index.php');
        expect(actual.url.queryParameters, <String, String>{
          'region': 'toshkent-shahri',
          'lang': 'ru',
          'period': '2026-08',
          'format': 'json',
        });
        return _response(namozVaqtiMonthPayload());
      }),
      timeProvider: FixedPrayerTimeProvider(fetchedAt),
    );

    final month = await provider.loadMonth(request);
    final reference = month.day(LocalDate(2026, 8, 25))!;

    expect(month.days, hasLength(31));
    expect(reference.times.fajr.raw.toString(), '04:17');
    expect(reference.times.sunrise.raw.toString(), '05:42');
    expect(reference.times.dhuhr.raw.toString(), '12:25');
    expect(reference.times.asr.raw.toString(), '17:09');
    expect(reference.times.maghrib.raw.toString(), '19:11');
    expect(reference.times.isha.raw.toString(), '20:32');
    expect(reference.timeZoneId, 'Asia/Tashkent');
    expect(reference.utcOffsetMinutes, 300);
    expect(month.provenance.source.displayName, 'Namoz-vaqti.uz');
    expect(
      month.provenance.source.kind,
      PrayerTimeSourceKind.publishedSchedule,
    );
    expect(month.provenance.fetchedAtUtc, fetchedAt);
    expect(month.provenance.providerRegionSlug, 'toshkent-shahri');
    expect(month.provenance.providerRegionalOffsetMinutes, 0);
    expect(month.provenance.attribution, contains('does not guarantee'));
  });

  for (final scenario
      in <
        ({
          String name,
          String expectedCode,
          void Function(Map<String, Object?>) mutate,
        })
      >[
        (
          name: 'missing prayer',
          expectedCode: 'namoz_vaqti_missing_prayer',
          mutate: (payload) => _times(payload, 0).remove('xufton'),
        ),
        (
          name: 'bad HH:mm',
          expectedCode: 'namoz_vaqti_bad_time',
          mutate: (payload) => _times(payload, 0)['bomdod'] = '4:00',
        ),
        (
          name: 'duplicate date',
          expectedCode: 'namoz_vaqti_duplicate_date',
          mutate: (payload) => _row(payload, 1)['date'] = '01.08.2026',
        ),
        (
          name: 'wrong requested month',
          expectedCode: 'namoz_vaqti_wrong_month',
          mutate: (payload) => _meta(payload)['ym'] = '2026-09',
        ),
        (
          name: 'wrong region',
          expectedCode: 'namoz_vaqti_wrong_region',
          mutate: (payload) =>
              (_meta(payload)['region']! as Map<String, Object?>)['slug'] =
                  'samarqand-shahri',
        ),
        (
          name: 'wrong parent region',
          expectedCode: 'namoz_vaqti_wrong_parent_region',
          mutate: (payload) =>
              (_meta(payload)['region']! as Map<String, Object?>)['parent'] =
                  'samarqand-viloyati',
        ),
      ]) {
    test('rejects ${scenario.name}', () async {
      final payload = namozVaqtiMonthPayload();
      scenario.mutate(payload);
      final provider = NamozVaqtiUzPrayerTimeProvider(
        client: MockClient((_) async => _response(payload)),
        timeProvider: FixedPrayerTimeProvider(fetchedAt),
      );

      await expectLater(
        provider.loadMonth(request),
        throwsA(
          isA<PrayerScheduleProviderException>().having(
            (error) => error.code,
            'code',
            scenario.expectedCode,
          ),
        ),
      );
    });
  }

  test('maps a network response without retaining its body', () async {
    final provider = NamozVaqtiUzPrayerTimeProvider(
      client: MockClient((_) async => http.Response('private error page', 503)),
      timeProvider: FixedPrayerTimeProvider(fetchedAt),
    );

    try {
      await provider.loadMonth(request);
      fail('Expected a provider exception.');
    } on PrayerScheduleProviderException catch (error) {
      expect(error.code, 'namoz_vaqti_http');
      expect(error.statusCode, 503);
      expect(error.toString(), isNot(contains('private error page')));
    }
  });

  test('rejects HTML and oversized bodies before JSON parsing', () async {
    Future<String> codeFor(http.Response response) async {
      final provider = NamozVaqtiUzPrayerTimeProvider(
        client: MockClient((_) async => response),
        timeProvider: FixedPrayerTimeProvider(fetchedAt),
      );
      try {
        await provider.loadMonth(request);
        fail('Expected a provider exception.');
      } on PrayerScheduleProviderException catch (error) {
        return error.code;
      }
    }

    expect(
      await codeFor(
        http.Response(
          '<html>not an API response</html>',
          200,
          headers: const <String, String>{'content-type': 'text/html'},
        ),
      ),
      'namoz_vaqti_content_type',
    );
    expect(
      await codeFor(
        http.Response.bytes(
          List<int>.filled(
            NamozVaqtiUzPrayerTimeProvider.maxResponseBytes + 1,
            0x20,
          ),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        ),
      ),
      'namoz_vaqti_response_too_large',
    );
  });
}

http.Response _response(Map<String, Object?> value) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  200,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);

Map<String, Object?> _meta(Map<String, Object?> payload) =>
    payload['meta']! as Map<String, Object?>;

Map<String, Object?> _row(Map<String, Object?> payload, int index) =>
    (payload['period_table']! as List<Object?>)[index]! as Map<String, Object?>;

Map<String, Object?> _times(Map<String, Object?> payload, int index) =>
    _row(payload, index)['times']! as Map<String, Object?>;
