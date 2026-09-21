import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Reported by the owner: «Важиб для Витр не появляется как каза».
///
/// The cause is not a rule that is wrong but a choice the app forced. He wanted
/// his Witr part called «Важиб»; the only way to name a part was to make its
/// kind `custom`; and a custom part carries no prayer's obligation, so a Qada
/// Witr kept none of his parts and had nothing to mark. Nothing said so.
///
/// The policy itself stays exactly as it was — Qada records the obligation and
/// not the voluntary acts around it. What changed is that naming a part and
/// saying what it *is* are now separate questions.
void main() {
  late AppDatabase database;
  late PrayerRoutineRepository routines;

  final localDate = LocalDate(2026, 9, 21);
  final startedAt = DateTime.utc(2026, 9, 21, 16);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    routines = PrayerRoutineRepository(database);
  });

  tearDown(() => database.close());

  Future<void> setWitrPart({
    required PrayerRoutinePartKind kind,
    String? label,
  }) async {
    final current = await routines.getTemplate(PrayerType.witr);
    await routines.replaceTemplate(
      prayerType: PrayerType.witr,
      expectedRevision: current.revision,
      displayName: current.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: 'witr-part',
          stableKey: 'witr-part',
          orderIndex: 0,
          kind: kind,
          customLabel: label,
          rakaatCount: 3,
          requiredSurahSlots: 3,
        ),
      ],
    );
  }

  Future<PrayerRoutineSessionSnapshot?> sessionFor({required bool isQada}) =>
      routines.ensureCurrentSession(
        context: PrayerContext(prayerType: PrayerType.witr, isQada: isQada),
        localDate: localDate,
        startedAtUtc: startedAt,
      );

  test('the owner\'s configuration reproduces it exactly', () async {
    // A custom part named «Важиб» — what his device actually holds.
    await setWitrPart(kind: PrayerRoutinePartKind.custom, label: 'Важиб');

    expect(
      (await sessionFor(isQada: false))?.parts,
      hasLength(1),
      reason: 'an ordinary Witr keeps every part, so this always worked',
    );
    expect(
      await sessionFor(isQada: true),
      isNull,
      reason:
          'and this is the bug: a Qada Witr keeps only the obligatory part, a '
          'custom part is not one, so nothing remains to mark',
    );
  });

  test('a named Witr part carries the obligation, which is the fix', () async {
    // The same name, on a part that says what it is. Possible only now that
    // the label is offered for every kind.
    await setWitrPart(kind: PrayerRoutinePartKind.witr, label: 'Важиб');

    final qada = await sessionFor(isQada: true);

    expect(qada, isNotNull);
    expect(qada!.parts, hasLength(1));
    expect(
      qada.parts.single.part.label,
      'Важиб',
      reason: 'he keeps his own word for it',
    );
    expect(qada.parts.single.part.requiredSurahSlots, 3);
  });

  test('the Qada rule itself is unchanged', () async {
    // A voluntary part must still never become Qada — that is the religious
    // invariant this whole policy exists for, and the fix must not loosen it.
    final current = await routines.getTemplate(PrayerType.isha);
    await routines.replaceTemplate(
      prayerType: PrayerType.isha,
      expectedRevision: current.revision,
      displayName: current.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: 'isha-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          customLabel: 'Фард',
          rakaatCount: 4,
          requiredSurahSlots: 2,
        ),
        PrayerRoutinePartTemplate(
          id: 'isha-sunnah',
          stableKey: 'sunnah',
          orderIndex: 1,
          kind: PrayerRoutinePartKind.sunnah,
          customLabel: 'Сунна',
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
      ],
    );

    final qada = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.isha, isQada: true),
      localDate: localDate,
      startedAtUtc: startedAt,
    );

    expect(qada!.parts, hasLength(1));
    expect(
      qada.parts.single.part.kind,
      PrayerRoutinePartKind.fard,
      reason: 'a named Sunnah is still a Sunnah, and is still never made up',
    );
    expect(
      qada.parts.single.part.label,
      'Фард',
      reason: 'a label does not change what a part is, only what it is called',
    );
  });

  test('a name is optional, and its absence is not an empty name', () async {
    await setWitrPart(kind: PrayerRoutinePartKind.witr);

    final session = await sessionFor(isQada: true);

    expect(
      session!.parts.single.part.label,
      isNotEmpty,
      reason: 'an unnamed part still shows as its kind rather than as blank',
    );
    expect(
      (await routines.getTemplate(PrayerType.witr)).parts.single.customLabel,
      isNull,
      reason: 'absence is stored as absence, not as an empty string',
    );
  });
}
