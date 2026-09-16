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
  BoolColumn get isCurrentlyMastered =>
      boolean().withDefault(const Constant<bool>(true))();
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
    'CHECK (is_currently_mastered = 1 OR is_active = 0)',
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
  BoolColumn get resetsRotationBaseline =>
      boolean().withDefault(const Constant<bool>(false))();
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
        "'isha', 'jumuah', 'witr', 'nafl'))",
    "CHECK (is_qada = 0 OR prayer_type NOT IN ('nafl', 'jumuah'))",
  ];
}

@DataClassName('PrayerRoutineTemplateRow')
class PrayerRoutineTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get prayerType => text()();
  TextColumn get displayName => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (prayer_type)',
    'CHECK (length(display_name) > 0)',
    'CHECK (revision > 0)',
  ];
}

@DataClassName('PrayerRoutinePartTemplateRow')
class PrayerRoutinePartTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get routineTemplateId => text().references(
    PrayerRoutineTemplates,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get stableKey => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get kind => text()();
  TextColumn get customLabel => text().nullable()();
  IntColumn get rakaatCount => integer()();
  IntColumn get requiredSurahSlots => integer()();
  BoolColumn get allowsFollowingImam =>
      boolean().withDefault(const Constant(false))();
  TextColumn get defaultCompletionMode =>
      text().withDefault(const Constant('recitations'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (routine_template_id, stable_key)',
    'UNIQUE (routine_template_id, order_index)',
    'CHECK (order_index >= 0)',
    "CHECK (kind IN ('fard', 'sunnah', 'witr', 'nafl', 'custom'))",
    "CHECK (kind != 'custom' OR length(custom_label) > 0)",
    'CHECK (rakaat_count > 0)',
    'CHECK (required_surah_slots >= 0)',
    "CHECK (default_completion_mode IN ('recitations', 'followedImam'))",
  ];
}

@DataClassName('PrayerSessionPartRow')
class PrayerSessionParts extends Table {
  TextColumn get id => text()();
  TextColumn get prayerSessionId =>
      text().references(PrayerSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceTemplatePartId => text().nullable()();
  IntColumn get templateRevision => integer().nullable()();
  TextColumn get stableKey => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get label => text()();
  TextColumn get kind => text()();
  IntColumn get rakaatCount => integer()();
  IntColumn get requiredSurahSlots => integer()();
  BoolColumn get allowsFollowingImam => boolean()();
  TextColumn get completionMode =>
      text().withDefault(const Constant('recitations'))();
  DateTimeColumn get completedAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (prayer_session_id, order_index)',
    'CHECK (order_index >= 0)',
    'CHECK (length(label) > 0)',
    "CHECK (kind IN ('fard', 'sunnah', 'witr', 'nafl', 'custom'))",
    'CHECK (rakaat_count > 0)',
    'CHECK (required_surah_slots >= 0)',
    "CHECK (completion_mode IN ('recitations', 'followedImam'))",
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
  TextColumn get prayerSessionPartId => text().nullable().references(
    PrayerSessionParts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get slotIndex => integer().nullable()();
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
        "'isha', 'jumuah', 'witr', 'nafl'))",
    "CHECK (is_qada = 0 OR prayer_type NOT IN ('nafl', 'jumuah'))",
    'CHECK (rakaat_span_count >= 1)',
    'CHECK (slot_index IS NULL OR slot_index >= 0)',
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
  TextColumn get planKind =>
      text().withDefault(const Constant<String>('classicCumulative'))();
  TextColumn get stageKind => text()();
  IntColumn get stageStartAyah => integer()();
  IntColumn get stageEndAyah => integer()();
  IntColumn get targetStartAyah => integer()();
  IntColumn get targetEndAyah => integer()();
  IntColumn get blockSize => integer().nullable()();
  IntColumn get learningCycle =>
      integer().withDefault(const Constant<int>(1))();
  TextColumn get status => text()();
  DateTimeColumn get lastLearningActivityAtUtc => dateTime().nullable()();
  DateTimeColumn get inactivityRollbackForActivityAtUtc =>
      dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (ayah_count > 0)',
    'CHECK (target_start_ayah > 0 AND '
        'target_end_ayah >= target_start_ayah AND '
        'target_end_ayah <= ayah_count)',
    'CHECK (stage_start_ayah >= target_start_ayah AND '
        'stage_end_ayah >= stage_start_ayah AND '
        'stage_end_ayah <= target_end_ayah)',
    "CHECK (plan_kind IN ('classicCumulative', 'chunked'))",
    "CHECK (stage_kind IN ('newAyah', 'cumulative', 'reviewRange', "
        "'bridge', 'sectionReview', 'finalReview'))",
    'CHECK (block_size IS NULL OR block_size > 0)',
    "CHECK (plan_kind = 'chunked' OR block_size IS NULL)",
    "CHECK (plan_kind = 'classicCumulative' OR block_size IS NOT NULL)",
    'CHECK (learning_cycle > 0)',
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
  IntColumn get learningCycle =>
      integer().withDefault(const Constant<int>(1))();
  TextColumn get fromPlanKind => text()();
  IntColumn get fromTargetStartAyah => integer()();
  IntColumn get fromTargetEndAyah => integer()();
  IntColumn get fromBlockSize => integer().nullable()();
  TextColumn get fromStageKind => text()();
  IntColumn get fromStageStartAyah => integer()();
  IntColumn get fromStageEndAyah => integer()();
  TextColumn get toPlanKind => text()();
  IntColumn get toTargetStartAyah => integer()();
  IntColumn get toTargetEndAyah => integer()();
  IntColumn get toBlockSize => integer().nullable()();
  TextColumn get toStageKind => text()();
  IntColumn get toStageStartAyah => integer()();
  IntColumn get toStageEndAyah => integer()();
  TextColumn get reason => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{id},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    "CHECK (type IN ('repeated', 'learned', 'inactivityRollback', "
        "'completed', 'restarted', 'planChanged'))",
    'CHECK (learning_cycle > 0)',
    "CHECK (from_plan_kind IN ('classicCumulative', 'chunked'))",
    "CHECK (to_plan_kind IN ('classicCumulative', 'chunked'))",
    'CHECK (from_target_start_ayah > 0 AND '
        'from_target_end_ayah >= from_target_start_ayah)',
    'CHECK (to_target_start_ayah > 0 AND '
        'to_target_end_ayah >= to_target_start_ayah)',
    "CHECK (from_plan_kind = 'chunked' OR from_block_size IS NULL)",
    "CHECK (to_plan_kind = 'chunked' OR to_block_size IS NULL)",
    "CHECK (from_plan_kind = 'classicCumulative' OR "
        'from_block_size IS NOT NULL)',
    "CHECK (to_plan_kind = 'classicCumulative' OR "
        'to_block_size IS NOT NULL)',
    "CHECK (from_stage_kind IN ('newAyah', 'cumulative', 'reviewRange', "
        "'bridge', 'sectionReview', 'finalReview'))",
    "CHECK (to_stage_kind IN ('newAyah', 'cumulative', 'reviewRange', "
        "'bridge', 'sectionReview', 'finalReview'))",
    'CHECK (from_stage_start_ayah > 0 AND '
        'from_stage_end_ayah >= from_stage_start_ayah)',
    'CHECK (to_stage_start_ayah > 0 AND '
        'to_stage_end_ayah >= to_stage_start_ayah)',
    'CHECK (reason IS NULL OR length(reason) > 0)',
  ];
}

@DataClassName('RecallAttemptRow')
class RecallAttempts extends Table {
  @override
  String get tableName => 'recall_attempts';

  TextColumn get id => text()();
  IntColumn get sequence => integer().autoIncrement()();
  TextColumn get surahId =>
      text().references(SurahMetadata, #id, onDelete: KeyAction.restrict)();
  IntColumn get ayahStart => integer()();
  IntColumn get ayahEnd => integer()();
  IntColumn get learningCycle =>
      integer().withDefault(const Constant<int>(1))();
  TextColumn get result => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  TextColumn get localDate => text()();
  TextColumn get source => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{id},
  ];

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    'CHECK (ayah_start > 0)',
    'CHECK (ayah_end >= ayah_start)',
    'CHECK (learning_cycle > 0)',
    "CHECK (result IN ('recalled', 'recalledWithMistake', 'notRecalled'))",
    "CHECK (source IN ('learning', 'surah'))",
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

/// The durable outbox: local changes that have not reached the account yet.
///
/// Both the retry queue and the quarantine live here under one [status], so a
/// permanently rejected change is never lost — only moved out of the way of the
/// ones behind it. The envelope is stored as its own JSON rather than shredded
/// into columns: it is transport payload, and re-deriving it from local tables
/// after a later schema change would risk pushing something the user never did.
@DataClassName('SyncOutboxEntryRow')
class SyncOutboxEntries extends Table {
  @override
  String get tableName => 'sync_outbox_entries';

  TextColumn get ownerKey => text()();
  TextColumn get envelopeId => text()();

  /// `entityType:entityId` — what the queued change is about, across devices.
  TextColumn get entityKey => text()();
  TextColumn get status => text()();
  BoolColumn get isTombstone =>
      boolean().withDefault(const Constant<bool>(false))();

  /// Microseconds since epoch, UTC. An integer rather than a `DateTime`
  /// column because Drift stores those as whole seconds by default, and the
  /// drain order must not depend on two entries landing in the same second.
  IntColumn get enqueuedAtUs => integer()();
  IntColumn get envelopeUpdatedAtUs => integer()();
  IntColumn get attemptCount => integer().withDefault(const Constant<int>(0))();
  TextColumn get lastFailureReason => text().nullable()();
  TextColumn get envelopeJson => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerKey, envelopeId};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(owner_key) > 0)',
    'CHECK (length(envelope_id) > 0)',
    'CHECK (length(entity_key) > 0)',
    "CHECK (status IN ('pending', 'quarantined'))",
    'CHECK (attempt_count >= 0)',
    'CHECK (last_failure_reason IS NULL OR length(last_failure_reason) > 0)',
    'CHECK (length(envelope_json) > 0)',
  ];
}

/// Where a pull left off, per owner.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  @override
  String get tableName => 'sync_cursors';

  TextColumn get ownerKey => text()();

  /// Opaque server token. An empty string means "from the beginning".
  TextColumn get pullCursor => text()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerKey};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(owner_key) > 0)',
  ];
}

/// Whether an account has been allowed to touch this device's data yet.
///
/// Signing in is not activation. The CHECK keeps that distinction in the
/// schema: a row can only be active if its recorded choice was `merge`, so no
/// code path can flip activation on while the user chose to stay local.
@DataClassName('SyncActivationRow')
class SyncActivations extends Table {
  @override
  String get tableName => 'sync_activations';

  TextColumn get ownerKey => text()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(false))();
  TextColumn get choice => text().nullable()();

  /// The local backup taken before the merge preview was shown.
  TextColumn get backupId => text().nullable()();
  DateTimeColumn get decidedAtUtc => dateTime().nullable()();
  DateTimeColumn get lastSuccessAtUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerKey};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(owner_key) > 0)',
    "CHECK (choice IS NULL OR choice IN ('merge', 'keepDeviceLocalOnly'))",
    "CHECK (is_active = 0 OR choice = 'merge')",
    'CHECK (choice IS NULL OR decided_at_utc IS NOT NULL)',
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
    PrayerRoutineTemplates,
    PrayerRoutinePartTemplates,
    PrayerSessionParts,
    RecitationEvents,
    RecitationEventParts,
    RotationAdjustments,
    LearningSurahs,
    LearningEvents,
    RecallAttempts,
    AppSettings,
    SyncOutboxEntries,
    SyncCursors,
    SyncActivations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'murajaah_user'));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createVersionTwoIndexes();
      await _createVersionFourIndexesAndGuards();
      await _createVersionFiveIndexes();
      await _createVersionSixIndexes();
      await _createVersionSevenIndexes();
      await _ensureEmptyRoutineTemplates();
      await _ensureRotationSingleton();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from == to) return;
      if (from < 1 || from > 6 || to != 7) {
        throw StateError('Unsupported database migration from $from to $to.');
      }
      if (from < 2) {
        await _migrateVersionOneToTwo(migrator);
      }
      if (from < 3) {
        await _migrateVersionTwoToThree(migrator);
      }
      if (from < 4) {
        await _migrateVersionThreeToFour(migrator);
      }
      if (from < 5) {
        await _migrateVersionFourToFive(migrator, sourceVersion: from);
      }
      if (from < 6) {
        await _migrateVersionFiveToSix(migrator);
      }
      if (from < 7) {
        await _migrateVersionSixToSeven(migrator);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createVersionFourIndexesAndGuards();
      await _createVersionFiveIndexes();
      await _createVersionSixIndexes();
      await _createVersionSevenIndexes();
      await _ensureRotationSingleton();
      await _ensureEmptyRoutineTemplates();
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

  Future<void> _createVersionFourIndexesAndGuards() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_mastered_current_order '
      'ON mastered_surahs '
      '(is_currently_mastered, is_active, display_order)',
    );
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_mastered_current_insert
      BEFORE INSERT ON mastered_surahs
      WHEN NEW.is_currently_mastered = 0 AND NEW.is_active != 0
      BEGIN
        SELECT RAISE(ABORT,
          'A surah that is not currently mastered cannot be active');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_mastered_current_update
      BEFORE UPDATE OF is_currently_mastered, is_active ON mastered_surahs
      WHEN NEW.is_currently_mastered = 0 AND NEW.is_active != 0
      BEGIN
        SELECT RAISE(ABORT,
          'A surah that is not currently mastered cannot be active');
      END
    ''');
  }

  Future<void> _createVersionFiveIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_routine_parts_order '
      'ON prayer_routine_part_templates (routine_template_id, order_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_session_parts_order '
      'ON prayer_session_parts (prayer_session_id, order_index)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_recitation_session_slot '
      'ON recitation_events (prayer_session_part_id, slot_index) '
      'WHERE prayer_session_part_id IS NOT NULL AND slot_index IS NOT NULL '
      'AND deleted_at_utc IS NULL',
    );
  }

  Future<void> _createVersionSixIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recall_attempts_surah_sequence '
      'ON recall_attempts (surah_id, sequence)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recall_attempts_date '
      'ON recall_attempts (local_date, sequence)',
    );
  }

  Future<void> _createVersionSevenIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_drain '
      'ON sync_outbox_entries '
      '(owner_key, status, enqueued_at_us, envelope_id)',
    );
    // One queued change per entity per owner. Coalescing is what keeps ten
    // offline edits to one template from becoming ten pushes, and a database
    // constraint is what keeps a future code path from breaking that quietly.
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_outbox_pending_entity '
      'ON sync_outbox_entries (owner_key, entity_key) '
      "WHERE status = 'pending'",
    );
  }

  /// Adds the durable sync transport tables.
  ///
  /// Nothing is backfilled and no existing table is touched. A queue entry
  /// describes a change that has not reached an account yet; synthesizing one
  /// per historical recitation would push a user's whole journal the first time
  /// they ever sign in, which is exactly the merge the activation gate exists
  /// to make explicit.
  Future<void> _migrateVersionSixToSeven(Migrator migrator) async {
    if (!await _tableExists('sync_outbox_entries')) {
      await migrator.createTable(syncOutboxEntries);
    }
    if (!await _tableExists('sync_cursors')) {
      await migrator.createTable(syncCursors);
    }
    if (!await _tableExists('sync_activations')) {
      await migrator.createTable(syncActivations);
    }
    await _createVersionSevenIndexes();
    final violations = await customSelect('PRAGMA foreign_key_check').get();
    if (violations.isNotEmpty) {
      throw StateError(
        'Foreign-key violations after v6 to v7 migration: '
        '${violations.length}.',
      );
    }
  }

  /// Adds the append-only recall journal. Nothing is backfilled: recall
  /// attempts are a new kind of fact, and inventing historical ones would
  /// misreport how well the user actually remembered anything.
  Future<void> _migrateVersionFiveToSix(Migrator migrator) async {
    if (!await _tableExists('recall_attempts')) {
      await migrator.createTable(recallAttempts);
    }
    await _createVersionSixIndexes();
    final violations = await customSelect('PRAGMA foreign_key_check').get();
    if (violations.isNotEmpty) {
      throw StateError(
        'Foreign-key violations after v5 to v6 migration: '
        '${violations.length}.',
      );
    }
  }

  Future<void> _ensureEmptyRoutineTemplates() async {
    for (final type in <String>[
      'fajr',
      'dhuhr',
      'jumuah',
      'asr',
      'maghrib',
      'isha',
      'witr',
      'nafl',
    ]) {
      await customStatement(
        'INSERT OR IGNORE INTO prayer_routine_templates '
        '(id, prayer_type, display_name, enabled, revision) '
        'VALUES (?, ?, ?, 1, 1)',
        <Object?>['routine:$type', type, type],
      );
    }
  }

  Future<void> _migrateVersionFourToFive(
    Migrator migrator, {
    required int sourceVersion,
  }) async {
    if (!await _tableExists('prayer_routine_templates')) {
      await migrator.createTable(prayerRoutineTemplates);
    }
    if (!await _tableExists('prayer_routine_part_templates')) {
      await migrator.createTable(prayerRoutinePartTemplates);
    }
    if (sourceVersion >= 2) {
      await migrator.alterTable(TableMigration(prayerSessions));
    }
    if (!await _tableExists('prayer_session_parts')) {
      await migrator.createTable(prayerSessionParts);
    }
    final eventColumns = await customSelect(
      'PRAGMA table_info(recitation_events)',
    ).get();
    final hasSessionPart = eventColumns.any(
      (row) => row.read<String>('name') == 'prayer_session_part_id',
    );
    if (!hasSessionPart) {
      await migrator.alterTable(
        TableMigration(
          recitationEvents,
          newColumns: <GeneratedColumn<Object>>[
            recitationEvents.prayerSessionPartId,
            recitationEvents.slotIndex,
          ],
        ),
      );
    }
    await _createVersionFiveIndexes();
    await _ensureEmptyRoutineTemplates();
    final violations = await customSelect('PRAGMA foreign_key_check').get();
    if (violations.isNotEmpty) {
      throw StateError(
        'Foreign-key violations after v4 to v5 migration: ${violations.length}.',
      );
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final row = await customSelect(
      'SELECT 1 AS found FROM sqlite_schema '
      'WHERE type = ? AND name = ? LIMIT 1',
      variables: <Variable<Object>>[
        const Variable<String>('table'),
        Variable<String>(tableName),
      ],
    ).getSingleOrNull();
    return row != null;
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

    // Current RecitationEvents has an optional v5 foreign key to this table.
    // During a chained v1 -> v5 upgrade SQLite requires the referenced table
    // to exist before legacy recitations can be inserted. It stays empty until
    // the v5 routine/session-part flow creates snapshots explicitly.
    await migrator.createTable(prayerSessionParts);

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

  Future<void> _migrateVersionThreeToFour(Migrator migrator) async {
    final schemeColumns = await customSelect(
      'PRAGMA table_info(rotation_schemes)',
    ).get();
    final hasResetBaselineColumn = schemeColumns.any(
      (row) => row.read<String>('name') == 'resets_rotation_baseline',
    );
    if (!hasResetBaselineColumn) {
      // A chained v1 upgrade creates rotation_schemes from the current table
      // definition during v1→v2, while v2/v3 databases still need the column.
      await migrator.addColumn(
        rotationSchemes,
        rotationSchemes.resetsRotationBaseline,
      );
    }

    await migrator.alterTable(
      TableMigration(
        masteredSurahs,
        newColumns: <GeneratedColumn<Object>>[
          masteredSurahs.isCurrentlyMastered,
        ],
        columnTransformer: <GeneratedColumn<Object>, Expression<Object>>{
          masteredSurahs.isCurrentlyMastered: const Constant<bool>(true),
        },
      ),
    );

    // Learning v4 stores a generic stage range and an immutable plan snapshot.
    // Rebuilding both tables is required because SQLite cannot alter their
    // CHECK constraints in place. Every legacy row remains in cycle 1 and
    // retains its exact timestamps, status, event id, and event sequence.
    await customStatement(
      'DROP INDEX IF EXISTS idx_learning_events_owner_sequence',
    );
    await customStatement('DROP INDEX IF EXISTS idx_learning_surah_status');
    await customStatement(
      'ALTER TABLE learning_events RENAME TO learning_events_v3',
    );
    await customStatement(
      'ALTER TABLE learning_surahs RENAME TO learning_surahs_v3',
    );

    await migrator.createTable(learningSurahs);
    await customStatement('''
      INSERT INTO learning_surahs (
        id, surah_id, ayah_count, plan_kind, stage_kind,
        stage_start_ayah, stage_end_ayah, target_start_ayah,
        target_end_ayah, block_size, learning_cycle, status,
        last_learning_activity_at_utc,
        inactivity_rollback_for_activity_at_utc
      )
      SELECT
        id,
        surah_id,
        ayah_count,
        'classicCumulative',
        stage_kind,
        CASE WHEN stage_kind = 'cumulative' THEN 1 ELSE stage_end_ayah END,
        stage_end_ayah,
        1,
        ayah_count,
        NULL,
        1,
        status,
        last_learning_activity_at_utc,
        inactivity_rollback_for_activity_at_utc
      FROM learning_surahs_v3
    ''');

    await migrator.createTable(learningEvents);
    await customStatement('''
      INSERT INTO learning_events (
        id, sequence, learning_surah_id, type, created_at_utc,
        learning_cycle,
        from_plan_kind, from_target_start_ayah, from_target_end_ayah,
        from_block_size, from_stage_kind, from_stage_start_ayah,
        from_stage_end_ayah,
        to_plan_kind, to_target_start_ayah, to_target_end_ayah,
        to_block_size, to_stage_kind, to_stage_start_ayah,
        to_stage_end_ayah, reason
      )
      SELECT
        event.id,
        event.sequence,
        event.learning_surah_id,
        event.type,
        event.created_at_utc,
        1,
        'classicCumulative',
        1,
        owner.ayah_count,
        NULL,
        event.from_stage_kind,
        CASE WHEN event.from_stage_kind = 'cumulative'
          THEN 1 ELSE event.from_stage_end_ayah END,
        event.from_stage_end_ayah,
        'classicCumulative',
        1,
        owner.ayah_count,
        NULL,
        event.to_stage_kind,
        CASE WHEN event.to_stage_kind = 'cumulative'
          THEN 1 ELSE event.to_stage_end_ayah END,
        event.to_stage_end_ayah,
        NULL
      FROM learning_events_v3 AS event
      INNER JOIN learning_surahs_v3 AS owner
        ON owner.id = event.learning_surah_id
      ORDER BY event.sequence
    ''');

    await customStatement('DROP TABLE learning_events_v3');
    await customStatement('DROP TABLE learning_surahs_v3');
    await _createVersionTwoIndexes();
    await _createVersionFourIndexesAndGuards();

    final foreignKeyViolations = await customSelect(
      'PRAGMA foreign_key_check',
    ).get();
    if (foreignKeyViolations.isNotEmpty) {
      throw StateError(
        'Foreign-key violations after v3 to v4 migration: '
        '${foreignKeyViolations.length}.',
      );
    }
  }
}
