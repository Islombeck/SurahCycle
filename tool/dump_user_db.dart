// Read-only inspector for a pulled copy of the user database.
//
// Temporary QA aid: it never opens the file on the device and never writes.
// Usage: dart run tool/dump_user_db.dart <path-to-copy> [extra SQL ...]
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dump_user_db.dart <db-file> [sql ...]');
    exitCode = 64;
    return;
  }

  // `dart run` builds no native assets, so the sqlite3 package falls back to a
  // process-wide symbol lookup. Loading the library the Flutter build already
  // produced puts those symbols in this process.
  if (Platform.isWindows) {
    final dll = File('.dart_tool/lib/sqlite3.dll');
    if (dll.existsSync()) DynamicLibrary.open(dll.absolute.path);
  }

  final db = sqlite3.open(args.first, mode: OpenMode.readOnly);
  try {
    stdout.writeln(
      'user_version=${db.select('pragma user_version').first.values.first}',
    );
    final tables = db.select(
      "select name from sqlite_master where type = 'table' "
      "and name not like 'sqlite_%' order by name",
    );
    for (final row in tables) {
      final name = row['name'] as String;
      final count = db.select('select count(*) as c from "$name"').first['c'];
      stdout.writeln('$name=$count');
    }
    for (final sql in args.skip(1)) {
      stdout.writeln('--- $sql');
      for (final row in db.select(sql)) {
        stdout.writeln(row.values.map((v) => v ?? 'null').join(' | '));
      }
    }
  } finally {
    db.close();
  }
}
