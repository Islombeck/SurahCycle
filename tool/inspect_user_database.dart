/// Reads a pulled copy of `murajaah_user.sqlite` without migrating it.
///
/// Verifying a migration on the owner's real data means comparing the same
/// counts before and after, and the "before" copy must be read **exactly as it
/// is**. Opening it through `AppDatabase` would migrate it on the spot, which
/// is precisely the thing under test.
///
/// Usage:
///   `dart run tool/inspect_user_database.dart <before.sqlite> [<after.sqlite>]`
///
/// With two paths it prints a comparison and exits non-zero if anything the
/// user owns differs.
library;

import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

/// Tables whose row counts must be identical across a migration. A migration
/// that adds a column has no business changing any of these.
const List<String> _userTables = <String>[
  'recitation_events',
  'recitation_event_parts',
  'prayer_sessions',
  'prayer_session_parts',
  'prayer_routine_templates',
  'prayer_routine_part_templates',
  'mastered_surahs',
  'rotation_states',
  'rotation_schemes',
  'rotation_parts',
  'rotation_adjustments',
  'recall_attempts',
  'learning_surahs',
  'learning_events',
  'app_settings',
  'surah_metadata',
];

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/inspect_user_database.dart <db> [<db2>]',
    );
    exitCode = 64;
    return;
  }

  final first = _read(arguments.first);
  _print(arguments.first, first);
  if (arguments.length == 1) return;

  final second = _read(arguments[1]);
  stdout.writeln('');
  _print(arguments[1], second);

  stdout.writeln('');
  var differs = false;
  for (final table in _userTables) {
    final before = first.counts[table];
    final after = second.counts[table];
    if (before != after) {
      differs = true;
      stdout.writeln('DIFFERS  $table: $before -> $after');
    }
  }
  stdout.writeln(
    differs
        ? 'User-owned row counts CHANGED.'
        : 'Every user-owned row count is identical.',
  );
  if (differs) exitCode = 1;
}

_Snapshot _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No such file: $path');
    exit(66);
  }
  // Read-only: this must not create, migrate or journal anything.
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final counts = <String, int?>{};
    for (final table in _userTables) {
      final exists = database.select(
        "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = ?",
        <Object?>[table],
      ).isNotEmpty;
      counts[table] = exists
          ? database.select('SELECT COUNT(*) AS n FROM "$table"').first['n']
                as int
          : null;
    }
    return _Snapshot(
      userVersion:
          database.select('PRAGMA user_version').first['user_version'] as int,
      counts: counts,
      integrity:
          database.select('PRAGMA integrity_check').first['integrity_check']
              as String,
      foreignKeyViolations: database.select('PRAGMA foreign_key_check').length,
      triggers: database
          .select(
            "SELECT name FROM sqlite_schema WHERE type = 'trigger' "
            "AND name LIKE 'trg_%_touch_%' ORDER BY name",
          )
          .map((row) => row['name'] as String)
          .toList(),
      datedRows: _datedRows(database),
    );
  } finally {
    database.close();
  }
}

/// How many rows in each v10 table already carry `updated_at_utc`.
///
/// Null means the column is not there at all, which is what a pre-v10 copy
/// should say.
Map<String, int?> _datedRows(Database database) {
  const tables = <String>[
    'mastered_surahs',
    'rotation_states',
    'rotation_schemes',
    'prayer_routine_templates',
    'prayer_sessions',
    'learning_surahs',
  ];
  final dated = <String, int?>{};
  for (final table in tables) {
    final hasColumn = database
        .select('PRAGMA table_info("$table")')
        .any((row) => row['name'] == 'updated_at_utc');
    dated[table] = hasColumn
        ? database
                  .select(
                    'SELECT COUNT(*) AS n FROM "$table" '
                    'WHERE updated_at_utc IS NOT NULL',
                  )
                  .first['n']
              as int
        : null;
  }
  return dated;
}

void _print(String path, _Snapshot snapshot) {
  stdout.writeln(path);
  stdout.writeln('  user_version: ${snapshot.userVersion}');
  stdout.writeln('  integrity_check: ${snapshot.integrity}');
  stdout.writeln('  foreign_key_check rows: ${snapshot.foreignKeyViolations}');
  stdout.writeln('  touch triggers: ${snapshot.triggers.length}');
  for (final entry in snapshot.counts.entries) {
    stdout.writeln('  ${entry.key}: ${entry.value ?? '(no such table)'}');
  }
  stdout.writeln('  rows carrying updated_at_utc:');
  for (final entry in snapshot.datedRows.entries) {
    stdout.writeln('    ${entry.key}: ${entry.value ?? '(no such column)'}');
  }
}

final class _Snapshot {
  const _Snapshot({
    required this.userVersion,
    required this.counts,
    required this.integrity,
    required this.foreignKeyViolations,
    required this.triggers,
    required this.datedRows,
  });

  final int userVersion;
  final Map<String, int?> counts;
  final String integrity;
  final int foreignKeyViolations;
  final List<String> triggers;
  final Map<String, int?> datedRows;
}
