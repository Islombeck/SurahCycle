/// One roster entry, in the shape it crosses the boundary in — and back.
///
/// The roster is what the owner has chosen to keep in rotation, and it is a
/// prerequisite for everything else: a recitation cannot be written on a device
/// whose roster does not hold its surah, because the schema enforces that as a
/// foreign key. So this has to sync before recitations can.
///
/// **The cached statistics are deliberately absent.** `cached_rotation_score`,
/// `cached_total_recitations` and `cached_last_used_at_utc` are a projection
/// rebuilt from the journal, not facts in their own right. Sending them would
/// create a second source of truth for a number the receiving device computes
/// anyway — and the two would disagree the moment one device applied a
/// recitation the other had not seen yet. What travels is the owner's
/// *intent*: which surahs are in the roster, which are active, what they are
/// called and in what order they are shown.
library;

import 'sync_envelope.dart';

/// Raised when a roster payload cannot be read.
final class MasteredSurahPayloadException implements Exception {
  const MasteredSurahPayloadException(this.reason);

  /// A category and a field name, never a value.
  final String reason;

  @override
  String toString() => 'MasteredSurahPayloadException($reason)';
}

/// The stored, non-derived shape of one roster entry.
final class MasteredSurahSyncRecord {
  factory MasteredSurahSyncRecord({
    required String surahId,
    required bool isCurrentlyMastered,
    required bool isActive,
    required bool hasEnteredRotation,
    int? activationBaselineScore,
    String? alias,
    int displayOrder = 0,
  }) {
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    // The same three rules the table's CHECK constraints hold, restated here so
    // a malformed payload is refused with a reason rather than arriving as an
    // opaque database error several layers down.
    if (isActive && !isCurrentlyMastered) {
      throw ArgumentError(
        'A surah that is not currently mastered cannot be active.',
      );
    }
    if (isActive && !hasEnteredRotation) {
      throw ArgumentError(
        'An active surah must already have entered the rotation.',
      );
    }
    if (activationBaselineScore != null && activationBaselineScore < 0) {
      throw ArgumentError.value(
        activationBaselineScore,
        'activationBaselineScore',
      );
    }
    if (displayOrder < 0) {
      throw ArgumentError.value(displayOrder, 'displayOrder');
    }
    return MasteredSurahSyncRecord._(
      surahId: surahId,
      isCurrentlyMastered: isCurrentlyMastered,
      isActive: isActive,
      hasEnteredRotation: hasEnteredRotation,
      activationBaselineScore: activationBaselineScore,
      alias: alias,
      displayOrder: displayOrder,
    );
  }

  const MasteredSurahSyncRecord._({
    required this.surahId,
    required this.isCurrentlyMastered,
    required this.isActive,
    required this.hasEnteredRotation,
    required this.activationBaselineScore,
    required this.alias,
    required this.displayOrder,
  });

  final String surahId;
  final bool isCurrentlyMastered;
  final bool isActive;
  final bool hasEnteredRotation;
  final int? activationBaselineScore;
  final String? alias;
  final int displayOrder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasteredSurahSyncRecord &&
          surahId == other.surahId &&
          isCurrentlyMastered == other.isCurrentlyMastered &&
          isActive == other.isActive &&
          hasEnteredRotation == other.hasEnteredRotation &&
          activationBaselineScore == other.activationBaselineScore &&
          alias == other.alias &&
          displayOrder == other.displayOrder;

  @override
  int get hashCode => Object.hash(
    surahId,
    isCurrentlyMastered,
    isActive,
    hasEnteredRotation,
    activationBaselineScore,
    alias,
    displayOrder,
  );
}

abstract final class MasteredSurahSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.masteredSurah;

  /// `surahId` is absent: it is the envelope's `entityId`.
  static Map<String, Object?> encode(MasteredSurahSyncRecord record) =>
      <String, Object?>{
        'isCurrentlyMastered': record.isCurrentlyMastered,
        'isActive': record.isActive,
        'hasEnteredRotation': record.hasEnteredRotation,
        'activationBaselineScore': record.activationBaselineScore,
        'alias': record.alias,
        'displayOrder': record.displayOrder,
      };

  static MasteredSurahSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    try {
      return MasteredSurahSyncRecord(
        surahId: entityId,
        // No defaults, for the same reason as a recitation: a missing
        // `isActive` read as false would silently drop a surah out of the
        // owner's rotation on the receiving device.
        isCurrentlyMastered: _requiredBool(payload, 'isCurrentlyMastered'),
        isActive: _requiredBool(payload, 'isActive'),
        hasEnteredRotation: _requiredBool(payload, 'hasEnteredRotation'),
        activationBaselineScore: _optionalInt(
          payload,
          'activationBaselineScore',
        ),
        alias: _optionalString(payload, 'alias'),
        displayOrder: _requiredInt(payload, 'displayOrder'),
      );
    } on ArgumentError {
      throw const MasteredSurahPayloadException('domain-rejected-roster-entry');
    }
  }

  static SyncEnvelope upsert(
    MasteredSurahSyncRecord record, {
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
      entityId: record.surahId,
      operation: SyncOperation.upsert,
      schemaVersion: schemaVersion,
      // A roster entry has no moment of its own the way a prayer does — there
      // is no "when this surah was recited" here, only when the entry last
      // changed. So both dates are that same moment rather than an invented
      // creation time.
      createdAtUtc: at,
      updatedAtUtc: at,
      idempotencyKey: idempotencyKey,
      payload: encode(record),
    );
  }

  static bool _requiredBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) return value;
    throw MasteredSurahPayloadException('missing-$key');
  }

  static int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    throw MasteredSurahPayloadException('missing-$key');
  }

  static int? _optionalInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is int) return value;
    throw MasteredSurahPayloadException('malformed-$key');
  }

  static String? _optionalString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    throw MasteredSurahPayloadException('malformed-$key');
  }
}
