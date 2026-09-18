/// What this device holds, and what the account holds, in the one shape the
/// first-sync preview can compare.
///
/// This is a survey, not a sync. It reads both sides, advances no cursor,
/// writes nothing, and is safe to run before the user has agreed to anything —
/// which is the whole point, since its output is what they are agreeing to.
///
/// A null timestamp is a real answer here: present, last change not datable.
/// Six tables had no such column until schema v10 added one, and v10 backfills
/// nothing, so every row untouched since the upgrade still reports null. The
/// alternative — substituting `started_at_utc`, `cached_last_used_at_utc` or
/// the migration time — would state agreement or disagreement on evidence that
/// does not exist. The preview counts these separately for exactly that reason.
library;

import '../../sync/sync.dart';
import '../database/app_database.dart';

final class DriftSyncInventory implements SyncInventory {
  DriftSyncInventory({
    required AppDatabase database,
    required SyncGateway gateway,
    required String userId,
    this.pageLimit = 100,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _database = database,
       // ignore: prefer_initializing_formals
       _gateway = gateway,
       // ignore: prefer_initializing_formals
       _userId = userId {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }
    if (pageLimit <= 0) {
      throw ArgumentError.value(pageLimit, 'pageLimit', 'Must be positive.');
    }
  }

  final AppDatabase _database;

  /// Already bound to one account, like [AppwriteSyncGateway] is. An inventory
  /// must never straddle two: surveying A's device against B's account is the
  /// one comparison that could talk a user into a destructive merge.
  final SyncGateway _gateway;
  final String _userId;

  final int pageLimit;

  /// Where each entity type lives, and what — if anything — dates it.
  ///
  /// Kept as one table rather than eleven methods so that a new
  /// [SyncEntityType] is an obvious omission here instead of a silently
  /// uncounted one.
  static const List<_EntitySource> _sources = <_EntitySource>[
    // Append-only journals. The row never changes after it is written, so the
    // only later event is its withdrawal — hence the coalesce.
    _EntitySource(
      SyncEntityType.recitationEvent,
      table: 'recitation_events',
      idColumn: 'id',
      changedAtColumn: 'COALESCE(deleted_at_utc, created_at_utc)',
    ),
    _EntitySource(
      SyncEntityType.rotationAdjustment,
      table: 'rotation_adjustments',
      idColumn: 'id',
      changedAtColumn: 'COALESCE(deleted_at_utc, created_at_utc)',
    ),
    _EntitySource(
      SyncEntityType.learningEvent,
      table: 'learning_events',
      idColumn: 'id',
      changedAtColumn: 'created_at_utc',
    ),
    _EntitySource(
      SyncEntityType.recallAttempt,
      table: 'recall_attempts',
      idColumn: 'id',
      changedAtColumn: 'created_at_utc',
    ),
    // The one mutable table that does record when it last changed.
    _EntitySource(
      SyncEntityType.appSetting,
      table: 'app_settings',
      idColumn: 'key',
      changedAtColumn: 'updated_at_utc',
    ),
    // Dated since schema v10, by a trigger rather than by their repositories.
    // Null until a row is next written: v10 backfills nothing, so anything
    // untouched since the upgrade is still honestly undetermined.
    _EntitySource(
      SyncEntityType.masteredSurah,
      table: 'mastered_surahs',
      idColumn: 'surah_id',
      changedAtColumn: 'updated_at_utc',
    ),
    _EntitySource(
      SyncEntityType.rotationState,
      table: 'rotation_states',
      idColumn: 'singleton_id',
      changedAtColumn: 'updated_at_utc',
    ),
    _EntitySource(
      SyncEntityType.rotationScheme,
      table: 'rotation_schemes',
      idColumn: 'id',
      changedAtColumn: 'updated_at_utc',
    ),
    _EntitySource(
      SyncEntityType.prayerRoutineTemplate,
      table: 'prayer_routine_templates',
      idColumn: 'id',
      changedAtColumn: 'updated_at_utc',
    ),
    _EntitySource(
      SyncEntityType.prayerSession,
      table: 'prayer_sessions',
      idColumn: 'id',
      changedAtColumn: 'updated_at_utc',
    ),
    _EntitySource(
      SyncEntityType.learningState,
      table: 'learning_surahs',
      idColumn: 'id',
      changedAtColumn: 'updated_at_utc',
    ),
  ];

  /// Every entity type this inventory knows how to survey.
  ///
  /// Exposed so that adding a [SyncEntityType] without adding a source fails a
  /// test here, rather than quietly producing a preview that omits a whole
  /// category of the user's data.
  static Set<SyncEntityType> get coveredTypes => <SyncEntityType>{
    for (final source in _sources) source.type,
  };

  @override
  Future<Map<String, DateTime?>> localEntities() async {
    final entities = <String, DateTime?>{};
    for (final source in _sources) {
      final changedAt = source.changedAtColumn;
      final rows = await _database
          .customSelect(
            changedAt == null
                ? 'SELECT "${source.idColumn}" AS entity_id, '
                      'NULL AS changed_at FROM "${source.table}"'
                : 'SELECT "${source.idColumn}" AS entity_id, '
                      '$changedAt AS changed_at FROM "${source.table}"',
          )
          .get();
      for (final row in rows) {
        final id = row.data['entity_id'];
        // A row with no id cannot be addressed across devices, so counting it
        // would put a number in the preview that no merge could act on.
        if (id == null) continue;
        entities['${source.type.name}:$id'] = _utcFrom(row.data['changed_at']);
      }
    }
    return entities;
  }

  @override
  Future<Map<String, DateTime?>> remoteEntities(String userId) async {
    if (userId != _userId) {
      throw StateError(
        'Refusing to survey an account this inventory is not bound to.',
      );
    }
    final entities = <String, DateTime?>{};
    // Deliberately from the beginning, and deliberately discarded afterwards:
    // this walk must not advance the durable pull cursor, or the first real
    // pull would start after everything the survey just read and skip it.
    var cursor = SyncCursor.beginning;
    while (true) {
      final page = await _gateway.pull(after: cursor, limit: pageLimit);
      for (final envelope in page.envelopes) {
        // A tombstone still counts as present: the account knows about this
        // entity, and a merge has to decide what wins. Treating it as absent
        // would let a deleted record look like a fresh local-only one and be
        // pushed straight back.
        entities[envelope.entityKey] = envelope.updatedAtUtc;
      }
      if (!page.hasMore) return entities;
      if (page.cursor.value == cursor.value) {
        // The server says there is more but handed back no new position.
        // Continuing would loop forever against a preview the user is waiting
        // on, so this stops and says why.
        throw const SyncTransportException('remote-inventory-stalled');
      }
      cursor = page.cursor;
    }
  }

  /// Drift stores these as whole seconds since the epoch; a raw select hands
  /// them back as integers rather than the typed `DateTime` a generated row
  /// would carry.
  static DateTime? _utcFrom(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

final class _EntitySource {
  const _EntitySource(
    this.type, {
    required this.table,
    required this.idColumn,
    this.changedAtColumn,
  });

  final SyncEntityType type;
  final String table;
  final String idColumn;

  /// A SQL expression, or null when the table records no such moment.
  final String? changedAtColumn;
}
