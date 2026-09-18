/// One rotation scheme — how the owner chose to split a surah — in the shape it
/// crosses the boundary in, and back.
///
/// **The journal sequences do not travel, and it turned out they need not.**
/// `activated_journal_sequence` is written when a scheme is created and then
/// **never read anywhere**; `superseded_journal_sequence` is read only as
/// `IS NULL`, that is, purely as "is this the scheme in force". So the numbers
/// are local provenance with no cross-device meaning, and what has to travel is
/// the boolean they stand for. That was worth checking rather than assuming:
/// copying a journal position from another device would have placed a scheme
/// among journal entries that do not exist here.
///
/// **Part ids travel, and must.** A recitation's coverage names the parts it
/// covered, so ids that differed between devices would leave every arriving
/// recitation pointing at nothing.
///
/// **The cached part statistics do not travel**, for the same reason as the
/// roster's: `cached_score`, `cached_recitation_count` and
/// `cached_last_used_at_utc` are a projection rebuilt from the journal.
///
/// **The `baseline*` fields travel, with one caveat found by a test.** For the
/// *first* scheme of a surah they are stored input — the score and count the
/// surah carried when it was first mastered — and nothing can recompute them,
/// so they would be lost forever if they stayed behind. For every later scheme
/// in the chain `rebuildFromJournal` overwrites them, carrying the previous
/// scheme's final state forward. They are sent anyway, because the sender
/// cannot know which position a scheme will occupy in the receiver's chain and
/// a value the rebuild then corrects costs nothing.
library;

import 'sync_envelope.dart';

/// Raised when a scheme payload cannot be read.
final class RotationSchemePayloadException implements Exception {
  const RotationSchemePayloadException(this.reason);

  /// A category and a field name, never a value.
  final String reason;

  @override
  String toString() => 'RotationSchemePayloadException($reason)';
}

/// One part of a split, as it crosses the boundary.
final class RotationSchemeSyncPart {
  factory RotationSchemeSyncPart({
    required String id,
    required int ordinal,
    required int startAyah,
    required int endAyah,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    if (startAyah < 1) throw ArgumentError.value(startAyah, 'startAyah');
    if (endAyah < startAyah) throw ArgumentError.value(endAyah, 'endAyah');
    return RotationSchemeSyncPart._(
      id: id,
      ordinal: ordinal,
      startAyah: startAyah,
      endAyah: endAyah,
    );
  }

  const RotationSchemeSyncPart._({
    required this.id,
    required this.ordinal,
    required this.startAyah,
    required this.endAyah,
  });

  final String id;
  final int ordinal;
  final int startAyah;
  final int endAyah;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationSchemeSyncPart &&
          id == other.id &&
          ordinal == other.ordinal &&
          startAyah == other.startAyah &&
          endAyah == other.endAyah;

  @override
  int get hashCode => Object.hash(id, ordinal, startAyah, endAyah);
}

/// The stored, non-derived shape of one scheme.
final class RotationSchemeSyncRecord {
  factory RotationSchemeSyncRecord({
    required String id,
    required String surahId,
    required int version,
    required int ayahCountSnapshot,
    required int baselineScore,
    required int baselineTotalRecitations,
    DateTime? baselineLastUsedAtUtc,
    bool resetsRotationBaseline = false,
    required bool isActive,
    required List<RotationSchemeSyncPart> parts,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (surahId.isEmpty) throw ArgumentError.value(surahId, 'surahId');
    if (version < 1) throw ArgumentError.value(version, 'version');
    if (ayahCountSnapshot < 1) {
      throw ArgumentError.value(ayahCountSnapshot, 'ayahCountSnapshot');
    }
    if (baselineScore < 0) throw ArgumentError.value(baselineScore);
    if (baselineTotalRecitations < 0) {
      throw ArgumentError.value(baselineTotalRecitations);
    }
    if (baselineLastUsedAtUtc != null && !baselineLastUsedAtUtc.isUtc) {
      throw ArgumentError.value(baselineLastUsedAtUtc, 'baselineLastUsedAtUtc');
    }
    if (parts.isEmpty) {
      throw ArgumentError.value(parts, 'parts', 'A scheme covers something.');
    }
    final ordinals = <int>{};
    final ids = <String>{};
    for (final part in parts) {
      if (!ordinals.add(part.ordinal)) {
        throw ArgumentError.value(part.ordinal, 'parts', 'Duplicate ordinal.');
      }
      if (!ids.add(part.id)) {
        throw ArgumentError.value(part.id, 'parts', 'Duplicate part id.');
      }
      if (part.endAyah > ayahCountSnapshot) {
        throw ArgumentError.value(
          part.endAyah,
          'parts',
          'A part cannot run past the surah.',
        );
      }
    }
    return RotationSchemeSyncRecord._(
      id: id,
      surahId: surahId,
      version: version,
      ayahCountSnapshot: ayahCountSnapshot,
      baselineScore: baselineScore,
      baselineTotalRecitations: baselineTotalRecitations,
      baselineLastUsedAtUtc: baselineLastUsedAtUtc,
      resetsRotationBaseline: resetsRotationBaseline,
      isActive: isActive,
      parts: List<RotationSchemeSyncPart>.unmodifiable(
        parts.toList()..sort((a, b) => a.ordinal.compareTo(b.ordinal)),
      ),
    );
  }

  const RotationSchemeSyncRecord._({
    required this.id,
    required this.surahId,
    required this.version,
    required this.ayahCountSnapshot,
    required this.baselineScore,
    required this.baselineTotalRecitations,
    required this.baselineLastUsedAtUtc,
    required this.resetsRotationBaseline,
    required this.isActive,
    required this.parts,
  });

  final String id;
  final String surahId;
  final int version;
  final int ayahCountSnapshot;
  final int baselineScore;
  final int baselineTotalRecitations;
  final DateTime? baselineLastUsedAtUtc;
  final bool resetsRotationBaseline;

  /// Whether this is the scheme in force for its surah.
  ///
  /// Stands in for `superseded_journal_sequence IS NULL`, which is the only
  /// thing anything ever asks of that column.
  final bool isActive;
  final List<RotationSchemeSyncPart> parts;
}

abstract final class RotationSchemeSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.rotationScheme;

  /// `id` is absent: it is the envelope's `entityId`.
  static Map<String, Object?> encode(RotationSchemeSyncRecord record) =>
      <String, Object?>{
        'surahId': record.surahId,
        'version': record.version,
        'ayahCountSnapshot': record.ayahCountSnapshot,
        'baselineScore': record.baselineScore,
        'baselineTotalRecitations': record.baselineTotalRecitations,
        'baselineLastUsedAtUtc': record.baselineLastUsedAtUtc
            ?.toUtc()
            .toIso8601String(),
        'resetsRotationBaseline': record.resetsRotationBaseline,
        'isActive': record.isActive,
        'parts': <Map<String, Object?>>[
          for (final part in record.parts)
            <String, Object?>{
              'id': part.id,
              'ordinal': part.ordinal,
              'startAyah': part.startAyah,
              'endAyah': part.endAyah,
            },
        ],
      };

  static RotationSchemeSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    final rawParts = payload['parts'];
    if (rawParts is! List) {
      throw const RotationSchemePayloadException('missing-parts');
    }
    try {
      return RotationSchemeSyncRecord(
        id: entityId,
        surahId: _requiredString(payload, 'surahId'),
        version: _requiredInt(payload, 'version'),
        ayahCountSnapshot: _requiredInt(payload, 'ayahCountSnapshot'),
        baselineScore: _requiredInt(payload, 'baselineScore'),
        baselineTotalRecitations: _requiredInt(
          payload,
          'baselineTotalRecitations',
        ),
        baselineLastUsedAtUtc: _optionalUtc(payload, 'baselineLastUsedAtUtc'),
        resetsRotationBaseline: _requiredBool(
          payload,
          'resetsRotationBaseline',
        ),
        isActive: _requiredBool(payload, 'isActive'),
        parts: <RotationSchemeSyncPart>[for (final raw in rawParts) _part(raw)],
      );
    } on ArgumentError {
      throw const RotationSchemePayloadException('domain-rejected-scheme');
    }
  }

  static SyncEnvelope upsert(
    RotationSchemeSyncRecord record, {
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
      // Like a roster entry, a scheme has no moment of its own beyond the
      // change itself.
      createdAtUtc: at,
      updatedAtUtc: at,
      idempotencyKey: idempotencyKey,
      payload: encode(record),
    );
  }

  static RotationSchemeSyncPart _part(Object? raw) {
    if (raw is! Map) {
      throw const RotationSchemePayloadException('malformed-parts');
    }
    final part = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    return RotationSchemeSyncPart(
      id: _requiredString(part, 'id'),
      ordinal: _requiredInt(part, 'ordinal'),
      startAyah: _requiredInt(part, 'startAyah'),
      endAyah: _requiredInt(part, 'endAyah'),
    );
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is String && value.isNotEmpty) return value;
    throw RotationSchemePayloadException('missing-$key');
  }

  static int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    throw RotationSchemePayloadException('missing-$key');
  }

  static bool _requiredBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) return value;
    throw RotationSchemePayloadException('missing-$key');
  }

  static DateTime? _optionalUtc(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw RotationSchemePayloadException('malformed-$key');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw RotationSchemePayloadException('malformed-$key');
    }
    return parsed.toUtc();
  }
}
