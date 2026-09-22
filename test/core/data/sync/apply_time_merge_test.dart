import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/sync_envelope_router.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/sync.dart';

/// What happens when the account's copy is **older** than this device's.
///
/// Every merge test until now ran against `FakeSyncBackend`, which decides the
/// winner on the server. The server this app uses decides nothing: TablesDB
/// upserts what it is handed. So the rules ADR-0002 accepted have to hold at
/// apply time, on the device, or they hold nowhere — and "nowhere" reads as
/// working for exactly as long as there is only one device.
///
/// The scenario throughout is the ordinary one for a phone: this device edits
/// a record, another device had edited it earlier and was offline, and its
/// older version arrives afterwards.
void main() {
  late AppDatabase database;
  late SyncEnvelopeRouter router;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    router = SyncEnvelopeRouter(database);
    await SurahRepository(database).getRotationSnapshot();
  });

  final older = DateTime.utc(2026, 9, 20, 8);
  final newer = DateTime.utc(2026, 9, 22, 8);

  SyncEnvelope envelopeOf({
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
    SyncOperation operation = SyncOperation.upsert,
  }) => SyncEnvelope(
    id: 'envelope-$entityId',
    deviceId: 'other-device',
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    schemaVersion: 10,
    createdAtUtc: older,
    updatedAtUtc: updatedAtUtc,
    idempotencyKey: 'key-$entityId-${updatedAtUtc.millisecondsSinceEpoch}',
    payload: payload,
  );

  /// Stamps a row the way a local edit at [at] would leave it. The update
  /// trigger steps aside when the writer sets the column itself, which is what
  /// makes an authored timestamp expressible at all.
  Future<void> stampMasteredSurah(String surahId, DateTime at) async =>
      (database.update(database.masteredSurahs)
            ..where((MasteredSurahs row) => row.surahId.equals(surahId)))
          .write(MasteredSurahsCompanion(updatedAtUtc: Value<DateTime>(at)));

  Future<MasteredSurahRow> masteredRow(String surahId) async =>
      (database.select(database.masteredSurahs)
            ..where((MasteredSurahs row) => row.surahId.equals(surahId)))
          .getSingle();

  Future<void> seedSurah(String surahId) async {
    final surahs = SurahRepository(database);
    await surahs.upsertCatalog(<SurahDescriptor>[
      SurahDescriptor(
        id: surahId,
        surahNumber: 112,
        officialName: 'Al-Ikhlas',
        ayahCount: 4,
      ),
    ]);
    await surahs.addMastered(surahId);
  }

  group('the roster', () {
    test(
      'an older remote entry does not overwrite a newer local one',
      () async {
        await seedSurah('surah-112');
        // The owner renamed it on this device, after the other device's edit.
        await (database.update(database.masteredSurahs)
              ..where((MasteredSurahs row) => row.surahId.equals('surah-112')))
            .write(const MasteredSurahsCompanion(alias: Value<String?>('мой')));
        await stampMasteredSurah('surah-112', newer);

        await database.transaction(
          () => router.apply(
            envelopeOf(
              entityType: SyncEntityType.masteredSurah,
              entityId: 'surah-112',
              updatedAtUtc: older,
              payload: <String, Object?>{
                'surahId': 'surah-112',
                'isCurrentlyMastered': true,
                'isActive': true,
                'hasEnteredRotation': true,
                'activationBaselineScore': null,
                'alias': 'его старое имя',
                'displayOrder': 0,
              },
            ),
          ),
        );

        expect(
          (await masteredRow('surah-112')).alias,
          'мой',
          reason:
              'the account held an older copy; applying it would undo an edit '
              'the owner made on this device and never asked to revert',
        );
      },
    );

    test('a newer remote entry is applied', () async {
      await seedSurah('surah-112');
      await stampMasteredSurah('surah-112', older);

      await database.transaction(
        () => router.apply(
          envelopeOf(
            entityType: SyncEntityType.masteredSurah,
            entityId: 'surah-112',
            updatedAtUtc: newer,
            payload: <String, Object?>{
              'surahId': 'surah-112',
              'isCurrentlyMastered': true,
              'isActive': true,
              'hasEnteredRotation': true,
              'activationBaselineScore': null,
              'alias': 'его новое имя',
              'displayOrder': 0,
            },
          ),
        ),
      );

      expect((await masteredRow('surah-112')).alias, 'его новое имя');
    });

    test('an applied record keeps the time it was authored', () async {
      await seedSurah('surah-112');
      await stampMasteredSurah('surah-112', older);

      await database.transaction(
        () => router.apply(
          envelopeOf(
            entityType: SyncEntityType.masteredSurah,
            entityId: 'surah-112',
            updatedAtUtc: newer,
            payload: <String, Object?>{
              'surahId': 'surah-112',
              'isCurrentlyMastered': true,
              'isActive': true,
              'hasEnteredRotation': true,
              'activationBaselineScore': null,
              'alias': null,
              'displayOrder': 0,
            },
          ),
        ),
      );

      expect(
        // Drift hands back a local-zone `DateTime` for a stored instant, so
        // the comparison has to be of instants and not of objects.
        (await masteredRow('surah-112')).updatedAtUtc?.toUtc(),
        newer,
        reason:
            'stamping "now" would make this device claim authorship of another '
            "device's edit, and the next device to receive it would then be "
            'told it is newer than the one it actually is',
      );
    });

    test('an undated local row loses, which is what null means', () async {
      await seedSurah('surah-112');
      await (database.update(
        database.masteredSurahs,
      )..where((MasteredSurahs row) => row.surahId.equals('surah-112'))).write(
        const MasteredSurahsCompanion(updatedAtUtc: Value<DateTime?>(null)),
      );

      await database.transaction(
        () => router.apply(
          envelopeOf(
            entityType: SyncEntityType.masteredSurah,
            entityId: 'surah-112',
            updatedAtUtc: older,
            payload: <String, Object?>{
              'surahId': 'surah-112',
              'isCurrentlyMastered': true,
              'isActive': true,
              'hasEnteredRotation': true,
              'activationBaselineScore': null,
              'alias': 'с аккаунта',
              'displayOrder': 0,
            },
          ),
        ),
      );

      expect((await masteredRow('surah-112')).alias, 'с аккаунта');
    });
  });

  group('the decision itself', () {
    test('a strictly older incoming record loses', () {
      expect(
        SyncMergeDecision.incomingWins(
          incomingUpdatedAtUtc: older,
          localUpdatedAtUtc: newer,
        ),
        isFalse,
      );
    });

    test('an exact tie goes to the account', () {
      expect(
        SyncMergeDecision.incomingWins(
          incomingUpdatedAtUtc: newer,
          localUpdatedAtUtc: newer,
        ),
        isTrue,
        reason:
            'the local row cannot say which device wrote it, so the ADR\'s '
            'third step is not available here; the account is the shared copy',
      );
    });

    test('sub-second precision does not decide anything', () {
      expect(
        SyncMergeDecision.incomingWins(
          incomingUpdatedAtUtc: newer.add(const Duration(milliseconds: 400)),
          localUpdatedAtUtc: newer,
        ),
        isTrue,
      );
      expect(
        SyncMergeDecision.incomingWins(
          incomingUpdatedAtUtc: newer,
          localUpdatedAtUtc: newer.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
        reason:
            'the touch triggers write whole seconds, so a fractional part is '
            'an artefact of formatting and must not outrank anything',
      );
    });
  });
}
