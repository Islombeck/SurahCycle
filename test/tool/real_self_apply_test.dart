import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_envelope_router.dart';
import 'package:murajaah/core/sync/sync.dart';

/// **His own history, applied back onto his own device.**
///
/// This is not an exotic case — it is what every cycle does. A device pushes
/// its records and the next pull hands them straight back, so the appliers
/// spend most of their time re-applying things the device already has. It has
/// to be a no-op, and on 2026-09-24 it was not: two of his own records broke
/// the applier outright, the exception was not a `SyncTransportException`, the
/// cycle died without writing anything down, and his phone stopped receiving
/// for a day while the screen looked healthy.
///
/// Both were about Al-Baqara, the one surah he has split twice:
///
/// - `StateError: Too many elements` — "does this surah have a scheme" asked
///   with `getSingleOrNull`, of a surah that has a chain of them;
/// - `SqliteException(275)` — a scheme stood down by writing zero into
///   `superseded_journal_sequence`, below the position it was really activated
///   at.
///
/// Neither was reachable from a fixture that had never re-split a surah.
///
///     $env:MURAJAAH_SOURCE_DB = '<path>\his-phone.sqlite'
///     flutter test test/tool/real_self_apply_test.dart
///
/// The file is copied before use, so it is not written to.
void main() {
  final sourcePath = Platform.environment['MURAJAAH_SOURCE_DB'];
  final skipReason = sourcePath == null
      ? 'Set MURAJAAH_SOURCE_DB to a pulled copy of a real device database.'
      : null;

  test('a device applying its own history back changes nothing', () async {
    final copy = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'murajaah-self-apply.sqlite',
    );
    if (copy.existsSync()) copy.deleteSync();
    File(sourcePath!).copySync(copy.path);
    final device = AppDatabase(NativeDatabase(copy));
    addTearDown(() async {
      await device.close();
      if (copy.existsSync()) copy.deleteSync();
    });

    Future<Map<String, int>> countsOf() async => <String, int>{
      for (final table in <String>[
        'recitation_events',
        'recitation_event_parts',
        'prayer_sessions',
        'mastered_surahs',
        'rotation_schemes',
        'rotation_parts',
        'learning_surahs',
        'learning_events',
        'prayer_routine_templates',
      ])
        table: (await device
                .customSelect('SELECT count(*) AS n FROM $table')
                .getSingle())
            .read<int>('n'),
    };

    final before = await countsOf();

    final outbox = InMemorySyncOutbox();
    var ids = 0;
    await DriftSyncBackfill(
      database: device,
      outbox: outbox,
      deviceId: () async => 'his-phone',
      newId: () => 'e-${++ids}',
    ).enqueueEverything(nowUtc: DateTime.now().toUtc());
    final envelopes = <SyncEnvelope>[
      for (final entry in await outbox.peek(limit: 100000)) entry.envelope,
    ];
    expect(envelopes, isNotEmpty);

    final router = SyncEnvelopeRouter(device);
    final refused = <String>[];
    final broke = <String>[];
    for (final envelope in router.inDependencyOrder(envelopes)) {
      try {
        await device.transaction(() => router.apply(envelope));
      } on SyncTransportException catch (error) {
        refused.add('${envelope.entityType.name} ${envelope.entityId}: '
            '${error.reason}');
      } on Object catch (error) {
        broke.add('${envelope.entityType.name} ${envelope.entityId}: '
            '${error.runtimeType}');
      }
    }
    await device.transaction(router.settleProjection);

    expect(
      broke,
      isEmpty,
      reason:
          'anything that is not a SyncTransportException escapes the cycle, '
          'and a cycle that escapes leaves a device that has stopped '
          'receiving with nothing anywhere to say so',
    );
    expect(
      refused,
      isEmpty,
      reason: 'a device cannot be unable to accept what it already holds',
    );
    expect(
      await countsOf(),
      before,
      reason:
          'applying his own history back is what every cycle does; it has to '
          'be a no-op, not a second copy of anything',
    );
  }, skip: skipReason, timeout: const Timeout(Duration(minutes: 10)));
}
