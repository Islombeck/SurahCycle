import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/app/murajaah_app.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/prayer_times/prayer_times.dart';

import '../features/prayer_times/prayer_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen opens', (tester) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);

    await fixture.pumpApp(tester);

    expect(find.byKey(const ValueKey<String>('home-screen')), findsOneWidget);
    await _disposeWidgetTree(tester);
  });

  testWidgets('active surahs are displayed', (tester) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-b', number: 2, name: 'Test Surah B'),
    );

    await fixture.pumpApp(tester);

    await _pumpUntil(
      tester,
      () async => find
          .byKey(const ValueKey<String>('active-surah-surah-a'))
          .evaluate()
          .isNotEmpty,
    );

    expect(
      find.byKey(const ValueKey<String>('active-surah-surah-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('active-surah-surah-b')),
      findsOneWidget,
    );
    expect(find.text('Test Surah A'), findsWidgets);
    expect(find.text('Test Surah B'), findsWidgets);
    expect(find.byIcon(Icons.add_task), findsNothing);

    final markControl = find.byKey(
      const ValueKey<String>('mark-surah-surah-a'),
    );
    final markSize = tester.getSize(markControl);
    expect(markSize.width, greaterThanOrEqualTo(48));
    expect(markSize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.widgetWithText(Chip, 'Test Surah A'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(await fixture.eventCount(), 0);

    final tile = find.byKey(const ValueKey<String>('active-surah-surah-a'));
    await tester.tap(
      find.descendant(of: tile, matching: find.text('Test Surah A')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(await fixture.eventCount(), 0);
    await _disposeWidgetTree(tester);
  });

  testWidgets(
    'split mark opens coverage sheet without writing before confirm',
    (tester) async {
      final fixture = await _WidgetFixture.create();
      addTearDown(fixture.close);
      await fixture.addActiveSplitSurah(
        _descriptor(
          id: 'split-surah',
          number: 101,
          name: 'Split Surah',
          ayahCount: 12,
        ),
        partCount: 3,
      );
      await fixture.pumpApp(tester);

      final before = await fixture.surahs.getRotationSnapshot();
      await _openCoverageSheet(tester, 'split-surah');

      expect(
        find.byKey(const ValueKey<String>('coverage-whole-surah')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
        findsOneWidget,
      );
      expect(await fixture.eventCount(), 0);

      await tester.tap(find.byKey(const ValueKey<String>('coverage-part-1')));
      await tester.pump();
      expect(await fixture.eventCount(), 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await fixture.eventCount(), 0);
      expect(await fixture.surahs.getRotationSnapshot(), before);
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('one-part scheme remains an immediate single-tap action', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(
        id: 'unsplit-surah',
        number: 101,
        name: 'Unsplit Surah',
        ayahCount: 12,
      ),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'unsplit-surah');

    await tester.tap(_markControl('unsplit-surah'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
      findsNothing,
    );
    await _pumpUntil(tester, () async => await fixture.eventCount() == 1);

    final history = await fixture.recitations.getHistory();
    final entry = history.single;
    expect(entry.event.rakaatSpanCount, 1);
    expect(entry.coveredParts, hasLength(1));
    expect(entry.event.coveredPartIds, <String>[entry.coveredParts.single.id]);
    expect(entry.isWholeSurah, isTrue);
    await _disposeWidgetTree(tester);
  });

  testWidgets('one-tap resolves automatic prayer at action time', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(
        id: 'boundary-surah',
        number: 101,
        name: 'Boundary Surah',
        ayahCount: 12,
      ),
    );
    final clock = _MutableTimeProvider(_utcForTashkent(2026, 8, 25, 17, 8, 59));
    await fixture.pumpAutomaticApp(tester, clock);
    await _pumpUntil(
      tester,
      () async => find.text('Dhuhr').evaluate().isNotEmpty,
    );
    final callback = tester
        .widget<IconButton>(_markControl('boundary-surah'))
        .onPressed!;

    // Invoke the callback captured by the pre-boundary build without first
    // allowing the presentation timer to rebuild Home.
    clock.value = _utcForTashkent(2026, 8, 25, 17, 9);
    callback();
    await _pumpUntil(tester, () async => await fixture.eventCount() == 1);

    final event = (await fixture.recitations.getHistory()).single.event;
    expect(event.prayerContext.prayerType, PrayerType.asr);
    expect(event.localDate, LocalDate(2026, 8, 25));
    await _disposeWidgetTree(tester);
  });

  testWidgets('Previous prayer is recalculated while the sheet is open', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(
        id: 'previous-boundary-surah',
        number: 101,
        name: 'Previous Boundary Surah',
        ayahCount: 12,
      ),
    );
    final clock = _MutableTimeProvider(_utcForTashkent(2026, 8, 25, 17, 8, 50));
    await fixture.pumpAutomaticApp(tester, clock);
    await _pumpUntil(
      tester,
      () async => find.text('Dhuhr').evaluate().isNotEmpty,
    );
    await _openAdvancedCoverageSheet(tester, 'previous-boundary-surah');
    await _openOccurrenceSheet(tester);

    clock.value = _utcForTashkent(2026, 8, 25, 17, 9, 10);
    await tester.tap(
      find.byKey(const ValueKey<String>('registration-previous-prayer')),
    );
    await tester.pump();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('confirm-registration-occurrence')),
      settle: true,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
    );
    await _pumpUntil(tester, () async => await fixture.eventCount() == 1);

    final event = (await fixture.recitations.getHistory()).single.event;
    expect(event.prayerContext.prayerType, PrayerType.dhuhr);
    expect(event.localDate, LocalDate(2026, 8, 25));
    await _disposeWidgetTree(tester);
  });

  testWidgets('one-part advanced action opens recitation options', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(
        id: 'unsplit-surah',
        number: 101,
        name: 'Unsplit Surah',
        ayahCount: 12,
      ),
    );
    await fixture.pumpApp(tester);

    await _openAdvancedCoverageSheet(tester, 'unsplit-surah');

    expect(
      find.byKey(const ValueKey<String>('rakaat-span-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('select-registration-occurrence')),
      findsOneWidget,
    );
    expect(await fixture.eventCount(), 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await fixture.eventCount(), 0);
    await _disposeWidgetTree(tester);
  });

  testWidgets(
    'Yesterday and Witr preserve occurrence day separately from entry time',
    (tester) async {
      final fixture = await _WidgetFixture.create();
      addTearDown(fixture.close);
      await fixture.addActiveSurah(
        _descriptor(
          id: 'historical-surah',
          number: 101,
          name: 'Historical Surah',
          ayahCount: 12,
        ),
      );
      await fixture.pumpApp(tester);
      await _openAdvancedCoverageSheet(tester, 'historical-surah');
      await _openOccurrenceSheet(tester);

      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('registration-yesterday')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('registration-prayer-witr')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('confirm-registration-occurrence')),
        settle: true,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
      );
      await _pumpUntil(tester, () async => await fixture.eventCount() == 1);

      final event = (await fixture.recitations.getHistory()).single.event;
      expect(event.prayerContext.prayerType, PrayerType.witr);
      expect(event.prayerContext.isQada, isFalse);
      expect(event.localDate, LocalDate(2026, 8, 23));
      expect(event.createdAtUtc, fixture.now);
      expect(event.rakaatSpanCount, 1);
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('a past prayer is Qada only when explicitly selected', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(
        id: 'qada-surah',
        number: 101,
        name: 'Qada Surah',
        ayahCount: 12,
      ),
    );
    await fixture.pumpApp(tester);
    await _openAdvancedCoverageSheet(tester, 'qada-surah');
    await _openOccurrenceSheet(tester);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('registration-yesterday')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('registration-qada')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('confirm-registration-occurrence')),
      settle: true,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
    );
    await _pumpUntil(tester, () async => await fixture.eventCount() == 1);

    final event = (await fixture.recitations.getHistory()).single.event;
    expect(event.prayerContext.prayerType, PrayerType.fajr);
    expect(event.prayerContext.isQada, isTrue);
    expect(event.localDate, LocalDate(2026, 8, 23));
    expect(event.createdAtUtc, fixture.now);
    await _disposeWidgetTree(tester);
  });

  const coverageCases =
      <
        ({
          String label,
          Set<int> selectedPartNumbers,
          int rakaatSpanCount,
          bool useWholeControl,
        })
      >[
        (
          label: 'one part and one rakaat',
          selectedPartNumbers: <int>{2},
          rakaatSpanCount: 1,
          useWholeControl: false,
        ),
        (
          label: 'multiple parts and two rakaat',
          selectedPartNumbers: <int>{1, 3},
          rakaatSpanCount: 2,
          useWholeControl: false,
        ),
        (
          label: 'whole surah and three rakaat',
          selectedPartNumbers: <int>{1, 2, 3},
          rakaatSpanCount: 3,
          useWholeControl: true,
        ),
        (
          label: 'one part and four rakaat',
          selectedPartNumbers: <int>{3},
          rakaatSpanCount: 4,
          useWholeControl: false,
        ),
      ];
  for (final coverageCase in coverageCases) {
    testWidgets(
      'split confirmation persists ${coverageCase.label} exactly once',
      (tester) async {
        final fixture = await _WidgetFixture.create();
        addTearDown(fixture.close);
        final scheme = await fixture.addActiveSplitSurah(
          _descriptor(
            id: 'split-surah',
            number: 101,
            name: 'Split Surah',
            ayahCount: 12,
          ),
          partCount: 3,
        );
        await fixture.pumpApp(tester);
        await _openCoverageSheet(tester, 'split-surah');

        if (coverageCase.useWholeControl) {
          await tester.tap(
            find.byKey(const ValueKey<String>('coverage-part-2')),
          );
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey<String>('coverage-whole-surah')),
          );
          await tester.pump();
        } else {
          for (final part in scheme.parts) {
            if (!coverageCase.selectedPartNumbers.contains(part.partNumber)) {
              await tester.tap(
                find.byKey(
                  ValueKey<String>('coverage-part-${part.partNumber}'),
                ),
              );
              await tester.pump();
            }
          }
        }
        await _selectRakaatSpan(tester, coverageCase.rakaatSpanCount);
        expect(await fixture.eventCount(), 0);

        await tester.tap(
          find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
        );
        await _pumpUntil(tester, () async => await fixture.eventCount() == 1);
        await _pumpFor(tester, const Duration(milliseconds: 300));

        final history = await fixture.recitations.getHistory();
        final entry = history.single;
        final expectedPartIds = <String>[
          for (final part in scheme.parts)
            if (coverageCase.selectedPartNumbers.contains(part.partNumber))
              part.id,
        ];
        expect(await fixture.eventCount(), 1);
        expect(entry.event.rotationSchemeId, scheme.id);
        expect(entry.event.coveredPartIds, expectedPartIds);
        expect(entry.coveredParts.map((part) => part.id), expectedPartIds);
        expect(entry.event.rakaatSpanCount, coverageCase.rakaatSpanCount);
        expect(
          entry.isWholeSurah,
          coverageCase.selectedPartNumbers.length == scheme.parts.length,
        );
        await _disposeWidgetTree(tester);
      },
    );
  }

  testWidgets(
    'empty split selection disables confirmation and writes nothing',
    (tester) async {
      final fixture = await _WidgetFixture.create();
      addTearDown(fixture.close);
      final scheme = await fixture.addActiveSplitSurah(
        _descriptor(
          id: 'split-surah',
          number: 101,
          name: 'Split Surah',
          ayahCount: 12,
        ),
        partCount: 3,
      );
      await fixture.pumpApp(tester);
      await _openCoverageSheet(tester, 'split-surah');

      for (final part in scheme.parts) {
        await tester.tap(
          find.byKey(ValueKey<String>('coverage-part-${part.partNumber}')),
        );
        await tester.pump();
      }
      final confirm = find.byKey(
        const ValueKey<String>('confirm-recitation-coverage'),
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 300));
      expect(await fixture.eventCount(), 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('rapid split mark taps open one sheet and create one event', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSplitSurah(
      _descriptor(
        id: 'split-surah',
        number: 101,
        name: 'Split Surah',
        ayahCount: 12,
      ),
      partCount: 3,
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'split-surah');

    final onPressed = tester
        .widget<IconButton>(_markControl('split-surah'))
        .onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('coverage-whole-surah')),
      findsOneWidget,
    );
    expect(await fixture.eventCount(), 0);

    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
    );
    await _pumpUntil(tester, () async => await fixture.eventCount() == 1);
    await _pumpFor(tester, const Duration(milliseconds: 500));
    expect(await fixture.eventCount(), 1);
    await _disposeWidgetTree(tester);
  });

  testWidgets(
    'scheme editor previews presets, custom count, and manual ranges',
    (tester) async {
      final fixture = await _WidgetFixture.create();
      addTearDown(fixture.close);
      await fixture.addActiveSurah(
        _descriptor(
          id: 'scheme-surah',
          number: 101,
          name: 'Scheme Surah',
          ayahCount: 10,
        ),
      );
      await fixture.pumpApp(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('primary-tab-surahs')),
      );
      await _pumpUntil(
        tester,
        () async => find
            .byKey(const ValueKey<String>('mastered-scheme-surah'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('mastered-scheme-surah')),
      );
      await tester.pumpAndSettle();

      final editButton = find.widgetWithIcon(FilledButton, Icons.call_split);
      await tester.scrollUntilVisible(
        editButton,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      final selector = find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<int>,
      );
      expect(selector, findsOneWidget);
      final sheet = find.ancestor(
        of: selector,
        matching: find.byType(SingleChildScrollView),
      );
      expect(sheet, findsOneWidget);

      for (var count = 1; count <= 4; count += 1) {
        await tester.tap(
          find.descendant(of: selector, matching: find.text('$count')),
        );
        await tester.pump();
        final ranges = suggestEvenRanges(ayahCount: 10, partCount: count);
        final sheetText = tester
            .widgetList<Text>(
              find.descendant(of: sheet, matching: find.byType(Text)),
            )
            .map((widget) => widget.data)
            .whereType<String>()
            .join(' | ');
        for (final range in ranges) {
          expect(
            find.descendant(
              of: sheet,
              matching: find.textContaining(
                '${range.startAyah}\u2013${range.endAyah}',
              ),
            ),
            findsOneWidget,
            reason: 'Visible sheet text: $sheetText',
          );
        }
      }

      await tester.tap(
        find.descendant(of: selector, matching: find.text('Custom')),
      );
      await tester.pump();
      final customCount = find.byKey(
        const ValueKey<String>('custom-part-count'),
      );
      expect(customCount, findsOneWidget);
      await tester.enterText(customCount, '5');
      await tester.pump();
      final customRanges = suggestEvenRanges(ayahCount: 10, partCount: 5);
      for (final range in customRanges) {
        expect(
          find.descendant(
            of: sheet,
            matching: find.textContaining(
              '${range.startAyah}\u2013${range.endAyah}',
            ),
          ),
          findsOneWidget,
        );
      }

      await tester.tap(find.descendant(of: selector, matching: find.text('3')));
      await tester.pump();
      await tester.tap(
        find.descendant(of: sheet, matching: find.byType(SwitchListTile)),
      );
      await tester.pump();
      final boundaries = find.descendant(
        of: sheet,
        matching: find.byType(TextField),
      );
      expect(boundaries, findsNWidgets(2));

      await tester.enterText(boundaries.at(0), '2');
      await tester.enterText(boundaries.at(1), '8');
      await tester.pump();
      for (final range in <String>['1\u20132', '3\u20138', '9\u201310']) {
        expect(
          find.descendant(of: sheet, matching: find.textContaining(range)),
          findsOneWidget,
        );
      }
      final save = find.descendant(
        of: sheet,
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tester.enterText(boundaries.at(0), '9');
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(
        find.descendant(of: sheet, matching: find.textContaining('1\u20139')),
        findsNothing,
      );
      expect(await fixture.eventCount(), 0);
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('registration changes state and snackbar Undo restores it', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.pumpApp(tester);

    await _pumpUntil(
      tester,
      () async => find
          .byKey(const ValueKey<String>('mark-surah-surah-a'))
          .evaluate()
          .isNotEmpty,
    );

    final before = await fixture.surahs.getRotationSnapshot();
    expect(before.rotationTarget, 1);
    expect(before.surahById('surah-a').totalRecitations, 0);

    await tester.tap(find.byKey(const ValueKey<String>('mark-surah-surah-a')));
    await _pumpUntil(
      tester,
      () async =>
          (await fixture.surahs.getRotationSnapshot())
              .surahById('surah-a')
              .totalRecitations ==
          1,
    );

    final registered = await fixture.surahs.getRotationSnapshot();
    expect(registered.surahById('surah-a').totalRecitations, 1);
    expect(registered.surahById('surah-a').rotationScore, 1);
    expect(registered.rotationTarget, 2);
    expect(
      find.byKey(const ValueKey<String>('undo-recitation')),
      findsOneWidget,
    );
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.persist, isFalse);
    expect((snackBar.content as Text).data, isNotEmpty);
    expect(snackBar.action?.label, isNotEmpty);

    tester
        .widget<SnackBarAction>(
          find.byKey(const ValueKey<String>('undo-recitation')),
        )
        .onPressed();
    await tester.pump();
    await _pumpUntil(
      tester,
      () async =>
          (await fixture.surahs.getRotationSnapshot())
              .surahById('surah-a')
              .totalRecitations ==
          0,
    );

    final restored = await fixture.surahs.getRotationSnapshot();
    expect(restored, before);
    await _disposeWidgetTree(tester);
  });

  testWidgets('rapid taps coalesce while the same surah is in flight', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'surah-a');

    final gate = await fixture.holdDatabaseTransaction();
    try {
      final markControl = find.byKey(
        const ValueKey<String>('mark-surah-surah-a'),
      );
      await tester.tap(markControl);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('mark-surah-busy-surah-a')),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(markControl).onPressed, isNull);

      await tester.tapAt(tester.getCenter(markControl));
      await tester.pump();
    } finally {
      gate.release();
      await gate.done;
    }

    await _pumpUntil(tester, () async => await fixture.eventCount() == 1);
    expect(await fixture.eventCount(), 1);
    await _disposeWidgetTree(tester);
  });

  testWidgets('a normal tap after completion creates a second event', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'surah-a');

    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 1);
    await _pumpUntil(tester, () async {
      final control = find.byKey(const ValueKey<String>('mark-surah-surah-a'));
      return control.evaluate().isNotEmpty &&
          tester.widget<IconButton>(control).onPressed != null;
    });
    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 2);

    expect(await fixture.eventCount(), 2);
    await _disposeWidgetTree(tester);
  });

  testWidgets('ahead badges and due presentation follow the global target', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-b', number: 2, name: 'Test Surah B'),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'surah-a');

    expect(_dueCountText(tester), contains('2'));
    expect(find.widgetWithText(Chip, 'Test Surah A'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Test Surah B'), findsOneWidget);

    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 1);
    await _pumpUntil(
      tester,
      () async => find.widgetWithText(Chip, 'Test Surah A').evaluate().isEmpty,
    );
    expect(_dueCountText(tester), contains('1'));
    expect(find.widgetWithText(Chip, 'Test Surah A'), findsNothing);
    expect(find.widgetWithText(Chip, 'Test Surah B'), findsOneWidget);
    expect(_markIcon('surah-a', Icons.check), findsOneWidget);

    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 2);
    await _pumpUntil(
      tester,
      () async => _markText('surah-a', '-x').evaluate().isNotEmpty,
    );
    expect(_markText('surah-a', '-x'), findsOneWidget);

    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 3);
    await _pumpUntil(
      tester,
      () async => _markText('surah-a', '-2x').evaluate().isNotEmpty,
    );
    expect(_markText('surah-a', '-2x'), findsOneWidget);

    await _tapMarkAndWait(
      tester,
      fixture,
      'surah-b',
      expectedEvents: 4,
      invokeDirectly: true,
    );
    await _pumpUntil(
      tester,
      () async => _markText('surah-a', '-x').evaluate().isNotEmpty,
    );
    expect(_markText('surah-a', '-2x'), findsNothing);
    expect(_markText('surah-a', '-x'), findsOneWidget);

    await _tapMarkAndWait(
      tester,
      fixture,
      'surah-b',
      expectedEvents: 5,
      invokeDirectly: true,
    );
    await _pumpUntil(
      tester,
      () async => _markText('surah-a', '-x').evaluate().isEmpty,
    );
    expect(_markText('surah-a', '-x'), findsNothing);
    expect(_markIcon('surah-a', Icons.check), findsOneWidget);
    await _disposeWidgetTree(tester);
  });

  testWidgets('recitation snackbar expires after the explicit window', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'surah-a');
    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 1);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('undo-recitation')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.byKey(const ValueKey<String>('undo-recitation')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('undo-recitation')), findsNothing);
    expect(await fixture.eventCount(), 1);
    await _disposeWidgetTree(tester);
  });

  testWidgets('primary tab navigation dismisses the recitation snackbar', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'surah-a');
    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 1);

    expect(
      find.byKey(const ValueKey<String>('undo-recitation')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('primary-tab-statistics')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('undo-recitation')), findsNothing);
    expect(await fixture.eventCount(), 1);
    await _disposeWidgetTree(tester);
  });

  testWidgets(
    'an in-flight completion does not resurrect Undo on another tab',
    (tester) async {
      final fixture = await _WidgetFixture.create();
      addTearDown(fixture.close);
      await fixture.addActiveSurah(
        _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
      );
      await fixture.pumpApp(tester);
      await _waitForMarkControl(tester, 'surah-a');

      final gate = await fixture.holdDatabaseTransaction();
      try {
        await tester.tap(_markControl('surah-a'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('mark-surah-busy-surah-a')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('primary-tab-statistics')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const ValueKey<String>('undo-recitation')),
          findsNothing,
        );
      } finally {
        gate.release();
        await gate.done;
      }

      await _pumpUntil(tester, () async => await fixture.eventCount() == 1);
      await _pumpFor(tester, const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey<String>('undo-recitation')),
        findsNothing,
      );
      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('a new snackbar replaces the old token and stale Undo is safe', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-b', number: 2, name: 'Test Surah B'),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'surah-a');

    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 1);
    await _pumpUntil(
      tester,
      () async => find.byType(SnackBar).evaluate().length == 1,
    );
    final oldSnackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final oldAction = tester.widget<SnackBarAction>(
      find.byKey(const ValueKey<String>('undo-recitation')),
    );

    await _tapMarkAndWait(
      tester,
      fixture,
      'surah-b',
      expectedEvents: 2,
      invokeDirectly: true,
    );
    await _pumpUntil(tester, () async {
      final bars = find.byType(SnackBar);
      return bars.evaluate().length == 1 &&
          tester.widget<SnackBar>(bars).key != oldSnackBar.key;
    });
    expect(find.byType(SnackBar), findsOneWidget);

    oldAction.onPressed();
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(await fixture.eventCount(), 2);

    tester
        .widget<SnackBarAction>(
          find.byKey(const ValueKey<String>('undo-recitation')),
        )
        .onPressed();
    await tester.pump();
    await _pumpUntil(tester, () async => await fixture.eventCount() == 1);
    final history = await fixture.recitations.getHistory();
    expect(history.single.event.surahId, 'surah-a');
    await _disposeWidgetTree(tester);
  });

  testWidgets('disposing with a visible snackbar leaves no delayed exception', (
    tester,
  ) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    await fixture.addActiveSurah(
      _descriptor(id: 'surah-a', number: 101, name: 'Test Surah A'),
    );
    await fixture.pumpApp(tester);
    await _waitForMarkControl(tester, 'surah-a');
    await _tapMarkAndWait(tester, fixture, 'surah-a', expectedEvents: 1);
    expect(
      find.byKey(const ValueKey<String>('undo-recitation')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('current learning card is displayed', (tester) async {
    final fixture = await _WidgetFixture.create();
    addTearDown(fixture.close);
    final descriptor = _descriptor(
      id: 'learning-surah',
      number: 3,
      name: 'Test Learning Surah',
    );
    await fixture.surahs.upsertCatalog(<SurahDescriptor>[descriptor]);
    await fixture.learning.saveState(
      LearningSurahState(
        id: 'learning-state',
        surahId: descriptor.id,
        ayahCount: descriptor.ayahCount,
        stage: LearningStage.newAyah(1),
        lastLearningActivityAtUtc: fixture.now,
      ),
    );

    await fixture.pumpApp(tester);

    await _pumpUntil(
      tester,
      () async => find
          .byKey(const ValueKey<String>('learning-card'))
          .evaluate()
          .isNotEmpty,
    );

    expect(find.byKey(const ValueKey<String>('learning-card')), findsOneWidget);
    expect(find.text('Test Learning Surah'), findsOneWidget);
    await _disposeWidgetTree(tester);
  });
}

SurahDescriptor _descriptor({
  required String id,
  required int number,
  required String name,
  int ayahCount = 3,
}) => SurahDescriptor(
  id: id,
  surahNumber: number,
  officialName: name,
  ayahCount: ayahCount,
);

Finder _markControl(String surahId) =>
    find.byKey(ValueKey<String>('mark-surah-$surahId'));

Finder _markText(String surahId, String value) =>
    find.descendant(of: _markControl(surahId), matching: find.text(value));

Finder _markIcon(String surahId, IconData icon) =>
    find.descendant(of: _markControl(surahId), matching: find.byIcon(icon));

String? _dueCountText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey<String>('due-surah-count')))
    .data;

Future<void> _waitForMarkControl(WidgetTester tester, String surahId) =>
    _pumpUntil(tester, () async => _markControl(surahId).evaluate().isNotEmpty);

Future<void> _openCoverageSheet(WidgetTester tester, String surahId) async {
  await _waitForMarkControl(tester, surahId);
  await tester.tap(_markControl(surahId));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
    findsOneWidget,
  );
}

Future<void> _openAdvancedCoverageSheet(
  WidgetTester tester,
  String surahId,
) async {
  await _waitForMarkControl(tester, surahId);
  await _tapVisible(
    tester,
    find.byKey(ValueKey<String>('advanced-mark-surah-$surahId')),
    settle: true,
  );
  expect(
    find.byKey(const ValueKey<String>('confirm-recitation-coverage')),
    findsOneWidget,
  );
}

Future<void> _openOccurrenceSheet(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.byKey(const ValueKey<String>('select-registration-occurrence')),
    settle: true,
  );
  expect(
    find.byKey(const ValueKey<String>('confirm-registration-occurrence')),
    findsOneWidget,
  );
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder, {
  bool settle = false,
}) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _selectRakaatSpan(WidgetTester tester, int count) async {
  final selector = find.byKey(const ValueKey<String>('rakaat-span-selector'));
  final segment = find.descendant(of: selector, matching: find.text('$count'));
  expect(segment, findsOneWidget);
  await tester.tap(segment);
  await tester.pump();
}

Future<void> _tapMarkAndWait(
  WidgetTester tester,
  _WidgetFixture fixture,
  String surahId, {
  required int expectedEvents,
  bool invokeDirectly = false,
}) async {
  await _pumpUntil(tester, () async {
    final control = _markControl(surahId);
    return control.evaluate().isNotEmpty &&
        tester.widget<IconButton>(control).onPressed != null;
  });
  final control = _markControl(surahId);
  if (invokeDirectly) {
    tester.widget<IconButton>(control).onPressed!();
    await tester.pump();
  } else {
    await tester.ensureVisible(control);
    await tester.pump();
    await tester.tap(control);
  }
  await _pumpUntil(
    tester,
    () async => await fixture.eventCount() == expectedEvents,
  );
}

final class _WidgetFixture {
  _WidgetFixture._({
    required this.database,
    required this.quranCacheDatabase,
    required this.now,
  }) : surahs = SurahRepository(database),
       learning = LearningRepository(database),
       recitations = RecitationRepository(database);

  static Future<_WidgetFixture> create() async {
    final fixture = _WidgetFixture._(
      database: AppDatabase(NativeDatabase.memory()),
      quranCacheDatabase: QuranCacheDatabase(NativeDatabase.memory()),
      now: DateTime.utc(2026, 8, 24, 10),
    );
    // Open and migrate before ProviderScope begins watching the database.
    await fixture.surahs.getRotationSnapshot();
    await PrayerRepository(fixture.database).saveSelectedContext(
      PrayerContext(prayerType: PrayerType.fajr),
      updatedAtUtc: fixture.now,
    );
    return fixture;
  }

  final AppDatabase database;
  final QuranCacheDatabase quranCacheDatabase;
  final DateTime now;
  final SurahRepository surahs;
  final LearningRepository learning;
  final RecitationRepository recitations;

  Future<void> addActiveSurah(SurahDescriptor descriptor) async {
    await surahs.upsertCatalog(<SurahDescriptor>[descriptor]);
    await surahs.addMastered(descriptor.id);
  }

  Future<SurahRotationScheme> addActiveSplitSurah(
    SurahDescriptor descriptor, {
    required int partCount,
  }) async {
    await addActiveSurah(descriptor);
    final current = (await surahs.getRotationSnapshot()).surahById(
      descriptor.id,
    );
    final proposed = SurahRotationScheme.evenlySplit(
      id: '${descriptor.id}-scheme-v${current.rotationScheme.version + 1}',
      surahId: descriptor.id,
      version: current.rotationScheme.version + 1,
      ayahCount: descriptor.ayahCount,
      partCount: partCount,
    );
    final updated = await surahs.changeRotationScheme(
      surahId: descriptor.id,
      proposedScheme: proposed,
      createdAtUtc: now,
    );
    return updated.surahById(descriptor.id).rotationScheme;
  }

  Future<int> eventCount() async => (await recitations.getHistory()).length;

  Future<_DatabaseTransactionGate> holdDatabaseTransaction() async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final done = database.transaction(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    return _DatabaseTransactionGate(releaseCompleter: release, done: done);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(_FixedTimeProvider(now)),
          localDateProvider.overrideWithValue(
            _FixedLocalDateProvider(LocalDate(2026, 8, 24)),
          ),
          prayerTimeSettingsProvider.overrideWith(
            (ref) => Stream<PrayerTimeSettings>.value(
              PrayerTimeSettings(
                location: testTashkentLocation(),
                contextSelectionMode: PrayerContextSelectionMode.manual,
                contextModeExplicitlyChosen: true,
              ),
            ),
          ),
          prayerContextResolutionProvider.overrideWith(
            (ref) => Stream<PrayerContextResolution>.value(
              PrayerContextResolution(
                status: PrayerContextResolutionStatus.manual,
                context: PrayerContext(prayerType: PrayerType.fajr),
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
      () async => find
          .byKey(const ValueKey<String>('home-screen'))
          .evaluate()
          .isNotEmpty,
    );
  }

  Future<void> pumpAutomaticApp(
    WidgetTester tester,
    _MutableTimeProvider timeProvider,
  ) async {
    final settings = PrayerTimeSettings(
      location: testTashkentLocation(),
      locationConfirmed: true,
      contextSelectionMode: PrayerContextSelectionMode.automatic,
    );
    final fetchedAtUtc = DateTime.utc(2026, 8, 25);
    final today = PrayerTodaySchedule(
      day: testPrayerDay(25, fetchedAtUtc: fetchedAtUtc),
      previousDay: testPrayerDay(24, fetchedAtUtc: fetchedAtUtc),
      previousDayIsReliable: true,
      nextDay: testPrayerDay(26, fetchedAtUtc: fetchedAtUtc),
      nextDayIsReliable: true,
      loadResult: PrayerScheduleLoadResult(
        schedule: testPrayerMonth(fetchedAtUtc: fetchedAtUtc),
        origin: PrayerScheduleLoadOrigin.freshCache,
        freshness: PrayerScheduleFreshness.fresh,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCacheDatabase),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(timeProvider),
          localDateProvider.overrideWithValue(
            _TashkentLocalDateProvider(timeProvider),
          ),
          prayerTimeSettingsProvider.overrideWith(
            (ref) => Stream<PrayerTimeSettings>.value(settings),
          ),
          prayerTodayScheduleProvider.overrideWith((ref) async => today),
        ],
        child: const MurajaahApp(),
      ),
    );
    await _pumpUntil(
      tester,
      () async => find
          .byKey(const ValueKey<String>('home-screen'))
          .evaluate()
          .isNotEmpty,
    );
  }

  Future<void> close() async {
    await database.close();
    await quranCacheDatabase.close();
  }
}

final class _DatabaseTransactionGate {
  const _DatabaseTransactionGate({
    required this.releaseCompleter,
    required this.done,
  });

  final Completer<void> releaseCompleter;
  final Future<void> done;

  void release() {
    if (!releaseCompleter.isCompleted) releaseCompleter.complete();
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Future<bool> Function() condition,
) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (await condition()) return;
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .join(' | ');
  throw TestFailure(
    'Condition was not met after 100 pumped frames. Visible text: '
    '$visibleText',
  );
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 20);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Drift may cascade zero-duration cleanup timers while watched queries close.
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

final class _MutableTimeProvider implements TimeProvider {
  _MutableTimeProvider(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _TashkentLocalDateProvider implements LocalDateProvider {
  const _TashkentLocalDateProvider(this.timeProvider);

  final TimeProvider timeProvider;

  @override
  LocalDate today() => LocalDate.fromLocalDateTime(
    timeProvider.nowUtc().add(const Duration(hours: 5)),
  );
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this.value);

  final LocalDate value;

  @override
  LocalDate today() => value;
}

DateTime _utcForTashkent(
  int year,
  int month,
  int day,
  int hour,
  int minute, [
  int second = 0,
]) => DateTime.utc(
  year,
  month,
  day,
  hour,
  minute,
  second,
).subtract(const Duration(hours: 5));
