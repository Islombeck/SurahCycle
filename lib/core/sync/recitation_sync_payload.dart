/// One recitation, in the shape it crosses the boundary in — and back again.
///
/// This is the seam both directions need: a push has to serialise a recitation
/// into an envelope's payload, and a pull has to turn that payload back into
/// the same recitation on another device. Writing them as one pair, in one
/// file, is what keeps them from drifting apart.
///
/// **Nothing is defaulted on the way in.** Every field that makes a recitation
/// what it is must be present and well-formed, or the payload is refused. The
/// temptation is real — a missing `isQada` could "obviously" be false — and it
/// is exactly wrong here: that default would quietly turn someone's make-up
/// prayer into an ordinary one, and a missing `qadaOriginIsUnknown` defaulted
/// to false would claim he named a day he had already said he could not name.
/// A refused payload stalls one entity loudly; a defaulted one rewrites a
/// religious record silently.
///
/// Optional fields are a different case and are treated differently: absent and
/// null mean the same thing for them, because the domain already says so.
library;

import '../domain/domain.dart';
import 'sync_envelope.dart';

/// Raised when a payload cannot be read as a recitation.
final class SyncPayloadException implements Exception {
  const SyncPayloadException(this.reason);

  /// A category and a field name, never a value: this can reach a log, and the
  /// values here are one person's prayer history.
  final String reason;

  @override
  String toString() => 'SyncPayloadException($reason)';
}

abstract final class RecitationSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.recitationEvent;

  /// The envelope for a recitation that was written or changed.
  ///
  /// `createdAtUtc` is the **recitation's** moment, not this envelope's. The
  /// envelope records when the fact happened, and that is when the surah was
  /// recited; stamping it with "now" would make every re-push look like a
  /// fresh prayer. `updatedAtUtc` is when the change being sent happened, and
  /// it is what a later merge compares.
  ///
  /// The caller supplies the identity and the clock — the envelope id, the
  /// device, the idempotency key and the schema version — because none of them
  /// are the recitation's business and all of them must survive a retry
  /// unchanged. A key regenerated per attempt would make every retry look like
  /// a new change to the server's unique index.
  static SyncEnvelope upsert(
    SurahRecitationEvent event, {
    required String envelopeId,
    required String deviceId,
    required String idempotencyKey,
    required int schemaVersion,
    required DateTime updatedAtUtc,
  }) => SyncEnvelope(
    id: envelopeId,
    deviceId: deviceId,
    entityType: entityType,
    entityId: event.id,
    operation: SyncOperation.upsert,
    schemaVersion: schemaVersion,
    createdAtUtc: event.createdAtUtc.toUtc(),
    updatedAtUtc: updatedAtUtc.toUtc(),
    idempotencyKey: idempotencyKey,
    payload: encode(event),
  );

  /// The envelope for a recitation that was withdrawn.
  ///
  /// It carries no payload — there is nothing left to describe, and keeping the
  /// last known values is how a resurrection bug starts. [originalCreatedAtUtc]
  /// is still the recitation's own moment: a tombstone is a statement about
  /// that prayer, so dating it "now" would detach it from the record it
  /// withdraws.
  static SyncEnvelope tombstone({
    required String entityId,
    required String envelopeId,
    required String deviceId,
    required String idempotencyKey,
    required int schemaVersion,
    required DateTime originalCreatedAtUtc,
    required DateTime deletedAtUtc,
  }) => SyncEnvelope(
    id: envelopeId,
    deviceId: deviceId,
    entityType: entityType,
    entityId: entityId,
    operation: SyncOperation.delete,
    schemaVersion: schemaVersion,
    createdAtUtc: originalCreatedAtUtc.toUtc(),
    updatedAtUtc: deletedAtUtc.toUtc(),
    idempotencyKey: idempotencyKey,
  );

  /// The payload an envelope carries for [event].
  ///
  /// `id` is deliberately absent: it is the envelope's `entityId`, and storing
  /// it twice would create two places for the same fact to disagree.
  static Map<String, Object?> encode(SurahRecitationEvent event) =>
      <String, Object?>{
        'surahId': event.surahId,
        'prayerType': event.prayerType.name,
        'isQada': event.isQada,
        'createdAtUtc': event.createdAtUtc.toUtc().toIso8601String(),
        'localDate': event.localDate.toString(),
        'rakaatSpanCount': event.rakaatSpanCount,
        'prayerSessionId': event.prayerSessionId,
        'prayerSessionPartId': event.prayerSessionPartId,
        'slotIndex': event.slotIndex,
        'qadaOriginIsUnknown': event.qadaOriginIsUnknown,
        'qadaFulfilledLocalDate': event.qadaFulfilledLocalDate?.toString(),
        // The coverage is what the rotation balance is rebuilt from, so it
        // travels with the recitation rather than being recomputed on arrival:
        // the receiving device may split that surah differently.
        'rotationSchemeId': event.coverage?.rotationSchemeId,
        'coveredPartIds': event.coverage?.coveredPartIds,
      };

  /// Reads a payload back into a recitation.
  ///
  /// [entityId] comes from the envelope, which is the one place the identity
  /// lives.
  static SurahRecitationEvent decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    final coveredPartIds = _optionalStringList(payload, 'coveredPartIds');
    final rotationSchemeId = _optionalString(payload, 'rotationSchemeId');
    // Both or neither: a coverage with no scheme cannot be placed, and a scheme
    // with no parts covers nothing. Accepting half would build a record whose
    // balance contribution is undefined.
    if ((coveredPartIds == null) != (rotationSchemeId == null)) {
      throw const SyncPayloadException('coverage-is-half-present');
    }
    try {
      return SurahRecitationEvent(
        id: entityId,
        surahId: _requiredString(payload, 'surahId'),
        prayerContext: PrayerContext(
          prayerType: _requiredPrayerType(payload),
          isQada: _requiredBool(payload, 'isQada'),
        ),
        createdAtUtc: _requiredUtc(payload, 'createdAtUtc'),
        localDate: _requiredLocalDate(payload, 'localDate'),
        rakaatSpanCount: _requiredInt(payload, 'rakaatSpanCount'),
        prayerSessionId: _optionalString(payload, 'prayerSessionId'),
        prayerSessionPartId: _optionalString(payload, 'prayerSessionPartId'),
        slotIndex: _optionalInt(payload, 'slotIndex'),
        qadaOriginIsUnknown: _requiredBool(payload, 'qadaOriginIsUnknown'),
        qadaFulfilledLocalDate: _optionalLocalDate(
          payload,
          'qadaFulfilledLocalDate',
        ),
        rotationSchemeId: rotationSchemeId,
        coveredPartIds: coveredPartIds,
      );
    } on ArgumentError {
      // The domain refused the combination — a make-up dated before the day it
      // belongs to, an unknown origin on an ordinary prayer. Those rules are
      // the domain's to enforce and this must not restate them; it only has to
      // refuse rather than let an invalid record through.
      throw const SyncPayloadException('domain-rejected-recitation');
    }
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is String && value.isNotEmpty) return value;
    throw SyncPayloadException('missing-$key');
  }

  static bool _requiredBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) return value;
    throw SyncPayloadException('missing-$key');
  }

  static int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    throw SyncPayloadException('missing-$key');
  }

  static PrayerType _requiredPrayerType(Map<String, Object?> payload) {
    final name = _requiredString(payload, 'prayerType');
    for (final candidate in PrayerType.values) {
      if (candidate.name == name) return candidate;
    }
    // Written by a build that knows a prayer this one does not. Refusing is the
    // honest outcome: guessing which prayer was meant would file a recitation
    // under the wrong one.
    throw const SyncPayloadException('unknown-prayerType');
  }

  static DateTime _requiredUtc(Map<String, Object?> payload, String key) {
    final parsed = DateTime.tryParse(_requiredString(payload, key));
    if (parsed == null) throw SyncPayloadException('malformed-$key');
    return parsed.toUtc();
  }

  static LocalDate _requiredLocalDate(
    Map<String, Object?> payload,
    String key,
  ) {
    final parsed = _parseLocalDate(_requiredString(payload, key));
    if (parsed == null) throw SyncPayloadException('malformed-$key');
    return parsed;
  }

  static String? _optionalString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    throw SyncPayloadException('malformed-$key');
  }

  static int? _optionalInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is int) return value;
    throw SyncPayloadException('malformed-$key');
  }

  static LocalDate? _optionalLocalDate(
    Map<String, Object?> payload,
    String key,
  ) {
    final value = _optionalString(payload, key);
    if (value == null) return null;
    final parsed = _parseLocalDate(value);
    if (parsed == null) throw SyncPayloadException('malformed-$key');
    return parsed;
  }

  static List<String>? _optionalStringList(
    Map<String, Object?> payload,
    String key,
  ) {
    final value = payload[key];
    if (value == null) return null;
    if (value is! List) throw SyncPayloadException('malformed-$key');
    return <String>[
      for (final item in value)
        if (item is String && item.isNotEmpty)
          item
        else
          throw SyncPayloadException('malformed-$key'),
    ];
  }

  /// `YYYY-MM-DD`, and nothing looser.
  ///
  /// `DateTime.tryParse` would happily accept a full timestamp here and quietly
  /// drop its time, which is how a recitation ends up on the wrong local day.
  static LocalDate? _parseLocalDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    try {
      return LocalDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      return null;
    }
  }
}
