import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/sync.dart';

/// The preview a user says yes or no to is only as honest as this survey. Its
/// two failure modes are opposite and both bad: inventing a timestamp makes
/// unknown data look settled, and omitting an entity makes a merge look emptier
/// than it is.
void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-a',
          surahNumber: 2,
          officialName: 'Test Surah A',
          ayahCount: 3,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-a');
  });

  tearDown(() => database.close());

  DriftSyncInventory inventoryWith(
    _FakeGateway gateway, {
    String userId = 'user-a',
  }) => DriftSyncInventory(
    database: database,
    gateway: gateway,
    userId: userId,
    pageLimit: 2,
  );

  test('every entity type is surveyed, or this fails', () {
    expect(
      DriftSyncInventory.coveredTypes,
      SyncEntityType.values.toSet(),
      reason:
          'an uncovered type would be missing from the preview entirely, and '
          'a user would agree to a merge without seeing that category at all',
    );
  });

  group('what this device holds', () {
    test('an append-only record is dated by when it was written', () async {
      await _insertEvent(
        database,
        id: 'event-1',
        createdAtUtc: DateTime.utc(2026, 9, 10, 8),
      );

      final local = await inventoryWith(_FakeGateway()).localEntities();

      expect(local['recitationEvent:event-1'], DateTime.utc(2026, 9, 10, 8));
    });

    test('a withdrawn record is dated by the withdrawal', () async {
      await _insertEvent(
        database,
        id: 'event-1',
        createdAtUtc: DateTime.utc(2026, 9, 10, 8),
      );
      await database.customStatement(
        'UPDATE recitation_events SET deleted_at_utc = ? WHERE id = ?',
        <Object?>[
          DateTime.utc(2026, 9, 12, 9).millisecondsSinceEpoch ~/ 1000,
          'event-1',
        ],
      );

      final local = await inventoryWith(_FakeGateway()).localEntities();

      expect(
        local['recitationEvent:event-1'],
        DateTime.utc(2026, 9, 12, 9),
        reason:
            'the row never changes after it is written, so its withdrawal is '
            'the only later event there is',
      );
      expect(
        local.containsKey('recitationEvent:event-1'),
        isTrue,
        reason:
            'a tombstone is state; dropping it would let the account push the '
            'record straight back',
      );
    });

    test('a mutable row with a timestamp uses it', () async {
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'theme',
              value: 'dark',
              valueType: 'string',
              updatedAtUtc: DateTime.utc(2026, 9, 11, 7),
            ),
          );

      final local = await inventoryWith(_FakeGateway()).localEntities();

      expect(local['appSetting:theme'], DateTime.utc(2026, 9, 11, 7));
    });

    test('a row written since v10 carries the trigger stamp', () async {
      // `addMastered` in setUp wrote these, so the v10 touch trigger has
      // already dated them without any repository knowing the column exists.
      final local = await inventoryWith(_FakeGateway()).localEntities();

      expect(local.containsKey('masteredSurah:surah-a'), isTrue);
      expect(
        local['masteredSurah:surah-a'],
        isNotNull,
        reason: 'this is what v10 bought: these rows used to be undatable',
      );
      expect(local['rotationScheme:surah-a:scheme:1'], isNotNull);
    });

    test('a row untouched since v10 is present with no date', () async {
      // The state of every row that existed before the upgrade: v10 backfills
      // nothing, so it is honestly undatable until something writes to it.
      await database.customStatement(
        'UPDATE mastered_surahs SET updated_at_utc = NULL',
      );

      final local = await inventoryWith(_FakeGateway()).localEntities();

      expect(
        local.containsKey('masteredSurah:surah-a'),
        isTrue,
        reason: 'omitting it would make a merge look emptier than it is',
      );
      expect(
        local['masteredSurah:surah-a'],
        isNull,
        reason:
            'substituting cached_last_used_at_utc — when it was last recited, '
            'not when the roster entry changed — would state agreement the '
            'schema cannot support',
      );
    });
  });

  group('what the account holds', () {
    test('every page is walked, not just the first', () async {
      final gateway = _FakeGateway(
        pages: <List<SyncEnvelope>>[
          <SyncEnvelope>[_envelope('a'), _envelope('b')],
          <SyncEnvelope>[_envelope('c')],
        ],
      );

      final remote = await inventoryWith(gateway).remoteEntities('user-a');

      expect(remote.keys, <String>{
        'recitationEvent:a',
        'recitationEvent:b',
        'recitationEvent:c',
      });
    });

    test('the walk starts at the beginning and keeps no cursor', () async {
      final gateway = _FakeGateway(
        pages: <List<SyncEnvelope>>[
          <SyncEnvelope>[_envelope('a')],
        ],
      );
      final inventory = inventoryWith(gateway);

      await inventory.remoteEntities('user-a');
      await inventory.remoteEntities('user-a');

      expect(
        gateway.cursorsSeen,
        <String>['', ''],
        reason:
            'a survey that advanced the durable cursor would make the first '
            'real pull start after everything it had just read',
      );
    });

    test('a withdrawn remote record still counts as held', () async {
      final gateway = _FakeGateway(
        pages: <List<SyncEnvelope>>[
          <SyncEnvelope>[_envelope('a', deleted: true)],
        ],
      );

      final remote = await inventoryWith(gateway).remoteEntities('user-a');

      expect(remote.containsKey('recitationEvent:a'), isTrue);
    });

    test('a cursor that will not move is refused, not looped on', () async {
      final gateway = _FakeGateway(
        pages: <List<SyncEnvelope>>[
          <SyncEnvelope>[_envelope('a')],
        ],
        alwaysMore: true,
        freezeCursor: true,
      );

      await expectLater(
        () => inventoryWith(gateway).remoteEntities('user-a'),
        throwsA(
          isA<SyncTransportException>().having(
            (error) => error.reason,
            'reason',
            'remote-inventory-stalled',
          ),
        ),
        reason: 'a user is waiting on this preview',
      );
    });

    test('another account is refused outright', () async {
      await expectLater(
        () => inventoryWith(_FakeGateway()).remoteEntities('user-b'),
        throwsA(isA<StateError>()),
        reason:
            "surveying A's device against B's account is the one comparison "
            'that could talk someone into a destructive merge',
      );
    });
  });

  test('inputs are checked', () {
    expect(
      () => DriftSyncInventory(
        database: database,
        gateway: _FakeGateway(),
        userId: '',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => DriftSyncInventory(
        database: database,
        gateway: _FakeGateway(),
        userId: 'user-a',
        pageLimit: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

SyncEnvelope _envelope(String entityId, {bool deleted = false}) => SyncEnvelope(
  id: 'envelope-$entityId',
  deviceId: 'device-1',
  entityType: SyncEntityType.recitationEvent,
  entityId: entityId,
  operation: deleted ? SyncOperation.delete : SyncOperation.upsert,
  schemaVersion: 9,
  createdAtUtc: DateTime.utc(2026, 9, 1),
  updatedAtUtc: DateTime.utc(2026, 9, 2),
  idempotencyKey: 'key-$entityId',
);

final class _FakeGateway implements SyncGateway {
  _FakeGateway({
    this.pages = const <List<SyncEnvelope>>[],
    this.alwaysMore = false,
    this.freezeCursor = false,
  });

  final List<List<SyncEnvelope>> pages;
  final bool alwaysMore;
  final bool freezeCursor;

  /// Every cursor the survey asked from, in order.
  final List<String> cursorsSeen = <String>[];

  @override
  Future<SyncPullPage> pull({
    required SyncCursor after,
    int limit = 100,
  }) async {
    cursorsSeen.add(after.value);
    final index = after.isBeginning ? 0 : int.parse(after.value);
    final envelopes = index < pages.length
        ? pages[index]
        : const <SyncEnvelope>[];
    return SyncPullPage(
      envelopes: envelopes,
      cursor: freezeCursor ? after : SyncCursor('${index + 1}'),
      hasMore: alwaysMore || index + 1 < pages.length,
    );
  }

  @override
  Future<SyncPushResult> push(List<SyncEnvelope> envelopes) =>
      throw UnimplementedError('A survey never pushes.');
}

Future<void> _insertEvent(
  AppDatabase database, {
  required String id,
  required DateTime createdAtUtc,
}) => database
    .into(database.recitationEvents)
    .insert(
      RecitationEventsCompanion.insert(
        id: id,
        journalSequence: 1,
        surahId: 'surah-a',
        rotationSchemeId: 'surah-a:scheme:1',
        rakaatSpanCount: 1,
        createdAtUtc: createdAtUtc,
        localDate: '2026-09-10',
        prayerType: PrayerType.asr.name,
      ),
    );
