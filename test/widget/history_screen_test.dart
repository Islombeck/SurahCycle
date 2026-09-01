import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/history/presentation/history_screen.dart';
import 'package:murajaah/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'historical row keeps occurrence date separate from added timestamp',
    (tester) async {
      final createdAtUtc = DateTime.utc(2026, 8, 26, 12, 15);
      final entry = _entry(
        id: 'historical',
        prayerType: PrayerType.witr,
        localDate: LocalDate(2026, 8, 25),
        createdAtUtc: createdAtUtc,
      );

      await _pumpHistory(tester, <RecitationHistoryEntry>[entry]);

      final occurrence = tester.widget<Text>(
        find.byKey(const ValueKey<String>('history-occurrence-historical')),
      );
      final added = tester.widget<Text>(
        find.byKey(const ValueKey<String>('history-added-historical')),
      );
      final addedLocalTime = createdAtUtc.toLocal();
      expect(
        occurrence.data,
        'Witr · ${DateFormat.MMMd('en').format(DateTime(2026, 8, 25))}',
      );
      expect(
        added.data,
        'Added ${DateFormat.MMMd('en').format(addedLocalTime)} '
        '${DateFormat.Hm('en').format(addedLocalTime)}',
      );
      expect(
        occurrence.data,
        isNot(contains(DateFormat.Hm('en').format(addedLocalTime))),
      );
    },
  );

  testWidgets(
    'compact unsplit whole-surah row hides one rakaat but details show it',
    (tester) async {
      final entry = _entry(id: 'unsplit-one');

      await _pumpHistory(tester, <RecitationHistoryEntry>[entry]);

      final compactCoverage = tester.widget<Text>(
        find.byKey(const ValueKey<String>('history-coverage-unsplit-one')),
      );
      expect(compactCoverage.data, 'Whole surah');
      expect(find.text('Rakaats: 1'), findsNothing);

      final detailsButton = find.byKey(
        const ValueKey<String>('history-open-details-unsplit-one'),
      );
      expect(find.byTooltip('Open recitation details'), findsOneWidget);
      await tester.tap(detailsButton);
      await tester.pumpAndSettle();

      final rakaatDetails = find.byKey(
        const ValueKey<String>('history-details-rakaats-unsplit-one'),
      );
      expect(rakaatDetails, findsOneWidget);
      expect(
        find.descendant(of: rakaatDetails, matching: find.text('Rakaats: 1')),
        findsOneWidget,
      );
      expect(
        find.text(
          'This is only the number of rakaats spanned by the recitation. '
          'Individual ayahs are not mapped to specific rakaats.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('compact primary one-tap row also hides one rakaat', (
    tester,
  ) async {
    final entry = _entry(id: 'implicit-whole-one', implicitWhole: true);

    await _pumpHistory(tester, <RecitationHistoryEntry>[entry]);

    final compactCoverage = tester.widget<Text>(
      find.byKey(const ValueKey<String>('history-coverage-implicit-whole-one')),
    );
    expect(compactCoverage.data, 'Whole surah');
    expect(find.text('Rakaats: 1'), findsNothing);
  });

  testWidgets('compact split row shows one-rakaat span', (tester) async {
    final entry = _entry(
      id: 'split-one',
      isWholeSurah: false,
      ranges: <AyahRange>[AyahRange(startAyah: 1, endAyah: 2)],
    );

    await _pumpHistory(tester, <RecitationHistoryEntry>[entry]);

    final compactCoverage = tester.widget<Text>(
      find.byKey(const ValueKey<String>('history-coverage-split-one')),
    );
    expect(compactCoverage.data, contains('Part 1 (Ayahs 1–2)'));
    expect(compactCoverage.data, contains('Rakaats: 1'));
  });

  testWidgets('compact and detail views show a multi-rakaat span', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = _entry(
      id: 'multi-rakaat',
      rakaatSpanCount: 3,
      isWholeSurah: true,
      ranges: <AyahRange>[
        AyahRange(startAyah: 1, endAyah: 2),
        AyahRange(startAyah: 3, endAyah: 4),
      ],
    );

    await _pumpHistory(tester, <RecitationHistoryEntry>[entry]);

    final compactCoverage = tester.widget<Text>(
      find.byKey(const ValueKey<String>('history-coverage-multi-rakaat')),
    );
    expect(compactCoverage.data, 'Whole surah · Rakaats: 3');

    await tester.tap(
      find.byKey(const ValueKey<String>('history-entry-multi-rakaat')),
    );
    await tester.pumpAndSettle();

    final rakaatDetails = find.byKey(
      const ValueKey<String>('history-details-rakaats-multi-rakaat'),
    );
    expect(rakaatDetails, findsOneWidget);
    expect(
      find.descendant(of: rakaatDetails, matching: find.text('Rakaats: 3')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester,
  List<RecitationHistoryEntry> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        recitationHistoryProvider.overrideWith(
          (ref) => Stream<List<RecitationHistoryEntry>>.value(entries),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RecitationHistoryEntry _entry({
  required String id,
  PrayerType prayerType = PrayerType.fajr,
  LocalDate? localDate,
  DateTime? createdAtUtc,
  int rakaatSpanCount = 1,
  bool isWholeSurah = true,
  List<AyahRange>? ranges,
  bool implicitWhole = false,
}) {
  final resolvedRanges = implicitWhole
      ? const <AyahRange>[]
      : ranges ?? <AyahRange>[AyahRange(startAyah: 1, endAyah: 4)];
  final parts = <SurahRotationPart>[
    for (var index = 0; index < resolvedRanges.length; index += 1)
      SurahRotationPart(
        id: '$id-part-${index + 1}',
        schemeId: '$id-scheme',
        partNumber: index + 1,
        ayahRange: resolvedRanges[index],
      ),
  ];
  return RecitationHistoryEntry(
    event: SurahRecitationEvent(
      id: id,
      surahId: 'surah-1',
      prayerContext: PrayerContext(prayerType: prayerType),
      createdAtUtc: createdAtUtc ?? DateTime.utc(2026, 8, 26, 12),
      localDate: localDate ?? LocalDate(2026, 8, 26),
      rotationSchemeId: implicitWhole ? null : '$id-scheme',
      coveredPartIds: implicitWhole ? null : parts.map((part) => part.id),
      rakaatSpanCount: rakaatSpanCount,
    ),
    surah: SurahDescriptor(
      id: 'surah-1',
      surahNumber: 112,
      officialName: 'Al-Ikhlas',
      ayahCount: 4,
    ),
    journalSequence: 1,
    coveredParts: parts,
    isWholeSurah: isWholeSurah,
  );
}
