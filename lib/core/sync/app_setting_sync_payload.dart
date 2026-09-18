/// One app setting, in the shape it crosses the boundary in.
///
/// **Most settings deliberately do not cross it**, and which ones was decided
/// before this file existed: [SyncAppSettingPolicy] holds the allow-list and
/// this defers to it entirely. Restating the list here would give the project
/// two of them, free to drift apart — and the first drift to matter would be
/// the one that let `sync.deviceId` through, leaving both devices claiming the
/// same identity and breaking the server's tie-break with it.
///
/// The policy is an allow-list rather than a deny-list, and the direction is
/// the point: a setting added later that nobody has classified simply does not
/// sync, which is a missing feature somebody notices. The reverse default would
/// leak whatever was added last.
///
/// What it leaves behind is worth knowing, because each exclusion is a
/// different kind of "belongs to this device":
///
/// - `learningNotificationEnabled` decides whether *this* device interrupts
///   him, and whether to be interrupted here is a judgement about here;
/// - `selected_prayer_type`, `selected_prayer_is_qada` and
///   `selected_learning_surah_id` are where this device is *right now*. One
///   phone being on Asr says nothing about a tablet in a drawer, and sharing it
///   is how the context starts jumping under the owner's finger;
/// - `recommendationBatch` is a projection this device rebuilds. A second
///   source of truth for it is what produced `cycleNumber = 5392`;
/// - `sync.deviceId` is this device's name inside the account. Never.
library;

import 'sync_app_setting_policy.dart';
import 'sync_envelope.dart';

/// Raised when a setting payload cannot be read.
final class AppSettingPayloadException implements Exception {
  const AppSettingPayloadException(this.reason);

  /// A category and a field name, never a value: a setting's value can be the
  /// owner's location.
  final String reason;

  @override
  String toString() => 'AppSettingPayloadException($reason)';
}

/// The stored shape of one setting.
final class AppSettingSyncRecord {
  factory AppSettingSyncRecord({
    required String key,
    required String value,
    required String valueType,
    required DateTime updatedAtUtc,
  }) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key');
    if (!AppSettingSyncPayload.valueTypes.contains(valueType)) {
      throw ArgumentError.value(valueType, 'valueType');
    }
    if (!updatedAtUtc.isUtc) {
      throw ArgumentError.value(updatedAtUtc, 'updatedAtUtc');
    }
    return AppSettingSyncRecord._(
      key: key,
      value: value,
      valueType: valueType,
      updatedAtUtc: updatedAtUtc,
    );
  }

  const AppSettingSyncRecord._({
    required this.key,
    required this.value,
    required this.valueType,
    required this.updatedAtUtc,
  });

  final String key;

  /// Stored as text whatever its type, exactly as the table does. Parsing it
  /// here would mean this layer understanding every setting's shape, and it has
  /// no business knowing what a translation profile looks like.
  final String value;
  final String valueType;
  final DateTime updatedAtUtc;
}

abstract final class AppSettingSyncPayload {
  static const SyncEntityType entityType = SyncEntityType.appSetting;

  /// The four the table's CHECK allows.
  static const Set<String> valueTypes = <String>{
    'string',
    'bool',
    'int',
    'double',
  };

  /// Whether [key] is one the owner owns rather than one this device does.
  ///
  /// Delegated, never duplicated: [SyncAppSettingPolicy] is where the decision
  /// was made and reviewed.
  static bool isSyncable(String key) => SyncAppSettingPolicy.shouldSync(key);

  static Map<String, Object?> encode(AppSettingSyncRecord record) =>
      <String, Object?>{
        'value': record.value,
        'valueType': record.valueType,
        'updatedAtUtc': record.updatedAtUtc.toUtc().toIso8601String(),
      };

  static AppSettingSyncRecord decode(
    Map<String, Object?> payload, {
    required String entityId,
  }) {
    if (!isSyncable(entityId)) {
      // Refused on arrival as well as on departure. A sending device on an
      // older build, or one whose allow-list has drifted, must not be able to
      // put this device's identity or location into this device's settings.
      throw const AppSettingPayloadException('setting-is-not-syncable');
    }
    try {
      return AppSettingSyncRecord(
        key: entityId,
        value: _requiredValue(payload),
        valueType: _requiredString(payload, 'valueType'),
        updatedAtUtc: _requiredUtc(payload, 'updatedAtUtc'),
      );
    } on ArgumentError {
      throw const AppSettingPayloadException('domain-rejected-setting');
    }
  }

  static SyncEnvelope upsert(
    AppSettingSyncRecord record, {
    required String envelopeId,
    required String deviceId,
    required String idempotencyKey,
    required int schemaVersion,
  }) {
    if (!isSyncable(record.key)) {
      throw const AppSettingPayloadException('setting-is-not-syncable');
    }
    final at = record.updatedAtUtc.toUtc();
    return SyncEnvelope(
      id: envelopeId,
      deviceId: deviceId,
      entityType: entityType,
      entityId: record.key,
      operation: SyncOperation.upsert,
      schemaVersion: schemaVersion,
      // A setting's own `updated_at_utc` is both dates: it is a standing
      // preference, and the moment it changed is the only moment it has.
      createdAtUtc: at,
      updatedAtUtc: at,
      idempotencyKey: idempotencyKey,
      payload: encode(record),
    );
  }

  /// An empty string is a legitimate value, so this checks the type rather than
  /// emptiness — unlike every other required string in this layer.
  static String _requiredValue(Map<String, Object?> payload) {
    final value = payload['value'];
    if (value is String) return value;
    throw const AppSettingPayloadException('missing-value');
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is String && value.isNotEmpty) return value;
    throw AppSettingPayloadException('missing-$key');
  }

  static DateTime _requiredUtc(Map<String, Object?> payload, String key) {
    final parsed = DateTime.tryParse(_requiredString(payload, key));
    if (parsed == null) throw AppSettingPayloadException('malformed-$key');
    return parsed.toUtc();
  }
}
