import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

import '../../generated_migrations/schema.dart';

void main() {
  test(
    'v1 to v4 preserves every legacy table and backfills v4 semantics',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(1);
      final raw = schema.rawDatabase;
      raw.execute('PRAGMA foreign_keys = ON');
      _seedVersionOne(raw);

      final migrationDatabase = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(
        migrationDatabase,
        4,
        // Runtime-only performance indexes are intentionally absent from the
        // generated Drift schema. Old tables are checked explicitly below.
        options: const ValidationOptions(),
      );

      expect(migrationDatabase.schemaVersion, 4);
      expect(
        await migrationDatabase
            .customSelect('PRAGMA user_version')
            .map((row) => row.read<int>('user_version'))
            .getSingle(),
        4,
      );
      expect(
        await migrationDatabase.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );

      final metadata = await migrationDatabase
          .select(migrationDatabase.surahMetadata)
          .get();
      expect(
        metadata
            .map(
              (row) => <Object?>[
                row.id,
                row.surahNumber,
                row.officialName,
                row.ayahCount,
                row.sourceId,
                row.sourceVersion,
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>['test-a', 2, 'Test A', 12, 'legacy-source', 'v1'],
          <Object?>['test-b', 3, 'Test B', 4, null, null],
        ],
      );

      final mastered = await migrationDatabase
          .select(migrationDatabase.masteredSurahs)
          .get();
      expect(mastered, hasLength(2));
      final masteredA = mastered.singleWhere((row) => row.surahId == 'test-a');
      expect(masteredA.isCurrentlyMastered, isTrue);
      expect(masteredA.isActive, isTrue);
      expect(masteredA.hasEnteredRotation, isTrue);
      expect(masteredA.activationBaselineScore, 5);
      expect(masteredA.cachedRotationScore, 8);
      expect(masteredA.cachedTotalRecitations, 2);
      expect(masteredA.cachedLastUsedAtUtc?.toUtc(), _utc(5));
      expect(masteredA.alias, 'Legacy alias');
      expect(masteredA.displayOrder, 7);
      final masteredB = mastered.singleWhere((row) => row.surahId == 'test-b');
      expect(masteredB.isCurrentlyMastered, isTrue);
      expect(masteredB.isActive, isFalse);
      expect(masteredB.hasEnteredRotation, isFalse);
      expect(masteredB.activationBaselineScore, isNull);
      expect(masteredB.cachedRotationScore, 0);
      expect(masteredB.cachedTotalRecitations, 0);
      expect(masteredB.cachedLastUsedAtUtc, isNull);
      expect(masteredB.displayOrder, 3);

      final state = await migrationDatabase
          .select(migrationDatabase.rotationStates)
          .getSingle();
      expect(state.singletonId, 1);
      expect(state.rotationTarget, 9);
      expect(state.lastJournalSequence, 5);
      expect(state.projectionVersion, 2);

      final schemes = await migrationDatabase
          .select(migrationDatabase.rotationSchemes)
          .get();
      expect(schemes, hasLength(2));
      final schemeA = schemes.singleWhere((row) => row.surahId == 'test-a');
      expect(schemeA.id, 'v1:test-a:scheme:1');
      expect(schemeA.version, 1);
      expect(schemeA.ayahCountSnapshot, 12);
      expect(schemeA.baselineScore, 5);
      expect(schemeA.baselineTotalRecitations, 0);
      expect(schemeA.baselineLastUsedAtUtc, isNull);
      expect(schemeA.resetsRotationBaseline, isFalse);
      expect(schemeA.activatedJournalSequence, 0);
      expect(schemeA.supersededJournalSequence, isNull);
      final schemeB = schemes.singleWhere((row) => row.surahId == 'test-b');
      expect(schemeB.id, 'v1:test-b:scheme:1');
      expect(schemeB.baselineScore, 0);
      expect(schemeB.resetsRotationBaseline, isFalse);

      final parts = await migrationDatabase
          .select(migrationDatabase.rotationParts)
          .get();
      expect(parts, hasLength(2));
      final partA = parts.singleWhere((row) => row.schemeId == schemeA.id);
      expect(partA.id, 'v1:test-a:scheme:1:part:1');
      expect(partA.ordinal, 1);
      expect(partA.startAyah, 1);
      expect(partA.endAyah, 12);
      expect(partA.cachedScore, 8);
      expect(partA.cachedRecitationCount, 2);
      expect(partA.cachedLastUsedAtUtc?.toUtc(), _utc(5));

      final sessions = await migrationDatabase
          .select(migrationDatabase.prayerSessions)
          .get();
      expect(sessions, hasLength(1));
      expect(sessions.single.id, 'legacy-session');
      expect(sessions.single.prayerType, 'dhuhr');
      expect(sessions.single.isQada, isTrue);
      expect(sessions.single.startedAtUtc.toUtc(), _utc(0));
      expect(sessions.single.localDate, '2026-08-24');

      final events = await migrationDatabase
          .select(migrationDatabase.recitationEvents)
          .get();
      events.sort(
        (left, right) => left.journalSequence.compareTo(right.journalSequence),
      );
      expect(events, hasLength(3));
      expect(
        events
            .map(
              (row) => <Object?>[
                row.id,
                row.journalSequence,
                row.surahId,
                row.rotationSchemeId,
                row.rakaatSpanCount,
                row.prayerSessionId,
                row.createdAtUtc.toUtc(),
                row.localDate,
                row.prayerType,
                row.isQada,
                row.deletedAtUtc?.toUtc(),
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>[
            'legacy-live-1',
            1,
            'test-a',
            schemeA.id,
            1,
            'legacy-session',
            _utc(1),
            '2026-08-24',
            'dhuhr',
            true,
            null,
          ],
          <Object?>[
            'legacy-deleted',
            2,
            'test-a',
            schemeA.id,
            1,
            null,
            _utc(2),
            '2026-08-24',
            'asr',
            false,
            _utc(9),
          ],
          <Object?>[
            'legacy-live-2',
            5,
            'test-a',
            schemeA.id,
            1,
            null,
            _utc(5),
            '2026-08-24',
            'maghrib',
            false,
            null,
          ],
        ],
      );
      expect(events.every((row) => row.rotationSchemeId == schemeA.id), isTrue);
      expect(events.every((row) => row.rakaatSpanCount == 1), isTrue);
      final liveOne = events.singleWhere((row) => row.id == 'legacy-live-1');
      expect(liveOne.journalSequence, 1);
      expect(liveOne.prayerSessionId, 'legacy-session');
      expect(liveOne.createdAtUtc.toUtc(), _utc(1));
      expect(liveOne.localDate, '2026-08-24');
      expect(liveOne.prayerType, 'dhuhr');
      expect(liveOne.isQada, isTrue);
      expect(liveOne.deletedAtUtc, isNull);
      final deleted = events.singleWhere((row) => row.id == 'legacy-deleted');
      expect(deleted.deletedAtUtc?.toUtc(), _utc(9));

      final coverage = await migrationDatabase
          .select(migrationDatabase.recitationEventParts)
          .get();
      expect(coverage, hasLength(3));
      expect(coverage.map((row) => row.eventId).toSet(), <String>{
        'legacy-live-1',
        'legacy-deleted',
        'legacy-live-2',
      });
      expect(coverage.every((row) => row.schemeId == schemeA.id), isTrue);
      expect(coverage.every((row) => row.partId == partA.id), isTrue);

      final adjustments = await migrationDatabase
          .select(migrationDatabase.rotationAdjustments)
          .get();
      adjustments.sort(
        (left, right) => left.journalSequence.compareTo(right.journalSequence),
      );
      expect(adjustments, hasLength(2));
      expect(
        adjustments.every((row) => row.rotationSchemeId == schemeA.id),
        isTrue,
      );
      expect(
        adjustments
            .map(
              (row) => <Object?>[
                row.id,
                row.journalSequence,
                row.surahId,
                row.rotationSchemeId,
                row.delta,
                row.reason,
                row.createdAtUtc.toUtc(),
                row.deletedAtUtc?.toUtc(),
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>[
            'legacy-adjustment-live',
            3,
            'test-a',
            schemeA.id,
            1,
            'Legacy correction',
            _utc(3),
            null,
          ],
          <Object?>[
            'legacy-adjustment-deleted',
            4,
            'test-a',
            schemeA.id,
            2,
            'Removed correction',
            _utc(4),
            _utc(10),
          ],
        ],
      );
      final liveAdjustment = adjustments.singleWhere(
        (row) => row.id == 'legacy-adjustment-live',
      );
      expect(liveAdjustment.journalSequence, 3);
      expect(liveAdjustment.delta, 1);
      expect(liveAdjustment.reason, 'Legacy correction');
      expect(liveAdjustment.createdAtUtc.toUtc(), _utc(3));
      expect(liveAdjustment.deletedAtUtc, isNull);
      expect(
        adjustments
            .singleWhere((row) => row.id == 'legacy-adjustment-deleted')
            .deletedAtUtc
            ?.toUtc(),
        _utc(10),
      );

      final learning = await migrationDatabase
          .select(migrationDatabase.learningSurahs)
          .getSingle();
      expect(learning.id, 'legacy-learning');
      expect(learning.surahId, 'test-b');
      expect(learning.ayahCount, 4);
      expect(learning.planKind, 'classicCumulative');
      expect(learning.stageKind, 'cumulative');
      expect(learning.stageStartAyah, 1);
      expect(learning.stageEndAyah, 3);
      expect(learning.targetStartAyah, 1);
      expect(learning.targetEndAyah, 4);
      expect(learning.blockSize, isNull);
      expect(learning.learningCycle, 1);
      expect(learning.status, 'active');
      expect(learning.lastLearningActivityAtUtc?.toUtc(), _utc(6));
      expect(learning.inactivityRollbackForActivityAtUtc?.toUtc(), _utc(2));
      final learningEvent = await migrationDatabase
          .select(migrationDatabase.learningEvents)
          .getSingle();
      expect(learningEvent.id, 'legacy-learning-event');
      expect(learningEvent.sequence, 11);
      expect(learningEvent.learningSurahId, learning.id);
      expect(learningEvent.type, 'learned');
      expect(learningEvent.createdAtUtc.toUtc(), _utc(7));
      expect(learningEvent.learningCycle, 1);
      expect(learningEvent.fromPlanKind, 'classicCumulative');
      expect(learningEvent.fromTargetStartAyah, 1);
      expect(learningEvent.fromTargetEndAyah, 4);
      expect(learningEvent.fromBlockSize, isNull);
      expect(learningEvent.fromStageKind, 'newAyah');
      expect(learningEvent.fromStageStartAyah, 3);
      expect(learningEvent.fromStageEndAyah, 3);
      expect(learningEvent.toPlanKind, 'classicCumulative');
      expect(learningEvent.toTargetStartAyah, 1);
      expect(learningEvent.toTargetEndAyah, 4);
      expect(learningEvent.toBlockSize, isNull);
      expect(learningEvent.toStageKind, 'cumulative');
      expect(learningEvent.toStageStartAyah, 1);
      expect(learningEvent.toStageEndAyah, 3);
      expect(learningEvent.reason, isNull);

      final settings = await migrationDatabase
          .select(migrationDatabase.appSettings)
          .get();
      expect(settings, hasLength(2));
      expect(
        settings
            .map(
              (row) => <Object?>[
                row.key,
                row.value,
                row.valueType,
                row.updatedAtUtc.toUtc(),
              ],
            )
            .toSet(),
        <List<Object?>>{
          <Object?>['legacy-bool', 'true', 'bool', _utc(8)],
          <Object?>['legacy-string', 'preserved', 'string', _utc(8)],
        },
      );

      final oldTables = await migrationDatabase.customSelect('''
        SELECT name FROM sqlite_schema
        WHERE type = 'table' AND (name LIKE '%_v1' OR name LIKE '%_v3')
      ''').get();
      expect(oldTables, isEmpty);

      await migrationDatabase.close();

      final reopened = AppDatabase(schema.newConnection());
      addTearDown(() async {
        await reopened.close();
        schema.close();
      });
      final surahs = SurahRepository(reopened);
      final recitations = RecitationRepository(reopened);
      final prayers = PrayerRepository(reopened);

      var snapshot = await surahs.getRotationSnapshot();
      expect(snapshot.rotationTarget, 9);
      expect(snapshot.surahById('test-a').rotationScore, 8);
      expect(snapshot.surahById('test-a').totalRecitations, 2);

      snapshot = await surahs.changeRotationScheme(
        surahId: 'test-a',
        proposedScheme: SurahRotationScheme.evenlySplit(
          id: 'test-a:scheme:2',
          surahId: 'test-a',
          version: 2,
          ayahCount: 12,
          partCount: 5,
        ),
        createdAtUtc: _utc(11),
      );
      final split = snapshot.surahById('test-a').rotationScheme;
      expect(split.parts, hasLength(5));
      expect(split.parts.map((part) => part.rotationScore), <int>[
        8,
        8,
        8,
        8,
        8,
      ]);

      final witrContext = PrayerContext(
        prayerType: PrayerType.witr,
        isQada: true,
      );
      await prayers.saveSession(
        PrayerSession(
          id: 'witr-session',
          context: witrContext,
          startedAtUtc: _utc(12),
        ),
        localDate: LocalDate(2026, 8, 24),
      );
      final registration = await recitations.register(
        SurahRecitationEvent(
          id: 'post-migration-split',
          surahId: 'test-a',
          prayerContext: witrContext,
          prayerSessionId: 'witr-session',
          createdAtUtc: _utc(13),
          localDate: LocalDate(2026, 8, 24),
          coverage: RecitationCoverage(
            rotationSchemeId: split.id,
            coveredPartIds: <String>[split.parts[0].id, split.parts[2].id],
          ),
          rakaatSpanCount: 3,
        ),
      );
      expect(registration.event.rakaatSpanCount, 3);
      expect(registration.event.coveredPartIds, <String>[
        split.parts[0].id,
        split.parts[2].id,
      ]);
      expect(
        registration.snapshot
            .surahById('test-a')
            .rotationScheme
            .parts
            .map((part) => part.rotationScore),
        <int>[9, 8, 9, 8, 8],
      );
      final storedPostMigration = await (reopened.select(
        reopened.recitationEvents,
      )..where((row) => row.id.equals('post-migration-split'))).getSingle();
      expect(storedPostMigration.prayerType, 'witr');
      expect(storedPostMigration.isQada, isTrue);
      expect(storedPostMigration.rakaatSpanCount, 3);
      expect(
        await (reopened.select(
          reopened.recitationEventParts,
        )..where((row) => row.eventId.equals('post-migration-split'))).get(),
        hasLength(2),
      );

      await _expectConstraint(reopened, """
          INSERT INTO prayer_sessions
            (id, prayer_type, is_qada, started_at_utc)
          VALUES ('invalid-nafl-qada', 'nafl', 1, 1)
        """);
      await _expectConstraint(reopened, """
          INSERT INTO recitation_events
            (id, journal_sequence, surah_id, rotation_scheme_id,
             rakaat_span_count, created_at_utc, local_date, prayer_type,
             is_qada)
          VALUES ('invalid-rakaat', 101, 'test-a', 'test-a:scheme:2',
                  0, 1, '2026-08-24', 'asr', 0)
        """);
      await _expectConstraint(reopened, """
          INSERT INTO recitation_event_parts (event_id, scheme_id, part_id)
          VALUES ('missing-event', 'test-a:scheme:2',
                  'test-a:scheme:2:part:1')
        """);
      await _expectConstraint(reopened, """
          INSERT INTO recitation_events
            (id, journal_sequence, surah_id, rotation_scheme_id,
             rakaat_span_count, created_at_utc, local_date, prayer_type,
             is_qada)
          VALUES ('cross-surah-event', 102, 'test-b', 'test-a:scheme:2',
                  1, 1, '2026-08-24', 'asr', 0)
        """);
      await _expectConstraint(reopened, """
          INSERT INTO rotation_adjustments
            (id, journal_sequence, surah_id, rotation_scheme_id, delta,
             reason, created_at_utc)
          VALUES ('cross-surah-adjustment', 103, 'test-b',
                  'test-a:scheme:2', 1, 'Invalid tuple', 1)
        """);
      await _expectConstraint(reopened, """
          INSERT INTO recitation_event_parts (event_id, scheme_id, part_id)
          VALUES ('post-migration-split', 'v1:test-a:scheme:1',
                  'v1:test-a:scheme:1:part:1')
        """);
      await _expectConstraint(reopened, """
          INSERT INTO recitation_event_parts (event_id, scheme_id, part_id)
          VALUES ('post-migration-split', 'test-a:scheme:2',
                  'v1:test-a:scheme:1:part:1')
        """);
      await _expectConstraint(reopened, """
          INSERT INTO rotation_parts
            (id, scheme_id, ordinal, start_ayah, end_ayah, cached_score,
             cached_recitation_count)
          VALUES ('orphan-part', 'missing-scheme', 1, 1, 1, 0, 0)
        """);
      await _expectConstraint(reopened, """
          INSERT INTO rotation_schemes
            (id, surah_id, version, ayah_count_snapshot, baseline_score,
             baseline_total_recitations, activated_journal_sequence)
          VALUES ('duplicate-current', 'test-a', 3, 12, 0, 0, 5)
        """);
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test('v2 to v4 preserves four-part state and accepts a fifth part', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(2);
    final raw = schema.rawDatabase;
    raw.execute('PRAGMA foreign_keys = ON');
    _seedVersionTwo(raw);

    final database = AppDatabase(schema.newConnection());
    addTearDown(() async {
      await database.close();
      schema.close();
    });
    await verifier.migrateAndValidate(
      database,
      4,
      options: const ValidationOptions(),
    );

    expect(database.schemaVersion, 4);
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      4,
    );
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );

    final metadata = await database.select(database.surahMetadata).getSingle();
    expect(
      <Object?>[
        metadata.id,
        metadata.surahNumber,
        metadata.officialName,
        metadata.ayahCount,
        metadata.sourceId,
        metadata.sourceVersion,
      ],
      <Object?>['v2-surah', 2, 'V2 Surah', 12, 'v2-source', 'v2'],
    );
    final mastered = await database.select(database.masteredSurahs).getSingle();
    expect(
      <Object?>[
        mastered.surahId,
        mastered.isCurrentlyMastered,
        mastered.isActive,
        mastered.hasEnteredRotation,
        mastered.activationBaselineScore,
        mastered.cachedRotationScore,
        mastered.cachedTotalRecitations,
        mastered.cachedLastUsedAtUtc?.toUtc(),
        mastered.alias,
        mastered.displayOrder,
      ],
      <Object?>['v2-surah', true, true, true, 5, 7, 3, _utc(4), 'V2 alias', 6],
    );
    final rotationState = await database
        .select(database.rotationStates)
        .getSingle();
    expect(
      <int>[
        rotationState.rotationTarget,
        rotationState.lastJournalSequence,
        rotationState.projectionVersion,
      ],
      <int>[10, 3, 2],
    );

    final tableSql = await database
        .customSelect(
          "SELECT sql FROM sqlite_schema "
          "WHERE type = 'table' AND name = 'rotation_parts'",
        )
        .map((row) => row.read<String>('sql'))
        .getSingle();
    expect(tableSql, contains('CHECK (ordinal >= 1)'));
    expect(tableSql, isNot(contains('BETWEEN 1 AND 4')));

    final schemes = await database.select(database.rotationSchemes).get();
    expect(
      schemes
          .map(
            (row) => <Object?>[
              row.id,
              row.surahId,
              row.version,
              row.ayahCountSnapshot,
              row.baselineScore,
              row.baselineTotalRecitations,
              row.baselineLastUsedAtUtc?.toUtc(),
              row.resetsRotationBaseline,
              row.activatedJournalSequence,
              row.supersededJournalSequence,
            ],
          )
          .toList(),
      <List<Object?>>[
        <Object?>[
          'v2-surah:scheme:1',
          'v2-surah',
          1,
          12,
          5,
          2,
          _utc(0),
          false,
          0,
          null,
        ],
      ],
    );

    final parts = await database.select(database.rotationParts).get()
      ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
    expect(
      parts
          .map(
            (row) => <Object?>[
              row.id,
              row.schemeId,
              row.ordinal,
              row.startAyah,
              row.endAyah,
              row.cachedScore,
              row.cachedRecitationCount,
              row.cachedLastUsedAtUtc?.toUtc(),
            ],
          )
          .toList(),
      <List<Object?>>[
        <Object?>['v2-p1', 'v2-surah:scheme:1', 1, 1, 3, 8, 4, _utc(1)],
        <Object?>['v2-p2', 'v2-surah:scheme:1', 2, 4, 6, 7, 3, _utc(2)],
        <Object?>['v2-p3', 'v2-surah:scheme:1', 3, 7, 9, 9, 5, _utc(3)],
        <Object?>['v2-p4', 'v2-surah:scheme:1', 4, 10, 12, 7, 3, _utc(4)],
      ],
    );

    final eventRows = await database.select(database.recitationEvents).get()
      ..sort(
        (left, right) => left.journalSequence.compareTo(right.journalSequence),
      );
    expect(
      eventRows
          .map(
            (row) => <Object?>[
              row.id,
              row.journalSequence,
              row.rotationSchemeId,
              row.rakaatSpanCount,
              row.prayerSessionId,
              row.createdAtUtc.toUtc(),
              row.localDate,
              row.prayerType,
              row.isQada,
              row.deletedAtUtc?.toUtc(),
            ],
          )
          .toList(),
      <List<Object?>>[
        <Object?>[
          'v2-live',
          1,
          'v2-surah:scheme:1',
          2,
          'v2-session',
          _utc(5),
          '2026-08-24',
          'asr',
          false,
          null,
        ],
        <Object?>[
          'v2-deleted',
          2,
          'v2-surah:scheme:1',
          1,
          null,
          _utc(6),
          '2026-08-24',
          'maghrib',
          false,
          _utc(9),
        ],
      ],
    );
    final coverage = await database.select(database.recitationEventParts).get()
      ..sort((left, right) {
        final event = left.eventId.compareTo(right.eventId);
        return event != 0 ? event : left.partId.compareTo(right.partId);
      });
    expect(
      coverage.map((row) => <String>[row.eventId, row.schemeId, row.partId]),
      <List<String>>[
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p1'],
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p2'],
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p3'],
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p4'],
        <String>['v2-live', 'v2-surah:scheme:1', 'v2-p2'],
        <String>['v2-live', 'v2-surah:scheme:1', 'v2-p4'],
      ],
    );

    final prayerSession = await database
        .select(database.prayerSessions)
        .getSingle();
    expect(
      <Object?>[
        prayerSession.id,
        prayerSession.prayerType,
        prayerSession.isQada,
        prayerSession.startedAtUtc.toUtc(),
        prayerSession.localDate,
      ],
      <Object?>['v2-session', 'dhuhr', true, _utc(5), '2026-08-24'],
    );
    final adjustment = await database
        .select(database.rotationAdjustments)
        .getSingle();
    expect(
      <Object?>[
        adjustment.id,
        adjustment.journalSequence,
        adjustment.surahId,
        adjustment.rotationSchemeId,
        adjustment.delta,
        adjustment.reason,
        adjustment.createdAtUtc.toUtc(),
        adjustment.deletedAtUtc?.toUtc(),
      ],
      <Object?>[
        'v2-adjustment',
        3,
        'v2-surah',
        'v2-surah:scheme:1',
        -1,
        'Preserved v2 adjustment',
        _utc(7),
        null,
      ],
    );
    final learning = await database.select(database.learningSurahs).getSingle();
    expect(
      <Object?>[
        learning.id,
        learning.surahId,
        learning.ayahCount,
        learning.planKind,
        learning.stageKind,
        learning.stageStartAyah,
        learning.stageEndAyah,
        learning.targetStartAyah,
        learning.targetEndAyah,
        learning.blockSize,
        learning.learningCycle,
        learning.status,
        learning.lastLearningActivityAtUtc?.toUtc(),
        learning.inactivityRollbackForActivityAtUtc?.toUtc(),
      ],
      <Object?>[
        'v2-learning',
        'v2-surah',
        12,
        'classicCumulative',
        'newAyah',
        5,
        5,
        1,
        12,
        null,
        1,
        'active',
        _utc(8),
        null,
      ],
    );
    final learningEvent = await database
        .select(database.learningEvents)
        .getSingle();
    expect(
      <Object?>[
        learningEvent.id,
        learningEvent.sequence,
        learningEvent.learningSurahId,
        learningEvent.type,
        learningEvent.createdAtUtc.toUtc(),
        learningEvent.learningCycle,
        learningEvent.fromPlanKind,
        learningEvent.fromStageKind,
        learningEvent.fromStageStartAyah,
        learningEvent.fromStageEndAyah,
        learningEvent.toPlanKind,
        learningEvent.toStageKind,
        learningEvent.toStageStartAyah,
        learningEvent.toStageEndAyah,
        learningEvent.reason,
      ],
      <Object?>[
        'v2-learning-event',
        12,
        'v2-learning',
        'repeated',
        _utc(8),
        1,
        'classicCumulative',
        'newAyah',
        5,
        5,
        'classicCumulative',
        'newAyah',
        5,
        5,
        null,
      ],
    );
    final setting = await database.select(database.appSettings).getSingle();
    expect(
      <Object?>[
        setting.key,
        setting.value,
        setting.valueType,
        setting.updatedAtUtc.toUtc(),
      ],
      <Object?>['v2-setting', '42', 'int', _utc(9)],
    );

    await _expectConstraint(database, '''
      INSERT INTO rotation_parts
        (id, scheme_id, ordinal, start_ayah, end_ayah, cached_score,
         cached_recitation_count)
      VALUES ('invalid-zero', 'v2-surah:scheme:1', 0, 1, 1, 0, 0)
    ''');

    final surahs = SurahRepository(database);
    final recitations = RecitationRepository(database);
    final beforeChange = await surahs.getRotationSnapshot();
    expect(beforeChange.surahById('v2-surah').rotationScore, 7);
    expect(beforeChange.surahById('v2-surah').totalRecitations, 3);

    final proposed = SurahRotationScheme.evenlySplit(
      id: 'v2-surah:scheme:2',
      surahId: 'v2-surah',
      version: 2,
      ayahCount: 12,
      partCount: 5,
    );
    final afterChange = await surahs.changeRotationScheme(
      surahId: 'v2-surah',
      proposedScheme: proposed,
      createdAtUtc: _utc(11),
    );
    final fivePartScheme = afterChange.surahById('v2-surah').rotationScheme;
    expect(fivePartScheme.parts, hasLength(5));
    expect(fivePartScheme.parts.map((part) => part.rotationScore), <int>[
      7,
      7,
      7,
      7,
      7,
    ]);
    expect(fivePartScheme.parts.map((part) => part.recitationCount), <int>[
      3,
      3,
      3,
      3,
      3,
    ]);

    await recitations.register(
      SurahRecitationEvent(
        id: 'v3-fifth-part',
        surahId: 'v2-surah',
        prayerContext: PrayerContext(prayerType: PrayerType.asr),
        createdAtUtc: _utc(12),
        localDate: LocalDate(2026, 8, 24),
        rotationSchemeId: fivePartScheme.id,
        coveredPartIds: <String>[fivePartScheme.parts[4].id],
        // Part count and rakaat count are intentionally independent.
        rakaatSpanCount: 1,
      ),
    );
    final storedFifthCoverage = await (database.select(
      database.recitationEventParts,
    )..where((row) => row.eventId.equals('v3-fifth-part'))).getSingle();
    expect(storedFifthCoverage.partId, fivePartScheme.parts[4].id);

    final oldParts = await (database.select(
      database.rotationParts,
    )..where((row) => row.schemeId.equals('v2-surah:scheme:1'))).get();
    expect(oldParts, hasLength(4));
    final history = await recitations.getHistory();
    final legacyHistory = history.singleWhere(
      (entry) => entry.event.id == 'v2-live',
    );
    expect(legacyHistory.event.rakaatSpanCount, 2);
    expect(legacyHistory.coveredParts.map((part) => part.id).toSet(), <String>{
      'v2-p2',
      'v2-p4',
    });
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });

  test('v3 to v4 preserves all data and backfills generic learning', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);
    final raw = schema.rawDatabase;
    raw.execute('PRAGMA foreign_keys = ON');
    _seedVersionThree(raw);

    final database = AppDatabase(schema.newConnection());
    addTearDown(() async {
      await database.close();
      schema.close();
    });
    await verifier.migrateAndValidate(
      database,
      4,
      options: const ValidationOptions(),
    );

    expect(database.schemaVersion, 4);
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      4,
    );
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );

    final mastered = await database.select(database.masteredSurahs).getSingle();
    expect(mastered.surahId, 'v2-surah');
    expect(mastered.isCurrentlyMastered, isTrue);
    expect(mastered.isActive, isTrue);
    expect(mastered.cachedRotationScore, 7);
    expect(mastered.cachedTotalRecitations, 3);
    expect(mastered.alias, 'V2 alias');
    final rotationState = await database
        .select(database.rotationStates)
        .getSingle();
    expect(rotationState.rotationTarget, 10);
    expect(rotationState.lastJournalSequence, 4);
    expect(rotationState.projectionVersion, 2);
    final scheme = await database.select(database.rotationSchemes).getSingle();
    expect(
      <Object?>[
        scheme.id,
        scheme.surahId,
        scheme.version,
        scheme.ayahCountSnapshot,
        scheme.baselineScore,
        scheme.baselineTotalRecitations,
        scheme.baselineLastUsedAtUtc?.toUtc(),
        scheme.resetsRotationBaseline,
        scheme.activatedJournalSequence,
        scheme.supersededJournalSequence,
      ],
      <Object?>[
        'v2-surah:scheme:1',
        'v2-surah',
        1,
        12,
        5,
        2,
        _utc(0),
        false,
        0,
        null,
      ],
    );
    final parts = await database.select(database.rotationParts).get()
      ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
    expect(
      parts
          .map(
            (row) => <Object?>[
              row.id,
              row.ordinal,
              row.startAyah,
              row.endAyah,
              row.cachedScore,
              row.cachedRecitationCount,
              row.cachedLastUsedAtUtc?.toUtc(),
            ],
          )
          .toList(),
      <List<Object?>>[
        <Object?>['v2-p1', 1, 1, 3, 8, 4, _utc(1)],
        <Object?>['v2-p2', 2, 4, 6, 7, 3, _utc(2)],
        <Object?>['v2-p3', 3, 7, 9, 9, 5, _utc(3)],
        <Object?>['v2-p4', 4, 10, 12, 7, 3, _utc(4)],
      ],
    );
    expect(
      (await database.select(database.recitationEvents).get())
          .map(
            (row) => <Object?>[
              row.id,
              row.journalSequence,
              row.rotationSchemeId,
              row.rakaatSpanCount,
              row.prayerSessionId,
              row.createdAtUtc.toUtc(),
              row.localDate,
              row.prayerType,
              row.isQada,
              row.deletedAtUtc?.toUtc(),
            ],
          )
          .toSet(),
      <List<Object?>>{
        <Object?>[
          'v2-live',
          1,
          'v2-surah:scheme:1',
          2,
          'v2-session',
          _utc(5),
          '2026-08-24',
          'asr',
          false,
          null,
        ],
        <Object?>[
          'v2-deleted',
          2,
          'v2-surah:scheme:1',
          1,
          null,
          _utc(6),
          '2026-08-24',
          'maghrib',
          false,
          _utc(9),
        ],
      },
    );
    expect(
      (await database.select(database.recitationEventParts).get())
          .map((row) => <String>[row.eventId, row.schemeId, row.partId])
          .toSet(),
      <List<String>>{
        <String>['v2-live', 'v2-surah:scheme:1', 'v2-p2'],
        <String>['v2-live', 'v2-surah:scheme:1', 'v2-p4'],
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p1'],
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p2'],
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p3'],
        <String>['v2-deleted', 'v2-surah:scheme:1', 'v2-p4'],
      },
    );
    final adjustments = await database
        .select(database.rotationAdjustments)
        .get();
    expect(
      adjustments
          .map(
            (row) => <Object?>[
              row.id,
              row.journalSequence,
              row.surahId,
              row.rotationSchemeId,
              row.delta,
              row.reason,
              row.createdAtUtc.toUtc(),
              row.deletedAtUtc?.toUtc(),
            ],
          )
          .toSet(),
      <List<Object?>>{
        <Object?>[
          'v2-adjustment',
          3,
          'v2-surah',
          'v2-surah:scheme:1',
          -1,
          'Preserved v2 adjustment',
          _utc(7),
          null,
        ],
        <Object?>[
          'v3-adjustment',
          4,
          'v2-surah',
          'v2-surah:scheme:1',
          1,
          'Preserved v3 adjustment',
          _utc(12),
          null,
        ],
      },
    );
    final sessions = await database.select(database.prayerSessions).get();
    expect(
      sessions
          .map(
            (row) => <Object?>[
              row.id,
              row.prayerType,
              row.isQada,
              row.startedAtUtc.toUtc(),
              row.localDate,
            ],
          )
          .toSet(),
      <List<Object?>>{
        <Object?>['v2-session', 'dhuhr', true, _utc(5), '2026-08-24'],
        <Object?>['v3-session', 'witr', false, _utc(12), '2026-08-24'],
      },
    );
    final settings = await database.select(database.appSettings).get();
    expect(
      settings
          .map(
            (row) => <Object?>[
              row.key,
              row.value,
              row.valueType,
              row.updatedAtUtc.toUtc(),
            ],
          )
          .toSet(),
      <List<Object?>>{
        <Object?>['v2-setting', '42', 'int', _utc(9)],
        <Object?>['v3-setting', 'preserved', 'string', _utc(14)],
      },
    );

    final learning = await database.select(database.learningSurahs).getSingle();
    expect(learning.id, 'v3-learning');
    expect(learning.surahId, 'v2-surah');
    expect(learning.planKind, LearningPlanKind.classicCumulative.name);
    expect(learning.stageKind, LearningStageKind.cumulative.name);
    expect(learning.stageStartAyah, 1);
    expect(learning.stageEndAyah, 6);
    expect(learning.targetStartAyah, 1);
    expect(learning.targetEndAyah, 12);
    expect(learning.blockSize, isNull);
    expect(learning.learningCycle, 1);
    expect(learning.status, LearningStatus.active.name);
    expect(learning.lastLearningActivityAtUtc?.toUtc(), _utc(13));
    expect(learning.inactivityRollbackForActivityAtUtc?.toUtc(), _utc(10));

    final event = await database.select(database.learningEvents).getSingle();
    expect(event.id, 'v3-learning-event');
    expect(event.sequence, 21);
    expect(event.learningCycle, 1);
    expect(event.fromPlanKind, LearningPlanKind.classicCumulative.name);
    expect(event.fromTargetStartAyah, 1);
    expect(event.fromTargetEndAyah, 12);
    expect(event.fromStageKind, LearningStageKind.newAyah.name);
    expect(event.fromStageStartAyah, 6);
    expect(event.fromStageEndAyah, 6);
    expect(event.toPlanKind, LearningPlanKind.classicCumulative.name);
    expect(event.toTargetStartAyah, 1);
    expect(event.toTargetEndAyah, 12);
    expect(event.toStageKind, LearningStageKind.cumulative.name);
    expect(event.toStageStartAyah, 1);
    expect(event.toStageEndAyah, 6);
    expect(event.reason, isNull);

    final learningRepository = LearningRepository(database);
    final restored = await learningRepository.getById('v3-learning');
    expect(restored, isNotNull);
    expect(restored!.plan.kind, LearningPlanKind.classicCumulative);
    expect(restored.plan.targetStartAyah, 1);
    expect(restored.plan.targetEndAyah, 12);
    expect(restored.stage.kind, LearningStageKind.cumulative);
    expect(restored.stage.startAyah, 1);
    expect(restored.stage.endAyah, 6);
    expect(restored.stage.sequenceIndex, 10);
    expect(restored.lastLearningActivityAtUtc, _utc(13));
    final restoredEvents = await learningRepository.getEvents(restored.id);
    expect(restoredEvents.single.fromStage.sequenceIndex, 9);
    expect(restoredEvents.single.toStage.sequenceIndex, 10);
    final rollbackMachine = LearningStateMachine(
      timeProvider: _FixedTimeProvider(_utc(13).add(const Duration(hours: 72))),
    );
    final rollback = rollbackMachine.applyInactivityRollback(
      restored,
      rollbackEventId: 'v3-post-migration-rollback',
    );
    expect(rollback.didRollback, isTrue);
    expect(rollback.state.stage.kind, LearningStageKind.newAyah);
    expect(rollback.state.stage.startAyah, 6);
    expect(rollback.state.stage.endAyah, 6);
    expect(rollback.state.stage.sequenceIndex, 9);
    final sameIdlePeriod = rollbackMachine.applyInactivityRollback(
      rollback.state,
      rollbackEventId: 'v3-post-migration-rollback-again',
    );
    expect(sameIdlePeriod.didRollback, isFalse);
    expect(sameIdlePeriod.state.stage.sequenceIndex, 9);

    await _expectConstraint(database, '''
      UPDATE mastered_surahs
      SET is_currently_mastered = 0, is_active = 1
      WHERE surah_id = 'v2-surah'
    ''');
    await database.customStatement('''
      UPDATE mastered_surahs
      SET is_currently_mastered = 0, is_active = 0
      WHERE surah_id = 'v2-surah'
    ''');
    final archived = await database.select(database.masteredSurahs).getSingle();
    expect(archived.isCurrentlyMastered, isFalse);
    expect(archived.isActive, isFalse);
    expect(
      await database.select(database.recitationEvents).get(),
      hasLength(2),
    );
    expect(await database.select(database.rotationSchemes).get(), hasLength(1));
  });
}

DateTime _utc(int minute) => DateTime.utc(2026, 8, 24, 10, minute);

int _encoded(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

void _seedVersionOne(dynamic raw) {
  raw.execute(
    'INSERT INTO surah_metadata '
    '(id, surah_number, official_name, ayah_count, source_id, source_version) '
    "VALUES ('test-a', 2, 'Test A', 12, 'legacy-source', 'v1'), "
    "('test-b', 3, 'Test B', 4, NULL, NULL)",
  );
  raw.execute(
    'INSERT INTO mastered_surahs '
    '(surah_id, is_active, has_entered_rotation, activation_baseline_score, '
    'cached_rotation_score, cached_total_recitations, '
    'cached_last_used_at_utc, alias, display_order) VALUES (?, ?, ?, ?, ?, ?, '
    '?, ?, ?)',
    <Object?>['test-a', 1, 1, 5, 8, 2, _encoded(_utc(5)), 'Legacy alias', 7],
  );
  raw.execute(
    'INSERT INTO mastered_surahs '
    '(surah_id, is_active, has_entered_rotation, activation_baseline_score, '
    'cached_rotation_score, cached_total_recitations, '
    'cached_last_used_at_utc, alias, display_order) '
    "VALUES ('test-b', 0, 0, NULL, 0, 0, NULL, NULL, 3)",
  );
  raw.execute(
    'INSERT INTO rotation_states '
    '(singleton_id, rotation_target, last_journal_sequence, '
    'projection_version) VALUES (1, 9, 5, 1)',
  );
  raw.execute(
    'INSERT INTO prayer_sessions '
    '(id, prayer_type, is_qada, started_at_utc, local_date) '
    'VALUES (?, ?, ?, ?, ?)',
    <Object?>['legacy-session', 'dhuhr', 1, _encoded(_utc(0)), '2026-08-24'],
  );
  raw.execute(
    'INSERT INTO recitation_events '
    '(id, journal_sequence, surah_id, prayer_session_id, created_at_utc, '
    'local_date, prayer_type, is_qada, deleted_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'legacy-live-1',
      1,
      'test-a',
      'legacy-session',
      _encoded(_utc(1)),
      '2026-08-24',
      'dhuhr',
      1,
      null,
    ],
  );
  raw.execute(
    'INSERT INTO recitation_events '
    '(id, journal_sequence, surah_id, prayer_session_id, created_at_utc, '
    'local_date, prayer_type, is_qada, deleted_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'legacy-deleted',
      2,
      'test-a',
      null,
      _encoded(_utc(2)),
      '2026-08-24',
      'asr',
      0,
      _encoded(_utc(9)),
    ],
  );
  raw.execute(
    'INSERT INTO rotation_adjustments '
    '(id, journal_sequence, surah_id, delta, reason, created_at_utc, '
    'deleted_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'legacy-adjustment-live',
      3,
      'test-a',
      1,
      'Legacy correction',
      _encoded(_utc(3)),
      null,
    ],
  );
  raw.execute(
    'INSERT INTO rotation_adjustments '
    '(id, journal_sequence, surah_id, delta, reason, created_at_utc, '
    'deleted_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'legacy-adjustment-deleted',
      4,
      'test-a',
      2,
      'Removed correction',
      _encoded(_utc(4)),
      _encoded(_utc(10)),
    ],
  );
  raw.execute(
    'INSERT INTO recitation_events '
    '(id, journal_sequence, surah_id, prayer_session_id, created_at_utc, '
    'local_date, prayer_type, is_qada, deleted_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'legacy-live-2',
      5,
      'test-a',
      null,
      _encoded(_utc(5)),
      '2026-08-24',
      'maghrib',
      0,
      null,
    ],
  );
  raw.execute(
    'INSERT INTO learning_surahs '
    '(id, surah_id, ayah_count, stage_kind, stage_end_ayah, status, '
    'last_learning_activity_at_utc, '
    'inactivity_rollback_for_activity_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'legacy-learning',
      'test-b',
      4,
      'cumulative',
      3,
      'active',
      _encoded(_utc(6)),
      _encoded(_utc(2)),
    ],
  );
  raw.execute(
    'INSERT INTO learning_events '
    '(id, sequence, learning_surah_id, type, created_at_utc, '
    'from_stage_kind, from_stage_end_ayah, to_stage_kind, to_stage_end_ayah) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'legacy-learning-event',
      11,
      'legacy-learning',
      'learned',
      _encoded(_utc(7)),
      'newAyah',
      3,
      'cumulative',
      3,
    ],
  );
  raw.execute(
    'INSERT INTO app_settings (key, value, value_type, updated_at_utc) '
    'VALUES (?, ?, ?, ?), (?, ?, ?, ?)',
    <Object?>[
      'legacy-bool',
      'true',
      'bool',
      _encoded(_utc(8)),
      'legacy-string',
      'preserved',
      'string',
      _encoded(_utc(8)),
    ],
  );
}

void _seedVersionTwo(dynamic raw) {
  raw.execute(
    'INSERT INTO surah_metadata '
    '(id, surah_number, official_name, ayah_count, source_id, source_version) '
    "VALUES ('v2-surah', 2, 'V2 Surah', 12, 'v2-source', 'v2')",
  );
  raw.execute(
    'INSERT INTO mastered_surahs '
    '(surah_id, is_active, has_entered_rotation, activation_baseline_score, '
    'cached_rotation_score, cached_total_recitations, '
    'cached_last_used_at_utc, alias, display_order) VALUES (?, ?, ?, ?, ?, ?, '
    '?, ?, ?)',
    <Object?>['v2-surah', 1, 1, 5, 7, 3, _encoded(_utc(4)), 'V2 alias', 6],
  );
  raw.execute(
    'INSERT INTO rotation_states '
    '(singleton_id, rotation_target, last_journal_sequence, '
    'projection_version) VALUES (1, 10, 3, 2)',
  );
  raw.execute(
    'INSERT INTO rotation_schemes '
    '(id, surah_id, version, ayah_count_snapshot, baseline_score, '
    'baseline_total_recitations, baseline_last_used_at_utc, '
    'activated_journal_sequence, superseded_journal_sequence) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v2-surah:scheme:1',
      'v2-surah',
      1,
      12,
      5,
      2,
      _encoded(_utc(0)),
      0,
      null,
    ],
  );
  for (final part in <(String, int, int, int, int, int, DateTime)>[
    ('v2-p1', 1, 1, 3, 8, 4, _utc(1)),
    ('v2-p2', 2, 4, 6, 7, 3, _utc(2)),
    ('v2-p3', 3, 7, 9, 9, 5, _utc(3)),
    ('v2-p4', 4, 10, 12, 7, 3, _utc(4)),
  ]) {
    raw.execute(
      'INSERT INTO rotation_parts '
      '(id, scheme_id, ordinal, start_ayah, end_ayah, cached_score, '
      'cached_recitation_count, cached_last_used_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        part.$1,
        'v2-surah:scheme:1',
        part.$2,
        part.$3,
        part.$4,
        part.$5,
        part.$6,
        _encoded(part.$7),
      ],
    );
  }
  raw.execute(
    'INSERT INTO prayer_sessions '
    '(id, prayer_type, is_qada, started_at_utc, local_date) '
    'VALUES (?, ?, ?, ?, ?)',
    <Object?>['v2-session', 'dhuhr', 1, _encoded(_utc(5)), '2026-08-24'],
  );
  raw.execute(
    'INSERT INTO recitation_events '
    '(id, journal_sequence, surah_id, rotation_scheme_id, rakaat_span_count, '
    'prayer_session_id, created_at_utc, local_date, prayer_type, is_qada, '
    'deleted_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v2-live',
      1,
      'v2-surah',
      'v2-surah:scheme:1',
      2,
      'v2-session',
      _encoded(_utc(5)),
      '2026-08-24',
      'asr',
      0,
      null,
    ],
  );
  raw.execute(
    'INSERT INTO recitation_events '
    '(id, journal_sequence, surah_id, rotation_scheme_id, rakaat_span_count, '
    'created_at_utc, local_date, prayer_type, is_qada, deleted_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v2-deleted',
      2,
      'v2-surah',
      'v2-surah:scheme:1',
      1,
      _encoded(_utc(6)),
      '2026-08-24',
      'maghrib',
      0,
      _encoded(_utc(9)),
    ],
  );
  for (final partId in <String>['v2-p2', 'v2-p4']) {
    raw.execute(
      'INSERT INTO recitation_event_parts (event_id, scheme_id, part_id) '
      "VALUES ('v2-live', 'v2-surah:scheme:1', ?)",
      <Object?>[partId],
    );
  }
  for (final partId in <String>['v2-p1', 'v2-p2', 'v2-p3', 'v2-p4']) {
    raw.execute(
      'INSERT INTO recitation_event_parts (event_id, scheme_id, part_id) '
      "VALUES ('v2-deleted', 'v2-surah:scheme:1', ?)",
      <Object?>[partId],
    );
  }
  raw.execute(
    'INSERT INTO rotation_adjustments '
    '(id, journal_sequence, surah_id, rotation_scheme_id, delta, reason, '
    'created_at_utc, deleted_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v2-adjustment',
      3,
      'v2-surah',
      'v2-surah:scheme:1',
      -1,
      'Preserved v2 adjustment',
      _encoded(_utc(7)),
      null,
    ],
  );
  raw.execute(
    'INSERT INTO learning_surahs '
    '(id, surah_id, ayah_count, stage_kind, stage_end_ayah, status, '
    'last_learning_activity_at_utc, '
    'inactivity_rollback_for_activity_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v2-learning',
      'v2-surah',
      12,
      'newAyah',
      5,
      'active',
      _encoded(_utc(8)),
      null,
    ],
  );
  raw.execute(
    'INSERT INTO learning_events '
    '(id, sequence, learning_surah_id, type, created_at_utc, '
    'from_stage_kind, from_stage_end_ayah, to_stage_kind, to_stage_end_ayah) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v2-learning-event',
      12,
      'v2-learning',
      'repeated',
      _encoded(_utc(8)),
      'newAyah',
      5,
      'newAyah',
      5,
    ],
  );
  raw.execute(
    'INSERT INTO app_settings (key, value, value_type, updated_at_utc) '
    'VALUES (?, ?, ?, ?)',
    <Object?>['v2-setting', '42', 'int', _encoded(_utc(9))],
  );
}

void _seedVersionThree(dynamic raw) {
  _seedVersionTwo(raw);
  raw.execute(
    'UPDATE rotation_states SET last_journal_sequence = 4 '
    'WHERE singleton_id = 1',
  );
  raw.execute(
    'INSERT INTO prayer_sessions '
    '(id, prayer_type, is_qada, started_at_utc, local_date) '
    'VALUES (?, ?, ?, ?, ?)',
    <Object?>['v3-session', 'witr', 0, _encoded(_utc(12)), '2026-08-24'],
  );
  raw.execute(
    'INSERT INTO rotation_adjustments '
    '(id, journal_sequence, surah_id, rotation_scheme_id, delta, reason, '
    'created_at_utc, deleted_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v3-adjustment',
      4,
      'v2-surah',
      'v2-surah:scheme:1',
      1,
      'Preserved v3 adjustment',
      _encoded(_utc(12)),
      null,
    ],
  );
  raw.execute("DELETE FROM learning_events WHERE id = 'v2-learning-event'");
  raw.execute("DELETE FROM learning_surahs WHERE id = 'v2-learning'");
  raw.execute(
    'INSERT INTO learning_surahs '
    '(id, surah_id, ayah_count, stage_kind, stage_end_ayah, status, '
    'last_learning_activity_at_utc, '
    'inactivity_rollback_for_activity_at_utc) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v3-learning',
      'v2-surah',
      12,
      'cumulative',
      6,
      'active',
      _encoded(_utc(13)),
      _encoded(_utc(10)),
    ],
  );
  raw.execute(
    'INSERT INTO learning_events '
    '(id, sequence, learning_surah_id, type, created_at_utc, '
    'from_stage_kind, from_stage_end_ayah, to_stage_kind, to_stage_end_ayah) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      'v3-learning-event',
      21,
      'v3-learning',
      'learned',
      _encoded(_utc(13)),
      'newAyah',
      6,
      'cumulative',
      6,
    ],
  );
  raw.execute(
    'INSERT INTO app_settings (key, value, value_type, updated_at_utc) '
    'VALUES (?, ?, ?, ?)',
    <Object?>['v3-setting', 'preserved', 'string', _encoded(_utc(14))],
  );
}

Future<void> _expectConstraint(AppDatabase database, String sql) async {
  await expectLater(database.customStatement(sql), throwsA(isA<Exception>()));
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
