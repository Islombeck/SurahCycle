import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/prayer_routine_sync_payload.dart';
import 'package:murajaah/core/sync/recitation_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// A device that has been used for years and only now signs in must send that
/// history, or an account is an empty promise. Nothing else in this feature can
/// do it: a recorder queues a change as it is written, so it has nothing to say
/// about anything written before the account existed.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;
  late InMemorySyncOutbox outbox;
  late DriftSyncBackfill backfill;

  final now = DateTime.utc(2026, 9, 21, 12);
  final localDate = LocalDate(2026, 9, 21);

  var ids = 0;
  String newId() => 'id-${++ids}';

  setUp(() async {
    ids = 0;
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    outbox = InMemorySyncOutbox();
    backfill = DriftSyncBackfill(
      database: database,
      outbox: outbox,
      deviceId: () async => 'device-a',
      newId: newId,
      // Small on purpose: the paging has to be exercised by a history a test
      // can hold in its head.
      pageSize: 2,
    );
    await surahs.getRotationSnapshot();
  });

  tearDown(() => database.close());

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

  Future<SurahRecitationEvent> recite(String id, String surahId) async {
    final event = SurahRecitationEvent(
      id: id,
      surahId: surahId,
      prayerContext: PrayerContext(prayerType: PrayerType.fajr),
      createdAtUtc: now,
      localDate: localDate,
      rakaatSpanCount: 1,
    );
    await recitations.register(event);
    return event;
  }

  Map<SyncEntityType, List<SyncEnvelope>> byType(
    List<SyncOutboxEntry> entries,
  ) {
    final grouped = <SyncEntityType, List<SyncEnvelope>>{};
    for (final entry in entries) {
      grouped
          .putIfAbsent(entry.envelope.entityType, () => <SyncEnvelope>[])
          .add(entry.envelope);
    }
    return grouped;
  }

  /// The envelopes of one type, in the order they were queued.
  Future<List<SyncEnvelope>> queuedOfType(SyncEntityType type) async =>
      <SyncEnvelope>[
        for (final entry in await outbox.peek(limit: 1000))
          if (entry.envelope.entityType == type) entry.envelope,
      ];

  test('a device with no history still has a configuration', () async {
    // Not "queues nothing": a fresh database already holds the eight prayer
    // routines, and they are the user's configuration whether or not they have
    // edited them. An account that received none of them would hand a second
    // device a blank set of prayers.
    final report = await backfill.enqueueEverything(nowUtc: now);

    expect(report.enqueuedByType[SyncEntityType.recitationEvent], isNull);
    expect(
      report.enqueuedByType[SyncEntityType.prayerRoutineTemplate],
      greaterThan(0),
    );
    expect(report.skippedCount, 0);
  });

  test('every recitation reaches the queue, across pages', () async {
    await addSurah('surah-a', 112);
    // Five against a page size of two: the walk has to come back for more, and
    // the last page has to be recognised as the last.
    for (var index = 0; index < 5; index += 1) {
      await recite('event-$index', 'surah-a');
    }

    final report = await backfill.enqueueEverything(nowUtc: now);

    expect(report.enqueuedByType[SyncEntityType.recitationEvent], 5);
    expect(report.skippedCount, 0);
    final queued = byType(
      await outbox.peek(limit: 100),
    )[SyncEntityType.recitationEvent]!;
    expect(
      queued.map((envelope) => envelope.entityId).toSet(),
      <String>{'event-0', 'event-1', 'event-2', 'event-3', 'event-4'},
      reason: 'a page boundary must not drop or repeat a recitation',
    );
    expect(
      queued.every((envelope) => envelope.operation == SyncOperation.upsert),
      isTrue,
    );
  });

  test('a withdrawn recitation travels as the withdrawal, once', () async {
    await addSurah('surah-a', 112);
    final kept = await recite('kept', 'surah-a');
    await recite('withdrawn', 'surah-a');
    await recitations.deleteRecitation(
      'withdrawn',
      deletedAtUtc: now.add(const Duration(minutes: 5)),
    );

    final report = await backfill.enqueueEverything(nowUtc: now);

    final queued = byType(
      await outbox.peek(limit: 100),
    )[SyncEntityType.recitationEvent]!;
    expect(report.enqueuedByType[SyncEntityType.recitationEvent], 2);
    final withdrawn = queued.singleWhere(
      (envelope) => envelope.entityId == 'withdrawn',
    );
    expect(
      withdrawn.isTombstone,
      isTrue,
      reason:
          'the account needs the end state; sending the record and its deletion '
          'separately would race them',
    );
    expect(
      queued
          .singleWhere((envelope) => envelope.entityId == kept.id)
          .isTombstone,
      isFalse,
    );
  });

  test('the envelope is dated when the thing happened, not now', () async {
    await addSurah('surah-a', 112);
    final longAgo = DateTime.utc(2024, 3, 1, 5);
    await recitations.register(
      SurahRecitationEvent(
        id: 'old',
        surahId: 'surah-a',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr),
        createdAtUtc: longAgo,
        localDate: LocalDate(2024, 3, 1),
        rakaatSpanCount: 1,
      ),
    );

    await backfill.enqueueEverything(nowUtc: now);

    final envelope = (await queuedOfType(
      SyncEntityType.recitationEvent,
    )).single;
    expect(
      envelope.updatedAtUtc,
      longAgo,
      reason:
          'backdating is the point: an old recitation must not outrank a newer '
          'change on another device merely because it was queued today',
    );
  });

  test('running it twice leaves one envelope per record', () async {
    await addSurah('surah-a', 112);
    await recite('event-0', 'surah-a');
    await recite('event-1', 'surah-a');

    await backfill.enqueueEverything(nowUtc: now);
    final second = await backfill.enqueueEverything(
      nowUtc: now.add(const Duration(minutes: 1)),
    );

    expect(
      (await queuedOfType(SyncEntityType.recitationEvent)).length,
      2,
      reason:
          'the outbox coalesces per entity, which is what makes re-running the '
          'recovery path rather than a duplication',
    );
    expect(
      second.enqueuedByType[SyncEntityType.recitationEvent],
      2,
      reason: 'the report says what was offered, not what survived coalescing',
    );
  });

  test('the other three journals travel too', () async {
    await addSurah('surah-a', 112);
    // Written straight to the tables: this is a test of what the backfill
    // reads, and each of these has its own repository API whose shape is not
    // what is under examination here.
    await database
        .into(database.learningSurahs)
        .insert(
          LearningSurahsCompanion.insert(
            id: 'plan-1',
            surahId: 'surah-a',
            ayahCount: 4,
            stageKind: 'newAyah',
            stageStartAyah: 1,
            stageEndAyah: 2,
            targetStartAyah: 1,
            targetEndAyah: 4,
            status: 'active',
          ),
        );
    await database
        .into(database.learningEvents)
        .insert(
          LearningEventsCompanion.insert(
            id: 'learning-1',
            learningSurahId: 'plan-1',
            type: 'repeated',
            createdAtUtc: now,
            fromPlanKind: 'classicCumulative',
            fromTargetStartAyah: 1,
            fromTargetEndAyah: 4,
            fromStageKind: 'newAyah',
            fromStageStartAyah: 1,
            fromStageEndAyah: 1,
            toPlanKind: 'classicCumulative',
            toTargetStartAyah: 1,
            toTargetEndAyah: 4,
            toStageKind: 'newAyah',
            toStageStartAyah: 1,
            toStageEndAyah: 2,
          ),
        );
    await database
        .into(database.recallAttempts)
        .insert(
          RecallAttemptsCompanion.insert(
            id: 'recall-1',
            surahId: 'surah-a',
            ayahStart: 1,
            ayahEnd: 2,
            result: 'recalled',
            createdAtUtc: now,
            localDate: localDate.toString(),
            source: 'learning',
          ),
        );

    final report = await backfill.enqueueEverything(nowUtc: now);

    expect(
      report.enqueuedByType[SyncEntityType.learningEvent],
      1,
      reason:
          'the journal is what a rollback reads; it has to reach an account',
    );
    expect(
      report.enqueuedByType[SyncEntityType.recallAttempt],
      1,
      reason: 'his memory record is part of the history an account holds',
    );
    expect(report.skippedCount, 0);
  });

  test('one unrepresentable row does not cost the user the rest', () async {
    await addSurah('surah-a', 112);
    await recite('good', 'surah-a');
    await database
        .into(database.learningSurahs)
        .insert(
          LearningSurahsCompanion.insert(
            id: 'plan-1',
            surahId: 'surah-a',
            ayahCount: 4,
            stageKind: 'newAyah',
            stageStartAyah: 1,
            stageEndAyah: 2,
            targetStartAyah: 1,
            targetEndAyah: 4,
            status: 'active',
          ),
        );
    // A stage that today's invariants refuse: it ends past its own target.
    // The table predates the check and still holds rows like it.
    await database
        .into(database.learningEvents)
        .insert(
          LearningEventsCompanion.insert(
            id: 'impossible',
            learningSurahId: 'plan-1',
            type: 'repeated',
            createdAtUtc: now,
            fromPlanKind: 'classicCumulative',
            fromTargetStartAyah: 1,
            fromTargetEndAyah: 4,
            fromStageKind: 'newAyah',
            fromStageStartAyah: 1,
            fromStageEndAyah: 1,
            toPlanKind: 'classicCumulative',
            toTargetStartAyah: 1,
            toTargetEndAyah: 4,
            toStageKind: 'newAyah',
            toStageStartAyah: 1,
            toStageEndAyah: 99,
          ),
        );

    final report = await backfill.enqueueEverything(nowUtc: now);

    expect(
      report.enqueuedByType[SyncEntityType.recitationEvent],
      1,
      reason: 'the recitation is fine and must still go',
    );
    expect(
      report.skippedByType[SyncEntityType.learningEvent],
      1,
      reason: 'and the one that cannot be expressed is counted, not hidden',
    );
  });

  group('the versioned tables, and the date they cannot supply', () {
    test('a row that records when it changed says so', () async {
      await addSurah('surah-a', 112);
      final changedAt = DateTime.utc(2026, 9, 20, 8);
      await (database.update(
        database.masteredSurahs,
      )..where((row) => row.surahId.equals('surah-a'))).write(
        MasteredSurahsCompanion(updatedAtUtc: Value<DateTime>(changedAt)),
      );

      await backfill.enqueueEverything(nowUtc: now);

      final envelope = (await outbox.peek(limit: 100))
          .map((entry) => entry.envelope)
          .firstWhere(
            (envelope) => envelope.entityType == SyncEntityType.masteredSurah,
          );
      expect(envelope.updatedAtUtc, changedAt);
    });

    test('a row that cannot be dated loses to anything that can', () async {
      // Schema v10 added the column and backfilled nothing, so this is every
      // row a long-standing device has not touched since the upgrade.
      await addSurah('surah-a', 112);
      await (database.update(
        database.masteredSurahs,
      )..where((row) => row.surahId.equals('surah-a'))).write(
        const MasteredSurahsCompanion(updatedAtUtc: Value<DateTime?>(null)),
      );

      await backfill.enqueueEverything(nowUtc: now);

      final envelope = (await outbox.peek(limit: 100))
          .map((entry) => entry.envelope)
          .firstWhere(
            (envelope) => envelope.entityType == SyncEntityType.masteredSurah,
          );
      expect(
        envelope.updatedAtUtc,
        kUndatedByThisDevice,
        reason:
            'stamping it "now" would let a phone untouched for a year overwrite '
            'a newer edit from another one, simply by signing in — which is the '
            'loss the whole activation gate exists to prevent',
      );
      expect(
        envelope.updatedAtUtc.isBefore(now),
        isTrue,
        reason: 'and the account, which can date its copy, keeps it',
      );
    });

    test(
      'an undated prayer session is not refused by its own envelope',
      () async {
        // Found by the skipped counter, which is what it is for. An envelope
        // refuses an `updatedAtUtc` earlier than its `createdAtUtc`, and a
        // session's `createdAtUtc` is the moment the prayer began — a real past
        // moment, unlike every other versioned entity here. Stamping an undated
        // session at the epoch therefore contradicted it, and *every* session on
        // a device that upgraded to v10 would have been left behind: v10
        // backfilled nothing.
        final routines = PrayerRoutineRepository(database);
        final fajr = await routines.getTemplate(PrayerType.fajr);
        await routines.replaceTemplate(
          prayerType: PrayerType.fajr,
          expectedRevision: fajr.revision,
          displayName: fajr.displayName,
          enabled: true,
          parts: <PrayerRoutinePartTemplate>[
            PrayerRoutinePartTemplate(
              id: 'fajr-fard',
              stableKey: 'fard',
              orderIndex: 0,
              kind: PrayerRoutinePartKind.fard,
              rakaatCount: 2,
              requiredSurahSlots: 2,
            ),
          ],
        );
        final session = (await routines.ensureCurrentSession(
          context: PrayerContext(prayerType: PrayerType.fajr),
          localDate: localDate,
          startedAtUtc: now,
        ))!;
        // Exactly what an upgraded device holds: a real session with no date.
        await (database.update(
          database.prayerSessions,
        )..where((row) => row.id.equals(session.session.id))).write(
          const PrayerSessionsCompanion(updatedAtUtc: Value<DateTime?>(null)),
        );

        final report = await backfill.enqueueEverything(nowUtc: now);

        expect(
          report.skippedFields[SyncEntityType.prayerSession],
          isNull,
          reason: 'a session the owner really prayed has to reach his account',
        );
        expect(report.enqueuedByType[SyncEntityType.prayerSession], 1);
        final envelope = (await queuedOfType(
          SyncEntityType.prayerSession,
        )).single;
        expect(
          envelope.updatedAtUtc,
          now,
          reason:
              'raised to when the prayer began, which is the earliest it could '
              'honestly have changed — and still loses to any later edit',
        );
      },
    );

    test('a routine travels with its parts', () async {
      final routines = PrayerRoutineRepository(database);
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
            kind: PrayerRoutinePartKind.witr,
            customLabel: 'Важиб',
            rakaatCount: 3,
            requiredSurahSlots: 3,
          ),
        ],
      );

      final report = await backfill.enqueueEverything(nowUtc: now);

      expect(
        report.enqueuedByType[SyncEntityType.prayerRoutineTemplate],
        isNotNull,
      );
      final envelope = (await outbox.peek(limit: 100))
          .map((entry) => entry.envelope)
          .firstWhere(
            (envelope) =>
                envelope.entityType == SyncEntityType.prayerRoutineTemplate &&
                envelope.payload['prayerType'] == 'witr',
          );
      final decoded = PrayerRoutineSyncPayload.decode(
        envelope.payload,
        entityId: envelope.entityId,
      );
      expect(decoded.parts, hasLength(1));
      expect(
        decoded.parts.single.customLabel,
        'Важиб',
        reason: 'a part without its name is not the routine he configured',
      );
      expect(decoded.parts.single.kind, 'witr');
    });

    test('the rotation projection is never sent', () async {
      await addSurah('surah-a', 112);

      final report = await backfill.enqueueEverything(nowUtc: now);

      expect(
        report.enqueuedByType[SyncEntityType.rotationState],
        isNull,
        reason:
            'the router refuses this type by name, so queueing one would stall '
            'every other device on a record none of them can place',
      );
      expect(
        (await outbox.peek(limit: 100)).every(
          (entry) => entry.envelope.entityType != SyncEntityType.rotationState,
        ),
        isTrue,
      );
    });

    test('a setting outside the allow-list is a rule, not a gap', () async {
      final settings = AppSettingsRepository(database);
      await settings.setString('sync.deviceId', 'device-a', updatedAtUtc: now);

      final report = await backfill.enqueueEverything(nowUtc: now);

      expect(
        report.skippedByType[SyncEntityType.appSetting],
        isNull,
        reason:
            'this one has been decided never to travel; counting it as skipped '
            'would report a gap where there is a decision',
      );
      expect(
        (await outbox.peek(
          limit: 100,
        )).every((entry) => entry.envelope.entityId != 'sync.deviceId'),
        isTrue,
        reason: 'and a device id belongs to the device, not to the account',
      );
    });
  });

  group('what changed since last time', () {
    // This is the whole recorder. A change made after activation reaches the
    // queue because the database noticed it — schema v10 put touch triggers on
    // every versioned table — rather than because a repository remembered to
    // say so. A call site that forgets is a silent hole nothing fails on.
    // Two clocks meet in these tests and it is worth naming. The append-only
    // journals carry the timestamp the app supplies, which here is the fixed
    // `now`. The versioned tables are stamped by the v10 triggers, which call
    // `strftime('%s','now')` — the real wall clock, in whole seconds. A
    // watermark therefore has to be chosen against whichever of the two the
    // test is actually asking about.
    test('an unchanged device offers nothing', () async {
      await addSurah('surah-a', 112);
      await recite('event-0', 'surah-a');
      // Past both clocks, so neither kind of row can fall inside the window.
      // Taken from the real clock rather than from the fixture's `now`: the
      // trigger stamps wall time, and a fixture date plus a day stops being in
      // the future the moment the calendar passes it. It did, on 2026-09-23,
      // and this test failed for a reason that had nothing to do with the
      // change being made that day.
      final after = DateTime.now().toUtc().add(const Duration(days: 1));

      final report = await backfill.enqueueChangedSince(
        nowUtc: after,
        since: after,
      );

      expect(report.isEmpty, isTrue);
      expect(await outbox.pendingCount(), 0);
    });

    test('a surah added afterwards is offered, and only it', () async {
      await addSurah('surah-a', 112);
      // Long enough to cross a second boundary: the trigger's resolution is
      // one second, and a watermark inside the same second as the first row
      // would take it too, which is the inclusive boundary working as designed
      // rather than a fault.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // Truncated the way the cycle runner truncates it: the trigger writes
      // whole seconds, and a watermark carrying milliseconds would sit after a
      // row stamped in the same second and step over it.
      final wall = DateTime.now().toUtc();
      final watermark = DateTime.fromMillisecondsSinceEpoch(
        (wall.millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      );
      await addSurah('surah-b', 108);

      final report = await backfill.enqueueChangedSince(
        nowUtc: watermark,
        since: watermark,
      );

      expect(
        report.enqueuedByType[SyncEntityType.masteredSurah],
        1,
        reason:
            'the trigger stamped the new row and left the old one alone, which '
            'is the difference the scan is reading',
      );
      expect(
        (await queuedOfType(SyncEntityType.masteredSurah)).single.entityId,
        'surah-b',
      );
    });

    test('a recitation written afterwards is offered', () async {
      await addSurah('surah-a', 112);
      await recite('before', 'surah-a');
      final watermark = now.add(const Duration(hours: 1));
      await recitations.register(
        SurahRecitationEvent(
          id: 'after',
          surahId: 'surah-a',
          prayerContext: PrayerContext(prayerType: PrayerType.fajr),
          createdAtUtc: watermark.add(const Duration(minutes: 5)),
          localDate: localDate,
          rakaatSpanCount: 1,
        ),
      );

      await backfill.enqueueChangedSince(nowUtc: watermark, since: watermark);

      expect(
        (await queuedOfType(
          SyncEntityType.recitationEvent,
        )).map((envelope) => envelope.entityId).toList(),
        <String>['after'],
      );
    });

    test('a withdrawal afterwards is offered as the withdrawal', () async {
      await addSurah('surah-a', 112);
      await recite('event-0', 'surah-a');
      final watermark = now.add(const Duration(hours: 1));
      await recitations.deleteRecitation(
        'event-0',
        deletedAtUtc: watermark.add(const Duration(minutes: 5)),
      );

      await backfill.enqueueChangedSince(nowUtc: watermark, since: watermark);

      final queued = await queuedOfType(SyncEntityType.recitationEvent);
      expect(
        queued.single.isTombstone,
        isTrue,
        reason:
            'an append-only journal withdraws by writing a date rather than by '
            'removing the row, which is what makes a deletion visible to a scan',
      );
    });

    test('an undatable row is not mistaken for a recent change', () async {
      await addSurah('surah-a', 112);
      await (database.update(
        database.masteredSurahs,
      )..where((row) => row.surahId.equals('surah-a'))).write(
        const MasteredSurahsCompanion(updatedAtUtc: Value<DateTime?>(null)),
      );
      final watermark = now.add(const Duration(hours: 1));

      final report = await backfill.enqueueChangedSince(
        nowUtc: watermark,
        since: watermark,
      );

      expect(
        report.enqueuedByType[SyncEntityType.masteredSurah],
        isNull,
        reason:
            'a row with no date has not changed since the v10 upgrade — if it '
            'had, it would have one — and offering it every cycle would be a '
            'queue that never empties',
      );
    });

    test('completing a part makes its session travel', () async {
      // The one entity whose change can be entirely in a child row. Filling the
      // last slot of a part writes `prayer_session_parts.completed_at_utc` and
      // never touches the session, so a scan that looked only at the parent
      // would miss the most common change this app makes.
      await addSurah('surah-a', 112);
      final routines = PrayerRoutineRepository(database);
      // A prayer ships with an empty routine, and an empty routine has no
      // session to create.
      final fajr = await routines.getTemplate(PrayerType.fajr);
      await routines.replaceTemplate(
        prayerType: PrayerType.fajr,
        expectedRevision: fajr.revision,
        displayName: fajr.displayName,
        enabled: true,
        parts: <PrayerRoutinePartTemplate>[
          PrayerRoutinePartTemplate(
            id: 'fajr-fard',
            stableKey: 'fard',
            orderIndex: 0,
            kind: PrayerRoutinePartKind.fard,
            rakaatCount: 2,
            requiredSurahSlots: 2,
          ),
        ],
      );
      final session = (await routines.ensureCurrentSession(
        context: PrayerContext(prayerType: PrayerType.fajr),
        localDate: localDate,
        startedAtUtc: now,
      ))!;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final wall = DateTime.now().toUtc();
      final watermark = DateTime.fromMillisecondsSinceEpoch(
        (wall.millisecondsSinceEpoch ~/ 1000) * 1000,
        isUtc: true,
      );

      // The part completes; the session row is untouched.
      await (database.update(
        database.prayerSessionParts,
      )..where((row) => row.id.equals(session.parts.first.part.id))).write(
        PrayerSessionPartsCompanion(
          completedAtUtc: Value<DateTime>(
            watermark.add(const Duration(seconds: 1)),
          ),
        ),
      );

      final report = await backfill.enqueueChangedSince(
        nowUtc: watermark,
        since: watermark,
      );

      expect(
        report.skippedFields[SyncEntityType.prayerSession],
        isNull,
        reason: 'the session has to be expressible before it can travel',
      );
      expect(
        report.enqueuedByType[SyncEntityType.prayerSession],
        1,
        reason:
            'the account has to learn that the slot was filled, and nothing '
            'about the session row says so',
      );
    });

    test('the whole history is the same walk from the beginning', () async {
      await addSurah('surah-a', 112);
      await recite('event-0', 'surah-a');

      final everything = await backfill.enqueueEverything(nowUtc: now);
      await outbox.clear();
      final fromTheStart = await backfill.enqueueChangedSince(
        nowUtc: now,
        since: kUndatedByThisDevice,
      );

      expect(
        fromTheStart.enqueuedByType,
        everything.enqueuedByType,
        reason:
            'two walks that could drift apart is one more thing to keep in '
            'step; there is one, asked a different question',
      );
    });
  });

  test('the payload survives the round trip it was built for', () async {
    await addSurah('surah-a', 112);
    await recitations.register(
      SurahRecitationEvent(
        id: 'qada-event',
        surahId: 'surah-a',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr, isQada: true),
        createdAtUtc: now,
        localDate: localDate,
        rakaatSpanCount: 2,
        qadaOriginIsUnknown: true,
      ),
    );

    await backfill.enqueueEverything(nowUtc: now);

    final envelope = (await queuedOfType(
      SyncEntityType.recitationEvent,
    )).single;
    final decoded = RecitationSyncPayload.decode(
      envelope.payload,
      entityId: envelope.entityId,
    );
    expect(decoded.prayerContext.prayerType, PrayerType.fajr);
    expect(
      decoded.prayerContext.isQada,
      isTrue,
      reason: 'a Qada stays a Qada on the way out, or the account rewrites it',
    );
    expect(decoded.qadaOriginIsUnknown, isTrue);
    expect(decoded.rakaatSpanCount, 2);
  });
}
