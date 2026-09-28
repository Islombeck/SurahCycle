/// Every screen, laid out at the width of his actual phone.
///
/// The region selector ran off the edge of the settings card for weeks while
/// every test of that card passed, because the card was pumped at a device
/// pixel ratio of 1: his phone's 1080 pixels, but 1080 **logical** pixels
/// across — two and a half times any phone. A card that overflows by forty
/// pixels on the device has all the room it needs on a canvas that wide.
///
/// So this one is narrow on purpose. It asserts almost nothing by hand: a
/// `RenderFlex` that overflows reports a `FlutterError` while it paints, and
/// `flutter_test` fails the test that was running when it did. Walking every
/// tab to the bottom is therefore the whole assertion.
///
/// It is deliberately separate from the behavioural suites. Those are about
/// which prayer a mark belongs to and need the extra room so the widget they
/// reach for is built without scrolling; making them narrow too would mean
/// teaching each of them to scroll, which is work about test mechanics rather
/// than about the app.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Unihertz Jelly Max: 1080×2400 physical at 2.625, so 411×914 logical.
const Size _phonePhysical = Size(1080, 2400);
const double _phoneRatio = 2.625;

void main() {
  late AppDatabase database;
  late QuranCacheDatabase quranCache;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    quranCache = QuranCacheDatabase(NativeDatabase.memory());
    await SurahRepository(database).getRotationSnapshot();
  });

  tearDown(() async {
    await database.close();
    await quranCache.close();
  });

  for (final tab in const <String>[
    'home',
    'surahs',
    'learning',
    'statistics',
    'settings',
  ]) {
    testWidgets('$tab fits a phone from top to bottom', (tester) async {
      await _pumpPhone(tester, database, quranCache);

      await tester.tap(find.byKey(ValueKey<String>('primary-tab-$tab')));
      await tester.pumpAndSettle();

      await _scrollToEnd(tester);

      await _disposeWidgetTree(tester);
    });
  }

  testWidgets('the settings cards fit a phone once they are open', (
    tester,
  ) async {
    // Collapsed, a card cannot overflow, and the region selector that started
    // this is inside one. Opening them is the case that matters.
    await _pumpPhone(tester, database, quranCache);
    await tester.tap(find.byKey(const ValueKey<String>('primary-tab-settings')));
    await tester.pumpAndSettle();

    for (final card in const <String>[
      'prayer-time-settings',
      'prayer-routine-settings',
    ]) {
      final finder = find.byKey(ValueKey<String>(card));
      await _scrollUntilFound(tester, finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      // Back to the top for the next one, which is above whatever the last
      // expansion pushed off screen.
      await _scrollToStart(tester);
    }

    await _disposeWidgetTree(tester);
  });
}

Future<void> _pumpPhone(
  WidgetTester tester,
  AppDatabase database,
  QuranCacheDatabase quranCache,
) async {
  tester.view.physicalSize = _phonePhysical;
  tester.view.devicePixelRatio = _phoneRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        quranCacheDatabaseProvider.overrideWithValue(quranCache),
        startupProvider.overrideWith((ref) async {}),
        timeProviderProvider.overrideWithValue(
          _FixedTimeProvider(DateTime.utc(2026, 8, 25, 12)),
        ),
        // No network in a layout test, and an unavailable schedule is a state
        // the screens have to render anyway.
        prayerTodayScheduleProvider.overrideWith(
          (ref) async => throw StateError('Fixture schedule unavailable.'),
        ),
      ],
      child: const MurajaahApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _scrollable() {
  for (final type in <Type>[CustomScrollView, ListView, SingleChildScrollView]) {
    final finder = find.byType(type);
    if (finder.evaluate().isNotEmpty) return finder.first;
  }
  return find.byType(Scrollable).first;
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  if (find.byType(Scrollable).evaluate().isEmpty) return;
  for (var step = 0; step < 20; step += 1) {
    await tester.drag(_scrollable(), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollToStart(WidgetTester tester) async {
  if (find.byType(Scrollable).evaluate().isEmpty) return;
  for (var step = 0; step < 24; step += 1) {
    await tester.drag(_scrollable(), const Offset(0, 400));
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollUntilFound(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(_scrollable(), const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  throw TestFailure(
    'Never reached ${target.describeMatch(Plurality.one)} while scrolling.',
  );
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Drift cascades zero-duration cleanup timers while watched queries close.
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this._nowUtc);

  final DateTime _nowUtc;

  @override
  DateTime nowUtc() => _nowUtc;
}
