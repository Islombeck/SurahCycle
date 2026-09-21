import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Runs the backfill against a **copy** of a real device database and says what
/// would travel, what would not, and why.
///
/// Every other test here builds the history it examines, which means every
/// other test examines a history this project knows how to build. A phone that
/// has been in use for a year holds rows written by older versions of the app,
/// under invariants that have since been tightened — and the only way to learn
/// whether those still express is to try them. This is how the prayer-session
/// refusal was confirmed against real data rather than argued about.
///
/// Skipped unless pointed at a file, so it costs nothing in an ordinary run:
///
///     $env:MURAJAAH_DRY_RUN_DB = '<path>\copy.sqlite'
///     flutter test test/tool/real_database_backfill_test.dart
///
/// It **writes** — an outbox is a table — so it refuses a path that looks like
/// a live device file. Pull a copy first; `docs/AI_HANDOFF.md` has the command.
void main() {
  final path = Platform.environment['MURAJAAH_DRY_RUN_DB'];

  test(
    'a real history reaches the account in full',
    () async {
      expect(
        path!.contains('/data/data/') || path.contains(r'\data\data\'),
        isFalse,
        reason: 'this writes; point it at a pulled copy, never at the phone',
      );
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'no such file: $path');

      final database = AppDatabase(NativeDatabase(file));
      addTearDown(database.close);

      final outbox = InMemorySyncOutbox();
      var ids = 0;
      final backfill = DriftSyncBackfill(
        database: database,
        outbox: outbox,
        deviceId: () async => 'dry-run',
        newId: () => 'dry-${++ids}',
      );

      final report = await backfill.enqueueEverything(
        nowUtc: DateTime.now().toUtc(),
      );

      final summary = <String>[
        for (final type in SyncEntityType.values)
          if ((report.enqueuedByType[type] ?? 0) > 0 ||
              (report.skippedByType[type] ?? 0) > 0)
            '${type.name}: sent ${report.enqueuedByType[type] ?? 0}'
                '${(report.skippedByType[type] ?? 0) == 0 ? '' : ', LEFT BEHIND ${report.skippedByType[type]} '
                          '(${report.skippedFields[type]?.join(', ')})'}',
      ];
      // Printed either way: the counts are the point of running this at all.
      // ignore: avoid_print
      print(summary.join('\n'));

      expect(
        report.skippedCount,
        0,
        reason:
            'a backfill that sends most of a history is the one failure this '
            'feature cannot recover from on its own — the fields named above '
            'are where it refused',
      );
      expect(
        report.enqueuedCount,
        greaterThan(0),
        reason: 'a real database that offered nothing would mean a broken walk',
      );
    },
    skip: path == null
        ? 'Set MURAJAAH_DRY_RUN_DB to a pulled copy of a device database.'
        : null,
  );
}
