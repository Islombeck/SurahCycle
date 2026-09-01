import '../../../core/application/application.dart';
import '../../../core/data/repositories/prayer_repository.dart';
import '../../../core/domain/domain.dart';
import '../data/adhan_prayer_time_calculator.dart';
import '../data/namoz_vaqti_uz_prayer_time_provider.dart';
import '../data/prayer_schedule_cache.dart';
import '../domain/prayer_time_models.dart';
import 'prayer_execution_time_resolver.dart';

/// Resolves widget attribution entirely from persisted settings, local cache,
/// and (when explicitly enabled) the local astronomical calculator.
/// No HTTP provider is reachable from this object.
final class CachedRecitationPrayerContextResolver
    implements DetailedRecitationPrayerContextResolver {
  const CachedRecitationPrayerContextResolver({
    required this.settings,
    required this.manualContexts,
    required this.cache,
    required this.calculator,
    required this.timeProvider,
  });

  final PrayerTimeSettings settings;
  final PrayerRepository manualContexts;
  final PrayerScheduleCacheStore cache;
  final AdhanPrayerTimeCalculator calculator;
  final TimeProvider timeProvider;

  @override
  Future<PrayerContext?> resolve() async => (await resolveDetails()).context;

  @override
  Future<RecitationPrayerContextDetails> resolveDetails() async {
    if (settings.contextSelectionMode == PrayerContextSelectionMode.manual) {
      return RecitationPrayerContextDetails(
        context: await manualContexts.getSelectedContext(),
        isAutomatic: false,
      );
    }
    if (!settings.locationConfirmed) {
      return const RecitationPrayerContextDetails(
        context: null,
        isAutomatic: true,
      );
    }

    final nowUtc = timeProvider.nowUtc();
    if (!nowUtc.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return UTC.');
    }
    final localNow = nowUtc.add(
      Duration(minutes: settings.location.utcOffsetMinutes),
    );
    final currentDate = LocalDate.fromLocalDateTime(localNow);
    final currentRequest = PrayerScheduleRequest(
      location: settings.location,
      year: currentDate.year,
      month: currentDate.month,
      calculationSettings: settings.calculationSettings,
    );
    final previousMonthDate = DateTime.utc(
      currentDate.year,
      currentDate.month - 1,
    );
    final nextMonthDate = DateTime.utc(currentDate.year, currentDate.month + 1);

    CachedPrayerMonthSchedule? current;
    CachedPrayerMonthSchedule? previous;
    CachedPrayerMonthSchedule? next;
    if (settings.locationSelectionMode ==
        PrayerLocationSelectionMode.manualRegion) {
      current = await _readPublished(currentRequest);
      previous = await _readPublished(
        PrayerScheduleRequest(
          location: settings.location,
          year: previousMonthDate.year,
          month: previousMonthDate.month,
          calculationSettings: settings.calculationSettings,
        ),
      );
      next = await _readPublished(
        PrayerScheduleRequest(
          location: settings.location,
          year: nextMonthDate.year,
          month: nextMonthDate.month,
          calculationSettings: settings.calculationSettings,
        ),
      );
    }

    final currentIsReliable = current?.isReliableAt(nowUtc) ?? false;
    if (!currentIsReliable && settings.allowCalculatedFallback) {
      final calculatedCurrent = await _tryCalculateAndCache(currentRequest);
      if (calculatedCurrent != null) {
        current = calculatedCurrent;
        previous = await _tryCalculateAndCache(
          PrayerScheduleRequest(
            location: settings.location,
            year: previousMonthDate.year,
            month: previousMonthDate.month,
            calculationSettings: settings.calculationSettings,
          ),
        );
        next = await _tryCalculateAndCache(
          PrayerScheduleRequest(
            location: settings.location,
            year: nextMonthDate.year,
            month: nextMonthDate.month,
            calculationSettings: settings.calculationSettings,
          ),
        );
      }
    }

    final resolution = PrayerExecutionTimeResolver(timeProvider: timeProvider)
        .resolve(
          settings: settings,
          currentMonth: current,
          previousMonth: previous,
          nextMonth: next,
        );
    return RecitationPrayerContextDetails(
      context: resolution.context,
      isAutomatic: true,
      startsAt: resolution.currentStartsAt?.toString(),
      endsAt: resolution.currentEndsAt?.toString(),
    );
  }

  Future<CachedPrayerMonthSchedule?> _readPublished(
    PrayerScheduleRequest request,
  ) => cache.read(request.cacheKey(NamozVaqtiUzPrayerTimeProvider.sourceId));

  Future<CachedPrayerMonthSchedule> _calculateAndCache(
    PrayerScheduleRequest request,
  ) async {
    final key = request.calculationCacheKey(
      AdhanPrayerTimeCalculator.calculatorSource.id,
    );
    final existing = await cache.read(key);
    final nowUtc = timeProvider.nowUtc();
    if (existing?.isReliableAt(nowUtc) ?? false) return existing!;
    final schedule = await calculator.loadMonth(request);
    final calculated = CachedPrayerMonthSchedule(
      cacheKey: key,
      schedule: schedule,
      cachedAtUtc: nowUtc,
    );
    await cache.write(calculated);
    return calculated;
  }

  Future<CachedPrayerMonthSchedule?> _tryCalculateAndCache(
    PrayerScheduleRequest request,
  ) async {
    try {
      return await _calculateAndCache(request);
    } on Object {
      // Automatic widget attribution must fail closed. A missing coordinate,
      // corrupt local cache, or calculator failure becomes "choose in app"
      // instead of crashing snapshot restoration or guessing a prayer.
      return null;
    }
  }
}

final class PrayerSettingsLocalDateProvider
    implements RecitationLocalDateProvider {
  const PrayerSettingsLocalDateProvider({
    required this.timeProvider,
    required this.utcOffsetMinutes,
  });

  final TimeProvider timeProvider;
  final int utcOffsetMinutes;

  @override
  LocalDate today() => LocalDate.fromLocalDateTime(
    timeProvider.nowUtc().add(Duration(minutes: utcOffsetMinutes)),
  );
}
