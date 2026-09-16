import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// Reported by the owner on 2026-09-16 and captured on video: after marking a
/// surah the manually chosen Магриб was replaced by «Выбрать намаз ·
/// Автоматически», the prayer-time strip vanished and the page jumped to the
/// top.
///
/// These run against the real database and the real provider graph on purpose.
/// Whether the resolver computes the right answer is already pinned by its own
/// tests; the question here is whether an ordinary write can make the whole
/// context disappear underneath it.
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        startupProvider.overrideWith((ref) async {}),
        timeProviderProvider.overrideWithValue(
          _FixedTimeProvider(DateTime.utc(2026, 9, 16, 4, 31)),
        ),
        localDateProvider.overrideWithValue(
          _FixedLocalDateProvider(LocalDate(2026, 9, 16)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() async {
    for (var index = 0; index < 40; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The side effect every mark has: the stored recommendation batch is
  /// versioned JSON in `app_settings`, and Drift invalidates its streams per
  /// table, so unrelated keys in that table re-emit too.
  Future<void> writeUnrelatedSetting(ProviderContainer container) => container
      .read(settingsRepositoryProvider)
      .setString(
        'recommendation_batch_probe',
        '{}',
        updatedAtUtc: DateTime.utc(2026, 9, 16, 4, 32),
      );

  group('the resolved context survives an unrelated write', () {
    test('a sticky manual override is never dropped', () async {
      final container = buildContainer();
      container
          .read(prayerContextOverrideProvider.notifier)
          .state = PrayerContextOverride(
        context: PrayerContext(prayerType: PrayerType.maghrib),
        localDate: LocalDate(2026, 9, 16),
      );
      // Home keeps this provider listened for the whole time it is on screen,
      // so the listener has to exist before anything is measured.
      final observed = <PrayerContext?>[];
      final subscription = container
          .listen<AsyncValue<PrayerContextResolution>>(
            prayerContextResolutionProvider,
            (previous, next) => observed.add(next.valueOrNull?.context),
          );
      addTearDown(subscription.close);
      await settle();
      expect(
        container.read(prayerContextResolutionProvider).valueOrNull?.context,
        PrayerContext(prayerType: PrayerType.maghrib),
        reason: 'the override must be in effect before the write',
      );
      observed.clear();

      await writeUnrelatedSetting(container);
      await settle();

      expect(
        observed,
        everyElement(PrayerContext(prayerType: PrayerType.maghrib)),
        reason:
            'a sticky override exists precisely to survive a series of marks; '
            'everything on Home is derived from this context, so one blank '
            'frame empties the routine card, the batch and the strip at once',
      );
    });

    test('a persisted manual selection is never dropped', () async {
      final container = buildContainer();
      final settings = container.read(prayerTimeSettingsRepositoryProvider);
      final base = await settings.load();
      await settings.save(
        base.copyWith(
          contextSelectionMode: PrayerContextSelectionMode.manual,
          contextModeExplicitlyChosen: true,
        ),
        updatedAtUtc: DateTime.utc(2026, 9, 16, 4),
      );
      await container
          .read(prayerRepositoryProvider)
          .saveSelectedContext(
            PrayerContext(prayerType: PrayerType.maghrib),
            updatedAtUtc: DateTime.utc(2026, 9, 16, 4),
          );
      final observed = <PrayerContext?>[];
      final subscription = container
          .listen<AsyncValue<PrayerContextResolution>>(
            prayerContextResolutionProvider,
            (previous, next) => observed.add(next.valueOrNull?.context),
          );
      addTearDown(subscription.close);
      await settle();
      expect(
        container.read(prayerContextResolutionProvider).valueOrNull?.context,
        PrayerContext(prayerType: PrayerType.maghrib),
        reason: 'the manual choice must be in effect before the write',
      );
      observed.clear();

      await writeUnrelatedSetting(container);
      await settle();

      expect(
        observed,
        everyElement(PrayerContext(prayerType: PrayerType.maghrib)),
        reason: 'a write elsewhere in app_settings is not a context change',
      );
    });
  });

  group('reading the stored context is atomic', () {
    test('a concurrent save is never observed half-written', () async {
      final repository = PrayerRepository(database);
      // The two keys are written in one transaction, but the read performs two
      // independent awaits and can straddle it. When it does, it throws
      // `Stored prayer context is incomplete.` — and that exception surfaces
      // wherever the stored context is read, including the settings stream.
      final reads = <Future<PrayerContext?>>[];
      final write = repository.saveSelectedContext(
        PrayerContext(prayerType: PrayerType.maghrib),
        updatedAtUtc: DateTime.utc(2026, 9, 16, 4),
      );
      for (var index = 0; index < 40; index += 1) {
        reads.add(repository.getSelectedContext());
      }
      await write;

      for (final read in reads) {
        await expectLater(
          read,
          completes,
          reason:
              'a reader racing an ordinary save must see the old context or '
              'the new one, never half of each',
        );
      }
    });
  });
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this.value);

  final LocalDate value;

  @override
  LocalDate today() => value;
}
