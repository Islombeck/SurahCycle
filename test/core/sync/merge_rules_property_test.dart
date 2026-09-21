import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The merge rules, checked over generated cases rather than chosen ones.
///
/// `docs/ACCOUNT_SYNC_ARCHITECTURE.md` has carried these as prose since the
/// design was written, with a line saying they need an ADR and property tests
/// before multi-device sync ships. `docs/adr/ADR-0002` is the ADR; this is the
/// other half.
///
/// The properties are the ones a hand-written example cannot establish, because
/// each is a statement about *every* ordering rather than one:
///
/// - two devices that receive the same changes in different orders end up
///   agreeing, which is the only thing that makes a conflict rule a rule;
/// - a tie is broken the same way whichever side asks;
/// - a withdrawal is never undone by a change older than it.
///
/// Every generator is seeded, so a failure names a seed that reproduces it
/// exactly. A random test that cannot be re-run is a rumour.
void main() {
  const userId = 'user-a';

  /// One envelope, described by the few fields the rules actually read.
  SyncEnvelope envelope({
    required String entityId,
    required String deviceId,
    required int minute,
    required bool isTombstone,
    required String id,
    SyncEntityType entityType = SyncEntityType.appSetting,
  }) => SyncEnvelope(
    id: id,
    deviceId: deviceId,
    entityType: entityType,
    entityId: entityId,
    operation: isTombstone ? SyncOperation.delete : SyncOperation.upsert,
    schemaVersion: 1,
    createdAtUtc: DateTime.utc(2026, 9, 21),
    updatedAtUtc: DateTime.utc(2026, 9, 21, 0, minute),
    idempotencyKey: id,
    payload: isTombstone
        ? const <String, Object?>{}
        : <String, Object?>{'value': '$deviceId@$minute'},
  );

  /// What the account holds for one entity after [order] has been pushed.
  SyncEnvelope? settle(List<SyncEnvelope> order) {
    final backend = FakeSyncBackend(maxSupportedSchemaVersion: 6);
    for (final one in order) {
      backend.push(userId, <SyncEnvelope>[one]);
    }
    final records = backend.recordsOf(userId);
    return records.isEmpty ? null : records.single;
  }

  /// A readable description of a case, so a failure says what it was.
  String describe(List<SyncEnvelope> order) => order
      .map(
        (one) =>
            '${one.deviceId}@${one.updatedAtUtc.minute}'
            '${one.isTombstone ? '-x' : ''}',
      )
      .join(' → ');

  group('the order changes cannot matter', () {
    test('every interleaving of the same changes agrees', () {
      // The property the whole design rests on. If two devices push the same
      // set and the account's answer depends on which arrived first, then the
      // devices disagree and neither is wrong, which is not a rule at all.
      //
      // "Every interleaving" and not "every permutation": a device has one
      // queue, drained in order, so its own envelopes cannot reach the server
      // out of sequence. Asserting over permutations would be demanding that
      // the rules settle a case the system cannot produce — and the first run
      // of this test did exactly that, which is how the same-device tie in
      // `FakeSyncBackend._wins` was found.
      for (var seed = 0; seed < 200; seed += 1) {
        final random = Random(seed);
        final count = 2 + random.nextInt(4);
        final changes = <SyncEnvelope>[
          for (var index = 0; index < count; index += 1)
            envelope(
              entityId: 'theme',
              // Two devices, so ties between them are reachable.
              deviceId: random.nextBool() ? 'device-a' : 'device-b',
              // A small range of minutes, so exact ties happen often enough to
              // exercise the tie-break rather than being a rounding accident.
              minute: random.nextInt(3),
              isTombstone: random.nextInt(4) == 0,
              id: 'envelope-$seed-$index',
            ),
        ];

        final first = settle(changes);
        final interleaved = _interleave(changes, Random(seed + 1));
        final second = settle(interleaved);

        expect(
          _summarise(second),
          _summarise(first),
          reason:
              'seed $seed: ${describe(changes)} settled differently from '
              '${describe(interleaved)}',
        );
      }
    });

    test('and so does every order of a three-device argument', () {
      for (var seed = 0; seed < 100; seed += 1) {
        final random = Random(seed);
        final changes = <SyncEnvelope>[
          for (final device in <String>['device-a', 'device-b', 'device-c'])
            envelope(
              entityId: 'theme',
              deviceId: device,
              minute: random.nextInt(2),
              isTombstone: random.nextBool(),
              id: 'envelope-$seed-$device',
            ),
        ];

        // One envelope per device here, so every permutation is also a valid
        // interleaving and all six can be demanded.
        final orders = <List<SyncEnvelope>>[
          changes,
          changes.reversed.toList(),
          <SyncEnvelope>[changes[1], changes[2], changes[0]],
          <SyncEnvelope>[changes[2], changes[0], changes[1]],
        ];
        final settled = orders.map(settle).map(_summarise).toSet();

        expect(
          settled,
          hasLength(1),
          reason: 'seed $seed: ${describe(changes)} did not converge',
        );
      }
    });
  });

  group('the rule itself', () {
    test('later always beats earlier, whatever else differs', () {
      for (var seed = 0; seed < 200; seed += 1) {
        final random = Random(seed);
        final earlier = envelope(
          entityId: 'theme',
          deviceId: random.nextBool() ? 'device-a' : 'device-z',
          minute: 1,
          isTombstone: random.nextBool(),
          id: 'earlier-$seed',
        );
        final later = envelope(
          entityId: 'theme',
          deviceId: random.nextBool() ? 'device-a' : 'device-z',
          minute: 2,
          isTombstone: random.nextBool(),
          id: 'later-$seed',
        );

        expect(
          settle(<SyncEnvelope>[earlier, later])?.id,
          'later-$seed',
          reason:
              'seed $seed: time is the first question, and a device id must '
              'never answer it',
        );
        expect(settle(<SyncEnvelope>[later, earlier])?.id, 'later-$seed');
      }
    });

    test('an exact tie goes to the withdrawal', () {
      for (var seed = 0; seed < 100; seed += 1) {
        final random = Random(seed);
        final kept = envelope(
          entityId: 'theme',
          deviceId: 'device-${random.nextBool() ? 'a' : 'z'}',
          minute: 1,
          isTombstone: false,
          id: 'kept-$seed',
        );
        final withdrawn = envelope(
          entityId: 'theme',
          deviceId: 'device-${random.nextBool() ? 'a' : 'z'}',
          minute: 1,
          isTombstone: true,
          id: 'withdrawn-$seed',
        );

        for (final order in <List<SyncEnvelope>>[
          <SyncEnvelope>[kept, withdrawn],
          <SyncEnvelope>[withdrawn, kept],
        ]) {
          expect(
            settle(order)?.isTombstone,
            isTrue,
            reason:
                'seed $seed: both sides must converge, and "withdrawn" is the '
                'recoverable answer — History can undo a deletion, while a '
                'resurrection cannot be told from the user entering it again',
          );
        }
      }
    });

    test('a tie between two of a kind is broken the same way each time', () {
      for (var seed = 0; seed < 100; seed += 1) {
        final random = Random(seed);
        final tombstones = random.nextBool();
        final a = envelope(
          entityId: 'theme',
          deviceId: 'device-a',
          minute: 1,
          isTombstone: tombstones,
          id: 'a-$seed',
        );
        final b = envelope(
          entityId: 'theme',
          deviceId: 'device-b',
          minute: 1,
          isTombstone: tombstones,
          id: 'b-$seed',
        );

        expect(
          settle(<SyncEnvelope>[a, b])?.deviceId,
          settle(<SyncEnvelope>[b, a])?.deviceId,
          reason:
              'seed $seed: the tie-break is arbitrary on purpose, and the whole '
              'point is that it is arbitrary consistently',
        );
      }
    });

    test('a stale edit never resurrects a withdrawal', () {
      // The half of the restore fix that must not regress. An *older* upsert
      // arriving after a deletion is a device that had not heard yet, and it
      // must not bring the record back everywhere.
      for (var minute = 0; minute < 20; minute += 1) {
        final withdrawn = envelope(
          entityId: 'theme',
          deviceId: 'device-a',
          minute: 20,
          isTombstone: true,
          id: 'withdrawn-$minute',
        );
        final stale = envelope(
          entityId: 'theme',
          deviceId: 'device-b',
          minute: minute,
          isTombstone: false,
          id: 'stale-$minute',
        );

        expect(
          settle(<SyncEnvelope>[withdrawn, stale])?.isTombstone,
          isTrue,
          reason: 'an edit from before the deletion knows nothing about it',
        );
      }
    });

    test('but a later edit does undo one', () {
      // And the other half. History's undo pushes an upsert, and a server that
      // discarded it would leave every other device believing the record gone
      // while the device that restored it showed it back.
      for (var minute = 21; minute < 40; minute += 1) {
        final withdrawn = envelope(
          entityId: 'theme',
          deviceId: 'device-a',
          minute: 20,
          isTombstone: true,
          id: 'withdrawn-$minute',
        );
        final restored = envelope(
          entityId: 'theme',
          deviceId: 'device-b',
          minute: minute,
          isTombstone: false,
          id: 'restored-$minute',
        );

        expect(
          settle(<SyncEnvelope>[withdrawn, restored])?.isTombstone,
          isFalse,
          reason: 'a restore is an upsert whose whole purpose is to resurrect',
        );
      }
    });
  });

  group('an append-only record is added or withdrawn, never rewritten', () {
    test('a second version of the same fact is refused, not applied', () {
      const appendOnly = <SyncEntityType>[
        SyncEntityType.recitationEvent,
        SyncEntityType.rotationAdjustment,
        SyncEntityType.learningEvent,
        SyncEntityType.recallAttempt,
      ];
      for (final type in appendOnly) {
        final backend = FakeSyncBackend(maxSupportedSchemaVersion: 6);
        final original = envelope(
          entityId: 'fact',
          deviceId: 'device-a',
          minute: 1,
          isTombstone: false,
          id: 'original-${type.name}',
          entityType: type,
        );
        final rewrite = envelope(
          entityId: 'fact',
          deviceId: 'device-b',
          minute: 9,
          isTombstone: false,
          id: 'rewrite-${type.name}',
          entityType: type,
        );

        backend.push(userId, <SyncEnvelope>[original]);
        final result = backend.push(userId, <SyncEnvelope>[rewrite]);

        expect(
          result.rejectedEnvelopeIds,
          <String>['rewrite-${type.name}'],
          reason:
              'two devices can produce different facts about a moment; they '
              'cannot produce two versions of the same one, so an update here '
              'is a symptom and has to surface',
        );
        expect(
          backend.recordsOf(userId).single.id,
          'original-${type.name}',
          reason: 'and history is not overwritten while it surfaces',
        );
      }
    });

    test('withdrawing one is still allowed', () {
      final backend = FakeSyncBackend(maxSupportedSchemaVersion: 6);
      final original = envelope(
        entityId: 'fact',
        deviceId: 'device-a',
        minute: 1,
        isTombstone: false,
        id: 'original',
        entityType: SyncEntityType.recitationEvent,
      );
      final withdrawal = envelope(
        entityId: 'fact',
        deviceId: 'device-a',
        minute: 2,
        isTombstone: true,
        id: 'withdrawal',
        entityType: SyncEntityType.recitationEvent,
      );

      backend.push(userId, <SyncEnvelope>[original]);
      final result = backend.push(userId, <SyncEnvelope>[withdrawal]);

      expect(result.rejectedEnvelopeIds, isEmpty);
      expect(
        backend.recordsOf(userId).single.isTombstone,
        isTrue,
        reason: 'withdrawing a fact is a thing the owner really does',
      );
    });
  });

  test('a version that loses is kept for audit, not discarded', () {
    for (var seed = 0; seed < 50; seed += 1) {
      final random = Random(seed);
      final backend = FakeSyncBackend(maxSupportedSchemaVersion: 6);
      final changes = <SyncEnvelope>[
        for (var index = 0; index < 4; index += 1)
          envelope(
            entityId: 'theme',
            deviceId: random.nextBool() ? 'device-a' : 'device-b',
            minute: random.nextInt(4),
            isTombstone: random.nextInt(4) == 0,
            id: 'envelope-$seed-$index',
          ),
      ];
      for (final one in changes) {
        backend.push(userId, <SyncEnvelope>[one]);
      }

      expect(
        backend.auditLogOf(userId).map((one) => one.id).toSet(),
        changes.map((one) => one.id).toSet(),
        reason:
            'seed $seed: a conflict resolved wrongly is recoverable only while '
            'the loser still exists somewhere',
      );
    }
  });
}

/// A different arrival order that still respects each device's own sequence.
///
/// This is what a network can actually do to a set of pushes: reorder across
/// devices freely, never within one. A plain shuffle would also swap a device's
/// own two edits, which its single queue makes impossible.
List<SyncEnvelope> _interleave(List<SyncEnvelope> changes, Random random) {
  final queues = <String, List<SyncEnvelope>>{};
  for (final one in changes) {
    queues.putIfAbsent(one.deviceId, () => <SyncEnvelope>[]).add(one);
  }
  final pending = queues.values.toList();
  final order = <SyncEnvelope>[];
  while (pending.isNotEmpty) {
    final queue = pending[random.nextInt(pending.length)];
    order.add(queue.removeAt(0));
    pending.removeWhere((one) => one.isEmpty);
  }
  return order;
}

/// The part of a settled record two devices must agree on.
///
/// Compared instead of the whole envelope because the *identity* of the winner
/// is what has to match — its id, its device and whether it is a withdrawal —
/// while the cursor it happened to consume is not part of the answer.
String _summarise(SyncEnvelope? settled) => settled == null
    ? 'nothing'
    : '${settled.id}|${settled.deviceId}|${settled.isTombstone}';
