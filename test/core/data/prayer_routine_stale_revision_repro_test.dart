import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Reproduction for the reported "Не удалось выполнить действие" failures when
/// adding/deleting prayer routine parts. Documents the exact mechanism before
/// any fix: the editor holds one `template.revision` captured at widget-build
/// time and reuses it for a second mutation.
void main() {
  late AppDatabase database;
  late PrayerRoutineRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = PrayerRoutineRepository(database);
  });

  tearDown(() => database.close());

  PrayerRoutinePartTemplate part(String id, {int orderIndex = 0}) =>
      PrayerRoutinePartTemplate(
        id: id,
        stableKey: 'part:$id',
        orderIndex: orderIndex,
        kind: PrayerRoutinePartKind.fard,
        rakaatCount: 2,
        requiredSurahSlots: 2,
      );

  test(
    'reusing one captured revision for a second add fails with a conflict',
    () async {
      final captured = await repository.getTemplate(PrayerType.fajr);

      await repository.addPart(
        prayerType: PrayerType.fajr,
        expectedRevision: captured.revision,
        part: part('first'),
      );

      // The editor still holds `captured` until the watch stream delivers the
      // new revision, so a second tap sends the same stale expectedRevision.
      await expectLater(
        repository.addPart(
          prayerType: PrayerType.fajr,
          expectedRevision: captured.revision,
          part: part('second'),
        ),
        throwsA(isA<PrayerRoutineRevisionConflict>()),
      );

      final stored = await repository.getTemplate(PrayerType.fajr);
      expect(
        stored.parts.map((p) => p.id),
        <String>['first'],
        reason: 'the first add is persisted, so it "appears later" in the UI',
      );
    },
  );

  test('the same stale revision also breaks delete after an add', () async {
    final captured = await repository.getTemplate(PrayerType.fajr);
    await repository.addPart(
      prayerType: PrayerType.fajr,
      expectedRevision: captured.revision,
      part: part('first'),
    );

    await expectLater(
      repository.deletePart(
        prayerType: PrayerType.fajr,
        expectedRevision: captured.revision,
        partId: 'first',
      ),
      throwsA(isA<PrayerRoutineRevisionConflict>()),
    );
  });

  test('watchTemplate delivers the new revision only asynchronously', () async {
    final seen = <int>[];
    final subscription = repository
        .watchTemplate(PrayerType.fajr)
        .listen((template) => seen.add(template.revision));
    await pumpEventQueue();
    expect(seen, isNotEmpty);
    final initialRevision = seen.last;

    await repository.addPart(
      prayerType: PrayerType.fajr,
      expectedRevision: initialRevision,
      part: part('first'),
    );

    expect(
      seen.last,
      initialRevision,
      reason: 'the stream has not caught up at the moment the write returns',
    );

    await pumpEventQueue();
    expect(seen.last, greaterThan(initialRevision));
    await subscription.cancel();
  });
}
