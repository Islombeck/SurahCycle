import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/prayer_routine_sync_applier.dart';
import 'package:murajaah/core/sync/prayer_routine_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The routine is pure intent — how the owner has set each prayer up — and
/// nothing in it is derived from anything. Losing it means rebuilding the
/// prayer structure by hand on the second device.
void main() {
  late AppDatabase database;
  late PrayerRoutineSyncApplier applier;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    applier = PrayerRoutineSyncApplier(database);
  });

  tearDown(() => database.close());

  PrayerRoutineSyncPart part({
    required String id,
    required int orderIndex,
    String kind = 'fard',
    String? stableKey,
    String? customLabel,
    int requiredSurahSlots = 2,
  }) => PrayerRoutineSyncPart(
    id: id,
    stableKey: stableKey ?? id,
    orderIndex: orderIndex,
    kind: kind,
    customLabel: customLabel,
    rakaatCount: 4,
    requiredSurahSlots: requiredSurahSlots,
    allowsFollowingImam: true,
    defaultCompletionMode: 'recitations',
  );

  PrayerRoutineSyncRecord routine({
    String id = 'routine:dhuhr',
    String prayerType = 'dhuhr',
    bool enabled = true,
    int revision = 4,
    List<PrayerRoutineSyncPart>? parts,
  }) => PrayerRoutineSyncRecord(
    id: id,
    prayerType: prayerType,
    displayName: 'Зухр',
    enabled: enabled,
    revision: revision,
    parts:
        parts ??
        <PrayerRoutineSyncPart>[
          part(id: 'p-sunnah', orderIndex: 0, kind: 'sunnah'),
          part(id: 'p-fard', orderIndex: 1),
        ],
  );

  SyncEnvelope upsertOf(PrayerRoutineSyncRecord source, {int minute = 0}) =>
      PrayerRoutineSyncPayload.upsert(
        source,
        envelopeId: 'envelope-${source.id}-$minute',
        deviceId: 'other-device',
        idempotencyKey: 'key-${source.id}-$minute',
        schemaVersion: 10,
        updatedAtUtc: DateTime.utc(2026, 9, 18, 9, minute),
      );

  Future<void> applyIn(SyncEnvelope envelope) =>
      database.transaction(() => applier.apply(envelope));

  Matcher refuses(String reason) => throwsA(
    isA<SyncTransportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  Future<PrayerRoutineTemplateRow> template(String id) => (database.select(
    database.prayerRoutineTemplates,
  )..where((PrayerRoutineTemplates row) => row.id.equals(id))).getSingle();

  Future<List<PrayerRoutinePartTemplateRow>> partsOf(String id) =>
      (database.select(database.prayerRoutinePartTemplates)..where(
            (PrayerRoutinePartTemplates row) =>
                row.routineTemplateId.equals(id),
          ))
          .get();

  test('the eight templates are already here before any sync', () async {
    // Seeded at startup with deterministic ids, which is what makes
    // UNIQUE (prayer_type) safe across devices.
    final all = await database.select(database.prayerRoutineTemplates).get();

    expect(all, hasLength(8));
    expect(<String>[for (final row in all) row.id], contains('routine:dhuhr'));
  });

  test('an arriving routine fills a template in place', () async {
    await applyIn(upsertOf(routine()));

    final stored = await template('routine:dhuhr');
    expect(stored.displayName, 'Зухр');
    expect(stored.enabled, isTrue);
    expect(stored.revision, 4);

    final parts = await partsOf('routine:dhuhr')
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(
      <String>[for (final p in parts) p.id],
      <String>['p-sunnah', 'p-fard'],
    );
    expect(parts.first.kind, 'sunnah');
    expect(parts.last.requiredSurahSlots, 2);
  });

  test('applying it twice changes nothing', () async {
    final envelope = upsertOf(routine());
    await applyIn(envelope);

    await applyIn(envelope);

    expect(await partsOf('routine:dhuhr'), hasLength(2));
    expect(
      await database.select(database.prayerRoutineTemplates).get(),
      hasLength(8),
    );
  });

  test('a removed part is removed, because nothing points at it', () async {
    await applyIn(upsertOf(routine()));

    await applyIn(
      upsertOf(
        routine(
          parts: <PrayerRoutineSyncPart>[part(id: 'p-fard', orderIndex: 0)],
        ),
        minute: 30,
      ),
    );

    final parts = await partsOf('routine:dhuhr');
    expect(
      parts.single.id,
      'p-fard',
      reason:
          'a prayer session copies a template part rather than referencing it, '
          'so no history is lost by dropping one — unlike a session part, '
          'which a recitation points at',
    );
  });

  test('parts that swap places do not collide on the way', () async {
    await applyIn(upsertOf(routine()));

    await applyIn(
      upsertOf(
        routine(
          parts: <PrayerRoutineSyncPart>[
            part(id: 'p-fard', orderIndex: 0),
            part(id: 'p-sunnah', orderIndex: 1, kind: 'sunnah'),
          ],
        ),
        minute: 30,
      ),
    );

    final parts = await partsOf('routine:dhuhr')
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(
      <String>[for (final p in parts) p.id],
      <String>['p-fard', 'p-sunnah'],
    );
    expect(<int>[for (final p in parts) p.orderIndex], <int>[0, 1]);
  });

  test('two parts trading stable keys do not collide either', () async {
    await applyIn(
      upsertOf(
        routine(
          parts: <PrayerRoutineSyncPart>[
            part(id: 'p-a', orderIndex: 0, stableKey: 'first'),
            part(id: 'p-b', orderIndex: 1, stableKey: 'second'),
          ],
        ),
      ),
    );

    await applyIn(
      upsertOf(
        routine(
          parts: <PrayerRoutineSyncPart>[
            part(id: 'p-a', orderIndex: 0, stableKey: 'second'),
            part(id: 'p-b', orderIndex: 1, stableKey: 'first'),
          ],
        ),
        minute: 30,
      ),
    );

    final parts = await partsOf('routine:dhuhr')
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(
      <String>[for (final p in parts) p.stableKey],
      <String>['second', 'first'],
    );
  });

  test('a disabled routine keeps its parts', () async {
    await applyIn(upsertOf(routine()));

    await applyIn(upsertOf(routine(enabled: false), minute: 30));

    expect((await template('routine:dhuhr')).enabled, isFalse);
    expect(
      await partsOf('routine:dhuhr'),
      hasLength(2),
      reason:
          'turning a prayer off is not the same as forgetting how it was set '
          'up, and turning it back on must not start from nothing',
    );
  });

  test('an empty routine is a real state', () async {
    await applyIn(upsertOf(routine()));

    await applyIn(
      upsertOf(routine(parts: const <PrayerRoutineSyncPart>[]), minute: 30),
    );

    expect(await partsOf('routine:dhuhr'), isEmpty);
  });

  test('a template is never deleted', () async {
    await expectLater(
      () => applyIn(
        SyncEnvelope(
          id: 'envelope-gone',
          deviceId: 'other-device',
          entityType: SyncEntityType.prayerRoutineTemplate,
          entityId: 'routine:dhuhr',
          operation: SyncOperation.delete,
          schemaVersion: 10,
          createdAtUtc: DateTime.utc(2026, 9, 18, 9),
          updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
          idempotencyKey: 'key-gone',
        ),
      ),
      refuses('remote-routine-cannot-be-deleted'),
      reason:
          'the eight are seeded and always present; emptying or disabling one '
          'is what "removing" it means, and both are ordinary upserts',
    );
  });

  test('a prayer type already held by another id is refused', () async {
    await expectLater(
      () => applyIn(
        upsertOf(routine(id: 'routine:invented', prayerType: 'dhuhr')),
      ),
      refuses('remote-routine-prayer-type-taken'),
      reason:
          'the unique index would refuse it anyway; naming the reason is the '
          'difference between a legible refusal and a constraint failure',
    );
  });
}
