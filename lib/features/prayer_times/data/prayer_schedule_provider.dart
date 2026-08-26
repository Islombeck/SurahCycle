import '../domain/prayer_time_models.dart';

/// A failure at the external timetable boundary. Response bodies are not
/// retained so an upstream error page cannot leak into logs or persisted data.
final class PrayerScheduleProviderException implements Exception {
  const PrayerScheduleProviderException({
    required this.code,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() =>
      'PrayerScheduleProviderException($code, $message'
      '${statusCode == null ? '' : ', status: $statusCode'})';
}

abstract interface class PublishedPrayerScheduleProvider
    implements PrayerMonthScheduleSource {
  @override
  PrayerTimeSource get source;
}

abstract interface class CalculatedPrayerScheduleProvider
    implements PrayerMonthScheduleSource {
  @override
  PrayerTimeSource get source;
}
