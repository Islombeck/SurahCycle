import 'dart:io';

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

/// Marks a surah for a **Qada Witr** on a copy of the owner's own database,
/// through the screen he taps.
///
/// Every other test of this path builds the routine it then marks against, so
/// it can only prove that a routine shaped the way the test thinks works. His
/// Witr is one part he named «Важиб», edited across several app versions, and
/// the defect it exposed — a Qada with nothing to mark — was invisible to every
/// built fixture. This runs the real widget tree over the real rows.
///
/// It is on a **copy** and says so loudly, because the alternative — tapping it
/// on his phone — would write a recitation he never made into his own history.
/// A test that has to lie about an act of worship to prove something is not
/// worth the thing it proves.
///
///     $env:MURAJAAH_QADA_DB = '<path>\copy.sqlite'
///     flutter test test/tool/real_database_qada_witr_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` takes a flag rather than a reason, so the reason is in the
  // comment above and in the failure a missing file produces.
  final path = Platform.environment['MURAJAAH_QADA_DB'];

  testWidgets('a surah can be marked for a Qada Witr', (tester) async {
    expect(
      path!.contains('/data/data/') || path.contains(r'\data\data\'),
      isFalse,
      reason: 'this writes; point it at a pulled copy, never at the phone',
    );
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'no such file: $path');

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final quranCache = QuranCacheDatabase(NativeDatabase.memory());
    addTearDown(quranCache.close);

    // The day the copy was taken, so the Qada session it already holds is the
    // one the screen will find rather than a second one invented here.
    final localDate = LocalDate(2026, 9, 22);
    final nowUtc = DateTime.utc(2026, 9, 22, 10, 10);
    final qadaSessionId = 'routine-session:$localDate:witr:qada';

    Future<int> qadaWitrEvents() async =>
        (await database
                .customSelect(
                  "SELECT count(*) AS n FROM recitation_events "
                  "WHERE is_qada = 1 AND prayer_type = 'witr'",
                )
                .getSingle())
            .read<int>('n');

    final before = await qadaWitrEvents();

    // What picking «Витр · Каза» in the prayer sheet actually does. The tap
    // path reads this stored pair, not the resolution stream the card renders
    // from — overriding the stream alone would have produced a screen that
    // said Qada over a tap that resolved something else, which is a harness
    // lying in exactly the direction this test exists to rule out.
    await PrayerRepository(database).saveSelectedContext(
      PrayerContext(prayerType: PrayerType.witr, isQada: true),
      updatedAtUtc: nowUtc,
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          quranCacheDatabaseProvider.overrideWithValue(quranCache),
          startupProvider.overrideWith((ref) async {}),
          timeProviderProvider.overrideWithValue(_FixedTime(nowUtc)),
          localDateProvider.overrideWithValue(_FixedLocalDate(localDate)),
          prayerTimeSettingsProvider.overrideWith(
            (ref) => Stream<PrayerTimeSettings>.value(
              PrayerTimeSettings(
                location: testTashkentLocation(),
                contextSelectionMode: PrayerContextSelectionMode.manual,
                contextModeExplicitlyChosen: true,
              ),
            ),
          ),
          // The resolution is deliberately *not* stubbed: in manual mode it
          // comes from the pair saved above, so the card and the tap are
          // reading the same thing the app reads.
          prayerTodayScheduleProvider.overrideWith(
            (ref) async => throw StateError('Not under test here.'),
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
    await _pumpFrames(tester, 60);

    // A surah that is recited whole. A split one opens the coverage sheet
    // instead of recording, which is correct and is a different path from the
    // one under test here.
    final snapshot = await SurahRepository(database).getRotationSnapshot();
    final whole = <String>{
      for (final surah in snapshot.surahs)
        if (!surah.rotationScheme.isSplit) surah.id,
    };
    final onScreen = <String>[
      for (final element
          in find
              .byWidgetPredicate(
                (widget) =>
                    widget.key is ValueKey<String> &&
                    (widget.key! as ValueKey<String>).value.startsWith(
                      'mark-surah-',
                    ),
              )
              .evaluate())
        (element.widget.key! as ValueKey<String>).value.replaceFirst(
          'mark-surah-',
          '',
        ),
    ];
    final surahId = onScreen.firstWhere(
      whole.contains,
      orElse: () => throw TestFailure(
        'No whole-surah tile is on screen; the rotation shows $onScreen.',
      ),
    );
    final target = ValueKey<String>('mark-surah-$surahId');

    await tester.ensureVisible(find.byKey(target));
    await _pumpFrames(tester, 10);
    expect(
      tester.widget<IconButton>(find.byKey(target)).onPressed,
      isNotNull,
      reason:
          'this is the defect itself: a Qada Witr with no part to mark left '
          'every button dead and said nothing',
    );

    await tester.tap(find.byKey(target));
    await _pumpFrames(tester, 80);

    expect(
      find.byKey(const ValueKey<String>('prayer-routine-unavailable-snackbar')),
      findsNothing,
      reason: '«Порядок намаза завершён» over an empty Qada is the old bug',
    );

    // Says what actually happened before the assertion says what did not: a
    // tap that writes nothing has several possible reasons and a bare count
    // names none of them.
    final tail = await database
        .customSelect(
          'SELECT id, surah_id, prayer_type, is_qada, local_date, '
          'prayer_session_id FROM recitation_events ORDER BY rowid DESC '
          'LIMIT 3',
        )
        .get();
    for (final row in tail) {
      // ignore: avoid_print
      print('latest event: ${row.data}');
    }
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data ?? '';
      if (value.contains('Qada') ||
          value.contains('Witr') ||
          value.contains('slot') ||
          value.contains('complete')) {
        // ignore: avoid_print
        print('on screen: $value');
      }
    }
    expect(
      await qadaWitrEvents(),
      before + 1,
      reason: 'the tap has to land in his history, not merely not complain',
    );

    final written = await database
        .customSelect(
          'SELECT prayer_session_id, surah_id, local_date, slot_index '
          'FROM recitation_events WHERE is_qada = 1 '
          "AND prayer_type = 'witr' ORDER BY rowid DESC LIMIT 1",
        )
        .getSingle();
    expect(written.read<String>('surah_id'), surahId);
    expect(
      written.read<String?>('prayer_session_id'),
      qadaSessionId,
      reason:
          'a Qada mark that landed in the ordinary Witr session would be the '
          'same silence wearing a different shape',
    );
    expect(written.read<String>('local_date'), '$localDate');
    expect(
      written.read<int?>('slot_index'),
      isNotNull,
      reason: 'it occupies a real slot of the part, not a loose event',
    );

    // ignore: avoid_print
    print(
      'marked $surahId into $qadaSessionId '
      'at slot ${written.read<int?>('slot_index')}',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    for (var index = 0; index < 5; index += 1) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }, skip: path == null);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
  }
  throw TestFailure('Condition was not met after 200 pumped frames.');
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

final class _FixedTime implements TimeProvider {
  const _FixedTime(this._value);

  final DateTime _value;

  @override
  DateTime nowUtc() => _value;
}

final class _FixedLocalDate implements LocalDateProvider {
  const _FixedLocalDate(this._value);

  final LocalDate _value;

  @override
  LocalDate today() => _value;
}
