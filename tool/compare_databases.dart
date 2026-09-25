/// Compares two SurahCycle databases by **identifier**, not by count.
///
/// The independent audit's sharpest correction was that 85 sessions on one
/// device and 84 on another proved nothing either way: counts can match while
/// the contents differ, and can differ while nothing was lost. It asked for
/// timestamped id sets to be compared instead, and then for the fields of the
/// rows that appear in both.
///
/// So this prints, per table: how many rows each side has, which ids only the
/// left has, which only the right has, and — for the tables where a field can
/// disagree without the id doing so — which shared rows differ and in what.
///
/// It reads. Both files are opened read-only and nothing is written anywhere,
/// because the databases worth comparing are copies of someone's real history.
///
/// Usage: `dart run tool/compare_databases.dart <left.sqlite> <right.sqlite>`
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Tables compared by their single-column primary key.
const Map<String, String> _byId = <String, String>{
  'recitation_events': 'id',
  'prayer_sessions': 'id',
  'prayer_session_parts': 'id',
  'rotation_schemes': 'id',
  // Named `rotation_parts` in SQL, not `rotation_scheme_parts` — the Drift
  // class name is not the table name, and comparing a table that does not
  // exist reports "absent on one side" rather than failing, which is how a
  // silent gap in a comparison gets shipped.
  'rotation_parts': 'id',
  'mastered_surahs': 'surah_id',
  'learning_surahs': 'id',
  'learning_events': 'id',
  'rotation_adjustments': 'id',
  'recall_attempts': 'id',
  'app_settings': 'key',
};

/// Tables whose identity is a pair of columns rather than one.
const Map<String, List<String>> _byPair = <String, List<String>>{
  'recitation_event_parts': <String>['event_id', 'part_id'],
};

/// Fields that can differ while the id does not, per table. These are the ones
/// the audit named: the day, whether it was a Qada, and whether it still
/// stands.
const Map<String, List<String>> _comparedFields = <String, List<String>>{
  'recitation_events': <String>[
    'surah_id',
    'rotation_scheme_id',
    'local_date',
    'prayer_type',
    'is_qada',
    'qada_origin_is_unknown',
    'qada_fulfilled_local_date',
    'rakaat_span_count',
    'deleted_at_utc',
  ],
  'prayer_sessions': <String>[
    'prayer_type',
    'is_qada',
    'local_date',
    'started_at_utc',
  ],
  'rotation_parts': <String>[
    'scheme_id',
    'ordinal',
    'start_ayah',
    'end_ayah',
  ],
};

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/compare_databases.dart <left.sqlite> '
      '<right.sqlite>',
    );
    exitCode = 64;
    return;
  }
  final leftPath = arguments[0];
  final rightPath = arguments[1];
  for (final path in <String>[leftPath, rightPath]) {
    if (!File(path).existsSync()) {
      stderr.writeln('No such file: $path');
      exitCode = 66;
      return;
    }
  }

  final left = sqlite3.open(leftPath, mode: OpenMode.readOnly);
  final right = sqlite3.open(rightPath, mode: OpenMode.readOnly);
  try {
    _line('left  : $leftPath  (schema v${_userVersion(left)})');
    _line('right : $rightPath  (schema v${_userVersion(right)})');
    _line('');

    var differences = 0;
    for (final entry in _byId.entries) {
      differences += _compareKeyed(
        left,
        right,
        table: entry.key,
        keyColumns: <String>[entry.value],
      );
    }
    for (final entry in _byPair.entries) {
      differences += _compareKeyed(
        left,
        right,
        table: entry.key,
        keyColumns: entry.value,
      );
    }
    _line('');
    _line(
      differences == 0
          ? 'Identical on every compared table.'
          : '$differences table(s) differ.',
    );
    // A difference is not a failure — two devices legitimately hold different
    // prayers. The exit code says only whether anything differed, so a script
    // can branch on it; deciding what a difference means is the reader's job.
    exitCode = differences == 0 ? 0 : 1;
  } finally {
    left.close();
    right.close();
  }
}

int _compareKeyed(
  Database left,
  Database right, {
  required String table,
  required List<String> keyColumns,
}) {
  if (!_hasTable(left, table) || !_hasTable(right, table)) {
    _line('$table: absent on one side, skipped');
    return 0;
  }
  final fields = _comparedFields[table] ?? const <String>[];
  final leftRows = _rowsOf(left, table, keyColumns, fields);
  final rightRows = _rowsOf(right, table, keyColumns, fields);

  final onlyLeft = leftRows.keys.where((k) => !rightRows.containsKey(k)).toList()
    ..sort();
  final onlyRight =
      rightRows.keys.where((k) => !leftRows.containsKey(k)).toList()..sort();
  final changed = <String, String>{};
  for (final key in leftRows.keys) {
    final other = rightRows[key];
    if (other == null) continue;
    final mine = leftRows[key]!;
    final differing = <String>[];
    for (final field in fields) {
      if ('${mine[field]}' != '${other[field]}') {
        differing.add('$field: ${mine[field]} | ${other[field]}');
      }
    }
    if (differing.isNotEmpty) changed[key] = differing.join(', ');
  }

  final same =
      onlyLeft.isEmpty && onlyRight.isEmpty && changed.isEmpty;
  _line(
    '$table: ${leftRows.length} | ${rightRows.length}'
    '${same ? '  — same ids, same fields' : ''}',
  );
  if (same) return 0;

  _report('only left', onlyLeft);
  _report('only right', onlyRight);
  if (changed.isNotEmpty) {
    _line('  shared but differing (${changed.length}):');
    for (final key in changed.keys.take(20)) {
      _line('    $key — ${changed[key]}');
    }
    if (changed.length > 20) {
      _line('    … ${changed.length - 20} more');
    }
  }
  return 1;
}

void _report(String label, List<String> keys) {
  if (keys.isEmpty) return;
  _line('  $label (${keys.length}):');
  for (final key in keys.take(20)) {
    _line('    $key');
  }
  if (keys.length > 20) {
    _line('    … ${keys.length - 20} more');
  }
}

Map<String, Map<String, Object?>> _rowsOf(
  Database database,
  String table,
  List<String> keyColumns,
  List<String> fields,
) {
  final columns = <String>{...keyColumns, ...fields}
      .where((c) => _hasColumn(database, table, c))
      .toList();
  final selected = columns.map((c) => '"$c"').join(', ');
  final result = database.select('SELECT $selected FROM "$table"');
  final rows = <String, Map<String, Object?>>{};
  for (final row in result) {
    final key = keyColumns.map((c) => '${row[c]}').join('/');
    rows[key] = <String, Object?>{
      for (final column in columns) column: row[column],
    };
  }
  return rows;
}

bool _hasTable(Database database, String table) =>
    database
        .select(
          "SELECT count(*) AS n FROM sqlite_master WHERE type = 'table' "
          'AND name = ?',
          <Object?>[table],
        )
        .first['n'] ==
    1;

bool _hasColumn(Database database, String table, String column) => database
    .select('PRAGMA table_info("$table")')
    .any((row) => row['name'] == column);

int _userVersion(Database database) =>
    database.select('PRAGMA user_version').first.values.first! as int;

void _line(String message) {
  // ignore: avoid_print
  print(message);
}
