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
import 'package:flutter/rendering.dart';
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
    _segmentsMeasured = 0;
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

  // **In all three languages, and that is the point.** The labels he reads are
  // the Russian ones, and they are the longest: «Как в системе» is thirteen
  // characters where English has six. A suite that only ever runs in English
  // would have called this fixed while his screen still broke the word.
  for (final locale in const <(String, List<String>)>[
    ('ru', <String>['Как в системе', 'Светлая', 'Тёмная']),
    ('en', <String>['System', 'Light', 'Dark']),
    ('uz', <String>['Tizim kabi', 'Yorug‘', 'Qorong‘i']),
  ]) {
    testWidgets('the theme selector does not break its own words in '
        '${locale.$1}', (tester) async {
      // Seen on his screen, not deduced: «Как в систем/е», «Светла/я»,
      // «Тёмна/я». Three segments, each with an icon and a word, do not fit
      // across 411 logical pixels, so Material wrapped the labels mid-word.
      //
      // Everything else in this file asserts by overflow, and **a wrap is not
      // an overflow** — the layout is legal, it is just unreadable. So this
      // one asks the question directly: was the text given less width than it
      // needs? That is the whole of what went wrong, and it is the check the
      // rest of the suite structurally cannot make.
      await _pumpPhone(tester, database, quranCache, locale: locale.$1);
      await tester.tap(
        find.byKey(const ValueKey<String>('primary-tab-settings')),
      );
      await tester.pumpAndSettle();

      for (final segment in locale.$2) {
        _expectUnwrapped(tester, segment);
      }

      await _disposeWidgetTree(tester);
    });
  }

  testWidgets('no segmented control in Settings breaks a word', (tester) async {
    // The theme selector was not the only one. Every `SegmentedButton` on
    // this screen divides the card between its segments, and Russian labels
    // are long: «Автоматически» and «Аср: стандартный» share a row two
    // segments wide and want more than it gives them.
    //
    // This walks what is actually on screen rather than naming labels, so a
    // segment added later is covered without anybody remembering to come
    // back here.
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
    }
    await _scrollToStart(tester);
    // `_scrollToEnd` measures at every step, so the walk is the assertion
    // here too. The count below is the guard against a sweep that swept
    // nothing: both of these cards hold segmented controls, and if a finder
    // ever stops matching them this fails instead of passing quietly.
    await _scrollToEnd(tester);

    expect(
      _segmentsMeasured,
      greaterThan(0),
      reason: 'a pass that measured nothing is not a pass',
    );

    await _disposeWidgetTree(tester);
  });
}

/// Fails when [text] was laid out narrower than it wants to be.
///
/// `getMaxIntrinsicWidth` is the width the paragraph would take on one line.
/// If the box it actually got is narrower, the only way the text fitted is by
/// wrapping — which is exactly the defect, and is invisible to an overflow
/// check because a wrapped line overflows nothing.
void _expectUnwrapped(WidgetTester tester, String text) =>
    _expectParagraphUnwrapped(
      tester.renderObject<RenderParagraph>(find.text(text)),
    );

void _expectParagraphUnwrapped(RenderParagraph paragraph) {
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5),
    reason:
        '"${paragraph.text.toPlainText()}" was given less width than one '
        'line of it needs',
  );
}

Future<void> _pumpPhone(
  WidgetTester tester,
  AppDatabase database,
  QuranCacheDatabase quranCache, {
  String locale = 'ru',
}) async {
  tester.view.physicalSize = _phonePhysical;
  tester.view.devicePixelRatio = _phoneRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Russian by default, because Russian is what he reads and its labels are
  // the long ones. A suite that only ever ran in English would have called
  // the theme selector fixed while his screen still broke the word.
  tester.platformDispatcher.localesTestValue = <Locale>[Locale(locale)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
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
  _expectNoWrappedSegment(tester);
  if (find.byType(Scrollable).evaluate().isEmpty) return;
  for (var step = 0; step < 20; step += 1) {
    await tester.drag(_scrollable(), const Offset(0, -400));
    await tester.pumpAndSettle();
    // Every screen, on the way past. A wrap is not an overflow, so the walk
    // alone would not see it; this is the same walk asked a second question.
    _expectNoWrappedSegment(tester);
  }
}

/// Fails when any segmented control on screen had to break a word.
///
/// By widget name, not by type: `find.byType` is invariant in the type
/// argument, so `SegmentedButton<Object?>` matches none of the concrete ones
/// in this app — and a finder that silently matches nothing is how a sweep
/// passes without sweeping.
void _expectNoWrappedSegment(WidgetTester tester) {
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString().startsWith('SegmentedButton<'),
      ),
      matching: find.byType(Text),
    ),
  )) {
    _expectParagraphUnwrapped(paragraph);
    _segmentsMeasured += 1;
  }
}

/// How many segment labels this test has actually measured.
///
/// Reset per test. One case asserts it is not zero, because the finder above
/// matches by widget name and a rename would turn the whole sweep into a
/// no-op that passes.
int _segmentsMeasured = 0;

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
