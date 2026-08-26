import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/domain/domain.dart';
import '../domain/prayer_time_models.dart';
import 'prayer_schedule_provider.dart';

final class NamozVaqtiUzPrayerTimeProvider
    implements PublishedPrayerScheduleProvider {
  NamozVaqtiUzPrayerTimeProvider({
    required this.client,
    required this.timeProvider,
  });

  static const String sourceId = 'namoz-vaqti.uz';
  static const Duration requestTimeout = Duration(seconds: 12);
  static const int maxResponseBytes = 256 * 1024;
  static const String attribution =
      'Namoz-vaqti.uz — schedule based on official Uzbekistan sources; '
      'the provider does not guarantee absolute religious accuracy.';

  static final PrayerTimeSource providerSource = PrayerTimeSource(
    id: sourceId,
    displayName: 'Namoz-vaqti.uz',
    kind: PrayerTimeSourceKind.publishedSchedule,
    description: 'Schedule based on official Uzbekistan sources.',
  );

  final http.Client client;
  final TimeProvider timeProvider;

  @override
  PrayerTimeSource get source => providerSource;

  Uri uriFor(PrayerScheduleRequest request) =>
      Uri.https('namoz-vaqti.uz', '/index.php', <String, String>{
        'region': request.location.providerSlug,
        'lang': 'ru',
        'period': _yearMonth(request.year, request.month),
        'format': 'json',
      });

  @override
  Future<PrayerMonthSchedule> loadMonth(PrayerScheduleRequest request) async {
    final uri = uriFor(request);
    final DateTime fetchedAtUtc = timeProvider.nowUtc();
    if (!fetchedAtUtc.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return UTC.');
    }

    late final http.Response response;
    try {
      response = await client
          .get(
            uri,
            headers: const <String, String>{'accept': 'application/json'},
          )
          .timeout(requestTimeout);
    } on Object catch (error) {
      throw PrayerScheduleProviderException(
        code: 'namoz_vaqti_network',
        message: 'Could not download the monthly prayer schedule.',
        cause: error,
      );
    }
    if (response.statusCode != 200) {
      throw PrayerScheduleProviderException(
        code: 'namoz_vaqti_http',
        message: 'The schedule provider returned a non-success status.',
        statusCode: response.statusCode,
      );
    }
    final contentType = response.headers['content-type']?.toLowerCase();
    if (contentType == null || !contentType.contains('application/json')) {
      throw PrayerScheduleProviderException(
        code: 'namoz_vaqti_content_type',
        message: 'The schedule provider did not return JSON.',
      );
    }
    if (response.bodyBytes.length > maxResponseBytes) {
      throw PrayerScheduleProviderException(
        code: 'namoz_vaqti_response_too_large',
        message: 'The monthly schedule response exceeded the safe limit.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on Object catch (error) {
      throw PrayerScheduleProviderException(
        code: 'namoz_vaqti_invalid_json',
        message: 'The provider response is not valid UTF-8 JSON.',
        cause: error,
      );
    }
    return NamozVaqtiUzScheduleParser.parse(
      decoded,
      request: request,
      fetchedAtUtc: fetchedAtUtc,
      sourceUri: uri,
    );
  }

  static String _yearMonth(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}';
}

abstract final class NamozVaqtiUzScheduleParser {
  static PrayerMonthSchedule parse(
    Object? decoded, {
    required PrayerScheduleRequest request,
    required DateTime fetchedAtUtc,
    required Uri sourceUri,
  }) {
    try {
      final root = _map(decoded, 'root');
      final meta = _map(root['meta'], 'meta');
      final region = _map(meta['region'], 'meta.region');
      final actualSlug = _string(region['slug'], 'meta.region.slug');
      if (actualSlug != request.location.providerSlug) {
        _invalid(
          'namoz_vaqti_wrong_region',
          'Provider region does not match the requested stable slug.',
        );
      }
      final expectedParent = request.location.parentProviderSlug;
      if (expectedParent != null &&
          _string(region['parent'], 'meta.region.parent') != expectedParent) {
        _invalid(
          'namoz_vaqti_wrong_parent_region',
          'Provider parent region does not match the audited directory.',
        );
      }
      final requestedMonth = NamozVaqtiUzPrayerTimeProvider._yearMonth(
        request.year,
        request.month,
      );
      if (_string(meta['ym'], 'meta.ym') != requestedMonth) {
        _invalid(
          'namoz_vaqti_wrong_month',
          'Provider month does not match the requested month.',
        );
      }
      final regionalOffset = _integer(meta['offset_min'], 'meta.offset_min');
      if (regionalOffset.abs() > 24 * 60) {
        _invalid(
          'namoz_vaqti_bad_regional_offset',
          'Provider regional correction is outside a safe range.',
        );
      }

      final rows = _list(root['period_table'], 'period_table');
      final expectedDayCount = DateTime.utc(
        request.year,
        request.month + 1,
        0,
      ).day;
      if (rows.length != expectedDayCount) {
        _invalid(
          'namoz_vaqti_incomplete_month',
          'Monthly response must contain every calendar day.',
        );
      }

      final provenance = PrayerTimeProvenance.published(
        source: NamozVaqtiUzPrayerTimeProvider.providerSource,
        sourceUri: sourceUri,
        fetchedAtUtc: fetchedAtUtc,
        attribution: NamozVaqtiUzPrayerTimeProvider.attribution,
        providerRegionSlug: actualSlug,
        providerRegionalOffsetMinutes: regionalOffset,
      );
      final seen = <LocalDate>{};
      final days = <PrayerDaySchedule>[];
      for (final rowValue in rows) {
        final row = _map(rowValue, 'period_table row');
        final date = _date(
          _string(row['date'], 'period_table.date'),
          request: request,
        );
        if (!seen.add(date)) {
          _invalid(
            'namoz_vaqti_duplicate_date',
            'Monthly response contains a duplicate date.',
          );
        }
        final times = _map(row['times'], 'period_table.times');
        days.add(
          PrayerDaySchedule(
            date: date,
            times: PrayerTimes(
              fajr: _clock(times, 'bomdod'),
              sunrise: _clock(times, 'quyosh'),
              dhuhr: _clock(times, 'peshin'),
              asr: _clock(times, 'asr'),
              maghrib: _clock(times, 'shom'),
              isha: _clock(times, 'xufton'),
            ),
            provenance: provenance,
            timeZoneId: request.location.timeZoneId,
            utcOffsetMinutes: request.location.utcOffsetMinutes,
          ),
        );
      }
      days.sort((left, right) => left.date.compareTo(right.date));
      for (var index = 0; index < days.length; index += 1) {
        if (days[index].date !=
            LocalDate(request.year, request.month, index + 1)) {
          _invalid(
            'namoz_vaqti_missing_date',
            'Monthly response does not contain each requested date.',
          );
        }
      }
      return PrayerMonthSchedule(
        location: request.location,
        year: request.year,
        month: request.month,
        days: days,
        provenance: provenance,
      );
    } on PrayerScheduleProviderException {
      rethrow;
    } on Object catch (error) {
      throw PrayerScheduleProviderException(
        code: 'namoz_vaqti_invalid_payload',
        message: 'The monthly schedule payload failed validation.',
        cause: error,
      );
    }
  }

  static Map<String, Object?> _map(Object? value, String field) {
    if (value is! Map<String, Object?>) {
      _invalid('namoz_vaqti_missing_field', '$field must be an object.');
    }
    return value;
  }

  static List<Object?> _list(Object? value, String field) {
    if (value is! List<Object?>) {
      _invalid('namoz_vaqti_missing_field', '$field must be a list.');
    }
    return value;
  }

  static String _string(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      _invalid(
        'namoz_vaqti_missing_field',
        '$field must be a non-empty string.',
      );
    }
    return value;
  }

  static int _integer(Object? value, String field) {
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      _invalid('namoz_vaqti_missing_field', '$field must be an integer.');
    }
    return value.toInt();
  }

  static LocalDate _date(
    String value, {
    required PrayerScheduleRequest request,
  }) {
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (match == null) {
      _invalid('namoz_vaqti_bad_date', 'Date must use DD.MM.YYYY.');
    }
    final date = LocalDate(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
    if (date.year != request.year || date.month != request.month) {
      _invalid(
        'namoz_vaqti_wrong_month',
        'A timetable row is outside the requested month.',
      );
    }
    return date;
  }

  static PrayerClockTime _clock(Map<String, Object?> times, String key) {
    final value = times[key];
    if (value is! String) {
      _invalid(
        'namoz_vaqti_missing_prayer',
        'A required prayer boundary is missing.',
      );
    }
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) {
      _invalid(
        'namoz_vaqti_bad_time',
        'Prayer boundaries must use strict HH:mm.',
      );
    }
    return PrayerClockTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  static Never _invalid(String code, String message) =>
      throw PrayerScheduleProviderException(code: code, message: message);
}
