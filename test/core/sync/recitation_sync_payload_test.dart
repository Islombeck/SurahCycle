import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/recitation_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// A recitation that survives a round trip intact is the least this has to do.
/// What the rest of these tests are about is the other direction: what happens
/// when the payload is wrong.
///
/// The answer has to be *refusal*, never a default. A missing `isQada` looks
/// like it could obviously be false, and that default would quietly turn
/// someone's make-up prayer into an ordinary one on the receiving device. One
/// stalled entity is a problem somebody notices; a silently rewritten
/// religious record is not.
void main() {
  SurahRecitationEvent event({
    bool isQada = false,
    bool qadaOriginIsUnknown = false,
    LocalDate? qadaFulfilledLocalDate,
    String? rotationSchemeId = 'scheme-1',
    List<String>? coveredPartIds = const <String>['part-1', 'part-2'],
  }) => SurahRecitationEvent(
    id: 'event-1',
    surahId: 'surah-112',
    prayerContext: PrayerContext(prayerType: PrayerType.asr, isQada: isQada),
    createdAtUtc: DateTime.utc(2026, 9, 17, 16, 58, 11),
    localDate: LocalDate(2026, 9, 17),
    rakaatSpanCount: 2,
    prayerSessionId: 'session-1',
    prayerSessionPartId: 'part-fard',
    slotIndex: 1,
    qadaOriginIsUnknown: qadaOriginIsUnknown,
    qadaFulfilledLocalDate: qadaFulfilledLocalDate,
    rotationSchemeId: rotationSchemeId,
    coveredPartIds: coveredPartIds,
  );

  Map<String, Object?> encoded(SurahRecitationEvent source) =>
      RecitationSyncPayload.encode(source);

  Matcher refuses(String reason) => throwsA(
    isA<SyncPayloadException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  group('a round trip keeps the record identical', () {
    test('an ordinary recitation survives unchanged', () {
      final original = event();

      final restored = RecitationSyncPayload.decode(
        encoded(original),
        entityId: original.id,
      );

      expect(restored.id, original.id);
      expect(restored.surahId, original.surahId);
      expect(restored.prayerType, PrayerType.asr);
      expect(restored.isQada, isFalse);
      expect(restored.createdAtUtc, original.createdAtUtc);
      expect(restored.localDate, original.localDate);
      expect(restored.rakaatSpanCount, 2);
      expect(restored.prayerSessionId, 'session-1');
      expect(restored.prayerSessionPartId, 'part-fard');
      expect(restored.slotIndex, 1);
      expect(restored.coverage?.rotationSchemeId, 'scheme-1');
      expect(restored.coverage?.coveredPartIds, <String>['part-1', 'part-2']);
    });

    test('a Qada with an unknown origin keeps both facts', () {
      final original = event(isQada: true, qadaOriginIsUnknown: true);

      final restored = RecitationSyncPayload.decode(
        encoded(original),
        entityId: original.id,
      );

      expect(restored.isQada, isTrue);
      expect(
        restored.qadaOriginIsUnknown,
        isTrue,
        reason:
            'losing this would claim the user named a day he had already said '
            'he could not name',
      );
    });

    test('a make-up keeps the day it belongs to and the day it was prayed', () {
      final original = event(
        isQada: true,
        qadaFulfilledLocalDate: LocalDate(2026, 9, 18),
      );

      final restored = RecitationSyncPayload.decode(
        encoded(original),
        entityId: original.id,
      );

      expect(restored.localDate, LocalDate(2026, 9, 17));
      expect(restored.qadaFulfilledLocalDate, LocalDate(2026, 9, 18));
    });

    test('the payload is JSON, not merely map-shaped', () {
      // The envelope is encoded to a string before it reaches the server, so a
      // value JSON cannot carry would fail there rather than here.
      final round = jsonDecode(jsonEncode(encoded(event())));

      expect(round, isA<Map<String, Object?>>());
      expect(
        RecitationSyncPayload.decode(
          round! as Map<String, Object?>,
          entityId: 'event-1',
        ).surahId,
        'surah-112',
      );
    });

    test('the id is carried by the envelope, not duplicated', () {
      expect(
        encoded(event()).containsKey('id'),
        isFalse,
        reason: 'two places for one fact is two places for it to disagree',
      );

      final restored = RecitationSyncPayload.decode(
        encoded(event()),
        entityId: 'a-different-id',
      );
      expect(restored.id, 'a-different-id');
    });
  });

  group('a wrong payload is refused, never defaulted', () {
    test('a missing required field names itself', () {
      for (final key in <String>[
        'surahId',
        'prayerType',
        'isQada',
        'createdAtUtc',
        'localDate',
        'rakaatSpanCount',
        'qadaOriginIsUnknown',
      ]) {
        final payload = encoded(event())..remove(key);

        expect(
          () => RecitationSyncPayload.decode(payload, entityId: 'event-1'),
          refuses('missing-$key'),
          reason: '$key has no safe default',
        );
      }
    });

    test('a prayer this build does not know is refused', () {
      final payload = encoded(event())..['prayerType'] = 'tahajjud';

      expect(
        () => RecitationSyncPayload.decode(payload, entityId: 'event-1'),
        refuses('unknown-prayerType'),
        reason: 'guessing would file the recitation under the wrong prayer',
      );
    });

    test('a local date with a time in it is refused, not truncated', () {
      final payload = encoded(event())
        ..['localDate'] = '2026-09-17T23:30:00.000Z';

      expect(
        () => RecitationSyncPayload.decode(payload, entityId: 'event-1'),
        refuses('malformed-localDate'),
        reason:
            'quietly dropping the time is how a recitation lands on the wrong '
            'local day, which is the one thing a local date exists to fix',
      );
    });

    test('half a coverage is refused', () {
      final withoutScheme = encoded(event())..remove('rotationSchemeId');
      final withoutParts = encoded(event())..remove('coveredPartIds');

      for (final payload in <Map<String, Object?>>[
        withoutScheme,
        withoutParts,
      ]) {
        expect(
          () => RecitationSyncPayload.decode(payload, entityId: 'event-1'),
          refuses('coverage-is-half-present'),
          reason:
              'a scheme with no parts covers nothing, and parts with no '
              'scheme cannot be placed',
        );
      }
    });

    test('a combination the domain forbids is refused here too', () {
      // A make-up dated before the day it belongs to. The rule lives in the
      // domain and is not restated here; this only proves an invalid record
      // cannot slip through by arriving over the wire.
      final payload = encoded(event(isQada: true))
        ..['qadaFulfilledLocalDate'] = '2026-09-01';

      expect(
        () => RecitationSyncPayload.decode(payload, entityId: 'event-1'),
        refuses('domain-rejected-recitation'),
      );
    });

    test('an optional field of the wrong type is refused', () {
      final payload = encoded(event())..['slotIndex'] = 'first';

      expect(
        () => RecitationSyncPayload.decode(payload, entityId: 'event-1'),
        refuses('malformed-slotIndex'),
      );
    });

    test('an absent optional field is simply absent', () {
      final payload = encoded(event())
        ..remove('slotIndex')
        ..remove('prayerSessionId')
        ..remove('prayerSessionPartId')
        ..remove('qadaFulfilledLocalDate');

      final restored = RecitationSyncPayload.decode(
        payload,
        entityId: 'event-1',
      );

      expect(restored.slotIndex, isNull);
      expect(restored.prayerSessionId, isNull);
      expect(
        restored.qadaFulfilledLocalDate,
        isNull,
        reason:
            'the domain already says absent and null mean the same thing for '
            'these, so refusing them would reject a legitimate record',
      );
    });
  });

  group('the envelope around it', () {
    test('it is dated by the prayer, not by the push', () {
      final envelope = RecitationSyncPayload.upsert(
        event(),
        envelopeId: 'envelope-1',
        deviceId: 'device-1',
        idempotencyKey: 'key-1',
        schemaVersion: 10,
        updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
      );

      expect(
        envelope.createdAtUtc,
        DateTime.utc(2026, 9, 17, 16, 58, 11),
        reason:
            'the envelope records when the fact happened, and that is when the '
            'surah was recited — stamping "now" would make every re-push look '
            'like a fresh prayer',
      );
      expect(envelope.updatedAtUtc, DateTime.utc(2026, 9, 18, 9));
      expect(envelope.entityId, 'event-1');
      expect(envelope.entityKey, 'recitationEvent:event-1');
      expect(envelope.isTombstone, isFalse);
    });

    test('a withdrawal carries no payload but keeps its prayer', () {
      final envelope = RecitationSyncPayload.tombstone(
        entityId: 'event-1',
        envelopeId: 'envelope-2',
        deviceId: 'device-1',
        idempotencyKey: 'key-2',
        schemaVersion: 10,
        originalCreatedAtUtc: DateTime.utc(2026, 9, 17, 16, 58, 11),
        deletedAtUtc: DateTime.utc(2026, 9, 17, 17),
      );

      expect(envelope.isTombstone, isTrue);
      expect(
        envelope.payload,
        isEmpty,
        reason: 'keeping the last known values is how resurrection starts',
      );
      expect(
        envelope.createdAtUtc,
        DateTime.utc(2026, 9, 17, 16, 58, 11),
        reason:
            'a tombstone is a statement about that prayer, so dating it "now" '
            'would detach it from the record it withdraws',
      );
      expect(envelope.updatedAtUtc, DateTime.utc(2026, 9, 17, 17));
    });

    test('an envelope survives the JSON the transport sends', () {
      final original = RecitationSyncPayload.upsert(
        event(isQada: true, qadaOriginIsUnknown: true),
        envelopeId: 'envelope-3',
        deviceId: 'device-1',
        idempotencyKey: 'key-3',
        schemaVersion: 10,
        updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
      );

      final restored = SyncEnvelope.fromJson(
        jsonDecode(jsonEncode(original.toJson()))! as Map<String, Object?>,
      );

      expect(restored, original);
      expect(
        RecitationSyncPayload.decode(
          restored.payload,
          entityId: restored.entityId,
        ).qadaOriginIsUnknown,
        isTrue,
      );
    });
  });

  test('no refusal reason carries a value from the payload', () {
    final payload = encoded(event())..['surahId'] = '';

    try {
      RecitationSyncPayload.decode(payload, entityId: 'event-1');
      fail('expected a refusal');
    } on SyncPayloadException catch (thrown) {
      expect(RegExp(r'^[a-zA-Z-]+$').hasMatch(thrown.reason), isTrue);
      expect(thrown.reason, isNot(contains('surah-112')));
    }
  });
}
