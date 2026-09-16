import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Reads a month straight out of the real schema. The classification rules
/// themselves are pinned by `prayer_calendar_test.dart`; what is checked here
/// is that the rows the app actually writes reach those rules intact.
void main() {
  late AppDatabase database;
  late PrayerCalendarRepository calendar;
  late PrayerRoutineRepository routines;

  final localDate = LocalDate(2026, 9, 16);
  final startedAt = DateTime.utc(2026, 9, 16, 7);

  Future<void> seedTemplate(PrayerType prayerType) async {
    final current = await routines.getTemplate(prayerType);
    await routines.replaceTemplate(
      prayerType: prayerType,
      expectedRevision: current.revision,
      displayName: current.displayName,
      enabled: true,
      parts: <PrayerRoutinePartTemplate>[
        PrayerRoutinePartTemplate(
          id: '${prayerType.name}-fard',
          stableKey: 'fard',
          orderIndex: 0,
          kind: PrayerRoutinePartKind.fard,
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
        PrayerRoutinePartTemplate(
          id: '${prayerType.name}-sunnah',
          stableKey: 'sunnah',
          orderIndex: 1,
          kind: PrayerRoutinePartKind.sunnah,
          rakaatCount: 2,
          requiredSurahSlots: 2,
        ),
      ],
    );
  }

  Future<void> completeParts(String sessionId, int count) async {
    final parts = await routines.getSessionParts(sessionId);
    for (final part in parts.take(count)) {
      await (database.update(
        database.prayerSessionParts,
      )..where((row) => row.id.equals(part.id))).write(
        PrayerSessionPartsCompanion(
          completedAtUtc: Value<DateTime>(DateTime.utc(2026, 9, 16, 8)),
        ),
      );
    }
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    calendar = PrayerCalendarRepository(database);
    routines = PrayerRoutineRepository(database);
  });

  tearDown(() => database.close());

  Future<PrayerCalendarDay> dayOf(LocalDate date) async {
    final month = await calendar.getMonth(year: date.year, month: date.month);
    return month.firstWhere((day) => day.date == date);
  }

  test('a month always has one cell per day', () async {
    final september = await calendar.getMonth(year: 2026, month: 9);
    final february = await calendar.getMonth(year: 2024, month: 2);

    expect(september, hasLength(30));
    expect(february, hasLength(29), reason: '2024 is a leap year');
    expect(september.every((day) => day.hasNoRecord), isTrue);
  });

  test('an untouched session colours nothing', () async {
    await seedTemplate(PrayerType.dhuhr);
    await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.dhuhr),
      localDate: localDate,
      startedAtUtc: startedAt,
    );

    expect(
      (await dayOf(localDate)).hasNoRecord,
      isTrue,
      reason: 'opening the app during a prayer window is not a record',
    );
  });

  test('a partly completed prayer is recorded and partial', () async {
    await seedTemplate(PrayerType.dhuhr);
    final session = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.dhuhr),
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    await completeParts(session!.session.id, 1);

    final day = await dayOf(localDate);
    expect(day.hasOrdinary, isTrue);
    expect(day.hasPartial, isTrue);
    expect(day.hasQada, isFalse);
  });

  test('a fully completed prayer is recorded and not partial', () async {
    await seedTemplate(PrayerType.dhuhr);
    final session = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.dhuhr),
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    await completeParts(session!.session.id, 2);

    final day = await dayOf(localDate);
    expect(day.hasOrdinary, isTrue);
    expect(day.hasPartial, isFalse);
    expect(day.ordinaryCount, 1);
  });

  test('ordinary and Qada on one day are both shown', () async {
    await seedTemplate(PrayerType.dhuhr);
    await seedTemplate(PrayerType.asr);
    final ordinary = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.dhuhr),
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    await completeParts(ordinary!.session.id, 2);
    final qada = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.asr, isQada: true),
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    await completeParts(qada!.session.id, 1);

    final day = await dayOf(localDate);
    expect(day.hasOrdinary, isTrue);
    expect(day.hasQada, isTrue);
    expect(day.ordinaryCount, 1);
    expect(day.qadaCount, 1);
    expect(
      day.entries.map((entry) => entry.isQada),
      <bool>[false, true],
      reason: 'neither marker may hide the other',
    );
  });

  test('a record on one day never bleeds into its neighbours', () async {
    await seedTemplate(PrayerType.dhuhr);
    final session = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.dhuhr),
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    await completeParts(session!.session.id, 2);

    expect((await dayOf(LocalDate(2026, 9, 15))).hasNoRecord, isTrue);
    expect((await dayOf(LocalDate(2026, 9, 17))).hasNoRecord, isTrue);
  });

  test('another month is not read into this one', () async {
    await seedTemplate(PrayerType.dhuhr);
    final session = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.dhuhr),
      localDate: localDate,
      startedAtUtc: startedAt,
    );
    await completeParts(session!.session.id, 2);

    final august = await calendar.getMonth(year: 2026, month: 8);
    expect(august.every((day) => day.hasNoRecord), isTrue);
  });

  test('the month watch re-emits when a part is completed', () async {
    await seedTemplate(PrayerType.dhuhr);
    final session = await routines.ensureCurrentSession(
      context: PrayerContext(prayerType: PrayerType.dhuhr),
      localDate: localDate,
      startedAtUtc: startedAt,
    );

    final stream = calendar.watchMonth(year: 2026, month: 9);
    final next = stream
        .map(
          (days) => days.firstWhere((day) => day.date == localDate).hasOrdinary,
        )
        .firstWhere((hasOrdinary) => hasOrdinary);

    await completeParts(session!.session.id, 1);

    expect(await next.timeout(const Duration(seconds: 5)), isTrue);
  });
}
