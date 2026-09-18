import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/app_setting_sync_applier.dart';
import 'package:murajaah/core/data/sync/sync_recorder.dart';
import 'package:murajaah/core/sync/app_setting_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Settings are the one table where *which rows travel* is the whole question.
/// The allow-list already existed as `SyncAppSettingPolicy`; what these tests
/// hold is that both directions defer to it, so a sending device on an older
/// build cannot put its identity or its position into this one.
void main() {
  late AppDatabase database;
  late AppSettingSyncApplier applier;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    applier = AppSettingSyncApplier(database);
  });

  tearDown(() => database.close());

  AppSettingSyncRecord setting({
    String key = 'theme_preference',
    String value = 'dark',
    String valueType = 'string',
  }) => AppSettingSyncRecord(
    key: key,
    value: value,
    valueType: valueType,
    updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
  );

  SyncEnvelope envelopeOf(AppSettingSyncRecord source) =>
      AppSettingSyncPayload.upsert(
        source,
        envelopeId: 'envelope-${source.key}',
        deviceId: 'other-device',
        idempotencyKey: 'key-${source.key}',
        schemaVersion: 10,
      );

  /// Builds an envelope for a key the sender should never have sent, the way a
  /// device on an older build would.
  SyncEnvelope forbiddenEnvelope(String key, String value) => SyncEnvelope(
    id: 'envelope-$key',
    deviceId: 'other-device',
    entityType: SyncEntityType.appSetting,
    entityId: key,
    operation: SyncOperation.upsert,
    schemaVersion: 10,
    createdAtUtc: DateTime.utc(2026, 9, 18, 9),
    updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
    idempotencyKey: 'key-$key',
    payload: <String, Object?>{
      'value': value,
      'valueType': 'string',
      'updatedAtUtc': '2026-09-18T09:00:00.000Z',
    },
  );

  Future<void> applyIn(SyncEnvelope envelope) =>
      database.transaction(() => applier.apply(envelope));

  test('a content preference travels', () async {
    await applyIn(envelopeOf(setting()));

    final stored = await AppSettingsRepository(
      database,
    ).getString('theme_preference');
    expect(stored, 'dark');
  });

  test('the value is carried as text, whatever its type', () async {
    await applyIn(
      envelopeOf(
        setting(key: 'quran_display_preferences_v1', value: '{"arabic":true}'),
      ),
    );

    final stored = await AppSettingsRepository(
      database,
    ).getString('quran_display_preferences_v1');
    expect(
      stored,
      '{"arabic":true}',
      reason:
          'this layer has no business knowing what a display preference looks '
          'like, and parsing it would mean understanding every setting',
    );
  });

  test('an empty value is a value, not a missing one', () async {
    await applyIn(envelopeOf(setting(value: '')));

    expect(
      await AppSettingsRepository(database).getString('theme_preference'),
      '',
    );
  });

  group('what must never arrive', () {
    test('the device id is refused', () async {
      await expectLater(
        () => applyIn(
          forbiddenEnvelope(SyncDeviceId.settingKey, 'someone-elses-device'),
        ),
        throwsA(isA<AppSettingPayloadException>()),
        reason:
            'both devices claiming one identity breaks "which of my devices '
            "wrote this\" and the server's tie-break with it",
      );
      expect(
        await AppSettingsRepository(
          database,
        ).getString(SyncDeviceId.settingKey),
        isNull,
      );
    });

    test('this device\'s current prayer is refused', () async {
      await expectLater(
        () => applyIn(forbiddenEnvelope('selected_prayer_type', 'asr')),
        throwsA(isA<AppSettingPayloadException>()),
        reason:
            'one phone being on Asr says nothing about a tablet in a drawer, '
            "and sharing it is how the context jumps under the owner's finger",
      );
    });

    test('the recommendation batch is refused', () async {
      await expectLater(
        () => applyIn(forbiddenEnvelope('recommendationBatch', '{}')),
        throwsA(isA<AppSettingPayloadException>()),
        reason:
            'a projection this device rebuilds; a second source of truth for '
            'it is what produced cycleNumber = 5392',
      );
    });

    test('sending one is refused too, not only receiving', () {
      expect(
        () => envelopeOf(setting(key: 'selected_prayer_type', value: 'asr')),
        throwsA(isA<AppSettingPayloadException>()),
      );
    });
  });

  test('the allow-list is the one the project already decided', () {
    // Deferred to rather than restated. Two lists free to drift apart is how a
    // device id eventually slips through one of them.
    for (final key in SyncAppSettingPolicy.syncableKeys) {
      expect(AppSettingSyncPayload.isSyncable(key), isTrue);
    }
    expect(AppSettingSyncPayload.isSyncable('anything-else'), isFalse);
  });

  test('clearing a preference returns it to the app default', () async {
    await applyIn(envelopeOf(setting()));

    await applyIn(
      SyncEnvelope(
        id: 'envelope-gone',
        deviceId: 'other-device',
        entityType: SyncEntityType.appSetting,
        entityId: 'theme_preference',
        operation: SyncOperation.delete,
        schemaVersion: 10,
        createdAtUtc: DateTime.utc(2026, 9, 18, 9),
        updatedAtUtc: DateTime.utc(2026, 9, 18, 10),
        idempotencyKey: 'key-gone',
      ),
    );

    expect(
      await AppSettingsRepository(database).getString('theme_preference'),
      isNull,
      reason: 'the default, not some other device\'s choice',
    );
  });

  test('a value type this build does not know is refused', () {
    expect(() => setting(valueType: 'json'), throwsA(isA<ArgumentError>()));
  });

  test('applying it twice changes nothing', () async {
    final envelope = envelopeOf(setting());
    await applyIn(envelope);

    await applyIn(envelope);

    expect(await database.select(database.appSettings).get(), hasLength(1));
  });
}
