/// Runs the migration over **real** databases, not built ones.
///
/// `app_database_migration_test.dart` seeds each old schema by hand, which
/// proves the migration handles the shapes we thought to write down. A phone
/// that has been used for months holds shapes nobody wrote down: a journal with
/// nine hundred records in it, schemes split and re-split, rows dated before a
/// column existed to date them.
///
/// So this points the same migration at copies of those files. It is skipped
/// unless `MURAJAAH_SNAPSHOT_DIR` names a directory of `.sqlite` snapshots,
/// because they are the owner's data and belong nowhere near the repository —
/// the check is reproducible, the files are not shipped.
///
/// **Copies only.** Each snapshot is copied into a temporary directory and the
/// copy is migrated; the file the variable points at is opened read-only, to
/// count what was in it, and never written to.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Tables whose contents a schema migration must never change. Everything the
/// owner recorded is here; the rest is derived, cached or transport.
const Set<String> _hisOwnWork = <String>{
  'recitation_events',
  'recitation_event_parts',
  'rotation_adjustments',
  'rotation_schemes',
  'rotation_scheme_parts',
  'mastered_surahs',
  'surah_metadata',
  'learning_surahs',
  'learning_events',
  'prayer_sessions',
  'prayer_session_parts',
  'recall_attempts',
  'app_settings',
};

void main() {
  final configured = Platform.environment['MURAJAAH_SNAPSHOT_DIR'];
  if (configured == null || configured.trim().isEmpty) {
    test('real snapshots are not available here', () {
      markTestSkipped(
        'Set MURAJAAH_SNAPSHOT_DIR to a directory of .sqlite snapshots to run '
        'the migration over real databases.',
      );
    }, skip: 'MURAJAAH_SNAPSHOT_DIR is not set');
    return;
  }

  final source = Directory(configured);
  final snapshots =
      source
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.sqlite'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the snapshot directory has something in it', () {
    expect(
      snapshots,
      isNotEmpty,
      reason: 'a green run over nothing is the fake green to avoid here',
    );
  });

  for (final snapshot in snapshots) {
    final name = snapshot.uri.pathSegments.last;

    test('$name migrates to v11 with his history intact', () async {
      final before = _countsOf(snapshot.path);
      // Anything that never reached v10 would be exercising the older steps,
      // which the hand-seeded suite already covers row by row. These files are
      // here for what a real v10 database contains.
      expect(
        before.userVersion,
        greaterThanOrEqualTo(1),
        reason: 'not a Murajaah database',
      );
      expect(before.userVersion, lessThanOrEqualTo(11));

      final directory = await Directory.systemTemp.createTemp('murajaah-real-');
      addTearDown(() => directory.delete(recursive: true));
      final copy = await snapshot.copy('${directory.path}/$name');

      final database = AppDatabase(NativeDatabase(copy));
      // Opening is what runs the migration; this is the first statement that
      // forces it rather than a query that happens to.
      final migratedVersion = await database
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((row) => row.read<int>('user_version'));
      final violations = await database
          .customSelect('PRAGMA foreign_key_check')
          .get();
      final unstamped = await database
          .customSelect(
            'SELECT count(*) AS n FROM recitation_events '
            'WHERE state_changed_at_utc IS NOT NULL',
          )
          .getSingle()
          .then((row) => row.read<int>('n'));
      final inbox = await database
          .customSelect('SELECT count(*) AS n FROM sync_inbox_entries')
          .getSingle()
          .then((row) => row.read<int>('n'));
      final aliases = await database
          .customSelect('SELECT count(*) AS n FROM sync_entity_aliases')
          .getSingle()
          .then((row) => row.read<int>('n'));
      await database.close();

      final after = _countsOf(copy.path);

      expect(migratedVersion, 11);
      expect(after.userVersion, 11);
      expect(
        violations,
        isEmpty,
        reason: 'a migration that leaves a dangling key has lost a link',
      );
      expect(
        inbox,
        0,
        reason: 'an inbox row invented by a migration is a record he never '
            'sent',
      );
      expect(aliases, 0);
      expect(
        unstamped,
        0,
        reason:
            'the stamp says when the standing of a prayer last changed, and '
            'for a record written before the column existed nobody knows — a '
            'migration that filled it in would be inventing that answer',
      );

      for (final table in _hisOwnWork) {
        if (!before.rows.containsKey(table)) continue;
        expect(
          after.rows[table],
          before.rows[table],
          reason: '$table changed from ${before.rows[table]} to '
              '${after.rows[table]} rows in $name',
        );
      }
      for (final table in before.rows.keys) {
        expect(
          after.rows[table],
          isNotNull,
          reason: '$table was dropped by the migration of $name',
        );
      }
    });
  }
}

final class _Counts {
  const _Counts(this.userVersion, this.rows);

  final int userVersion;
  final Map<String, int> rows;
}

/// Row counts read without drift, so nothing here can run a migration by
/// accident — which is the whole point of the "before" reading.
_Counts _countsOf(String path) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final version = database.select('PRAGMA user_version').first.values.first!;
    final tables = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
    );
    final rows = <String, int>{};
    for (final table in tables) {
      final name = table['name'] as String;
      rows[name] =
          database.select('SELECT count(*) AS n FROM "$name"').first['n']
              as int;
    }
    return _Counts(version as int, rows);
  } finally {
    database.close();
  }
}
