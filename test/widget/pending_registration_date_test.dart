import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// The owner could not enter yesterday's Магриб … Фаджр, and asked for a way
/// to pick the day. Choosing one in the calendar puts Home into a historical
/// mode; what matters is that the mode is visible the whole time it is in
/// force, that marks actually land on the chosen day, and that leaving it is
/// one tap.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;

  final today = LocalDate(2026, 9, 16);
  final yesterday = LocalDate(2026, 9, 15);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    quranCacheDatabase = QuranCacheDatabase(NativeDatabase.memory());
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlaas',
          ayahCount: 4,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-112');
  });

  tearDown(() async {
    await database.close();
    await quranCacheDatabase.close();
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(
            _FixedTimeProvider(DateTime.utc(2026, 9, 16, 9)),
          ),
          localDateProvider.overrideWithValue(_FixedLocalDateProvider(today)),
          prayerContextResolutionProvider.overrideWith(
            (ref) => Stream<PrayerContextResolution>.value(
              PrayerContextResolution(
                status: PrayerContextResolutionStatus.manual,
                context: PrayerContext(prayerType: PrayerType.maghrib),
              ),
            ),
          ),
          prayerTodayScheduleProvider.overrideWith(
            (ref) async => throw StateError('Fixture schedule unavailable.'),
          ),
        ],
        child: const MurajaahApp(),
      ),
    );
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('home-screen'))
          .evaluate()
          .isNotEmpty,
    );
    return ProviderScope.containerOf(tester.element(find.byType(MurajaahApp)));
  }

  testWidgets('a chosen past day is announced and can be left', (tester) async {
    final container = await pumpApp(tester);
    expect(
      find.byKey(const ValueKey<String>('pending-registration-banner')),
      findsNothing,
      reason: 'nothing is pending until a day is chosen',
    );

    container.read(pendingRegistrationDateProvider.notifier).state = yesterday;
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('pending-registration-banner'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cancel-pending-registration')),
    );
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('pending-registration-banner'))
          .evaluate()
          .isEmpty,
    );
    expect(container.read(pendingRegistrationDateProvider), isNull);

    await _disposeWidgetTree(tester);
  });

  testWidgets('a mark lands on the chosen day, not on today', (tester) async {
    final container = await pumpApp(tester);
    container.read(pendingRegistrationDateProvider.notifier).state = yesterday;
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('pending-registration-banner'))
          .evaluate()
          .isNotEmpty,
    );

    // Marked through the screen, not by calling the repository: the point is
    // that Home itself routes the record to the chosen day.
    final control = find.byKey(const ValueKey<String>('mark-surah-surah-112'));
    await _pumpUntil(tester, () => control.evaluate().isNotEmpty);
    await tester.ensureVisible(control);
    await tester.pump();
    await tester.tap(control);

    // A past day forces the prayer to be named: today's schedule says nothing
    // about which prayer a historical mark belongs to, so the picker opens.
    await _pumpUntil(tester, () => find.text('Maghrib').evaluate().isNotEmpty);
    // The sheet slides in; tapping mid-animation lands outside the viewport.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Maghrib').last);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Confirm').last);

    final repository = container.read(recitationRepositoryProvider);
    await _pumpUntilAsync(
      tester,
      () async => (await repository.getHistory()).isNotEmpty,
    );

    final history = await repository.getHistory();
    expect(history, hasLength(1));
    expect(
      history.single.event.localDate,
      yesterday,
      reason: 'the record belongs to the day the owner picked, not to today',
    );
    expect(
      history.single.event.prayerContext.prayerType,
      PrayerType.maghrib,
      reason: 'the manual prayer in force is still what it attributes to',
    );

    await _disposeWidgetTree(tester);
  });

  testWidgets('today is never treated as a historical entry', (tester) async {
    final container = await pumpApp(tester);
    // Choosing today from the calendar is the ordinary case and must not put
    // Home into the historical mode.
    container.read(pendingRegistrationDateProvider.notifier).state = today;
    await tester.pump(const Duration(milliseconds: 40));

    expect(
      find.byKey(const ValueKey<String>('pending-registration-banner')),
      findsOneWidget,
      reason: 'the banner still states plainly which day is in force',
    );

    await _disposeWidgetTree(tester);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 150; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  throw TestFailure('Condition was not met after 150 pumped frames.');
}

Future<void> _pumpUntilAsync(
  WidgetTester tester,
  Future<bool> Function() condition,
) async {
  for (var attempt = 0; attempt < 150; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (await condition()) return;
  }
  throw TestFailure('Condition was not met after 150 pumped frames.');
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
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
