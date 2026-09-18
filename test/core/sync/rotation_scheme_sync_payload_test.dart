import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/rotation_scheme_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// A scheme is how the owner chose to split a surah, and the awkward part is
/// what it stores alongside that choice: two journal sequence numbers that mean
/// something only on the device that wrote them.
///
/// Checking rather than assuming paid off. `activated_journal_sequence` is
/// written and never read; `superseded_journal_sequence` is only ever asked
/// whether it is null. So neither number travels — the boolean they stand for
/// does.
void main() {
  RotationSchemeSyncRecord record({
    bool isActive = true,
    List<RotationSchemeSyncPart>? parts,
    DateTime? baselineLastUsedAtUtc,
  }) => RotationSchemeSyncRecord(
    id: 'surah-2:scheme:2',
    surahId: 'surah-2',
    version: 2,
    ayahCountSnapshot: 6,
    baselineScore: 4,
    baselineTotalRecitations: 11,
    baselineLastUsedAtUtc: baselineLastUsedAtUtc,
    resetsRotationBaseline: true,
    isActive: isActive,
    parts:
        parts ??
        <RotationSchemeSyncPart>[
          RotationSchemeSyncPart(
            id: 'surah-2:scheme:2:part:1',
            ordinal: 1,
            startAyah: 1,
            endAyah: 3,
          ),
          RotationSchemeSyncPart(
            id: 'surah-2:scheme:2:part:2',
            ordinal: 2,
            startAyah: 4,
            endAyah: 6,
          ),
        ],
  );

  Matcher refuses(String reason) => throwsA(
    isA<RotationSchemePayloadException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  test('a round trip keeps the split identical', () {
    final original = record(
      baselineLastUsedAtUtc: DateTime.utc(2026, 9, 1, 12),
    );

    final restored = RotationSchemeSyncPayload.decode(
      RotationSchemeSyncPayload.encode(original),
      entityId: original.id,
    );

    expect(restored.id, original.id);
    expect(restored.surahId, 'surah-2');
    expect(restored.version, 2);
    expect(restored.ayahCountSnapshot, 6);
    expect(restored.baselineScore, 4);
    expect(restored.baselineTotalRecitations, 11);
    expect(restored.baselineLastUsedAtUtc, DateTime.utc(2026, 9, 1, 12));
    expect(restored.resetsRotationBaseline, isTrue);
    expect(restored.isActive, isTrue);
    expect(restored.parts, original.parts);
  });

  test('no journal sequence is sent', () {
    final encoded = RotationSchemeSyncPayload.encode(record());

    for (final local in <String>[
      'activatedJournalSequence',
      'supersededJournalSequence',
      'activated_journal_sequence',
      'superseded_journal_sequence',
    ]) {
      expect(
        encoded.containsKey(local),
        isFalse,
        reason:
            'a journal position from another device would place this scheme '
            'among entries that do not exist here',
      );
    }
    expect(
      encoded['isActive'],
      isTrue,
      reason: 'the boolean is what the column was ever asked for',
    );
  });

  test('the baselines do travel, because nothing can recompute them', () {
    final encoded = RotationSchemeSyncPayload.encode(record());

    expect(encoded['baselineScore'], 4);
    expect(encoded['baselineTotalRecitations'], 11);
  });

  test('part ids travel, because coverage names them', () {
    final encoded = RotationSchemeSyncPayload.encode(record());
    final parts = encoded['parts']! as List<Object?>;

    expect(
      (parts.first! as Map<String, Object?>)['id'],
      'surah-2:scheme:2:part:1',
      reason:
          'a recitation names the parts it covered, so ids that differed '
          'between devices would leave every arriving recitation pointing at '
          'nothing',
    );
  });

  test('the cached part statistics stay behind', () {
    final parts =
        RotationSchemeSyncPayload.encode(record())['parts']! as List<Object?>;

    for (final derived in <String>[
      'cachedScore',
      'cachedRecitationCount',
      'cachedLastUsedAtUtc',
      'rotationScore',
      'recitationCount',
    ]) {
      expect(
        (parts.first! as Map<String, Object?>).containsKey(derived),
        isFalse,
        reason: '$derived is rebuilt from the journal',
      );
    }
  });

  test('a superseded scheme says so', () {
    final encoded = RotationSchemeSyncPayload.encode(record(isActive: false));

    expect(
      RotationSchemeSyncPayload.decode(
        encoded,
        entityId: 'surah-2:scheme:2',
      ).isActive,
      isFalse,
    );
  });

  test('a missing field is refused, never defaulted', () {
    for (final key in <String>[
      'surahId',
      'version',
      'ayahCountSnapshot',
      'baselineScore',
      'baselineTotalRecitations',
      'resetsRotationBaseline',
      'isActive',
      'parts',
    ]) {
      final payload = RotationSchemeSyncPayload.encode(record())..remove(key);

      expect(
        () => RotationSchemeSyncPayload.decode(payload, entityId: 'x'),
        refuses('missing-$key'),
      );
    }
  });

  test('a scheme with no parts is refused', () {
    final payload = RotationSchemeSyncPayload.encode(record())
      ..['parts'] = <Object?>[];

    expect(
      () => RotationSchemeSyncPayload.decode(payload, entityId: 'x'),
      refuses('domain-rejected-scheme'),
      reason: 'a split that covers nothing is not a split',
    );
  });

  test('a part running past the surah is refused', () {
    final payload = RotationSchemeSyncPayload.encode(
      record(
        parts: <RotationSchemeSyncPart>[
          RotationSchemeSyncPart(
            id: 'p1',
            ordinal: 1,
            startAyah: 1,
            endAyah: 6,
          ),
        ],
      ),
    )..['ayahCountSnapshot'] = 3;

    expect(
      () => RotationSchemeSyncPayload.decode(payload, entityId: 'x'),
      refuses('domain-rejected-scheme'),
    );
  });

  test('duplicate part ids are refused', () {
    expect(
      () => record(
        parts: <RotationSchemeSyncPart>[
          RotationSchemeSyncPart(
            id: 'same',
            ordinal: 1,
            startAyah: 1,
            endAyah: 3,
          ),
          RotationSchemeSyncPart(
            id: 'same',
            ordinal: 2,
            startAyah: 4,
            endAyah: 6,
          ),
        ],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('it survives the JSON the transport sends', () {
    final envelope = RotationSchemeSyncPayload.upsert(
      record(),
      envelopeId: 'envelope-1',
      deviceId: 'device-1',
      idempotencyKey: 'key-1',
      schemaVersion: 10,
      updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
    );

    final restored = SyncEnvelope.fromJson(
      jsonDecode(jsonEncode(envelope.toJson()))! as Map<String, Object?>,
    );

    expect(restored, envelope);
    expect(restored.entityKey, 'rotationScheme:surah-2:scheme:2');
    expect(
      RotationSchemeSyncPayload.decode(
        restored.payload,
        entityId: restored.entityId,
      ).parts,
      hasLength(2),
    );
  });
}
