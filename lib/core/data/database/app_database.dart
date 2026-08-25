import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('SurahMetadataRow')
class SurahMetadata extends Table {
  @override
  String get tableName => 'surah_metadata';

  TextColumn get id => text()();
  IntColumn get surahNumber => integer().unique()();
  TextColumn get officialName => text()();
  IntColumn get ayahCount => integer()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get sourceVersion => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (surah_number > 0)',
    'CHECK (ayah_count > 0)',
    'CHECK (length(official_name) > 0)',
  ];
}

@DataClassName('MasteredSurahRow')
class MasteredSurahs extends Table {
  @override
  String get tableName => 'mastered_surahs';

  TextColumn get surahId =>
      text().references(SurahMetadata, #id, onDelete: KeyAction.restrict)();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(false))();
  BoolColumn get hasEnteredRotation =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get activationBaselineScore => integer().nullable()();
  IntColumn get cachedRotationScore =>
      integer().withDefault(const Constant<int>(0))();
  IntColumn get cachedTotalRecitations =>
      integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get cachedLastUsedAtUtc => dateTime().nullable()();
  TextColumn get alias => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant<int>(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{surahId};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (activation_baseline_score IS NULL OR '
        'activation_baseline_score >= 0)',
    'CHECK (cached_rotation_score >= 0)',
    'CHECK (cached_total_recitations >= 0)',
    'CHECK (has_entered_rotation = 1 OR is_active = 0)',
  ];
}

@DataClassName('RotationStateRow')
class RotationStates extends Table {
  @override
  String get tableName => 'rotation_states';

  IntColumn get singletonId => integer().withDefault(const Constant<int>(1))();
  IntColumn get rotationTarget =>
      integer().withDefault(const Constant<int>(1))();
  IntColumn get lastJournalSequence =>
      integer().withDefault(const Constant<int>(0))();
  IntColumn get projectionVersion =>
      integer().withDefault(const Constant<int>(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{singletonId};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (singleton_id = 1)',
    'CHECK (rotation_target >= 1)',
    'CHECK (last_journal_sequence >= 0)',
    'CHECK (projection_version > 0)',
  ];
}

@DataClassName('RotationSchemeRow')
class RotationSchemes extends Table {
  @override
  String get tableName => 'rotation_schemes';

  TextColumn get id => text()();
  TextColumn get surahId => text().references(
    MasteredSurahs,
    #surahId,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get version => integer()();
  IntColumn get ayahCountSnapshot => integer()();
  IntColumn get baselineScore => integer()();
  IntColumn get baselineTotalRecitations => integer()();
  DateTimeColumn get baselineLastUsedAtUtc => dateTime().nullable()();
  IntColumn get activatedJournalSequence => integer()();
  IntColumn get supersededJournalSequence => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{surahId, version},
    <Column<Object>>{id, surahId},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    'CHECK (version > 0)',
    'CHECK (ayah_count_snapshot > 0)',
    'CHECK (baseline_score >= 0)',
    'CHECK (baseline_total_recitations >= 0)',
    'CHECK (activated_journal_sequence >= 0)',
    'CHECK (superseded_journal_sequence IS NULL OR '
        'superseded_journal_sequence >= activated_journal_sequence)',
  ];
}

@DataClassName('RotationPartRow')
class RotationParts extends Table {
  @override
  String get tableName => 'rotation_parts';

  TextColumn get id => text()();
  TextColumn get schemeId =>
      text().references(RotationSchemes, #id, onDelete: KeyAction.cascade)();
  IntColumn get ordinal => integer()();
  IntColumn get startAyah => integer()();
  IntColumn get endAyah => integer()();
  IntColumn get cachedScore => integer()();
  IntColumn get cachedRecitationCount => integer()();
  DateTimeColumn get cachedLastUsedAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{schemeId, ordinal},
    <Column<Object>>{id, schemeId},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    'CHECK (ordinal >= 1)',
    'CHECK (start_ayah > 0)',
    'CHECK (end_ayah >= start_ayah)',
    'CHECK (cached_score >= 0)',
    'CHECK (cached_recitation_count >= 0)',
  ];
}

@DataClassName('PrayerSessionRow')
class PrayerSessions extends Table {
  @override
  String get tableName => 'prayer_sessions';

  TextColumn get id => text()();
  TextColumn get prayerType => text()();
  BoolColumn get isQada => boolean().withDefault(const Constant<bool>(false))();
  DateTimeColumn get startedAtUtc => dateTime()();
  TextColumn get localDate => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    "CHECK (prayer_type IN ('fajr', 'dhuhr', 'asr', 'maghrib', "
        "'isha', 'witr', 'nafl'))",
    "CHECK (is_qada = 0 OR prayer_type != 'nafl')",
  ];
}

@DataClassName('RecitationEventRow')
class RecitationEvents extends Table {
  @override
  String get tableName => 'recitation_events';

  TextColumn get id => text()();
  IntColumn get journalSequence => integer().unique()();
  TextColumn get surahId => text().references(
    MasteredSurahs,
    #surahId,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get rotationSchemeId => text()();
  IntColumn get rakaatSpanCount => integer()();
  TextColumn get prayerSessionId => text().nullable().references(
    PrayerSessions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAtUtc => dateTime()();
  TextColumn get localDate => text()();
  TextColumn get prayerType => text()();
  BoolColumn get isQada => boolean().withDefault(const Constant<bool>(false))();
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{id, rotationSchemeId},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    'CHECK (journal_sequence > 0)',
    "CHECK (prayer_type IN ('fajr', 'dhuhr', 'asr', 'maghrib', "
        "'isha', 'witr', 'nafl'))",
    "CHECK (is_qada = 0 OR prayer_type != 'nafl')",
    'CHECK (rakaat_span_count >= 1)',
    'FOREIGN KEY (rotation_scheme_id, surah_id) '
        'REFERENCES rotation_schemes (id, surah_id) ON DELETE RESTRICT',
  ];
}

@DataClassName('RecitationEventPartRow')
class RecitationEventParts extends Table {
  @override
  String get tableName => 'recitation_event_parts';

  TextColumn get eventId => text()();
  TextColumn get schemeId => text()();
  TextColumn get partId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{eventId, partId};

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (event_id, scheme_id) '
        'REFERENCES recitation_events (id, rotation_scheme_id) '
        'ON DELETE CASCADE',
    'FOREIGN KEY (part_id, scheme_id) '
        'REFERENCES rotation_parts (id, scheme_id) ON DELETE RESTRICT',
  ];
}

@DataClassName('RotationAdjustmentRow')
class RotationAdjustments extends Table {
  @override
  String get tableName => 'rotation_adjustments';

  TextColumn get id => text()();
  IntColumn get journalSequence => integer().unique()();
  TextColumn get surahId => text().references(
    MasteredSurahs,
    #surahId,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get rotationSchemeId => text()();
  IntColumn get delta => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    'CHECK (journal_sequence > 0)',
    'CHECK (delta != 0)',
    'CHECK (length(reason) > 0)',
    'FOREIGN KEY (rotation_scheme_id, surah_id) '
        'REFERENCES rotation_schemes (id, surah_id) ON DELETE RESTRICT',
  ];
}

@DataClassName('LearningSurahRow')
class LearningSurahs extends Table {
  @override
  String get tableName => 'learning_surahs';

  TextColumn get id => text()();
  TextColumn get surahId => text().unique().references(
    SurahMetadata,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get ayahCount => integer()();
  TextColumn get stageKind => text()();
  IntColumn get stageEndAyah => integer()();
  TextColumn get status => text()();
  DateTimeColumn get lastLearningActivityAtUtc => dateTime().nullable()();
  DateTimeColumn get inactivityRollbackForActivityAtUtc =>
      dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (ayah_count > 0)',
    'CHECK (stage_end_ayah > 0 AND stage_end_ayah <= ayah_count)',
    "CHECK (stage_kind IN ('newAyah', 'cumulative'))",
    "CHECK (status IN ('active', 'completed'))",
  ];
}

@DataClassName('LearningEventRow')
class LearningEvents extends Table {
  @override
  String get tableName => 'learning_events';

  TextColumn get id => text()();
  IntColumn get sequence => integer().autoIncrement()();
  TextColumn get learningSurahId =>
      text().references(LearningSurahs, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  TextColumn get fromStageKind => text()();
  IntColumn get fromStageEndAyah => integer()();
  TextColumn get toStageKind => text()();
  IntColumn get toStageEndAyah => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{id},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    "CHECK (type IN ('repeated', 'learned', 'inactivityRollback', "
        "'completed'))",
    "CHECK (from_stage_kind IN ('newAyah', 'cumulative'))",
    "CHECK (to_stage_kind IN ('newAyah', 'cumulative'))",
    'CHECK (from_stage_end_ayah > 0)',
    'CHECK (to_stage_end_ayah > 0)',
  ];
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get valueType => text()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};

  @override
  List<String> get customConstraints => <String>[
    "CHECK (value_type IN ('string', 'bool', 'int', 'double'))",
  ];
}

@DriftDatabase(
  tables: <Type>[
    SurahMetadata,
    MasteredSurahs,
    RotationStates,
    RotationSchemes,
    RotationParts,
    PrayerSessions,
    RecitationEvents,
    RecitationEventParts,
    RotationAdjustments,
    LearningSurahs,
    LearningEvents,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'murajaah_user'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createVersionTwoIndexes();
      await _ensureRotationSingleton();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from == to) return;
      if (from < 1 || from > 2 || to != 3) {
        throw StateError('Unsupported database migration from $from to $to.');
      }
      if (from < 2) {
        await _migrateVersionOneToTwo(migrator);
      }
      if (from < 3) {
        await _migrateVersionTwoToThree(migrator);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureRotationSingleton();
    },
  );

  Future<void> _ensureRotationSingleton() => customStatement(
    'INSERT OR IGNORE INTO rotation_states '
    '(singleton_id, rotation_target, last_journal_sequence, '
    'projection_version) VALUES (1, 1, 0, 2)',
  );

  Future<void> _createVersionTwoIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_mastered_active_order '
      'ON mastered_surahs (is_active, display_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recitations_surah_sequence '
      'ON recitation_events (surah_id, journal_sequence)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_rotation_current_scheme '
      'ON rotation_schemes (surah_id) '
      'WHERE superseded_journal_sequence IS NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_rotation_schemes_surah_version '
      'ON rotation_schemes (surah_id, version)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_rotation_parts_scheme_ordinal '
      'ON rotation_parts (scheme_id, ordinal)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recitation_parts_event '
      'ON recitation_event_parts (event_id, part_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recitations_history '
      'ON recitation_events (deleted_at_utc, journal_sequence DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recitations_prayer_date '
      'ON recitation_events (prayer_type, is_qada, local_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_adjustments_surah_sequence '
      'ON rotation_adjustments (surah_id, journal_sequence)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_learning_surah_status '
      'ON learning_surahs (status, surah_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_learning_events_owner_sequence '
      'ON learning_events (learning_surah_id, sequence)',
    );
  }

  Future<void> _migrateVersionOneToTwo(Migrator migrator) async {
    // Drop named v1 indexes before renaming their tables. SQLite keeps index
    // names attached to renamed tables, which would otherwise block v2 names.
    await customStatement(
      'DROP INDEX IF EXISTS idx_recitations_surah_sequence',
    );
    await customStatement('DROP INDEX IF EXISTS idx_recitations_history');
    await customStatement('DROP INDEX IF EXISTS idx_recitations_prayer_date');
    await customStatement(
      'DROP INDEX IF EXISTS idx_adjustments_surah_sequence',
    );

    await migrator.createTable(rotationSchemes);
    await migrator.createTable(rotationParts);

    // Stable identifiers make the backfill deterministic and auditable.
    await customStatement('''
      INSERT INTO rotation_schemes (
        id, surah_id, version, ayah_count_snapshot, baseline_score,
        baseline_total_recitations, baseline_last_used_at_utc,
        activated_journal_sequence, superseded_journal_sequence
      )
      SELECT
        'v1:' || mastered.surah_id || ':scheme:1',
        mastered.surah_id,
        1,
        metadata.ayah_count,
        COALESCE(mastered.activation_baseline_score, 0),
        0,
        NULL,
        0,
        NULL
      FROM mastered_surahs AS mastered
      INNER JOIN surah_metadata AS metadata ON metadata.id = mastered.surah_id
    ''');
    await customStatement('''
      INSERT INTO rotation_parts (
        id, scheme_id, ordinal, start_ayah, end_ayah, cached_score,
        cached_recitation_count, cached_last_used_at_utc
      )
      SELECT
        'v1:' || mastered.surah_id || ':scheme:1:part:1',
        'v1:' || mastered.surah_id || ':scheme:1',
        1,
        1,
        metadata.ayah_count,
        mastered.cached_rotation_score,
        mastered.cached_total_recitations,
        mastered.cached_last_used_at_utc
      FROM mastered_surahs AS mastered
      INNER JOIN surah_metadata AS metadata ON metadata.id = mastered.surah_id
    ''');

    await customStatement(
      'ALTER TABLE recitation_events RENAME TO recitation_events_v1',
    );
    await customStatement(
      'ALTER TABLE rotation_adjustments RENAME TO rotation_adjustments_v1',
    );
    await customStatement(
      'ALTER TABLE prayer_sessions RENAME TO prayer_sessions_v1',
    );

    await migrator.createTable(prayerSessions);
    await customStatement('''
      INSERT INTO prayer_sessions (
        id, prayer_type, is_qada, started_at_utc, local_date
      )
      SELECT id, prayer_type, is_qada, started_at_utc, local_date
      FROM prayer_sessions_v1
    ''');

    await migrator.createTable(recitationEvents);
    await customStatement('''
      INSERT INTO recitation_events (
        id, journal_sequence, surah_id, rotation_scheme_id,
        rakaat_span_count, prayer_session_id, created_at_utc, local_date,
        prayer_type, is_qada, deleted_at_utc
      )
      SELECT
        id,
        journal_sequence,
        surah_id,
        'v1:' || surah_id || ':scheme:1',
        1,
        prayer_session_id,
        created_at_utc,
        local_date,
        prayer_type,
        is_qada,
        deleted_at_utc
      FROM recitation_events_v1
    ''');
    await migrator.createTable(recitationEventParts);
    await customStatement('''
      INSERT INTO recitation_event_parts (event_id, scheme_id, part_id)
      SELECT
        id,
        'v1:' || surah_id || ':scheme:1',
        'v1:' || surah_id || ':scheme:1:part:1'
      FROM recitation_events_v1
    ''');

    await migrator.createTable(rotationAdjustments);
    await customStatement('''
      INSERT INTO rotation_adjustments (
        id, journal_sequence, surah_id, rotation_scheme_id, delta, reason,
        created_at_utc, deleted_at_utc
      )
      SELECT
        id,
        journal_sequence,
        surah_id,
        'v1:' || surah_id || ':scheme:1',
        delta,
        reason,
        created_at_utc,
        deleted_at_utc
      FROM rotation_adjustments_v1
    ''');

    await customStatement('DROP TABLE recitation_events_v1');
    await customStatement('DROP TABLE rotation_adjustments_v1');
    await customStatement('DROP TABLE prayer_sessions_v1');

    await _createVersionTwoIndexes();
    await customStatement(
      'UPDATE rotation_states SET projection_version = 2 '
      'WHERE singleton_id = 1',
    );

    final foreignKeyViolations = await customSelect(
      'PRAGMA foreign_key_check',
    ).get();
    if (foreignKeyViolations.isNotEmpty) {
      throw StateError(
        'Foreign-key violations after v1 to v2 migration: '
        '${foreignKeyViolations.length}.',
      );
    }
  }

  Future<void> _migrateVersionTwoToThree(Migrator migrator) async {
    // SQLite cannot alter a CHECK constraint in place. Drift performs the
    // recommended table-rebuild procedure and copies every existing column,
    // while retaining ids, cached state, and child coverage references.
    await migrator.alterTable(TableMigration(rotationParts));
    await _createVersionTwoIndexes();

    final foreignKeyViolations = await customSelect(
      'PRAGMA foreign_key_check',
    ).get();
    if (foreignKeyViolations.isNotEmpty) {
      throw StateError(
        'Foreign-key violations after v2 to v3 migration: '
        '${foreignKeyViolations.length}.',
      );
    }
  }
}
