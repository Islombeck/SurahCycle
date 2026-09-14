import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/settings/application/prayer_routine_editor.dart';

void main() {
  late AppDatabase database;
  late PrayerRoutineRepository repository;
  late PrayerRoutineEditor editor;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = PrayerRoutineRepository(database);
    editor = PrayerRoutineEditor(repository: repository);
  });

  tearDown(() => database.close());

  PrayerRoutinePartTemplate part(
    String id, {
    PrayerRoutinePartKind kind = PrayerRoutinePartKind.fard,
    int rakaatCount = 2,
    int requiredSurahSlots = 2,
  }) => PrayerRoutinePartTemplate(
    id: id,
    stableKey: 'part:$id',
    orderIndex: 0,
    kind: kind,
    rakaatCount: rakaatCount,
    requiredSurahSlots: requiredSurahSlots,
  );

  Future<List<String>> storedIds(PrayerType type) async =>
      (await repository.getTemplate(
        type,
      )).parts.map((item) => item.id).toList();

  test('adds the first part to an empty template', () async {
    final outcome = await editor.addPart(
      prayerType: PrayerType.fajr,
      part: part('first'),
    );

    expect(outcome, isA<PrayerRoutineEditApplied>());
    expect(await storedIds(PrayerType.fajr), <String>['first']);
  });

  test('several rapid additions all land instead of conflicting', () async {
    // Queued without awaiting in between: this is the exact sequence that used
    // to reuse one captured revision and fail.
    final outcomes = await Future.wait(<Future<PrayerRoutineEditOutcome>>[
      editor.addPart(prayerType: PrayerType.fajr, part: part('a')),
      editor.addPart(prayerType: PrayerType.fajr, part: part('b')),
      editor.addPart(prayerType: PrayerType.fajr, part: part('c')),
    ]);

    expect(outcomes, everyElement(isA<PrayerRoutineEditApplied>()));
    expect(await storedIds(PrayerType.fajr), <String>['a', 'b', 'c']);
  });

  test('an external revision change no longer breaks the next edit', () async {
    final captured = await repository.getTemplate(PrayerType.fajr);
    await repository.addPart(
      prayerType: PrayerType.fajr,
      expectedRevision: captured.revision,
      part: part('external'),
    );

    final outcome = await editor.addPart(
      prayerType: PrayerType.fajr,
      part: part('mine'),
    );

    expect(outcome, isA<PrayerRoutineEditApplied>());
    expect(await storedIds(PrayerType.fajr), <String>['external', 'mine']);
  });

  test('add, edit and delete run in one uninterrupted sequence', () async {
    await editor.addPart(prayerType: PrayerType.fajr, part: part('one'));

    final edited = await editor.updatePart(
      prayerType: PrayerType.fajr,
      replacement: PrayerRoutinePartTemplate(
        id: 'one',
        stableKey: 'part:one',
        orderIndex: 0,
        kind: PrayerRoutinePartKind.sunnah,
        rakaatCount: 4,
        requiredSurahSlots: 1,
      ),
    );
    expect(edited, isA<PrayerRoutineEditApplied>());

    final stored = await repository.getTemplate(PrayerType.fajr);
    expect(stored.parts.single.kind, PrayerRoutinePartKind.sunnah);
    expect(stored.parts.single.rakaatCount, 4);

    final deleted = await editor.deletePart(
      prayerType: PrayerType.fajr,
      partId: 'one',
    );
    expect(deleted, isA<PrayerRoutineEditApplied>());
    expect(await storedIds(PrayerType.fajr), isEmpty);
  });

  test('deletes the last remaining part', () async {
    await editor.addPart(prayerType: PrayerType.fajr, part: part('only'));

    final outcome = await editor.deletePart(
      prayerType: PrayerType.fajr,
      partId: 'only',
    );

    expect(outcome, isA<PrayerRoutineEditApplied>());
    expect(await storedIds(PrayerType.fajr), isEmpty);
  });

  test('reorder followed by delete keeps the order contiguous', () async {
    await editor.addPart(prayerType: PrayerType.fajr, part: part('a'));
    await editor.addPart(prayerType: PrayerType.fajr, part: part('b'));
    await editor.addPart(prayerType: PrayerType.fajr, part: part('c'));

    final reordered = await editor.reorderParts(
      prayerType: PrayerType.fajr,
      orderedPartIds: <String>['c', 'a', 'b'],
    );
    expect(reordered, isA<PrayerRoutineEditApplied>());
    expect(await storedIds(PrayerType.fajr), <String>['c', 'a', 'b']);

    await editor.deletePart(prayerType: PrayerType.fajr, partId: 'a');

    final stored = await repository.getTemplate(PrayerType.fajr);
    expect(stored.parts.map((item) => item.id), <String>['c', 'b']);
    expect(stored.parts.map((item) => item.orderIndex), <int>[0, 1]);
  });

  test('a repeated submit of the same part never duplicates it', () async {
    final first = await editor.addPart(
      prayerType: PrayerType.fajr,
      part: part('once'),
    );
    final second = await editor.addPart(
      prayerType: PrayerType.fajr,
      part: part('once'),
    );

    expect(first, isA<PrayerRoutineEditApplied>());
    expect(second, isA<PrayerRoutineEditUnchanged>());
    expect(await storedIds(PrayerType.fajr), <String>['once']);
  });

  test('deleting an already deleted part is reported as unchanged', () async {
    await editor.addPart(prayerType: PrayerType.fajr, part: part('gone'));
    await editor.deletePart(prayerType: PrayerType.fajr, partId: 'gone');

    final outcome = await editor.deletePart(
      prayerType: PrayerType.fajr,
      partId: 'gone',
    );

    expect(outcome, isA<PrayerRoutineEditUnchanged>());
  });

  test(
    'editing a part that no longer exists is reported as a conflict',
    () async {
      final outcome = await editor.updatePart(
        prayerType: PrayerType.fajr,
        replacement: part('missing'),
      );

      expect(outcome, isA<PrayerRoutineEditConflict>());
      expect(await storedIds(PrayerType.fajr), isEmpty);
    },
  );

  test('reordering a stale id set is a conflict and writes nothing', () async {
    await editor.addPart(prayerType: PrayerType.fajr, part: part('a'));
    await editor.addPart(prayerType: PrayerType.fajr, part: part('b'));

    final outcome = await editor.reorderParts(
      prayerType: PrayerType.fajr,
      orderedPartIds: <String>['b', 'a', 'removed-elsewhere'],
    );

    expect(outcome, isA<PrayerRoutineEditConflict>());
    expect(await storedIds(PrayerType.fajr), <String>['a', 'b']);
  });

  test('a rejected edit is reported as failed and changes nothing', () async {
    await editor.addPart(prayerType: PrayerType.fajr, part: part('kept'));

    // A stable key may never change; the repository rejects this outright.
    final outcome = await editor.updatePart(
      prayerType: PrayerType.fajr,
      replacement: PrayerRoutinePartTemplate(
        id: 'kept',
        stableKey: 'part:renamed',
        orderIndex: 0,
        kind: PrayerRoutinePartKind.fard,
        rakaatCount: 2,
        requiredSurahSlots: 2,
      ),
    );

    expect(outcome, isA<PrayerRoutineEditFailed>());
    final stored = await repository.getTemplate(PrayerType.fajr);
    expect(stored.parts.single.stableKey, 'part:kept');
  });

  test('toggling enabled twice reports the second call as unchanged', () async {
    final off = await editor.setEnabled(
      prayerType: PrayerType.fajr,
      enabled: false,
    );
    final again = await editor.setEnabled(
      prayerType: PrayerType.fajr,
      enabled: false,
    );

    expect(off, isA<PrayerRoutineEditApplied>());
    expect(again, isA<PrayerRoutineEditUnchanged>());
    expect((await repository.getTemplate(PrayerType.fajr)).enabled, isFalse);
  });

  test('Fard and Sunnah coexist in one routine', () async {
    await editor.addPart(prayerType: PrayerType.fajr, part: part('fard'));
    await editor.addPart(
      prayerType: PrayerType.fajr,
      part: part('sunnah', kind: PrayerRoutinePartKind.sunnah),
    );

    final stored = await repository.getTemplate(PrayerType.fajr);
    expect(stored.parts.map((item) => item.kind), <PrayerRoutinePartKind>[
      PrayerRoutinePartKind.fard,
      PrayerRoutinePartKind.sunnah,
    ]);
  });

  test('every seeded prayer template accepts a first part', () async {
    for (final type in PrayerType.values) {
      final outcome = await editor.addPart(
        prayerType: type,
        part: part('${type.name}-part'),
      );
      expect(
        outcome,
        isA<PrayerRoutineEditApplied>(),
        reason: 'failed for ${type.name}',
      );
    }
  });

  group('an unconfigured routine never forces Qada', () {
    test(
      'an empty template creates no session, keeping the slotless flow',
      () async {
        final snapshot = await repository.ensureCurrentSession(
          context: PrayerContext(prayerType: PrayerType.fajr),
          localDate: LocalDate(2026, 9, 14),
          startedAtUtc: DateTime.utc(2026, 9, 14, 3),
        );

        expect(snapshot, isNull);
      },
    );

    test('a disabled template with parts also creates no session', () async {
      await editor.addPart(prayerType: PrayerType.fajr, part: part('fard'));
      await editor.setEnabled(prayerType: PrayerType.fajr, enabled: false);

      final snapshot = await repository.ensureCurrentSession(
        context: PrayerContext(prayerType: PrayerType.fajr),
        localDate: LocalDate(2026, 9, 14),
        startedAtUtc: DateTime.utc(2026, 9, 14, 3),
      );

      expect(snapshot, isNull);
    });
  });
}
