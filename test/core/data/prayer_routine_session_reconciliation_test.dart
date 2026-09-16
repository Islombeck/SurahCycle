// `isNull` exists in both drift's query builder and matcher; this file needs
// drift only for `Value` and the generated companion.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// The owner deleted a part he had added by mistake, the editor showed three
/// parts, and Home still showed four. The template write had saved; the session
/// he was looking at keeps the snapshot it was created with, by design. A part
/// that was never used is not history, so it can follow the template — and
/// anything already prayed must not.
void main() {
  late AppDatabase database;
  late PrayerRoutineRepository repository;

  final context = PrayerContext(prayerType: PrayerType.dhuhr);
  final localDate = LocalDate(2026, 9, 16);
  final startedAt = DateTime.utc(2026, 9, 16, 7);

  PrayerRoutinePartTemplate part({
    required String key,
    required int order,
    PrayerRoutinePartKind kind = PrayerRoutinePartKind.sunnah,
    int slots = 2,
  }) => PrayerRoutinePartTemplate(
    id: 'part-$key',
    stableKey: key,
    orderIndex: order,
    kind: kind,
    rakaatCount: 2,
    requiredSurahSlots: slots,
  );

  Future<void> setTemplate(List<PrayerRoutinePartTemplate> parts) async {
    final current = await repository.getTemplate(PrayerType.dhuhr);
    await repository.replaceTemplate(
      prayerType: PrayerType.dhuhr,
      expectedRevision: current.revision,
      displayName: current.displayName,
      enabled: true,
      parts: parts,
    );
  }

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = PrayerRoutineRepository(database);
    await setTemplate(<PrayerRoutinePartTemplate>[
      part(key: 'sunnah-before', order: 0),
      part(key: 'fard', order: 1, kind: PrayerRoutinePartKind.fard),
      part(key: 'stray', order: 2, kind: PrayerRoutinePartKind.fard),
    ]);
    await repository.ensureCurrentSession(
      context: context,
      localDate: localDate,
      startedAtUtc: startedAt,
    );
  });

  tearDown(() => database.close());

  Future<List<String>> sessionKeys() async {
    final session = await repository.findCurrentSession(
      context: context,
      localDate: localDate,
    );
    return <String>[
      for (final progress in session?.parts ?? const <dynamic>[])
        progress.part.stableKey as String,
    ];
  }

  test('an unused part the template dropped leaves the open session', () async {
    expect(await sessionKeys(), <String>['sunnah-before', 'fard', 'stray']);

    await setTemplate(<PrayerRoutinePartTemplate>[
      part(key: 'sunnah-before', order: 0),
      part(key: 'fard', order: 1, kind: PrayerRoutinePartKind.fard),
    ]);
    final outcome = await repository.applyTemplateToCurrentSession(
      context: context,
      localDate: localDate,
    );

    expect(outcome.didChangeAnything, isTrue);
    expect(outcome.removedParts.map((p) => p.stableKey), <String>['stray']);
    expect(outcome.keptBecauseUsedParts, isEmpty);
    expect(await sessionKeys(), <String>['sunnah-before', 'fard']);
  });

  test('a part already prayed stays, and says so', () async {
    final session = await repository.findCurrentSession(
      context: context,
      localDate: localDate,
    );
    final stray = session!.parts.firstWhere(
      (progress) => progress.part.stableKey == 'stray',
    );
    await (database.update(
      database.prayerSessionParts,
    )..where((row) => row.id.equals(stray.part.id))).write(
      PrayerSessionPartsCompanion(
        completedAtUtc: Value<DateTime>(DateTime.utc(2026, 9, 16, 8)),
      ),
    );

    await setTemplate(<PrayerRoutinePartTemplate>[
      part(key: 'sunnah-before', order: 0),
      part(key: 'fard', order: 1, kind: PrayerRoutinePartKind.fard),
    ]);
    final outcome = await repository.applyTemplateToCurrentSession(
      context: context,
      localDate: localDate,
    );

    expect(outcome.didChangeAnything, isFalse);
    expect(outcome.removedParts, isEmpty);
    expect(
      outcome.keptBecauseUsedParts.map((p) => p.stableKey),
      <String>['stray'],
      reason:
          'what the user actually prayed is never rewritten, and the '
          'screen has to be able to say why it is still there',
    );
    expect(await sessionKeys(), <String>['sunnah-before', 'fard', 'stray']);
  });

  test('a template that still has every part changes nothing', () async {
    final outcome = await repository.applyTemplateToCurrentSession(
      context: context,
      localDate: localDate,
    );

    expect(outcome.didChangeAnything, isFalse);
    expect(await sessionKeys(), <String>['sunnah-before', 'fard', 'stray']);
  });

  test('a day with no session is a no-op, not an error', () async {
    final outcome = await repository.applyTemplateToCurrentSession(
      context: context,
      localDate: LocalDate(2026, 9, 17),
    );

    expect(outcome.session, isNull);
    expect(outcome.didChangeAnything, isFalse);
  });

  test('emptying the session reports it as absent so it is rebuilt', () async {
    await setTemplate(<PrayerRoutinePartTemplate>[
      part(key: 'brand-new', order: 0, kind: PrayerRoutinePartKind.fard),
    ]);
    final outcome = await repository.applyTemplateToCurrentSession(
      context: context,
      localDate: localDate,
    );

    expect(outcome.removedParts, hasLength(3));
    expect(
      outcome.session,
      isNull,
      reason: 'a plan with no parts must not be shown; the caller rebuilds it',
    );

    final rebuilt = await repository.ensureCurrentSession(
      context: context,
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    expect(rebuilt!.parts.map((p) => p.part.stableKey), <String>['brand-new']);
  });

  test('a Qada session is reconciled against the Qada-eligible parts', () async {
    // Qada keeps only the obligatory part, and the reconciliation must ask the
    // same question the snapshot did — otherwise it would "restore" a Sunnah
    // into a Qada plan that is not allowed to have one.
    final qada = PrayerContext(prayerType: PrayerType.dhuhr, isQada: true);
    final created = await repository.ensureCurrentSession(
      context: qada,
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    expect(
      created!.parts.map((progress) => progress.part.kind),
      everyElement(PrayerRoutinePartKind.fard),
    );

    await setTemplate(<PrayerRoutinePartTemplate>[
      part(key: 'sunnah-before', order: 0),
      part(key: 'fard', order: 1, kind: PrayerRoutinePartKind.fard),
    ]);
    final outcome = await repository.applyTemplateToCurrentSession(
      context: qada,
      localDate: localDate,
    );

    expect(outcome.removedParts.map((p) => p.stableKey), <String>['stray']);
    expect(
      outcome.session!.parts.map((progress) => progress.part.stableKey),
      <String>['fard'],
      reason: 'the Sunnah the template has must not appear in a Qada plan',
    );
  });
}
