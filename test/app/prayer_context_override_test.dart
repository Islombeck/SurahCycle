import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/domain/domain.dart';

/// A manually chosen Witr/Nafl context must survive a series of marks and only
/// ever end on an explicit action or once its own local date has passed.
void main() {
  ProviderContainer containerOn(LocalDate today) {
    final container = ProviderContainer(
      overrides: <Override>[
        localDateProvider.overrideWithValue(_FixedLocalDateProvider(today)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('no override resolves to nothing', () {
    final container = containerOn(LocalDate(2026, 9, 14));

    expect(container.read(activePrayerContextOverrideProvider), isNull);
  });

  test('an override chosen today keeps applying across marks', () {
    final container = containerOn(LocalDate(2026, 9, 14));
    final witr = PrayerContext(prayerType: PrayerType.witr);

    container.read(prayerContextOverrideProvider.notifier).state =
        PrayerContextOverride(context: witr, localDate: LocalDate(2026, 9, 14));

    // Nothing clears it between reads: marking a surah does not touch it.
    expect(container.read(activePrayerContextOverrideProvider), witr);
    expect(container.read(activePrayerContextOverrideProvider), witr);
    expect(container.read(activePrayerContextOverrideProvider), witr);
  });

  test('an explicit return to automatic clears it', () {
    final container = containerOn(LocalDate(2026, 9, 14));
    container
        .read(prayerContextOverrideProvider.notifier)
        .state = PrayerContextOverride(
      context: PrayerContext(prayerType: PrayerType.nafl),
      localDate: LocalDate(2026, 9, 14),
    );
    expect(container.read(activePrayerContextOverrideProvider), isNotNull);

    container.read(prayerContextOverrideProvider.notifier).state = null;

    expect(container.read(activePrayerContextOverrideProvider), isNull);
  });

  test('it stops applying once the local date has moved on', () {
    final container = containerOn(LocalDate(2026, 9, 15));

    container
        .read(prayerContextOverrideProvider.notifier)
        .state = PrayerContextOverride(
      context: PrayerContext(prayerType: PrayerType.witr),
      // Chosen yesterday, before midnight.
      localDate: LocalDate(2026, 9, 14),
    );

    expect(
      container.read(activePrayerContextOverrideProvider),
      isNull,
      reason: 'a sticky override must never create events for the next day',
    );
  });

  test('a Qada override is preserved exactly as chosen', () {
    final container = containerOn(LocalDate(2026, 9, 14));
    final qadaIsha = PrayerContext(prayerType: PrayerType.isha, isQada: true);

    container
        .read(prayerContextOverrideProvider.notifier)
        .state = PrayerContextOverride(
      context: qadaIsha,
      localDate: LocalDate(2026, 9, 14),
    );

    final resolved = container.read(activePrayerContextOverrideProvider);
    expect(resolved, qadaIsha);
    expect(resolved!.isQada, isTrue);
  });

  test('the override carries value equality', () {
    final first = PrayerContextOverride(
      context: PrayerContext(prayerType: PrayerType.witr),
      localDate: LocalDate(2026, 9, 14),
    );
    final same = PrayerContextOverride(
      context: PrayerContext(prayerType: PrayerType.witr),
      localDate: LocalDate(2026, 9, 14),
    );
    final otherDay = PrayerContextOverride(
      context: PrayerContext(prayerType: PrayerType.witr),
      localDate: LocalDate(2026, 9, 15),
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(otherDay));
  });
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this.value);

  final LocalDate value;

  @override
  LocalDate today() => value;
}
