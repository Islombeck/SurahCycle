import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/backup/drift_local_backup_gateway.dart';
import 'package:murajaah/core/data/database/app_database.dart';

/// A backup is only worth having if it is complete, if it is still there when
/// it is needed, and if restoring it puts the database back exactly as it was.
/// These tests are about those three things.
void main() {
  late AppDatabase database;
  late Directory directory;
  late DateTime now;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp('murajaah-backup-test');
    now = DateTime.utc(2026, 9, 18, 12);
  });

  tearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  DriftLocalBackupGateway gatewayWith({int keepAtMost = 5}) =>
      DriftLocalBackupGateway(
        database: database,
        backupDirectory: () async => directory,
        nowUtc: () => now,
        keepAtMost: keepAtMost,
      );

  Future<void> putSetting(String key, String value) => database
      .into(database.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: key,
          value: value,
          valueType: 'string',
          updatedAtUtc: DateTime.utc(2026, 9, 18, 10),
        ),
      );

  Future<List<String>> settingKeys([AppDatabase? target]) async {
    final db = target ?? database;
    final rows = await db.select(db.appSettings).get();
    return <String>[for (final row in rows) row.key]..sort();
  }

  group('taking a snapshot', () {
    test('the copy holds what the live database held', () async {
      await putSetting('theme', 'dark');
      await putSetting('locale', 'ru');

      final backup = await gatewayWith().createBackup();

      final copy = AppDatabase(
        NativeDatabase(
          File('${directory.path}${Platform.pathSeparator}${backup.id}'),
        ),
      );
      addTearDown(copy.close);
      expect(await settingKeys(copy), <String>['locale', 'theme']);
    });

    test('the descriptor reports the schema that was actually copied', () async {
      final backup = await gatewayWith().createBackup();

      expect(
        backup.schemaVersion,
        database.schemaVersion,
        reason:
            'a hard-coded version would let a restore accept a snapshot whose '
            'columns do not match',
      );
      expect(backup.createdAtUtc, now);
    });

    test('two snapshots in the same second both survive', () async {
      final gateway = gatewayWith();

      final first = await gateway.createBackup();
      final second = await gateway.createBackup();

      expect(first.id, isNot(second.id));
      for (final id in <String>[first.id, second.id]) {
        expect(
          File('${directory.path}${Platform.pathSeparator}$id').existsSync(),
          isTrue,
          reason: 'making room by deleting a recovery copy is never right',
        );
      }
    });
  });

  group('pruning', () {
    test('the oldest go and the newest stays', () async {
      final gateway = gatewayWith(keepAtMost: 2);
      final made = <String>[];
      for (var day = 1; day <= 4; day++) {
        now = DateTime.utc(2026, 9, day, 12);
        made.add((await gateway.createBackup()).id);
      }

      final kept = await gateway.listBackups();

      expect(kept, hasLength(2));
      expect(
        <String>[for (final backup in kept) backup.id],
        <String>[made[3], made[2]],
        reason: 'newest first, and the two oldest pruned',
      );
    });

    test('a file that is not ours is never deleted', () async {
      final foreign = File(
        '${directory.path}${Platform.pathSeparator}owner-notes.txt',
      );
      await foreign.writeAsString('not a backup');
      final gateway = gatewayWith(keepAtMost: 1);

      for (var day = 1; day <= 3; day++) {
        now = DateTime.utc(2026, 9, day, 12);
        await gateway.createBackup();
      }

      expect(foreign.existsSync(), isTrue);
      expect(await gateway.listBackups(), hasLength(1));
    });

    test('keeping none is refused rather than obeyed', () {
      expect(
        () => gatewayWith(keepAtMost: 0),
        throwsA(isA<ArgumentError>()),
        reason: 'it would delete the backup as soon as it was made',
      );
    });
  });

  group('restoring', () {
    test('rows deleted since the snapshot come back', () async {
      await putSetting('theme', 'dark');
      final gateway = gatewayWith();
      final backup = await gateway.createBackup();

      await database.delete(database.appSettings).go();
      expect(await settingKeys(), isEmpty);

      await gateway.restoreBackup(backup.id);

      expect(await settingKeys(), <String>['theme']);
    });

    test('rows added since the snapshot go away', () async {
      await putSetting('theme', 'dark');
      final gateway = gatewayWith();
      final backup = await gateway.createBackup();

      await putSetting('locale', 'ru');

      await gateway.restoreBackup(backup.id);

      expect(
        await settingKeys(),
        <String>['theme'],
        reason:
            'a restore is a point in time, not a merge — leaving later rows '
            'behind would produce a state that never existed',
      );
    });

    test('a backup from a newer build is refused, not truncated', () async {
      final newer = File(
        '${directory.path}${Platform.pathSeparator}'
        'murajaah-backup-v${database.schemaVersion + 1}-20260918T120000Z'
        '.sqlite',
      );
      await newer.writeAsBytes(const <int>[]);

      await expectLater(
        () => gatewayWith().restoreBackup(
          newer.path.split(RegExp(r'[/\\]')).last,
        ),
        throwsA(isA<ArgumentError>()),
        reason:
            'its tables can hold columns this build never heard of, and there '
            'is no downgrade path',
      );
    });

    test('an id that escapes the backup directory is refused', () async {
      for (final id in <String>[
        '../murajaah-backup-v9-20260918T120000Z.sqlite',
        r'..\murajaah-backup-v9-20260918T120000Z.sqlite',
        '',
      ]) {
        await expectLater(
          () => gatewayWith().restoreBackup(id),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('an older snapshot is migrated on a copy, never in place', () async {
      await putSetting('theme', 'dark');
      final gateway = gatewayWith();
      final backup = await gateway.createBackup();

      // Renamed to claim the previous schema, which sends the restore down the
      // migrate-first branch. The migration itself is covered by the direct
      // migration suites; what is checked here is the plumbing around it.
      final original = File(
        '${directory.path}${Platform.pathSeparator}${backup.id}',
      );
      final olderName =
          'murajaah-backup-v${database.schemaVersion - 1}-20260918T120000Z'
          '.sqlite';
      final older = await original.rename(
        '${directory.path}${Platform.pathSeparator}$olderName',
      );
      final bytesBefore = await older.readAsBytes();

      await database.delete(database.appSettings).go();
      await gateway.restoreBackup(olderName);

      expect(await settingKeys(), <String>['theme']);
      expect(
        await older.readAsBytes(),
        bytesBefore,
        reason:
            'migrating the snapshot itself would mean a failed restore had '
            'already altered the only copy of the data',
      );
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.migrating'),
        ),
        isEmpty,
        reason: 'the working copy is scratch and must not accumulate',
      );
    });

    test('an unknown backup leaves the database untouched', () async {
      await putSetting('theme', 'dark');

      await expectLater(
        () => gatewayWith().restoreBackup(
          'murajaah-backup-v9-20260101T000000Z.sqlite',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await settingKeys(), <String>['theme']);
    });
  });

  group('exporting', () {
    test('the user\'s own tables are included', () async {
      await putSetting('theme', 'dark');

      final export = await gatewayWith().exportLocalData();
      final tables = export['tables']! as Map<String, Object?>;

      expect(export['schemaVersion'], database.schemaVersion);
      expect(export['exportedAtUtc'], now.toIso8601String());
      final settings = tables['app_settings']! as List<Object?>;
      expect(settings, hasLength(1));
      expect((settings.single as Map<String, Object?>)['key'], 'theme');
    });

    test('the Quran corpus is not the user\'s data and is left out', () async {
      final export = await gatewayWith().exportLocalData();
      final tables = export['tables']! as Map<String, Object?>;

      expect(
        tables.containsKey('surah_metadata'),
        isFalse,
        reason:
            'it is re-fetched by manifest; copying it would bloat a portable '
            'export for nothing',
      );
      expect(tables.containsKey('recitation_events'), isTrue);
    });
  });

  test('a listing ignores names it cannot read rather than guessing', () async {
    for (final name in <String>[
      'murajaah-backup-vX-20260918T120000Z.sqlite',
      'murajaah-backup-v9-not-a-date.sqlite',
      'murajaah-backup-v9-20260918T120000Z.txt',
    ]) {
      await File(
        '${directory.path}${Platform.pathSeparator}$name',
      ).writeAsBytes(const <int>[]);
    }

    expect(await gatewayWith().listBackups(), isEmpty);
  });
}
