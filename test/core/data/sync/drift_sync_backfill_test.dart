import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
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

  test('an empty device queues nothing at all', () async {
    final report = await backfill.enqueueEverything(nowUtc: now);

    expect(report.isEmpty, isTrue);
    expect(report.skippedCount, 0);
    expect(await outbox.pendingCount(), 0);
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

    final envelope = (await outbox.peek(limit: 10)).single.envelope;
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
      await outbox.pendingCount(),
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

    final envelope = (await outbox.peek(limit: 10)).single.envelope;
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
