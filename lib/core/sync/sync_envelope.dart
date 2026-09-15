/// What kind of user-owned record an envelope carries.
///
/// Derived snapshots are deliberately absent: the widget snapshot, the rotation
/// projection and the recommendation batch are all rebuildable from these
/// facts, so syncing them would create a second source of truth that can
/// disagree with the journal.
enum SyncEntityType {
  recitationEvent,
  learningState,
  learningEvent,
  recallAttempt,
  rotationState,
  rotationScheme,
  rotationAdjustment,
  masteredSurah,
  prayerRoutineTemplate,
  prayerSession,
  appSetting,
}

/// Whether a record was written or withdrawn.
///
/// A withdrawal is a tombstone rather than a removal, so a device that has been
/// offline learns about the deletion instead of resurrecting the row.
enum SyncOperation { upsert, delete }

/// One user-owned change, in the shape it crosses the boundary in.
///
/// The envelope is transport-neutral on purpose: no backend type appears here,
/// so replacing the remote adapter never touches the domain.
final class SyncEnvelope {
  factory SyncEnvelope({
    required String id,
    required String deviceId,
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    required int schemaVersion,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    required String idempotencyKey,
    String? userId,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (deviceId.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Must not be empty.');
    }
    if (entityId.isEmpty) {
      throw ArgumentError.value(entityId, 'entityId', 'Must not be empty.');
    }
    if (idempotencyKey.isEmpty) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    if (userId != null && userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must be null or non-empty.');
    }
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    if (!updatedAtUtc.isUtc) {
      throw ArgumentError.value(updatedAtUtc, 'updatedAtUtc', 'Must be UTC.');
    }
    if (updatedAtUtc.isBefore(createdAtUtc)) {
      throw ArgumentError.value(
        updatedAtUtc,
        'updatedAtUtc',
        'Must not precede createdAtUtc.',
      );
    }
    // A tombstone carries no payload: there is nothing left to describe, and
    // keeping the last known values would invite a resurrection bug.
    if (operation == SyncOperation.delete && payload.isNotEmpty) {
      throw ArgumentError.value(
        payload,
        'payload',
        'A delete envelope must not carry a payload.',
      );
    }
    return SyncEnvelope._(
      id: id,
      userId: userId,
      deviceId: deviceId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      schemaVersion: schemaVersion,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      idempotencyKey: idempotencyKey,
      payload: _freezePayload(payload),
    );
  }

  factory SyncEnvelope.fromJson(Map<String, Object?> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Sync envelope field "$key" must be a string.');
      }
      return value;
    }

    T enumValue<T extends Enum>(String key, List<T> values) {
      final name = requiredString(key);
      for (final value in values) {
        if (value.name == name) return value;
      }
      throw FormatException('Unknown $key "$name".');
    }

    DateTime utcDate(String key) {
      final parsed = DateTime.tryParse(requiredString(key));
      if (parsed == null || !parsed.isUtc) {
        throw FormatException('Sync envelope field "$key" must be UTC.');
      }
      return parsed;
    }

    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int) {
      throw const FormatException(
        'Sync envelope field "schemaVersion" must be an integer.',
      );
    }
    final rawUserId = json['userId'];
    if (rawUserId != null && rawUserId is! String) {
      throw const FormatException(
        'Sync envelope field "userId" must be null or a string.',
      );
    }
    final rawPayload = json['payload'];
    if (rawPayload is! Map) {
      throw const FormatException(
        'Sync envelope field "payload" must be an object.',
      );
    }
    final payload = <String, Object?>{};
    for (final entry in rawPayload.entries) {
      if (entry.key is! String) {
        throw const FormatException('Sync payload keys must be strings.');
      }
      payload[entry.key as String] = entry.value;
    }
    try {
      return SyncEnvelope(
        id: requiredString('id'),
        userId: rawUserId as String?,
        deviceId: requiredString('deviceId'),
        entityType: enumValue('entityType', SyncEntityType.values),
        entityId: requiredString('entityId'),
        operation: enumValue('operation', SyncOperation.values),
        schemaVersion: schemaVersion,
        createdAtUtc: utcDate('createdAtUtc'),
        updatedAtUtc: utcDate('updatedAtUtc'),
        idempotencyKey: requiredString('idempotencyKey'),
        payload: payload,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid sync envelope: $error');
    }
  }

  const SyncEnvelope._({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.schemaVersion,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.idempotencyKey,
    required this.payload,
  });

  final String id;

  /// Absent while the user is anonymous; assigned when the record is first
  /// pushed under an account.
  final String? userId;
  final String deviceId;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final int schemaVersion;

  /// When the fact happened, by the client clock. A server never rewrites this.
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Makes a retried push a no-op instead of a duplicate.
  final String idempotencyKey;
  final Map<String, Object?> payload;

  bool get isTombstone => operation == SyncOperation.delete;

  bool get isAppendOnly => switch (entityType) {
    SyncEntityType.recitationEvent ||
    SyncEntityType.learningEvent ||
    SyncEntityType.recallAttempt ||
    SyncEntityType.rotationAdjustment => true,
    _ => false,
  };

  /// Identifies the record this envelope is about, across devices.
  String get entityKey => '${entityType.name}:$entityId';

  SyncEnvelope withUserId(String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'userId', 'Must not be empty.');
    }
    return SyncEnvelope._(
      id: id,
      userId: value,
      deviceId: deviceId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      schemaVersion: schemaVersion,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      idempotencyKey: idempotencyKey,
      payload: payload,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'deviceId': deviceId,
    'entityType': entityType.name,
    'entityId': entityId,
    'operation': operation.name,
    'schemaVersion': schemaVersion,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'idempotencyKey': idempotencyKey,
    'payload': payload,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncEnvelope &&
          id == other.id &&
          userId == other.userId &&
          deviceId == other.deviceId &&
          entityType == other.entityType &&
          entityId == other.entityId &&
          operation == other.operation &&
          schemaVersion == other.schemaVersion &&
          createdAtUtc == other.createdAtUtc &&
          updatedAtUtc == other.updatedAtUtc &&
          idempotencyKey == other.idempotencyKey &&
          _deepEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    deviceId,
    entityType,
    entityId,
    operation,
    schemaVersion,
    createdAtUtc,
    updatedAtUtc,
    idempotencyKey,
    _deepHash(payload),
  );

  @override
  String toString() =>
      'SyncEnvelope($entityKey, ${operation.name}, updated $updatedAtUtc)';
}

Map<String, Object?> _freezePayload(Map<String, Object?> payload) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final entry in payload.entries)
        entry.key: _freezeJsonValue(entry.value, 'payload.${entry.key}'),
    });

Object? _freezeJsonValue(Object? value, String path) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, path, 'Must be a finite JSON number.');
    }
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(<Object?>[
      for (var index = 0; index < value.length; index += 1)
        _freezeJsonValue(value[index], '$path[$index]'),
    ]);
  }
  if (value is Map) {
    final frozen = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError.value(
          entry.key,
          path,
          'JSON keys must be strings.',
        );
      }
      frozen[entry.key as String] = _freezeJsonValue(
        entry.value,
        '$path.${entry.key}',
      );
    }
    return Map<String, Object?>.unmodifiable(frozen);
  }
  throw ArgumentError.value(value, path, 'Must be JSON-compatible.');
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _deepHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(_deepHash));
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return Object.hashAll(
      keys.map((key) => Object.hash(key, _deepHash(value[key]))),
    );
  }
  return value.hashCode;
}
