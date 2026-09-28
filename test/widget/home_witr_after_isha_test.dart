import 'package:drift/drift.dart' show Value;
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

/// The owner reports that with the prayer chosen **automatically** — the card
/// read «Автоматически», which he confirmed — he finishes Иша and then cannot
/// mark Витр, the app telling him the prayer is already done, and only picking
/// Витр by hand works.
///
/// The providers were checked first and behaved: a finished Иша does hand the
/// automatic context to Витр. So these tests run the screen, where the two
/// answers to "which prayer is this" finally meet — the one the card shows and
/// the one a tap records against.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Fixture fixture;

  setUp(() async => fixture = await _Fixture.create());
  tearDown(() => fixture.close());

  group('with the resolution handed to Home ready-made', () {
    // 2026-08-25, well inside Иша. The schedule is unavailable here on
    // purpose: these two only ask what Home composes out of a resolution.
    testWidgets('a finished Isha leaves Witr markable', (tester) async {
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.addSurah('surah-b', 108);
      await fixture.completeIsha();

      await fixture.pumpWithStubbedResolution(tester);

      expect(
        _containerOf(tester)
            .read(homePrayerContextResolutionProvider)
            .valueOrNull
            ?.context
            ?.prayerType,
        PrayerType.witr,
        reason: 'a finished Иша hands the automatic context to Витр',
      );
      expect(
        find.text('Witr'),
        findsWidgets,
        reason:
            'and the card says so — the tree runs in English, so this is the '
            'same word he sees as «Витр»',
      );
      expect(
        _markEnabled(tester, 'surah-a'),
        isTrue,
        reason: 'Витр has three free slots, so there is something to mark',
      );

      await _disposeWidgetTree(tester);
    });

    testWidgets('surahs already recited for Isha stay markable', (
      tester,
    ) async {
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.addSurah('surah-b', 108);
      await fixture.fillIshaFard(<String>['surah-a', 'surah-b']);
      await fixture.completeIsha();

      await fixture.pumpWithStubbedResolution(tester);

      expect(
        _markEnabled(tester, 'surah-a'),
        isTrue,
        reason:
            'they were recited for Иша; under a Витр context they are unread '
            'again',
      );

      await _disposeWidgetTree(tester);
    });
  });

  group('a hand-picked prayer with nothing left to mark', () {
    testWidgets('says why, and offers the way out', (tester) async {
      // Result 3 of the investigation: manual + a finished Иша leaves marking
      // disabled and the context where it is. That is the behaviour he asked
      // for; the dead end was that nothing said so, and the rotation below
      // read as a list where everything had already been marked.
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.completeIsha();

      await fixture.pumpWithHandPickedPrayer(tester);

      expect(
        _markEnabled(tester, 'surah-a'),
        isFalse,
        reason: 'the prayer is finished, so there is genuinely no slot',
      );
      expect(
        find.byKey(const ValueKey<String>('routine-choose-next-prayer')),
        findsOneWidget,
        reason:
            'a disabled list with no explanation is the report this came from',
      );
      expect(
        find.byType(ChoiceChip),
        findsNothing,
        reason:
            'nothing on Home offers a prayer to choose until this is tapped',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('routine-choose-next-prayer')),
      );
      await _pumpFrames(tester, 40);

      expect(
        find.byType(ChoiceChip),
        findsWidgets,
        reason:
            'a hint that named the way out without opening it would be one '
            'more thing to read past',
      );
      expect(find.text('Witr'), findsWidgets);

      await _disposeWidgetTree(tester);
    });

    testWidgets('an unfinished one is left alone', (tester) async {
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);

      await fixture.pumpWithHandPickedPrayer(tester);

      expect(_markEnabled(tester, 'surah-a'), isTrue);
      expect(
        find.byKey(const ValueKey<String>('routine-choose-next-prayer')),
        findsNothing,
        reason: 'offering the next prayer while this one is unmarked is noise',
      );

      await _disposeWidgetTree(tester);
    });

    testWidgets('an automatic context is never told to pick by hand', (
      tester,
    ) async {
      // Automatic and everything finished is a different sentence: the day's
      // routine is done, which the card already says. Offering the picker here
      // would invite a mark against a prayer that is over.
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.completeIsha();
      await fixture.completePrayer(PrayerType.witr);

      await fixture.pumpWithStubbedResolution(tester);

      expect(
        _containerOf(tester)
            .read(homePrayerContextResolutionProvider)
            .valueOrNull
            ?.context
            ?.prayerType,
        PrayerType.witr,
      );
      expect(_markEnabled(tester, 'surah-a'), isFalse);
      expect(
        find.byKey(const ValueKey<String>('routine-choose-next-prayer')),
        findsNothing,
      );

      await _disposeWidgetTree(tester);
    });
  });

  group('with the real schedule and the real resolver', () {
    testWidgets('a tap after a finished Isha records Witr', (tester) async {
      // This is the report itself. The card and the routine card have already
      // moved to Витр; the only question left is what the tap does.
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.completeIsha();

      await fixture.pumpWithRealSchedule(tester);

      expect(
        _containerOf(tester)
            .read(homePrayerContextResolutionProvider)
            .valueOrNull
            ?.context
            ?.prayerType,
        PrayerType.witr,
        reason: 'the screen he was looking at said Витр',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('mark-surah-surah-a')),
      );
      await _pumpFrames(tester, 60);

      expect(
        find.byKey(
          const ValueKey<String>('prayer-routine-unavailable-snackbar'),
        ),
        findsNothing,
        reason:
            'this is what he saw: «Порядок намаза завершён» — the tap resolved '
            'the prayer from the schedule alone and landed on the finished Иша',
      );
      expect(
        (await fixture.recitations.getHistory(prayerType: PrayerType.witr)),
        hasLength(1),
        reason: 'the mark belongs to the prayer the screen was showing',
      );
      expect(
        (await fixture.recitations.getHistory(prayerType: PrayerType.isha)),
        isEmpty,
        reason: 'and never to the one that is already complete',
      );

      await _disposeWidgetTree(tester);
    });

    testWidgets('the coverage sheet names Witr under «now» too', (
      tester,
    ) async {
      // The sheet opens on Витр correctly; the «сейчас» shortcut resolved its
      // prayer from the schedule and so said Иша. Tapping it swapped the shown
      // prayer back while the record still went to Витр.
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.completeIsha();

      await fixture.pumpWithRealSchedule(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('advanced-mark-surah-surah-a')),
      );
      await _pumpFrames(tester, 40);
      // The shortcuts live in a second sheet, reached from the coverage sheet.
      await tester.tap(
        find.byKey(const ValueKey<String>('select-registration-occurrence')),
      );
      await _pumpFrames(tester, 40);
      expect(
        find.byKey(const ValueKey<String>('registration-now')),
        findsOneWidget,
        reason: 'the occurrence sheet is open',
      );

      await tester.tap(find.byKey(const ValueKey<String>('registration-now')));
      await _pumpFrames(tester, 20);

      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey<String>('registration-prayer-witr')),
            )
            .selected,
        isTrue,
        reason: '«сейчас» means the prayer Home resolved, which is Витр',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey<String>('registration-prayer-isha')),
            )
            .selected,
        isFalse,
        reason: 'and never the one the schedule alone would name',
      );

      await _disposeWidgetTree(tester);
    });

    testWidgets('after local midnight the automatic context reaches Witr', (
      tester,
    ) async {
      // Read off his device rather than assumed: the Иша parts of 2026-09-21
      // were completed at 00:29 local and Витр at 01:08. He marks after local
      // midnight, when the prayer he is in belongs to the previous day's
      // schedule.
      //
      // The seeded day used to be the 26th, because that is where his device
      // had actually filed it — and that was the defect, not the contract. A
      // prayer marked at 00:29 belongs to the night that is ending, so the
      // completed Иша this transition reads is the **25th's**. The assertion
      // below is unchanged: crossing midnight must still reach Витр.
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.completeIsha(localDate: LocalDate(2026, 8, 25));

      await fixture.pumpWithRealSchedule(
        tester,
        // 00:29 Tashkent on the 26th; Иша of the 25th ran from 20:32 and lasts
        // until Fajr at 04:17.
        nowUtc: DateTime.utc(2026, 8, 25, 19, 29),
        scheduleDay: 26,
      );

      final container = _containerOf(tester);
      expect(
        container.read(prayerContextResolutionProvider).valueOrNull?.status,
        PrayerContextResolutionStatus.automatic,
        reason:
            'nothing was picked by hand, so nothing may block the transition',
      );
      expect(
        container
            .read(homePrayerContextResolutionProvider)
            .valueOrNull
            ?.context
            ?.prayerType,
        PrayerType.witr,
        reason: 'crossing midnight does not undo a finished Иша',
      );

      await _disposeWidgetTree(tester);
    });

    testWidgets('a mark after midnight lands on the night that is ending', (
      tester,
    ) async {
      // His report, in his words: "if I mark Isha after 00:00 it marks it for
      // yesterday and for today, and then I cannot mark today's in the
      // evening."
      //
      // His database showed what that meant. At 00:32 local on 2026-09-21 the
      // record was filed with `local_date 2026-09-21`, and the 20th has no
      // Isha session at all: the night he had just prayed read as missed, and
      // the day he had not started read as done — so that evening there was
      // nothing left to mark.
      // The tap is driven too, and that matters: an earlier version of this
      // test asserted only on the resolution, and the mark it did not make
      // was hiding a second defect. Capture took the prayer day, the
      // freshness check took the wall clock, and after midnight every mark
      // was abandoned as "the context changed" — silently, recording
      // nothing. A test that stops at the resolution cannot see that.
      _sizePhone(tester);
      await fixture.seedOwnersRoutines();
      await fixture.addSurah('surah-a', 112);
      await fixture.completeIsha(localDate: LocalDate(2026, 8, 25));

      await fixture.pumpWithRealSchedule(
        tester,
        // 00:29 Tashkent on the 26th; the night he is in began at 20:32 on
        // the 25th and lasts until Fajr.
        nowUtc: DateTime.utc(2026, 8, 25, 19, 29),
        scheduleDay: 26,
      );

      final resolution = _containerOf(
        tester,
      ).read(homePrayerContextResolutionProvider).valueOrNull;
      expect(
        resolution?.contextLocalDate,
        LocalDate(2026, 8, 25),
        reason:
            'the night began on the 25th, so that is the day a mark belongs '
            'to — filing it on the 26th spends a day he has not prayed yet, '
            'and that is why the evening had nothing left to mark',
      );
      expect(
        resolution?.context?.prayerType,
        PrayerType.witr,
        reason:
            'and the Витр that follows stays on the same night rather than '
            'splitting one evening across two days',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('mark-surah-surah-a')),
      );
      await _pumpFrames(tester, 60);

      final history = await fixture.recitations.getHistory();
      expect(
        history,
        hasLength(1),
        reason:
            'the mark has to actually happen — abandoning it as "the context '
            'changed" is the silent failure this test exists to catch',
      );
      expect(history.single.event.localDate, LocalDate(2026, 8, 25));

      await _disposeWidgetTree(tester);
    });
  });
}

// Deliberately a ratio of 1, which is **wider than his phone**: 1080 logical
// pixels rather than 411. These tests are about which prayer a mark belongs
// to, and the extra room keeps the whole screen built so they do not have to
// scroll to find it. It does mean they can say nothing about layout — see the
// note in `AI_HANDOFF.md` about the region selector, which overflowed on his
// screen for as long as every test here had two and a half screens of width.
void _sizePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The container the screen itself reads from, so the test sees the values
/// Home sees rather than a second, separately-built copy.
ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey<String>('home-screen'))),
    );

bool _markEnabled(WidgetTester tester, String surahId) =>
    tester
        .widget<IconButton>(find.byKey(ValueKey<String>('mark-surah-$surahId')))
        .onPressed !=
    null;

final class _Fixture {
  _Fixture._({required this.database, required this.quranCache})
    : surahs = SurahRepository(database),
      recitations = RecitationRepository(database),
      routines = PrayerRoutineRepository(database);

  static Future<_Fixture> create() async {
    final fixture = _Fixture._(
      database: AppDatabase(NativeDatabase.memory()),
      quranCache: QuranCacheDatabase(NativeDatabase.memory()),
    );
    // Open and migrate before a ProviderScope starts watching the database.
    await fixture.surahs.getRotationSnapshot();
    return fixture;
  }

  final AppDatabase database;
  final QuranCacheDatabase quranCache;
  final SurahRepository surahs;
  final RecitationRepository recitations;
  final PrayerRoutineRepository routines;

  /// 21:00 Tashkent on 2026-08-25 — Иша started at 20:32.
  static final DateTime defaultNowUtc = DateTime.utc(2026, 8, 25, 16);
  static final LocalDate defaultLocalDate = LocalDate(2026, 8, 25);

  Future<void> close() async {
    await database.close();
    await quranCache.close();
  }

  /// His routines as his device holds them, read off it rather than imagined:
  /// Иша is Fard + Sunnah, and Витр is a single part he named «Важиб».
  Future<void> seedOwnersRoutines() async {
    final isha = await routines.getTemplate(PrayerType.isha);
    await routines.replaceTemplate(
      prayerType: PrayerType.isha,
      expectedRevision: isha.revision,
      displayName: isha.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: 'isha-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 4,
          requiredSurahSlots: 2,
          allowsFollowingImam: true,
        ),
        PrayerRoutinePartTemplate(
          id: 'isha-sunnah',
          stableKey: 'sunnah',
          orderIndex: 1,
          kind: PrayerRoutinePartKind.sunnah,
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
      ],
    );
    final witr = await routines.getTemplate(PrayerType.witr);
    await routines.replaceTemplate(
      prayerType: PrayerType.witr,
      expectedRevision: witr.revision,
      displayName: witr.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: 'witr-wajib',
          stableKey: 'witr-wajib',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.custom,
          customLabel: 'Важиб',
          rakaatCount: 3,
          requiredSurahSlots: 3,
        ),
      ],
    );
  }

  Future<void> addSurah(String id, int number) async {
    await surahs.upsertCatalog(<SurahDescriptor>[
      SurahDescriptor(
        id: id,
        surahNumber: number,
        officialName: 'Test $id',
        ayahCount: 4,
      ),
    ]);
    await surahs.addMastered(id);
  }

  Future<PrayerRoutineSessionSnapshot> _sessionFor(
    PrayerType prayerType,
    LocalDate localDate,
  ) async => (await routines.ensureCurrentSession(
    context: PrayerContext(prayerType: prayerType),
    localDate: localDate,
    startedAtUtc: defaultNowUtc,
  ))!;

  Future<PrayerRoutineSessionSnapshot> _ishaSession(LocalDate localDate) =>
      _sessionFor(PrayerType.isha, localDate);

  Future<void> fillIshaFard(
    List<String> surahIds, {
    LocalDate? localDate,
  }) async {
    final date = localDate ?? defaultLocalDate;
    final session = await _ishaSession(date);
    final fard = session.parts.first.part;
    for (var index = 0; index < surahIds.length; index += 1) {
      await recitations.register(
        SurahRecitationEvent(
          id: 'isha-${surahIds[index]}',
          surahId: surahIds[index],
          prayerContext: PrayerContext(prayerType: PrayerType.isha),
          createdAtUtc: defaultNowUtc,
          localDate: date,
          rakaatSpanCount: 2,
          prayerSessionId: session.session.id,
          prayerSessionPartId: fard.id,
          slotIndex: index,
        ),
      );
    }
  }

  Future<void> completeIsha({LocalDate? localDate}) =>
      completePrayer(PrayerType.isha, localDate: localDate);

  Future<void> completePrayer(
    PrayerType prayerType, {
    LocalDate? localDate,
  }) async {
    final session = await _sessionFor(
      prayerType,
      localDate ?? defaultLocalDate,
    );
    for (final progress in session.parts) {
      await (database.update(
        database.prayerSessionParts,
      )..where((row) => row.id.equals(progress.part.id))).write(
        PrayerSessionPartsCompanion(
          completedAtUtc: Value<DateTime>(defaultNowUtc),
        ),
      );
    }
  }

  Future<void> pumpWithStubbedResolution(WidgetTester tester) => _pump(
    tester,
    nowUtc: defaultNowUtc,
    localDates: _FixedLocalDateProvider(defaultLocalDate),
    settings: PrayerTimeSettings(
      location: testTashkentLocation(),
      contextSelectionMode: PrayerContextSelectionMode.automatic,
      contextModeExplicitlyChosen: true,
    ),
    extra: <Override>[
      prayerContextResolutionProvider.overrideWith(
        (ref) => Stream<PrayerContextResolution>.value(
          PrayerContextResolution(
            status: PrayerContextResolutionStatus.automatic,
            context: PrayerContext(prayerType: PrayerType.isha),
          ),
        ),
      ),
      prayerTodayScheduleProvider.overrideWith(
        (ref) async => throw StateError('Fixture schedule unavailable.'),
      ),
    ],
  );

  /// The prayer picked by hand — where result 3 of this investigation left the
  /// owner. A hand-picked prayer never advances on its own, which he asked for
  /// after being thrown from Иша to Витр.
  Future<void> pumpWithHandPickedPrayer(
    WidgetTester tester, {
    PrayerType prayerType = PrayerType.isha,
  }) => _pump(
    tester,
    nowUtc: defaultNowUtc,
    localDates: _FixedLocalDateProvider(defaultLocalDate),
    settings: PrayerTimeSettings(
      location: testTashkentLocation(),
      contextSelectionMode: PrayerContextSelectionMode.manual,
      contextModeExplicitlyChosen: true,
    ),
    extra: <Override>[
      prayerContextResolutionProvider.overrideWith(
        (ref) => Stream<PrayerContextResolution>.value(
          PrayerContextResolution(
            status: PrayerContextResolutionStatus.manual,
            context: PrayerContext(prayerType: prayerType),
          ),
        ),
      ),
      prayerTodayScheduleProvider.overrideWith(
        (ref) async => throw StateError('Fixture schedule unavailable.'),
      ),
    ],
  );

  Future<void> pumpWithRealSchedule(
    WidgetTester tester, {
    DateTime? nowUtc,
    int scheduleDay = 25,
  }) {
    final now = nowUtc ?? defaultNowUtc;
    final timeProvider = _FixedTimeProvider(now);
    // Fetched that morning: a schedule stamped in the future reads as
    // unreliable, which is right but is not the case under test.
    final fetchedAtUtc = DateTime.utc(2026, 8, 25, 6);
    final schedule = PrayerTodaySchedule(
      day: testPrayerDay(scheduleDay, fetchedAtUtc: fetchedAtUtc),
      previousDay: testPrayerDay(scheduleDay - 1, fetchedAtUtc: fetchedAtUtc),
      previousDayIsReliable: true,
      nextDay: testPrayerDay(scheduleDay + 1, fetchedAtUtc: fetchedAtUtc),
      nextDayIsReliable: true,
      loadResult: PrayerScheduleLoadResult(
        schedule: testPrayerMonth(fetchedAtUtc: fetchedAtUtc),
        origin: PrayerScheduleLoadOrigin.freshCache,
        freshness: PrayerScheduleFreshness.fresh,
      ),
    );
    return _pump(
      tester,
      nowUtc: now,
      localDates: _TashkentLocalDateProvider(timeProvider),
      settings: PrayerTimeSettings(
        location: testTashkentLocation(),
        locationConfirmed: true,
        contextSelectionMode: PrayerContextSelectionMode.automatic,
      ),
      extra: <Override>[
        prayerTodayScheduleProvider.overrideWith((ref) async => schedule),
      ],
    );
  }

  Future<void> _pump(
    WidgetTester tester, {
    required DateTime nowUtc,
    required LocalDateProvider localDates,
    required PrayerTimeSettings settings,
    required List<Override> extra,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCache),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(_FixedTimeProvider(nowUtc)),
          localDateProvider.overrideWithValue(localDates),
          prayerTimeSettingsProvider.overrideWith(
            (ref) => Stream<PrayerTimeSettings>.value(settings),
          ),
          ...extra,
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
    await _pumpFrames(tester, 60);
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  throw TestFailure('Condition was not met after 120 pumped frames.');
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var index = 0; index < 5; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this._value);

  final DateTime _value;

  @override
  DateTime nowUtc() => _value;
}

final class _FixedLocalDateProvider implements LocalDateProvider {
  const _FixedLocalDateProvider(this._value);

  final LocalDate _value;

  @override
  LocalDate today() => _value;
}

/// The date the app is on in Tashkent, which after 19:00 UTC is already
/// tomorrow — the whole point of the after-midnight case.
final class _TashkentLocalDateProvider implements LocalDateProvider {
  const _TashkentLocalDateProvider(this._time);

  final TimeProvider _time;

  @override
  LocalDate today() {
    final local = _time.nowUtc().add(const Duration(minutes: 300));
    return LocalDate(local.year, local.month, local.day);
  }
}
