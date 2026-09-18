/// The learning plan for one surah, and the journal of how it moved.
///
/// A plan is where the owner has got to in memorising a surah: which ayahs he
/// is working through, which stage he is in, which cycle. An event is one step
/// of that plan, recorded with the state it moved *from* and *to* — so the
/// journal can be replayed and a rollback knows what to return to.
///
/// **A plan's shape is checked here rather than left to the database.** The
/// table holds nine interlocking CHECKs — a chunked plan must have a block
/// size, a classic one must not, the stage must sit inside the target, the
/// target inside the surah — and a payload that violated one would otherwise
/// arrive as a constraint failure naming a column, several layers below anyone
/// who could act on it.
///
/// **`lastLearningActivityAtUtc` travels.** It is not derived: nothing else
/// records when the owner last worked on a plan, and the inactivity rollback
/// reads it. Its companion `inactivityRollbackForActivityAtUtc` travels for the
/// same reason — it is the guard that stops one inactivity rollback firing
/// twice for the same idle stretch, and losing it would roll a plan back again
/// on the second device.
library;

import 'sync_envelope.dart';

/// Raised when a learning payload cannot be read.
final class LearningPayloadException implements Exception {
  const LearningPayloadException(this.reason);

  /// A category and a field name, never a value.
  final String reason;

  @override
  String toString() => 'LearningPayloadException($reason)';
}

/// The vocabularies the two tables share, restated so a payload is refused
/// with a reason rather than as a constraint failure.
abstract final class LearningVocabulary {
  static const Set<String> planKinds = <String>{'classicCumulative', 'chunked'};
  static const Set<String> stageKinds = <String>{
    'newAyah',
    'cumulative',
    'reviewRange',
    'bridge',
    'sectionReview',
    'finalReview',
  };
  static const Set<String> statuses = <String>{'active', 'completed'};

  /// What a learning event can be. Missing this list was caught by a test: an
  /// unknown type arrived as `CHECK constraint failed: type IN (...)`, which is
  /// precisely the kind of unreadable failure this file exists to replace.
  static const Set<String> eventTypes = <String>{
    'repeated',
    'learned',
    'inactivityRollback',
    'completed',
    'restarted',
    'planChanged',
  };
}

/// One plan position: which stage, inside which target, under which plan kind.
final class LearningPlanPosition {
  factory LearningPlanPosition({
    required String planKind,
    required int targetStartAyah,
    required int targetEndAyah,
    int? blockSize,
    required String stageKind,
    required int stageStartAyah,
    required int stageEndAyah,
  }) {
    if (!LearningVocabulary.planKinds.contains(planKind)) {
      throw ArgumentError.value(planKind, 'planKind');
    }
    if (!LearningVocabulary.stageKinds.contains(stageKind)) {
      throw ArgumentError.value(stageKind, 'stageKind');
    }
    // A chunked plan is defined by its block size and a classic one has none.
    // Both halves matter: the table refuses either mismatch.
    if (planKind == 'chunked' && blockSize == null) {
      throw ArgumentError.value(blockSize, 'blockSize');
    }
    if (planKind == 'classicCumulative' && blockSize != null) {
      throw ArgumentError.value(blockSize, 'blockSize');
    }
    if (blockSize != null && blockSize < 1) {
      throw ArgumentError.value(blockSize, 'blockSize');
    }
    if (targetStartAyah < 1 || targetEndAyah < targetStartAyah) {
      throw ArgumentError.value(targetEndAyah, 'targetEndAyah');
    }
    if (stageStartAyah < targetStartAyah ||
        stageEndAyah < stageStartAyah ||
        stageEndAyah > targetEndAyah) {
      throw ArgumentError.value(stageEndAyah, 'stageEndAyah');
    }
    return LearningPlanPosition._(
      planKind: planKind,
      targetStartAyah: targetStartAyah,
      targetEndAyah: targetEndAyah,
      blockSize: blockSize,
      stageKind: stageKind,
      stageStartAyah: stageStartAyah,
      stageEndAyah: stageEndAyah,
    );
  }

  const LearningPlanPosition._({
    required this.planKind,
    required this.targetStartAyah,
    required this.targetEndAyah,
    required this.blockSize,
    required this.stageKind,
    required this.stageStartAyah,
    required this.stageEndAyah,
  });

  final String planKind;
  final int targetStartAyah;
  final int targetEndAyah;
  final int? blockSize;
  final String stageKind;
  final int stageStartAyah;
  final int stageEndAyah;

  Map<String, Object?> toJson(String prefix) => <String, Object?>{
    '${prefix}PlanKind': planKind,
    '${prefix}TargetStartAyah': targetStartAyah,
    '${prefix}TargetEndAyah': targetEndAyah,
    '${prefix}BlockSize': blockSize,
    '${prefix}StageKind': stageKind,
    '${prefix}StageStartAyah': stageStartAyah,
    '${prefix}StageEndAyah': stageEndAyah,
  };

  static LearningPlanPosition fromJson(
    Map<String, Object?> payload,
    String prefix,
  ) => LearningPlanPosition(
    planKind: _requiredString(payload, '${prefix}PlanKind'),
    targetStartAyah: _requiredInt(payload, '${prefix}TargetStartAyah'),
    targetEndAyah: _requiredInt(payload, '${prefix}TargetEndAyah'),
    blockSize: _optionalInt(payload, '${prefix}BlockSize'),
    stageKind: _requiredString(payload, '${prefix}StageKind'),
    stageStartAyah: _requiredInt(payload, '${prefix}StageStartAyah'),
    stageEndAyah: _requiredInt(payload, '${prefix}StageEndAyah'),
  );
}

/// Where the owner has got to in memorising one surah.
final class LearningStateSyncRecord {
  factory LearningStateSyncRecord({
    required String id,
    required String surahId,
    required int ayahCount,
    required LearningPlanPosition position,
    required int learningCycle,
    required String status,
    DateTime? lastLearningActivityAtUtc,
    DateTime? inactivityRollbackForActivityAtUtc,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (surahId.isEmpty) throw ArgumentError.value(surahId, 'surahId');
    if (ayahCount < 1) throw ArgumentError.value(ayahCount, 'ayahCount');
    if (position.targetEndAyah > ayahCount) {
      throw ArgumentError.value(position.targetEndAyah, 'targetEndAyah');
    }
    if (learningCycle < 1) {
      throw ArgumentError.value(learningCycle, 'learningCycle');
    }
    if (!LearningVocabulary.statuses.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    if (lastLearningActivityAtUtc != null && !lastLearningActivityAtUtc.isUtc) {
      throw ArgumentError.value(lastLearningActivityAtUtc);
    }
    if (inactivityRollbackForActivityAtUtc != null &&
        !inactivityRollbackForActivityAtUtc.isUtc) {
      throw ArgumentError.value(inactivityRollbackForActivityAtUtc);
    }
    return LearningStateSyncRecord._(
      id: id,
      surahId: surahId,
      ayahCount: ayahCount,
      position: position,
      learningCycle: learningCycle,
      status: status,
      lastLearningActivityAtUtc: lastLearningActivityAtUtc,
      inactivityRollbackForActivityAtUtc: inactivityRollbackForActivityAtUtc,
    );
  }

  const LearningStateSyncRecord._({
    required this.id,
    required this.surahId,
    required this.ayahCount,
    required this.position,
    required this.learningCycle,
    required this.status,
    required this.lastLearningActivityAtUtc,
    required this.inactivityRollbackForActivityAtUtc,
  });

  final String id;
  final String surahId;
  final int ayahCount;
  final LearningPlanPosition position;
  final int learningCycle;
  final String status;

  /// When the owner last worked on this plan. Nothing else records it, and the
  /// inactivity rollback reads it.
  final DateTime? lastLearningActivityAtUtc;

  /// The activity stamp an inactivity rollback has already fired for. Without
  /// it the second device would roll the same idle stretch back again.
  final DateTime? inactivityRollbackForActivityAtUtc;
}

/// One step of a plan, carrying where it moved from and to.
final class LearningEventSyncRecord {
  factory LearningEventSyncRecord({
    required String id,
    required String learningSurahId,
    required String type,
    required DateTime createdAtUtc,
    required int learningCycle,
    required LearningPlanPosition from,
    required LearningPlanPosition to,
    String? reason,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (learningSurahId.isEmpty) {
      throw ArgumentError.value(learningSurahId, 'learningSurahId');
    }
    if (!LearningVocabulary.eventTypes.contains(type)) {
      throw ArgumentError.value(type, 'type');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
    if (learningCycle < 1) {
      throw ArgumentError.value(learningCycle, 'learningCycle');
    }
    if (reason != null && reason.isEmpty) {
      throw ArgumentError.value(reason, 'reason');
    }
    return LearningEventSyncRecord._(
      id: id,
      learningSurahId: learningSurahId,
      type: type,
      createdAtUtc: createdAtUtc,
      learningCycle: learningCycle,
      from: from,
      to: to,
      reason: reason,
    );
  }

  const LearningEventSyncRecord._({
    required this.id,
    required this.learningSurahId,
    required this.type,
    required this.createdAtUtc,
    required this.learningCycle,
    required this.from,
    required this.to,
    required this.reason,
  });

  final String id;
  final String learningSurahId;
  final String type;
  final DateTime createdAtUtc;
  final int learningCycle;
  final LearningPlanPosition from;
  final LearningPlanPosition to;
  final String? reason;
}

abstract final class LearningStateSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.learningState;

  static Map<String, Object?> encode(LearningStateSyncRecord record) =>
      <String, Object?>{
        'surahId': record.surahId,
        'ayahCount': record.ayahCount,
        'learningCycle': record.learningCycle,
        'status': record.status,
        'lastLearningActivityAtUtc': record.lastLearningActivityAtUtc
            ?.toUtc()
            .toIso8601String(),
        'inactivityRollbackForActivityAtUtc': record
            .inactivityRollbackForActivityAtUtc
            ?.toUtc()
            .toIso8601String(),
        ...record.position.toJson('current'),
      };

  static LearningStateSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    try {
      return LearningStateSyncRecord(
        id: entityId,
        surahId: _requiredString(payload, 'surahId'),
        ayahCount: _requiredInt(payload, 'ayahCount'),
        position: LearningPlanPosition.fromJson(payload, 'current'),
        learningCycle: _requiredInt(payload, 'learningCycle'),
        status: _requiredString(payload, 'status'),
        lastLearningActivityAtUtc: _optionalUtc(
          payload,
          'lastLearningActivityAtUtc',
        ),
        inactivityRollbackForActivityAtUtc: _optionalUtc(
          payload,
          'inactivityRollbackForActivityAtUtc',
        ),
      );
    } on ArgumentError {
      throw const LearningPayloadException('domain-rejected-learning-state');
    }
  }

  static SyncEnvelope upsert(
    LearningStateSyncRecord record, {
    required String envelopeId,
    required String deviceId,
    required String idempotencyKey,
    required int schemaVersion,
    required DateTime updatedAtUtc,
  }) {
    final at = updatedAtUtc.toUtc();
    return SyncEnvelope(
      id: envelopeId,
      deviceId: deviceId,
      entityType: entityType,
      entityId: record.id,
      operation: SyncOperation.upsert,
      schemaVersion: schemaVersion,
      // A plan is a standing position, not an event: it has no moment of its
      // own beyond the change being sent.
      createdAtUtc: at,
      updatedAtUtc: at,
      idempotencyKey: idempotencyKey,
      payload: encode(record),
    );
  }
}

abstract final class LearningEventSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.learningEvent;

  static Map<String, Object?> encode(LearningEventSyncRecord record) =>
      <String, Object?>{
        'learningSurahId': record.learningSurahId,
        'type': record.type,
        'createdAtUtc': record.createdAtUtc.toUtc().toIso8601String(),
        'learningCycle': record.learningCycle,
        'reason': record.reason,
        ...record.from.toJson('from'),
        ...record.to.toJson('to'),
      };

  static LearningEventSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    try {
      return LearningEventSyncRecord(
        id: entityId,
        learningSurahId: _requiredString(payload, 'learningSurahId'),
        type: _requiredString(payload, 'type'),
        createdAtUtc: _requiredUtc(payload, 'createdAtUtc'),
        learningCycle: _requiredInt(payload, 'learningCycle'),
        from: LearningPlanPosition.fromJson(payload, 'from'),
        to: LearningPlanPosition.fromJson(payload, 'to'),
        reason: _optionalString(payload, 'reason'),
      );
    } on ArgumentError {
      throw const LearningPayloadException('domain-rejected-learning-event');
    }
  }

  static SyncEnvelope upsert(
    LearningEventSyncRecord record, {
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
  throw LearningPayloadException('missing-$key');
}

int _requiredInt(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is int) return value;
  throw LearningPayloadException('missing-$key');
}

int? _optionalInt(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value == null) return null;
  if (value is int) return value;
  throw LearningPayloadException('malformed-$key');
}

String? _optionalString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  throw LearningPayloadException('malformed-$key');
}

DateTime _requiredUtc(Map<String, Object?> payload, String key) {
  final parsed = DateTime.tryParse(_requiredString(payload, key));
  if (parsed == null) throw LearningPayloadException('malformed-$key');
  return parsed.toUtc();
}

DateTime? _optionalUtc(Map<String, Object?> payload, String key) {
  final value = _optionalString(payload, key);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw LearningPayloadException('malformed-$key');
  return parsed.toUtc();
}
