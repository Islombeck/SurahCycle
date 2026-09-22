/// Reading and writing `updated_at_utc` for the six tables that carry it.
///
/// Every applier for a mutable entity needs exactly two things from that
/// column: what the local copy says before deciding whether to write, and the
/// authored time afterwards so the record does not re-date itself on every
/// device it passes through. Five copies of both would drift apart, and the
/// second one has a trap in it — the insert trigger stamps `now`
/// unconditionally, while the update trigger steps aside when the writer sets
/// the column itself, so the stamp has to be its own statement **after** the
/// write rather than a column in it.
///
/// Raw SQL rather than Drift's typed API because the table is a parameter
/// here; the names come from [_keys] and never from a caller, so there is
/// nothing a payload could shape into an injection.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// The tables schema v10 gave `updated_at_utc`, with the column each is keyed
/// by. `rotation_states` is absent on purpose: it is a projection, it is
/// refused by the router, and nothing applies it.
const Map<String, String> _keys = <String, String>{
  'mastered_surahs': 'surah_id',
  'rotation_schemes': 'id',
  'prayer_sessions': 'id',
  'prayer_routine_templates': 'id',
  // Keyed by `id`, not by `surah_id`: the plan's id is what the envelope
  // carries, and the two differ on a device that started the same surah twice.
  'learning_surahs': 'id',
  'app_settings': 'key',
};

final class SyncVersionedRows {
  const SyncVersionedRows(this._database);

  final AppDatabase _database;

  /// When the local row last changed, or null when it is absent or undated.
  ///
  /// Both answers mean the same thing to the merge rule — nothing here can
  /// outrank the incoming record — and collapsing them is deliberate rather
  /// than lossy: see `SyncMergeDecision`.
  Future<DateTime?> updatedAtUtc({
    required String table,
    required String key,
  }) async {
    final column = _columnOf(table);
    final row = await _database
        .customSelect(
          'SELECT updated_at_utc AS at FROM $table WHERE $column = ?',
          variables: <Variable<Object>>[Variable<String>(key)],
        )
        .getSingleOrNull();
    final seconds = row?.data['at'];
    if (seconds is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// Records when the row was **authored**, not when it arrived.
  Future<void> stampAuthored({
    required String table,
    required String key,
    required DateTime authoredAtUtc,
  }) async {
    final column = _columnOf(table);
    await _database.customStatement(
      'UPDATE $table SET updated_at_utc = ? WHERE $column = ?',
      <Object?>[
        // Whole seconds, exactly what the touch triggers write, so a stamped
        // row and a touched one are comparable without one being rounded
        // behind the other's back.
        authoredAtUtc.toUtc().millisecondsSinceEpoch ~/ 1000,
        key,
      ],
    );
  }

  /// Marks a row as never authored by anyone.
  ///
  /// For rows this device **invented** rather than received or edited: the
  /// eight empty routine templates every install seeds, and the placeholder
  /// scheme a roster entry arrives with. The insert trigger dates them `now`,
  /// which would make a fresh phone's placeholders outrank the owner's real
  /// records — his routine, authored last week, refused by a blank one created
  /// during setup. Null is "nobody has an opinion here", which is exactly what
  /// a placeholder is, and it is the same reasoning ADR-0002 §7 applies to a
  /// row left undated by the v10 migration.
  Future<void> markUndated({required String table, required String key}) async {
    final column = _columnOf(table);
    await _database.customStatement(
      'UPDATE $table SET updated_at_utc = NULL WHERE $column = ?',
      <Object?>[key],
    );
  }

  static String _columnOf(String table) {
    final column = _keys[table];
    if (column == null) {
      throw ArgumentError.value(table, 'table', 'Carries no updated_at_utc.');
    }
    return column;
  }
}
