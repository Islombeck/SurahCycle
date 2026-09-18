import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

/// §E: a Qada records the day it was actually made up, separately from the day
/// it belongs to.
///
/// Written instead of a tap-through on the owner's phone. A stale screenshot
/// had already turned one intended tap into two real recitations in his
/// history; a test proves more, keeps proving it, and cannot write to anyone's
/// data.
void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCacheDatabase;

  final today = LocalDate(2026, 9, 18);

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

  Future<void> openOccurrenceSheet(WidgetTester tester) async {
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
            _FixedTimeProvider(DateTime.utc(2026, 9, 18, 9)),
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

    final advanced = find.byKey(
      const ValueKey<String>('advanced-mark-surah-surah-112'),
    );
    await _pumpUntil(tester, () => advanced.evaluate().isNotEmpty);
    await tester.ensureVisible(advanced);
    await tester.pump();
    await tester.tap(advanced);

    // No confirmed location in this fixture, so the prayer cannot be resolved
    // automatically and the picker opens first. Naming the prayer is exactly
    // what the app should insist on here.
    await _pumpUntil(tester, () => find.text('Maghrib').evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Maghrib').last);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Confirm').last);

    final occurrence = find.byKey(
      const ValueKey<String>('select-registration-occurrence'),
    );
    await _pumpUntil(tester, () => occurrence.evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(occurrence);
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('registration-qada'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> toggle(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('an ordinary record is never asked when it was made up', (
    tester,
  ) async {
    await openOccurrenceSheet(tester);

    expect(
      find.byKey(const ValueKey<String>('registration-qada-fulfilled')),
      findsNothing,
      reason: 'an ordinary record happened on its own day',
    );

    await _disposeWidgetTree(tester);
  });

  testWidgets('a Qada with a known day offers the make-up day, today first', (
    tester,
  ) async {
    await openOccurrenceSheet(tester);
    await toggle(tester, 'registration-qada');

    expect(
      find.byKey(const ValueKey<String>('registration-qada-fulfilled')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Made up on'),
      findsOneWidget,
      reason: 'the day is stated rather than hidden behind an edit button',
    );
    expect(
      find.textContaining('Sep 18'),
      findsWidgets,
      reason:
          'today is the default: praying a debt and recording it straight '
          'away is the ordinary case',
    );
    expect(
      find.byKey(const ValueKey<String>('change-qada-fulfilled-date')),
      findsOneWidget,
      reason: 'and one tap from correct for a late entry',
    );

    await _disposeWidgetTree(tester);
  });

  testWidgets('an unknown original day is not asked the same thing twice', (
    tester,
  ) async {
    await openOccurrenceSheet(tester);
    await toggle(tester, 'registration-qada');
    expect(
      find.byKey(const ValueKey<String>('registration-qada-fulfilled')),
      findsOneWidget,
    );

    await toggle(tester, 'registration-qada-origin-unknown');

    expect(
      find.byKey(const ValueKey<String>('registration-qada-fulfilled')),
      findsNothing,
      reason:
          'with no original day the record already sits on the day it was '
          'made up, so a second date field asks the same question twice',
    );

    await _disposeWidgetTree(tester);
  });

  testWidgets('turning Qada off takes the make-up day with it', (tester) async {
    await openOccurrenceSheet(tester);
    await toggle(tester, 'registration-qada');
    await toggle(tester, 'registration-qada');

    expect(
      find.byKey(const ValueKey<String>('registration-qada-fulfilled')),
      findsNothing,
    );

    await _disposeWidgetTree(tester);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  throw TestFailure('Condition was not met after 200 pumped frames.');
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
