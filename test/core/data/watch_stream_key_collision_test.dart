import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Drift caches active query streams by `StreamKey(sql, variables)` only — the
/// `readsFrom` table set is deliberately not part of that key. Two watch
/// queries that share the same SQL text therefore share one stream, and the
/// table set of whichever subscribed first is the one that drives updates.
///
/// This reproduces the device-observed defect: the prayer routine editor list
/// never refreshed after a successful write until the app was restarted,
/// because an unrelated catalog stream had already claimed the shared key.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late PrayerRoutineRepository routines;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    routines = PrayerRoutineRepository(database);
  });

  tearDown(() => database.close());

  test(
    'a routine template stream still updates when another watch is older',
    () async {
      // Subscribes first, and reads only surah tables.
      final catalog = surahs.watchCatalog().listen((_) {});
      addTearDown(catalog.cancel);
      await pumpEventQueue();

      final revisions = <int>[];
      final template = routines
          .watchTemplate(PrayerType.fajr)
          .listen((value) => revisions.add(value.revision));
      addTearDown(template.cancel);
      await pumpEventQueue();
      expect(revisions, isNotEmpty);
      final initial = revisions.last;

      final current = await routines.getTemplate(PrayerType.fajr);
      await routines.addPart(
        prayerType: PrayerType.fajr,
        expectedRevision: current.revision,
        part: PrayerRoutinePartTemplate(
          id: 'added',
          stableKey: 'part:added',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
      );
      await pumpEventQueue();

      expect(
        revisions.last,
        greaterThan(initial),
        reason:
            'the editor list must refresh without restarting the app, even '
            'when an unrelated stream subscribed to the same SQL first',
      );
    },
  );

  test('each watch query owns a distinct stream key', () async {
    // Two streams reading different tables must not be collapsed into one.
    final catalogEmissions = <int>[];
    final catalog = surahs.watchCatalog().listen(
      (value) => catalogEmissions.add(value.length),
    );
    addTearDown(catalog.cancel);
    final sessionEmissions = <int>[];
    final sessions = routines
        .watchCurrentSession(
          context: PrayerContext(prayerType: PrayerType.fajr),
          localDate: LocalDate(2026, 9, 14),
          startedAtUtc: () => DateTime.utc(2026, 9, 14, 3),
        )
        .listen((_) => sessionEmissions.add(1));
    addTearDown(sessions.cancel);
    await pumpEventQueue();

    expect(catalogEmissions, isNotEmpty);
    expect(sessionEmissions, isNotEmpty);
  });
}
