/// Device-owned backup and recovery, with no account and no network involved.
///
/// This is what makes the first-sync question answerable: a user can only be
/// asked to agree to a merge while the answer is still reversible. It is also
/// useful entirely on its own, which is why it lives here and not under sync.
///
/// Two implementation choices carry the whole file:
///
/// - a snapshot is taken with `VACUUM INTO`, never by copying the database
///   file. The live database runs in WAL mode, so the main file on its own can
///   be missing committed transactions, and a backup that silently omits the
///   last few recitations is worse than none;
/// - a restore replaces rows through `ATTACH`, inside one transaction, rather
///   than swapping files under an open connection. It is all-or-nothing, it
///   needs no restart, and it never has to guess where Drift put the file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import '../../sync/sync.dart';
import '../database/app_database.dart';

final class DriftLocalBackupGateway implements LocalBackupGateway {
  DriftLocalBackupGateway({
    required AppDatabase database,
    required Future<Directory> Function() backupDirectory,
    required DateTime Function() nowUtc,
    this.keepAtMost = 5,
    // Named parameters cannot be private, so an initializing formal is not
    // available for these fields.
    // ignore: prefer_initializing_formals
  }) : _database = database,
       // ignore: prefer_initializing_formals
       _backupDirectory = backupDirectory,
       // ignore: prefer_initializing_formals
       _nowUtc = nowUtc {
    if (keepAtMost < 1) {
      throw ArgumentError.value(
        keepAtMost,
        'keepAtMost',
        'Pruning to zero would delete the backup as soon as it was made.',
      );
    }
  }

  final AppDatabase _database;
  final Future<Directory> Function() _backupDirectory;
  final DateTime Function() _nowUtc;

  /// How many snapshots to keep. Older ones are pruned, newest first kept.
  final int keepAtMost;

  static const String _prefix = 'murajaah-backup';
  static const String _extension = '.sqlite';

  /// The schema name a snapshot is attached under during a restore. Fixed, so
  /// an alias left behind by an interrupted restore can be recognised.
  static const String _attachAlias = 'restore_source';

  /// Tables whose contents are re-fetched by manifest rather than carried in a
  /// portable export: the Quran corpus is not the user's own data, and copying
  /// it would turn a small JSON file into a large one for no gain.
  ///
  /// A *backup* still contains them — it is a snapshot of the file, and a
  /// restore that quietly dropped the corpus would leave an app that cannot
  /// render a surah.
  static const Set<String> _notUserData = <String>{'surah_metadata'};

  @override
  Future<LocalBackupDescriptor> createBackup() async {
    final createdAtUtc = _nowUtc().toUtc();
    final schemaVersion = _database.schemaVersion;
    final directory = await _backupDirectory();
    await directory.create(recursive: true);

    final file = _unusedFile(directory, schemaVersion, createdAtUtc);
    // Not a file copy: see the library comment. `VACUUM INTO` also refuses a
    // target that already exists, which is why [_unusedFile] finds a free name
    // instead of overwriting — silently replacing a recovery copy with a newer
    // one is exactly what a backup must never do.
    await _database.customStatement('VACUUM INTO ?', <Object?>[file.path]);

    await _prune(directory, keep: file);
    return LocalBackupDescriptor(
      id: _basename(file),
      schemaVersion: schemaVersion,
      createdAtUtc: createdAtUtc,
    );
  }

  /// Every snapshot this gateway can see, newest first.
  Future<List<LocalBackupDescriptor>> listBackups() async {
    final directory = await _backupDirectory();
    if (!directory.existsSync()) return const <LocalBackupDescriptor>[];
    final descriptors = <LocalBackupDescriptor>[];
    for (final file in _ourFiles(directory)) {
      final descriptor = _describe(_basename(file));
      // A name this build cannot parse is left alone rather than guessed at:
      // it may be a user's own file sitting in the same directory.
      if (descriptor != null) descriptors.add(descriptor);
    }
    descriptors.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return descriptors;
  }

  @override
  Future<void> restoreBackup(String backupId) async {
    if (!_isSafeId(backupId)) {
      // An id is a bare file name. Anything with a separator in it would let a
      // caller read outside the backup directory.
      throw ArgumentError.value(backupId, 'backupId', 'Not a backup name.');
    }
    final directory = await _backupDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$backupId');
    if (!file.existsSync()) {
      throw ArgumentError.value(backupId, 'backupId', 'No such backup.');
    }
    final descriptor = _describe(backupId);
    if (descriptor == null) {
      throw ArgumentError.value(backupId, 'backupId', 'Not a backup name.');
    }
    if (descriptor.schemaVersion > _database.schemaVersion) {
      // Written by a newer build. Its tables can hold columns this one has
      // never heard of, and there is no downgrade path; restoring it would
      // drop them without saying so.
      throw ArgumentError.value(
        backupId,
        'backupId',
        'Backup schema v${descriptor.schemaVersion} is newer than '
            'v${_database.schemaVersion}.',
      );
    }

    // An older snapshot is brought forward by Drift's own migration, run
    // against a copy, rather than by a second implementation of it here. The
    // copy is what gets migrated, so a failed restore leaves the original
    // backup exactly as it was.
    var source = file;
    if (descriptor.schemaVersion < _database.schemaVersion) {
      source = await _migratedCopy(file);
    }

    try {
      // Attaching and detaching both have to happen outside the transaction:
      // SQLite holds a lock on an attached database for as long as one is
      // open, and refuses to detach it.
      await _clearLeakedAttachment();
      await _database.customStatement(
        'ATTACH DATABASE ? AS $_attachAlias',
        <Object?>[source.path],
      );
      try {
        await _database.transaction(() async {
          // Foreign keys are checked at commit instead of per statement, so
          // the tables can be emptied and refilled in any order. Without this
          // a restore would depend on a hand-maintained topological ordering
          // that every new table could silently invalidate.
          await _database.customStatement('PRAGMA defer_foreign_keys = ON');
          for (final table in _database.allTables) {
            final name = table.actualTableName;
            await _database.customStatement('DELETE FROM "$name"');
            await _database.customStatement(
              'INSERT INTO "$name" SELECT * FROM $_attachAlias."$name"',
            );
          }
        });
      } finally {
        // Swallowed on purpose: a failure to detach must not replace the
        // failure that caused the unwind. A leaked alias is picked up by
        // [_clearLeakedAttachment] on the next attempt instead.
        try {
          await _database.customStatement('DETACH DATABASE $_attachAlias');
        } on Object {
          // Deliberately ignored; see above.
        }
      }
    } finally {
      // The migrated copy is scratch. The snapshot it came from is untouched.
      if (!identical(source, file) && source.existsSync()) {
        await source.delete();
      }
    }
  }

  @override
  Future<Map<String, Object?>> exportLocalData() async {
    final tables = <String, Object?>{};
    for (final table in _database.allTables) {
      final name = table.actualTableName;
      if (_notUserData.contains(name)) continue;
      final rows = await _database.customSelect('SELECT * FROM "$name"').get();
      tables[name] = <Map<String, Object?>>[
        for (final row in rows) _portable(row.data),
      ];
    }
    return <String, Object?>{
      'schemaVersion': _database.schemaVersion,
      'exportedAtUtc': _nowUtc().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  /// Detaches a snapshot an interrupted restore left attached.
  ///
  /// Without this one leaked alias would make every later restore fail with
  /// "already in use" — a permanent loss of recovery over a transient error.
  Future<void> _clearLeakedAttachment() async {
    try {
      await _database.customStatement('DETACH DATABASE $_attachAlias');
    } on Object {
      // The ordinary case: nothing was attached.
    }
  }

  /// Opens [file]'s copy as an [AppDatabase] so the real migration runs on it.
  Future<File> _migratedCopy(File file) async {
    final copy = await file.copy('${file.path}.migrating');
    final upgraded = AppDatabase(NativeDatabase(copy));
    try {
      // Any statement forces Drift to open the file and run its migration.
      await upgraded.customSelect('SELECT 1').get();
    } finally {
      await upgraded.close();
    }
    return copy;
  }

  File _unusedFile(Directory directory, int schemaVersion, DateTime at) {
    final stamp = _stamp(at);
    final base =
        '${directory.path}${Platform.pathSeparator}'
        '$_prefix-v$schemaVersion-$stamp';
    var candidate = File('$base$_extension');
    // Two backups inside the same second are rare and not an error. Keeping
    // both is the only safe answer, because the alternative is deleting a
    // recovery copy to make room for another.
    for (var suffix = 2; candidate.existsSync(); suffix++) {
      candidate = File('$base-$suffix$_extension');
    }
    return candidate;
  }

  Future<void> _prune(Directory directory, {required File keep}) async {
    final keepName = _basename(keep);
    final ours = <String>[
      for (final file in _ourFiles(directory))
        if (_describe(_basename(file)) != null) _basename(file),
    ]..sort();
    // Names sort chronologically because the stamp does, so the tail is the
    // newest. The backup just written is excluded by name as well as by
    // position: pruning must never be able to delete the copy its caller is
    // about to be handed.
    final doomed = ours.take(
      ours.length <= keepAtMost ? 0 : ours.length - keepAtMost,
    );
    for (final name in doomed) {
      if (name == keepName) continue;
      await File('${directory.path}${Platform.pathSeparator}$name').delete();
    }
  }

  Iterable<File> _ourFiles(Directory directory) => directory
      .listSync()
      .whereType<File>()
      .where((file) => _basename(file).startsWith('$_prefix-'));

  /// Reads a file name back into a descriptor, or null when it is not ours.
  ///
  /// The name is the only record: a snapshot is a plain SQLite file, and
  /// keeping metadata in a sidecar would mean a lost sidecar makes a perfectly
  /// good backup unrestorable.
  LocalBackupDescriptor? _describe(String name) {
    final match = RegExp(
      '^$_prefix-v(\\d+)-'
      r'(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z'
      r'(?:-\d+)?'
      '${RegExp.escape(_extension)}\$',
    ).firstMatch(name);
    if (match == null) return null;
    int group(int index) => int.parse(match.group(index)!);
    try {
      return LocalBackupDescriptor(
        id: name,
        schemaVersion: group(1),
        createdAtUtc: DateTime.utc(
          group(2),
          group(3),
          group(4),
          group(5),
          group(6),
          group(7),
        ),
      );
    } on ArgumentError {
      return null;
    }
  }

  static bool _isSafeId(String id) =>
      id.isNotEmpty &&
      !id.contains('/') &&
      !id.contains(r'\') &&
      !id.contains('..');

  static String _basename(File file) => file.path.split(RegExp(r'[/\\]')).last;

  /// Sortable, and legal on every platform — which rules out the colons an
  /// ISO-8601 timestamp would bring.
  static String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year.toString().padLeft(4, '0')}${two(at.month)}'
        '${two(at.day)}T${two(at.hour)}${two(at.minute)}${two(at.second)}Z';
  }

  /// SQLite hands back blobs and raw integers. JSON carries neither, so blobs
  /// become base64 and everything else is already portable.
  static Map<String, Object?> _portable(Map<String, Object?> row) =>
      <String, Object?>{
        for (final entry in row.entries)
          entry.key: entry.value is List<int>
              ? base64Encode(entry.value! as List<int>)
              : entry.value,
      };
}
