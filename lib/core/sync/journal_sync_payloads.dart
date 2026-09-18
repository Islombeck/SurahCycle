/// Two append-only journals, in the shape they cross the boundary in.
///
/// A rotation adjustment is the owner correcting a surah's standing by hand; a
/// recall attempt is a record of whether he remembered a passage. Both are
/// facts about a moment, both are written once and never edited, and both carry
/// a local sequence number that stays behind for the reason the recitation
/// applier established: two devices number their journals independently.
///
/// They share a file because they share a shape. Splitting them would duplicate
/// the same six parsing helpers twice over for no gain in clarity.
library;

import 'sync_envelope.dart';

/// Raised when a journal payload cannot be read.
final class JournalPayloadException implements Exception {
  const JournalPayloadException(this.reason);

  /// A category and a field name, never a value.
  final String reason;

  @override
  String toString() => 'JournalPayloadException($reason)';
}

/// One hand-made correction to a surah's rotation standing.
final class RotationAdjustmentSyncRecord {
  factory RotationAdjustmentSyncRecord({
    required String id,
    required String surahId,
    required String rotationSchemeId,
    required int delta,
    required String reason,
    required DateTime createdAtUtc,
    DateTime? deletedAtUtc,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (surahId.isEmpty) throw ArgumentError.value(surahId, 'surahId');
    if (rotationSchemeId.isEmpty) {
      throw ArgumentError.value(rotationSchemeId, 'rotationSchemeId');
    }
    // Zero would be a correction that corrects nothing, and the table refuses
    // it too.
    if (delta == 0) throw ArgumentError.value(delta, 'delta');
    if (reason.isEmpty) throw ArgumentError.value(reason, 'reason');
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
    if (deletedAtUtc != null && !deletedAtUtc.isUtc) {
      throw ArgumentError.value(deletedAtUtc, 'deletedAtUtc');
    }
    return RotationAdjustmentSyncRecord._(
      id: id,
      surahId: surahId,
      rotationSchemeId: rotationSchemeId,
      delta: delta,
      reason: reason,
      createdAtUtc: createdAtUtc,
      deletedAtUtc: deletedAtUtc,
    );
  }

  const RotationAdjustmentSyncRecord._({
    required this.id,
    required this.surahId,
    required this.rotationSchemeId,
    required this.delta,
    required this.reason,
    required this.createdAtUtc,
    required this.deletedAtUtc,
  });

  final String id;
  final String surahId;
  final String rotationSchemeId;
  final int delta;

  /// The owner's own words for why. Carried verbatim: it is his note, not a
  /// category this app gets to normalise.
  final String reason;
  final DateTime createdAtUtc;
  final DateTime? deletedAtUtc;
}

/// One record of whether a passage was remembered.
final class RecallAttemptSyncRecord {
  factory RecallAttemptSyncRecord({
    required String id,
    required String surahId,
    required int ayahStart,
    required int ayahEnd,
    required int learningCycle,
    required String result,
    required DateTime createdAtUtc,
    required String localDate,
    required String source,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (surahId.isEmpty) throw ArgumentError.value(surahId, 'surahId');
    if (ayahStart < 1) throw ArgumentError.value(ayahStart, 'ayahStart');
    if (ayahEnd < ayahStart) throw ArgumentError.value(ayahEnd, 'ayahEnd');
    if (learningCycle < 1) {
      throw ArgumentError.value(learningCycle, 'learningCycle');
    }
    if (!results.contains(result)) {
      throw ArgumentError.value(result, 'result');
    }
    if (!sources.contains(source)) {
      throw ArgumentError.value(source, 'source');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
    return RecallAttemptSyncRecord._(
      id: id,
      surahId: surahId,
      ayahStart: ayahStart,
      ayahEnd: ayahEnd,
      learningCycle: learningCycle,
      result: result,
      createdAtUtc: createdAtUtc,
      localDate: localDate,
      source: source,
    );
  }

  const RecallAttemptSyncRecord._({
    required this.id,
    required this.surahId,
    required this.ayahStart,
    required this.ayahEnd,
    required this.learningCycle,
    required this.result,
    required this.createdAtUtc,
    required this.localDate,
    required this.source,
  });

  /// The three the table's CHECK allows. A fourth would be a claim about the
  /// owner's memory that this build cannot represent.
  static const Set<String> results = <String>{
    'recalled',
    'recalledWithMistake',
    'notRecalled',
  };
  static const Set<String> sources = <String>{'learning', 'surah'};

  final String id;
  final String surahId;
  final int ayahStart;
  final int ayahEnd;
  final int learningCycle;
  final String result;
  final DateTime createdAtUtc;
  final String localDate;
  final String source;
}

abstract final class RotationAdjustmentSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.rotationAdjustment;

  static Map<String, Object?> encode(RotationAdjustmentSyncRecord record) =>
      <String, Object?>{
        'surahId': record.surahId,
        'rotationSchemeId': record.rotationSchemeId,
        'delta': record.delta,
        'reason': record.reason,
        'createdAtUtc': record.createdAtUtc.toUtc().toIso8601String(),
      };

  static RotationAdjustmentSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    try {
      return RotationAdjustmentSyncRecord(
        id: entityId,
        surahId: _requiredString(payload, 'surahId'),
        rotationSchemeId: _requiredString(payload, 'rotationSchemeId'),
        delta: _requiredInt(payload, 'delta'),
        reason: _requiredString(payload, 'reason'),
        createdAtUtc: _requiredUtc(payload, 'createdAtUtc'),
      );
    } on ArgumentError {
      throw const JournalPayloadException('domain-rejected-adjustment');
    }
  }

  static SyncEnvelope upsert(
    RotationAdjustmentSyncRecord record, {
    required String envelopeId,
    required String deviceId,
    required String idempotencyKey,
    required int schemaVersion,
    required DateTime updatedAtUtc,
  }) => SyncEnvelope(
    id: envelopeId,
    deviceId: deviceId,
    entityType: entityType,
    entityId: record.id,
    operation: SyncOperation.upsert,
    schemaVersion: schemaVersion,
    createdAtUtc: record.createdAtUtc.toUtc(),
    updatedAtUtc: updatedAtUtc.toUtc(),
    idempotencyKey: idempotencyKey,
    payload: encode(record),
  );

  /// A withdrawn adjustment. Like a recitation's, it keeps the original moment:
  /// the tombstone is a statement about that correction.
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
}

abstract final class RecallAttemptSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.recallAttempt;

  static Map<String, Object?> encode(RecallAttemptSyncRecord record) =>
      <String, Object?>{
        'surahId': record.surahId,
        'ayahStart': record.ayahStart,
        'ayahEnd': record.ayahEnd,
        'learningCycle': record.learningCycle,
        'result': record.result,
        'createdAtUtc': record.createdAtUtc.toUtc().toIso8601String(),
        'localDate': record.localDate,
        'source': record.source,
      };

  static RecallAttemptSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    try {
      return RecallAttemptSyncRecord(
        id: entityId,
        surahId: _requiredString(payload, 'surahId'),
        ayahStart: _requiredInt(payload, 'ayahStart'),
        ayahEnd: _requiredInt(payload, 'ayahEnd'),
        learningCycle: _requiredInt(payload, 'learningCycle'),
        // No default. A missing result would have to become one of three
        // statements about whether the owner remembered a passage, and this
        // app does not get to decide that on his behalf.
        result: _requiredString(payload, 'result'),
        createdAtUtc: _requiredUtc(payload, 'createdAtUtc'),
        localDate: _requiredLocalDate(payload, 'localDate'),
        source: _requiredString(payload, 'source'),
      );
    } on ArgumentError {
      throw const JournalPayloadException('domain-rejected-recall-attempt');
    }
  }

  static SyncEnvelope upsert(
    RecallAttemptSyncRecord record, {
    required String envelopeId,
    required String deviceId,
    required String idempotencyKey,
    required int schemaVersion,
    required DateTime updatedAtUtc,
  }) => SyncEnvelope(
    id: envelopeId,
    deviceId: deviceId,
    entityType: entityType,
    entityId: record.id,
    operation: SyncOperation.upsert,
    schemaVersion: schemaVersion,
    createdAtUtc: record.createdAtUtc.toUtc(),
    updatedAtUtc: updatedAtUtc.toUtc(),
    idempotencyKey: idempotencyKey,
    payload: encode(record),
  );
}

String _requiredString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is String && value.isNotEmpty) return value;
  throw JournalPayloadException('missing-$key');
}

int _requiredInt(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is int) return value;
  throw JournalPayloadException('missing-$key');
}

DateTime _requiredUtc(Map<String, Object?> payload, String key) {
  final parsed = DateTime.tryParse(_requiredString(payload, key));
  if (parsed == null) throw JournalPayloadException('malformed-$key');
  return parsed.toUtc();
}

/// `YYYY-MM-DD`, and nothing looser — the same rule a recitation's local date
/// follows, and for the same reason: a full timestamp quietly truncated is how
/// a record lands on the wrong local day.
String _requiredLocalDate(Map<String, Object?> payload, String key) {
  final value = _requiredString(payload, key);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw JournalPayloadException('malformed-$key');
  }
  return value;
}
