/// One prayer routine template and its parts, in the shape they cross the
/// boundary in.
///
/// The routine is how the owner has set each prayer up — which parts it has, in
/// what order, how many rakaats, how many slots for surahs. It is pure intent:
/// nothing here is derived from anything, and losing it means the owner
/// rebuilding his prayer structure by hand on the second device.
///
/// **Template ids are the same on every device.** `_ensureEmptyRoutineTemplates`
/// seeds them as `routine:<prayerType>` at startup, so the `UNIQUE
/// (prayer_type)` constraint cannot be violated by two devices having invented
/// different ids for the same prayer. Sync only ever updates one in place.
///
/// **`revision` travels but decides nothing.** It counts edits locally and two
/// phones both at revision 4 say nothing about which edit came last — the
/// column's own doc comment says so, which is why schema v10 gave the table a
/// real `updated_at_utc`. It is carried because the routine repository uses it
/// for optimistic concurrency *within* a device, and an imported row with a
/// stale number would make the next local edit look like a conflict.
library;

import 'sync_envelope.dart';

/// Raised when a routine payload cannot be read.
final class PrayerRoutinePayloadException implements Exception {
  const PrayerRoutinePayloadException(this.reason);

  /// A category and a field name, never a value.
  final String reason;

  @override
  String toString() => 'PrayerRoutinePayloadException($reason)';
}

/// One part of a routine, as it crosses the boundary.
final class PrayerRoutineSyncPart {
  factory PrayerRoutineSyncPart({
    required String id,
    required String stableKey,
    required int orderIndex,
    required String kind,
    String? customLabel,
    required int rakaatCount,
    required int requiredSurahSlots,
    required bool allowsFollowingImam,
    required String defaultCompletionMode,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (stableKey.isEmpty) throw ArgumentError.value(stableKey, 'stableKey');
    if (orderIndex < 0) throw ArgumentError.value(orderIndex, 'orderIndex');
    if (!_kinds.contains(kind)) throw ArgumentError.value(kind, 'kind');
    // A custom part is defined by its label; without one there is nothing to
    // show and the table refuses it too.
    if (kind == 'custom' && (customLabel == null || customLabel.isEmpty)) {
      throw ArgumentError.value(customLabel, 'customLabel');
    }
    if (rakaatCount < 1) throw ArgumentError.value(rakaatCount, 'rakaatCount');
    if (requiredSurahSlots < 0) {
      throw ArgumentError.value(requiredSurahSlots, 'requiredSurahSlots');
    }
    if (!_completionModes.contains(defaultCompletionMode)) {
      throw ArgumentError.value(defaultCompletionMode, 'defaultCompletionMode');
    }
    return PrayerRoutineSyncPart._(
      id: id,
      stableKey: stableKey,
      orderIndex: orderIndex,
      kind: kind,
      customLabel: customLabel,
      rakaatCount: rakaatCount,
      requiredSurahSlots: requiredSurahSlots,
      allowsFollowingImam: allowsFollowingImam,
      defaultCompletionMode: defaultCompletionMode,
    );
  }

  const PrayerRoutineSyncPart._({
    required this.id,
    required this.stableKey,
    required this.orderIndex,
    required this.kind,
    required this.customLabel,
    required this.rakaatCount,
    required this.requiredSurahSlots,
    required this.allowsFollowingImam,
    required this.defaultCompletionMode,
  });

  static const Set<String> _kinds = <String>{
    'fard',
    'sunnah',
    'witr',
    'nafl',
    'custom',
  };
  static const Set<String> _completionModes = <String>{
    'recitations',
    'followedImam',
  };

  final String id;
  final String stableKey;
  final int orderIndex;
  final String kind;
  final String? customLabel;
  final int rakaatCount;
  final int requiredSurahSlots;
  final bool allowsFollowingImam;
  final String defaultCompletionMode;
}

/// The stored shape of one routine template.
final class PrayerRoutineSyncRecord {
  factory PrayerRoutineSyncRecord({
    required String id,
    required String prayerType,
    required String displayName,
    required bool enabled,
    required int revision,
    required List<PrayerRoutineSyncPart> parts,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (prayerType.isEmpty) throw ArgumentError.value(prayerType, 'prayerType');
    if (displayName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    final orders = <int>{};
    final keys = <String>{};
    final ids = <String>{};
    for (final part in parts) {
      if (!orders.add(part.orderIndex)) {
        throw ArgumentError.value(part.orderIndex, 'parts', 'Duplicate order.');
      }
      if (!keys.add(part.stableKey)) {
        throw ArgumentError.value(part.stableKey, 'parts', 'Duplicate key.');
      }
      if (!ids.add(part.id)) {
        throw ArgumentError.value(part.id, 'parts', 'Duplicate part id.');
      }
    }
    return PrayerRoutineSyncRecord._(
      id: id,
      prayerType: prayerType,
      displayName: displayName,
      enabled: enabled,
      revision: revision,
      parts: List<PrayerRoutineSyncPart>.unmodifiable(
        parts.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
      ),
    );
  }

  const PrayerRoutineSyncRecord._({
    required this.id,
    required this.prayerType,
    required this.displayName,
    required this.enabled,
    required this.revision,
    required this.parts,
  });

  final String id;
  final String prayerType;
  final String displayName;
  final bool enabled;
  final int revision;

  /// May be empty: a prayer the owner has not set up yet is a real state, and
  /// the seeded templates all start that way.
  final List<PrayerRoutineSyncPart> parts;
}

abstract final class PrayerRoutineSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.prayerRoutineTemplate;

  static Map<String, Object?> encode(PrayerRoutineSyncRecord record) =>
      <String, Object?>{
        'prayerType': record.prayerType,
        'displayName': record.displayName,
        'enabled': record.enabled,
        'revision': record.revision,
        'parts': <Map<String, Object?>>[
          for (final part in record.parts)
            <String, Object?>{
              'id': part.id,
              'stableKey': part.stableKey,
              'orderIndex': part.orderIndex,
              'kind': part.kind,
              'customLabel': part.customLabel,
              'rakaatCount': part.rakaatCount,
              'requiredSurahSlots': part.requiredSurahSlots,
              'allowsFollowingImam': part.allowsFollowingImam,
              'defaultCompletionMode': part.defaultCompletionMode,
            },
        ],
      };

  static PrayerRoutineSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    final rawParts = payload['parts'];
    if (rawParts is! List) {
      throw const PrayerRoutinePayloadException('missing-parts');
    }
    try {
      return PrayerRoutineSyncRecord(
        id: entityId,
        prayerType: _requiredString(payload, 'prayerType'),
        displayName: _requiredString(payload, 'displayName'),
        enabled: _requiredBool(payload, 'enabled'),
        revision: _requiredInt(payload, 'revision'),
        parts: <PrayerRoutineSyncPart>[for (final raw in rawParts) _part(raw)],
      );
    } on ArgumentError {
      throw const PrayerRoutinePayloadException('domain-rejected-routine');
    }
  }

  static SyncEnvelope upsert(
    PrayerRoutineSyncRecord record, {
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
      // Like a roster entry: a routine has no moment of its own beyond the
      // change itself. It is a standing arrangement, not an event.
      createdAtUtc: at,
      updatedAtUtc: at,
      idempotencyKey: idempotencyKey,
      payload: encode(record),
    );
  }

  static PrayerRoutineSyncPart _part(Object? raw) {
    if (raw is! Map) {
      throw const PrayerRoutinePayloadException('malformed-parts');
    }
    final part = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    return PrayerRoutineSyncPart(
      id: _requiredString(part, 'id'),
      stableKey: _requiredString(part, 'stableKey'),
      orderIndex: _requiredInt(part, 'orderIndex'),
      kind: _requiredString(part, 'kind'),
      customLabel: _optionalString(part, 'customLabel'),
      rakaatCount: _requiredInt(part, 'rakaatCount'),
      requiredSurahSlots: _requiredInt(part, 'requiredSurahSlots'),
      allowsFollowingImam: _requiredBool(part, 'allowsFollowingImam'),
      defaultCompletionMode: _requiredString(part, 'defaultCompletionMode'),
    );
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is String && value.isNotEmpty) return value;
    throw PrayerRoutinePayloadException('missing-$key');
  }

  static int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    throw PrayerRoutinePayloadException('missing-$key');
  }

  static bool _requiredBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) return value;
    throw PrayerRoutinePayloadException('missing-$key');
  }

  static String? _optionalString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    throw PrayerRoutinePayloadException('malformed-$key');
  }
}
