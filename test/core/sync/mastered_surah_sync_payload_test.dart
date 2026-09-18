import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/mastered_surah_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The roster is the prerequisite for everything else — a recitation cannot be
/// written on a device whose roster does not hold its surah — so what travels
/// here has to be exactly the owner's intent and nothing derived from it.
void main() {
  MasteredSurahSyncRecord record({
    bool isCurrentlyMastered = true,
    bool isActive = true,
    bool hasEnteredRotation = true,
    int? activationBaselineScore = 3,
    String? alias = 'Моя сура',
    int displayOrder = 2,
  }) => MasteredSurahSyncRecord(
    surahId: 'surah-112',
    isCurrentlyMastered: isCurrentlyMastered,
    isActive: isActive,
    hasEnteredRotation: hasEnteredRotation,
    activationBaselineScore: activationBaselineScore,
    alias: alias,
    displayOrder: displayOrder,
  );

  Matcher refuses(String reason) => throwsA(
    isA<MasteredSurahPayloadException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  test('a round trip keeps the entry identical', () {
    final original = record();

    final restored = MasteredSurahSyncPayload.decode(
      MasteredSurahSyncPayload.encode(original),
      entityId: 'surah-112',
    );

    expect(restored, original);
  });

  test('the cached statistics never leave the device', () {
    final encoded = MasteredSurahSyncPayload.encode(record());

    for (final derived in <String>[
      'cachedRotationScore',
      'cachedTotalRecitations',
      'cachedLastUsedAtUtc',
      'rotationScore',
      'totalRecitations',
      'lastUsedAtUtc',
    ]) {
      expect(
        encoded.containsKey(derived),
        isFalse,
        reason:
            '$derived is rebuilt from the journal; sending it would create a '
            'second source of truth that disagrees the moment one device has '
            'applied a recitation the other has not',
      );
    }
  });

  test('the alias travels, because it is the owner\'s own word', () {
    final encoded = MasteredSurahSyncPayload.encode(record(alias: 'Ихлас'));

    expect(encoded['alias'], 'Ихлас');
    expect(
      MasteredSurahSyncPayload.decode(encoded, entityId: 'surah-112').alias,
      'Ихлас',
    );
  });

  test('an absent alias stays absent rather than becoming a name', () {
    final encoded = MasteredSurahSyncPayload.encode(record(alias: null));

    expect(
      MasteredSurahSyncPayload.decode(encoded, entityId: 'surah-112').alias,
      isNull,
    );
  });

  test('a missing flag is refused, never defaulted', () {
    for (final key in <String>[
      'isCurrentlyMastered',
      'isActive',
      'hasEnteredRotation',
      'displayOrder',
    ]) {
      final payload = MasteredSurahSyncPayload.encode(record())..remove(key);

      expect(
        () => MasteredSurahSyncPayload.decode(payload, entityId: 'surah-112'),
        refuses('missing-$key'),
        reason:
            'a missing isActive read as false would silently drop a surah out '
            "of the owner's rotation on the receiving device",
      );
    }
  });

  test('a combination the table forbids is refused here', () {
    // Active without having entered the rotation. The database would refuse it
    // too, several layers down and without a reason anyone can read.
    final payload = MasteredSurahSyncPayload.encode(record())
      ..['hasEnteredRotation'] = false;

    expect(
      () => MasteredSurahSyncPayload.decode(payload, entityId: 'surah-112'),
      refuses('domain-rejected-roster-entry'),
    );
  });

  test('the id comes from the envelope', () {
    final encoded = MasteredSurahSyncPayload.encode(record());

    expect(encoded.containsKey('surahId'), isFalse);
    expect(
      MasteredSurahSyncPayload.decode(encoded, entityId: 'surah-108').surahId,
      'surah-108',
    );
  });

  test('the envelope carries no invented creation moment', () {
    final envelope = MasteredSurahSyncPayload.upsert(
      record(),
      envelopeId: 'envelope-1',
      deviceId: 'device-1',
      idempotencyKey: 'key-1',
      schemaVersion: 10,
      updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
    );

    expect(envelope.entityKey, 'masteredSurah:surah-112');
    expect(
      envelope.createdAtUtc,
      envelope.updatedAtUtc,
      reason:
          'a roster entry has no moment of its own the way a prayer does, so '
          'there is nothing to date it by but the change itself',
    );
    expect(envelope.isTombstone, isFalse);
  });

  test('it survives the JSON the transport sends', () {
    final envelope = MasteredSurahSyncPayload.upsert(
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
    expect(
      MasteredSurahSyncPayload.decode(
        restored.payload,
        entityId: restored.entityId,
      ),
      record(),
    );
  });
}
