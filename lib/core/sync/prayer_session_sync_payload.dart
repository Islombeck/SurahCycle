/// One prayer session and its parts, in the shape they cross the boundary in.
///
/// A session is the prayer the owner actually performed on a given day, split
/// into the parts his routine calls for. Recitations point at both — a surah
/// filled *this slot of this part of this prayer* — so a session has to arrive
/// before the recitations that reference it, exactly as the roster does.
///
/// **The parts travel with the session rather than as their own entity.** They
/// have no meaning apart from it, they are created and replaced together, and
/// `ON DELETE CASCADE` already ties their lifetime to it. Splitting them into a
/// separate entity would invent an ordering problem that does not exist.
///
/// **`completedAtUtc` travels, `completionMode` travels, and neither is
/// derived.** The first records that the part was finished, the second *how* —
/// and "followed the imam" is a statement about what happened, not a
/// calculation. It creates no recitation, which is precisely why it cannot be
/// inferred from the recitations and has to be carried.
library;

import 'sync_envelope.dart';

/// Raised when a session payload cannot be read.
final class PrayerSessionPayloadException implements Exception {
  const PrayerSessionPayloadException(this.reason);

  /// A category and a field name, never a value.
  final String reason;

  @override
  String toString() => 'PrayerSessionPayloadException($reason)';
}

/// One part of a performed prayer, as it crosses the boundary.
final class PrayerSessionSyncPart {
  factory PrayerSessionSyncPart({
    required String id,
    required String stableKey,
    required int orderIndex,
    required String label,
    required String kind,
    required int rakaatCount,
    required int requiredSurahSlots,
    required bool allowsFollowingImam,
    required String completionMode,
    String? sourceTemplatePartId,
    int? templateRevision,
    DateTime? completedAtUtc,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (stableKey.isEmpty) throw ArgumentError.value(stableKey, 'stableKey');
    if (orderIndex < 0) throw ArgumentError.value(orderIndex, 'orderIndex');
    if (label.isEmpty) throw ArgumentError.value(label, 'label');
    if (!_kinds.contains(kind)) throw ArgumentError.value(kind, 'kind');
    if (rakaatCount < 1) throw ArgumentError.value(rakaatCount, 'rakaatCount');
    if (requiredSurahSlots < 0) {
      throw ArgumentError.value(requiredSurahSlots, 'requiredSurahSlots');
    }
    if (!_completionModes.contains(completionMode)) {
      throw ArgumentError.value(completionMode, 'completionMode');
    }
    if (completedAtUtc != null && !completedAtUtc.isUtc) {
      throw ArgumentError.value(completedAtUtc, 'completedAtUtc');
    }
    return PrayerSessionSyncPart._(
      id: id,
      stableKey: stableKey,
      orderIndex: orderIndex,
      label: label,
      kind: kind,
      rakaatCount: rakaatCount,
      requiredSurahSlots: requiredSurahSlots,
      allowsFollowingImam: allowsFollowingImam,
      completionMode: completionMode,
      sourceTemplatePartId: sourceTemplatePartId,
      templateRevision: templateRevision,
      completedAtUtc: completedAtUtc,
    );
  }

  const PrayerSessionSyncPart._({
    required this.id,
    required this.stableKey,
    required this.orderIndex,
    required this.label,
    required this.kind,
    required this.rakaatCount,
    required this.requiredSurahSlots,
    required this.allowsFollowingImam,
    required this.completionMode,
    required this.sourceTemplatePartId,
    required this.templateRevision,
    required this.completedAtUtc,
  });

  /// The kinds the table's CHECK allows. Restated so a payload is refused with
  /// a reason rather than arriving as an opaque constraint failure.
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
  final String label;
  final String kind;
  final int rakaatCount;
  final int requiredSurahSlots;
  final bool allowsFollowingImam;
  final String completionMode;
  final String? sourceTemplatePartId;
  final int? templateRevision;
  final DateTime? completedAtUtc;
}

/// The stored shape of one performed prayer.
final class PrayerSessionSyncRecord {
  factory PrayerSessionSyncRecord({
    required String id,
    required String prayerType,
    required bool isQada,
    required DateTime startedAtUtc,
    String? localDate,
    required List<PrayerSessionSyncPart> parts,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (!_prayerTypes.contains(prayerType)) {
      throw ArgumentError.value(prayerType, 'prayerType');
    }
    // Qada is only ever the five Fard prayers and Witr. A session claiming a
    // made-up Nafl or Jumuah is not a record this app can hold, and the table
    // refuses it too.
    if (isQada && (prayerType == 'nafl' || prayerType == 'jumuah')) {
      throw ArgumentError.value(prayerType, 'prayerType', 'Cannot be Qada.');
    }
    if (!startedAtUtc.isUtc) {
      throw ArgumentError.value(startedAtUtc, 'startedAtUtc');
    }
    final orders = <int>{};
    final ids = <String>{};
    for (final part in parts) {
      if (!orders.add(part.orderIndex)) {
        throw ArgumentError.value(part.orderIndex, 'parts', 'Duplicate order.');
      }
      if (!ids.add(part.id)) {
        throw ArgumentError.value(part.id, 'parts', 'Duplicate part id.');
      }
    }
    return PrayerSessionSyncRecord._(
      id: id,
      prayerType: prayerType,
      isQada: isQada,
      startedAtUtc: startedAtUtc,
      localDate: localDate,
      parts: List<PrayerSessionSyncPart>.unmodifiable(
        parts.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
      ),
    );
  }

  const PrayerSessionSyncRecord._({
    required this.id,
    required this.prayerType,
    required this.isQada,
    required this.startedAtUtc,
    required this.localDate,
    required this.parts,
  });

  static const Set<String> _prayerTypes = <String>{
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
    'jumuah',
    'witr',
    'nafl',
  };

  final String id;
  final String prayerType;
  final bool isQada;
  final DateTime startedAtUtc;
  final String? localDate;
  final List<PrayerSessionSyncPart> parts;
}

abstract final class PrayerSessionSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.prayerSession;

  static Map<String, Object?> encode(PrayerSessionSyncRecord record) =>
      <String, Object?>{
        'prayerType': record.prayerType,
        'isQada': record.isQada,
        'startedAtUtc': record.startedAtUtc.toUtc().toIso8601String(),
        'localDate': record.localDate,
        'parts': <Map<String, Object?>>[
          for (final part in record.parts)
            <String, Object?>{
              'id': part.id,
              'stableKey': part.stableKey,
              'orderIndex': part.orderIndex,
              'label': part.label,
              'kind': part.kind,
              'rakaatCount': part.rakaatCount,
              'requiredSurahSlots': part.requiredSurahSlots,
              'allowsFollowingImam': part.allowsFollowingImam,
              'completionMode': part.completionMode,
              'sourceTemplatePartId': part.sourceTemplatePartId,
              'templateRevision': part.templateRevision,
              'completedAtUtc': part.completedAtUtc?.toUtc().toIso8601String(),
            },
        ],
      };

  static PrayerSessionSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    final rawParts = payload['parts'];
    if (rawParts is! List) {
      throw const PrayerSessionPayloadException('missing-parts');
    }
    try {
      return PrayerSessionSyncRecord(
        id: entityId,
        prayerType: _requiredString(payload, 'prayerType'),
        isQada: _requiredBool(payload, 'isQada'),
        startedAtUtc: _requiredUtc(payload, 'startedAtUtc'),
        localDate: _optionalString(payload, 'localDate'),
        parts: <PrayerSessionSyncPart>[for (final raw in rawParts) _part(raw)],
      );
    } on ArgumentError {
      throw const PrayerSessionPayloadException('domain-rejected-session');
    }
  }

  static SyncEnvelope upsert(
    PrayerSessionSyncRecord record, {
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
    // Unlike a roster entry, a session *does* have a moment of its own: the
    // prayer began when it began, and no later edit to its parts changes that.
    createdAtUtc: record.startedAtUtc.toUtc(),
    updatedAtUtc: updatedAtUtc.toUtc(),
    idempotencyKey: idempotencyKey,
    payload: encode(record),
  );

  static PrayerSessionSyncPart _part(Object? raw) {
    if (raw is! Map) {
      throw const PrayerSessionPayloadException('malformed-parts');
    }
    final part = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    return PrayerSessionSyncPart(
      id: _requiredString(part, 'id'),
      stableKey: _requiredString(part, 'stableKey'),
      orderIndex: _requiredInt(part, 'orderIndex'),
      label: _requiredString(part, 'label'),
      kind: _requiredString(part, 'kind'),
      rakaatCount: _requiredInt(part, 'rakaatCount'),
      requiredSurahSlots: _requiredInt(part, 'requiredSurahSlots'),
      allowsFollowingImam: _requiredBool(part, 'allowsFollowingImam'),
      completionMode: _requiredString(part, 'completionMode'),
      sourceTemplatePartId: _optionalString(part, 'sourceTemplatePartId'),
      templateRevision: _optionalInt(part, 'templateRevision'),
      completedAtUtc: _optionalUtc(part, 'completedAtUtc'),
    );
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is String && value.isNotEmpty) return value;
    throw PrayerSessionPayloadException('missing-$key');
  }

  static int _requiredInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    throw PrayerSessionPayloadException('missing-$key');
  }

  static bool _requiredBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is bool) return value;
    throw PrayerSessionPayloadException('missing-$key');
  }

  static DateTime _requiredUtc(Map<String, Object?> payload, String key) {
    final parsed = DateTime.tryParse(_requiredString(payload, key));
    if (parsed == null) throw PrayerSessionPayloadException('malformed-$key');
    return parsed.toUtc();
  }

  static String? _optionalString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    throw PrayerSessionPayloadException('malformed-$key');
  }

  static int? _optionalInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is int) return value;
    throw PrayerSessionPayloadException('malformed-$key');
  }

  static DateTime? _optionalUtc(Map<String, Object?> payload, String key) {
    final value = _optionalString(payload, key);
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw PrayerSessionPayloadException('malformed-$key');
    return parsed.toUtc();
  }
}
