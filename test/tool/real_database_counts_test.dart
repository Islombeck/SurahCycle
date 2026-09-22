import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

/// Counts the rows in a pulled device database, and compares two of them.
///
/// This is the check that follows every install: the owner's history is the
/// thing this project cannot replace, and "the APK went on and the app opens"
/// is not evidence that it survived. It is deliberately dumber than the app —
/// it opens the file **read-only** with plain sqlite3 rather than through
/// `AppDatabase`, because opening it through the app would run the migrator,
/// and a check that writes to the thing it is checking proves nothing.
///
/// Every table in the file is counted, not a remembered list of them, so a
/// table added next year is covered by this without anyone remembering to add
/// it here.
///
///     $env:MURAJAAH_DB_BEFORE = '<path>\before.sqlite'
///     $env:MURAJAAH_DB_AFTER  = '<path>\after.sqlite'   # optional
///     flutter test test/tool/real_database_counts_test.dart
///
/// With only BEFORE set it prints that file's counts. With both it fails if any
/// table lost rows or the schema version moved backwards. Growth passes: an app
/// that was opened once may legitimately have written something.
void main() {
  final beforePath = Platform.environment['MURAJAAH_DB_BEFORE'];
  final afterPath = Platform.environment['MURAJAAH_DB_AFTER'];
  final skipReason = beforePath == null
      ? 'Set MURAJAAH_DB_BEFORE to a pulled copy of a device database.'
      : null;

  test('a pulled database still holds everything it held', () {
    final before = _readCounts(beforePath!);
    if (afterPath == null) {
      // ignore: avoid_print
      print(_describe('counts', before.counts, before.userVersion));
      return;
    }

    final after = _readCounts(afterPath);
    // ignore: avoid_print
    print(_describe('before', before.counts, before.userVersion));
    // ignore: avoid_print
    print(_describe('after', after.counts, after.userVersion));

    expect(
      after.userVersion,
      greaterThanOrEqualTo(before.userVersion),
      reason:
          'a schema version that went backwards is a downgrade, not an '
          'install',
    );
    final lost = <String>[
      for (final entry in before.counts.entries)
        if ((after.counts[entry.key] ?? 0) < entry.value)
          '${entry.key}: ${entry.value} → ${after.counts[entry.key] ?? 0}',
    ];
    expect(
      lost,
      isEmpty,
      reason:
          'rows the owner wrote are gone; this is the one outcome that '
          'cannot be undone from here',
    );
  }, skip: skipReason);
}

typedef _Snapshot = ({Map<String, int> counts, int userVersion});

_Snapshot _readCounts(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'no such file: $path');
  expect(
    path.contains('/data/data/') || path.contains(r'\data\data\'),
    isFalse,
    reason: 'point this at a pulled copy, never at the phone itself',
  );

  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final tables = <String>[
      for (final row in database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      ))
        row['name'] as String,
    ];
    return (
      counts: <String, int>{
        for (final table in tables)
          // The names come from `sqlite_master` in this same file, so there is
          // nothing here a caller could shape into an injection.
          table:
              database.select('SELECT count(*) AS n FROM "$table"').first['n']
                  as int,
      },
      userVersion: database.userVersion,
    );
  } finally {
    database.close();
  }
}

String _describe(String label, Map<String, int> counts, int userVersion) =>
    '$label (user_version = $userVersion): '
    '${counts.entries.where((entry) => entry.value > 0).map((entry) => '${entry.key}=${entry.value}').join(', ')}';
