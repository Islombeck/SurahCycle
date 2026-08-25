import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
  });

  tearDown(() => database.close());

  test(
    'catalog, mastered selection, alias, and active state persist',
    () async {
      await _seedCatalog(surahs);
      await surahs.addMastered('test-a');
      await surahs.addMastered('test-b', activate: false);
      await surahs.setAlias('test-a', 'My Test Alias');
      await surahs.setActive('test-b', isActive: true);
      await surahs.setActive('test-a', isActive: false);

      // Recreating repositories over the same executor models an app-layer
      // restart without retaining any in-memory repository state.
      final reopened = SurahRepository(database);
      final snapshot = await reopened.getRotationSnapshot();
      final catalog = await reopened.getCatalog(query: 'my test');

      expect(snapshot.rotationTarget, 1);
      expect(snapshot.surahById('test-a').isActive, isFalse);
      expect(snapshot.surahById('test-a').hasEnteredRotation, isTrue);
      expect(snapshot.surahById('test-a').surah.alias, 'My Test Alias');
      expect(snapshot.surahById('test-b').isActive, isTrue);
      expect(snapshot.surahById('test-b').hasEnteredRotation, isTrue);
      expect(snapshot.surahById('test-b').rotationScore, 0);
      expect(catalog, hasLength(1));
      expect(catalog.single.surah.id, 'test-a');
      expect(catalog.single.isMastered, isTrue);
    },
  );

  test(
    'register and immediate Undo restore the exact previous snapshot',
    () async {
      await _seedCatalog(surahs);
      await surahs.addMastered('test-a');
      final before = await surahs.getRotationSnapshot();
      final event = _recitation(
        id: '00000000-0000-4000-8000-000000000001',
        surahId: 'test-a',
        at: DateTime.utc(2026, 8, 24, 12, 0, 0, 987, 654),
        prayerType: PrayerType.asr,
      );

      final registration = await recitations.register(event);

      expect(registration.event.createdAtUtc, DateTime.utc(2026, 8, 24, 12));
      expect(registration.snapshot.rotationTarget, 2);
      expect(registration.snapshot.surahById('test-a').rotationScore, 1);
      expect(registration.snapshot.surahById('test-a').totalRecitations, 1);
      expect(
        registration.snapshot.surahById('test-a').lastUsedAtUtc,
        DateTime.utc(2026, 8, 24, 12),
      );
      expect((await recitations.getStats()).total, 1);

      final undo = await recitations.undo(registration.undoToken);

      expect(undo.didUndo, isTrue);
      expect(undo.undoneEventId, event.id);
      expect(undo.snapshot, before);
      expect(await surahs.getRotationSnapshot(), before);
      expect(await recitations.getHistory(), isEmpty);
      expect((await recitations.getStats()).total, 0);
      expect((await recitations.undo(registration.undoToken)).didUndo, isFalse);
    },
  );

  test(
    'history deletion rebuilds baseline, events, and adjustments with target floor',
    () async {
      await _seedCatalog(surahs);
      await surahs.addMastered('test-a');
      await surahs.addMastered('test-b');
      final eventA = _recitation(
        id: '00000000-0000-4000-8000-000000000010',
        surahId: 'test-a',
        at: DateTime.utc(2026, 8, 24, 10),
        prayerType: PrayerType.fajr,
      );
      await recitations.register(eventA);
      await recitations.applyAdjustment(
        RotationAdjustmentEvent(
          id: '00000000-0000-4000-8000-000000000011',
          surahId: 'test-a',
          delta: 2,
          reason: 'Test migration adjustment',
          createdAtUtc: DateTime.utc(2026, 8, 24, 10, 1),
        ),
      );
      await recitations.register(
        _recitation(
          id: '00000000-0000-4000-8000-000000000012',
          surahId: 'test-b',
          at: DateTime.utc(2026, 8, 24, 11),
          prayerType: PrayerType.asr,
        ),
      );
      await recitations.register(
        _recitation(
          id: '00000000-0000-4000-8000-000000000013',
          surahId: 'test-b',
          at: DateTime.utc(2026, 8, 24, 12),
          prayerType: PrayerType.asr,
        ),
      );
      expect((await surahs.getRotationSnapshot()).rotationTarget, 3);

      final deletion = await recitations.deleteRecitation(
        eventA.id,
        deletedAtUtc: DateTime.utc(2026, 8, 24, 13),
      );

      expect(deletion.didDelete, isTrue);
      expect(deletion.snapshot.rotationTarget, 3);
      expect(deletion.snapshot.surahById('test-a').rotationScore, 2);
      expect(deletion.snapshot.surahById('test-a').totalRecitations, 0);
      expect(deletion.snapshot.surahById('test-a').lastUsedAtUtc, isNull);
      expect(deletion.snapshot.surahById('test-b').rotationScore, 2);
      expect(deletion.snapshot.surahById('test-b').totalRecitations, 2);
      expect(await recitations.getHistory(), hasLength(2));
      final stats = await recitations.getStats();
      expect(stats.total, 2);
      expect(stats.bySurah.single.surah.id, 'test-b');
      expect(stats.bySurah.single.count, 2);
      expect(
        stats.byPrayer
            .singleWhere(
              (PrayerRecitationStat item) =>
                  item.context.prayerType == PrayerType.asr,
            )
            .count,
        2,
      );
    },
  );

  test(
    'learning inactivity Undo persists the retained period marker',
    () async {
      await _seedCatalog(surahs);
      final repository = LearningRepository(database);
      final lastActivity = DateTime.utc(2026, 8, 21, 8);
      final initial = LearningSurahState(
        id: 'learning-test-a',
        surahId: 'test-a',
        ayahCount: 3,
        stage: LearningStage.cumulative(3),
        lastLearningActivityAtUtc: lastActivity,
      );
      final machine = LearningStateMachine(
        timeProvider: _FixedTimeProvider(DateTime.utc(2026, 8, 24, 8)),
      );
      await repository.saveState(initial);
      final rollback = machine.applyInactivityRollback(
        initial,
        rollbackEventId: '00000000-0000-4000-8000-000000000020',
      );
      await repository.saveOutcome(rollback);
      final domainUndo = machine.undo(rollback);

      expect(
        await repository.undoOutcome(rollback, restoredState: domainUndo.value),
        isTrue,
      );

      final restored = await repository.getById(initial.id);
      expect(restored, domainUndo.value);
      expect(restored?.stage, LearningStage.cumulative(3));
      expect(restored?.inactivityRollbackForActivityAtUtc, lastActivity);
      expect(await repository.getEvents(initial.id), isEmpty);
    },
  );

  test(
    'learning Undo never overwrites progress saved after the target outcome',
    () async {
      await _seedCatalog(surahs);
      final repository = LearningRepository(database);
      final lastActivity = DateTime.utc(2026, 8, 21, 8);
      final initial = LearningSurahState(
        id: 'learning-test-a',
        surahId: 'test-a',
        ayahCount: 3,
        stage: LearningStage.cumulative(3),
        lastLearningActivityAtUtc: lastActivity,
      );
      final rollbackMachine = LearningStateMachine(
        timeProvider: _FixedTimeProvider(DateTime.utc(2026, 8, 24, 8)),
      );
      await repository.saveState(initial);
      final rollback = rollbackMachine.applyInactivityRollback(
        initial,
        rollbackEventId: '00000000-0000-4000-8000-000000000021',
      );
      await repository.saveOutcome(rollback);

      final progressMachine = LearningStateMachine(
        timeProvider: _FixedTimeProvider(DateTime.utc(2026, 8, 24, 8, 1)),
      );
      final newerProgress = progressMachine.markRepeated(
        rollback.state,
        eventId: '00000000-0000-4000-8000-000000000022',
      );
      await repository.saveOutcome(newerProgress);
      final domainUndo = rollbackMachine.undo(rollback);

      expect(
        await repository.undoOutcome(rollback, restoredState: domainUndo.value),
        isFalse,
      );
      expect(await repository.getById(initial.id), newerProgress.state);
      expect(
        (await repository.getEvents(initial.id)).map((event) => event.id),
        <String>[
          '00000000-0000-4000-8000-000000000021',
          '00000000-0000-4000-8000-000000000022',
        ],
      );
    },
  );

  test(
    'typed settings and selected prayer context survive repository recreation',
    () async {
      final settings = AppSettingsRepository(database);
      final at = DateTime.utc(2026, 8, 24, 14);
      await settings.setString('theme_mode', 'dark', updatedAtUtc: at);
      await settings.setBool('haptics', true, updatedAtUtc: at);
      await settings.setInt('history_limit', 50, updatedAtUtc: at);
      await settings.setDouble('text_scale', 1.25, updatedAtUtc: at);
      final prayers = PrayerRepository(database);
      final context = PrayerContext(prayerType: PrayerType.dhuhr, isQada: true);
      await prayers.saveSelectedContext(context, updatedAtUtc: at);

      final reopenedSettings = AppSettingsRepository(database);
      final reopenedPrayers = PrayerRepository(database);

      expect(await reopenedSettings.getString('theme_mode'), 'dark');
      expect(await reopenedSettings.getBool('haptics'), isTrue);
      expect(await reopenedSettings.getInt('history_limit'), 50);
      expect(await reopenedSettings.getDouble('text_scale'), 1.25);
      expect(await reopenedPrayers.getSelectedContext(), context);
    },
  );
}

Future<void> _seedCatalog(SurahRepository repository) =>
    repository.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'test-a',
          surahNumber: 1,
          officialName: 'Test Surah A',
          ayahCount: 3,
        ),
        SurahDescriptor(
          id: 'test-b',
          surahNumber: 2,
          officialName: 'Test Surah B',
          ayahCount: 4,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );

SurahRecitationEvent _recitation({
  required String id,
  required String surahId,
  required DateTime at,
  required PrayerType prayerType,
}) => SurahRecitationEvent(
  id: id,
  surahId: surahId,
  prayerContext: PrayerContext(prayerType: prayerType),
  createdAtUtc: at,
  localDate: LocalDate(2026, 8, 24),
);

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
