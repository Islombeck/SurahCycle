import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/data/sync/rotation_scheme_sync_applier.dart';
import 'package:murajaah/core/data/sync/sync_versioned_rows.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/sync/rotation_scheme_sync_payload.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Two local invariants have to survive every application of a scheme, and the
/// app breaks rather than degrades if either does not: exactly one scheme per
/// surah is in force, and a part some recitation covered is never removed.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;
  late RotationSchemeSyncApplier applier;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    applier = RotationSchemeSyncApplier(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Al-Ikhlas',
          ayahCount: 4,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('surah-112');
    // Dated the way the owner's own row would be: created days before the
    // envelopes below, not a millisecond ago. Without this the local scheme
    // carries the wall clock, every envelope here is "older", and the merge
    // rule skips the very applications these tests are about.
    await SyncVersionedRows(database).stampAuthored(
      table: 'rotation_schemes',
      key: 'surah-112:scheme:1',
      authoredAtUtc: DateTime.utc(2026, 9, 1),
    );
  });

  tearDown(() => database.close());

  RotationSchemeSyncRecord split({
    String id = 'surah-112:scheme:2',
    int version = 2,
    bool isActive = true,
  }) => RotationSchemeSyncRecord(
    id: id,
    surahId: 'surah-112',
    version: version,
    ayahCountSnapshot: 4,
    baselineScore: 2,
    baselineTotalRecitations: 7,
    baselineLastUsedAtUtc: DateTime.utc(2026, 9, 1, 12),
    isActive: isActive,
    parts: <RotationSchemeSyncPart>[
      RotationSchemeSyncPart(
        id: '$id:part:1',
        ordinal: 1,
        startAyah: 1,
        endAyah: 2,
      ),
      RotationSchemeSyncPart(
        id: '$id:part:2',
        ordinal: 2,
        startAyah: 3,
        endAyah: 4,
      ),
    ],
  );

  SyncEnvelope upsertOf(RotationSchemeSyncRecord source, {int minute = 0}) =>
      RotationSchemeSyncPayload.upsert(
        source,
        envelopeId: 'envelope-${source.id}-$minute',
        deviceId: 'other-device',
        idempotencyKey: 'key-${source.id}-$minute',
        schemaVersion: 10,
        updatedAtUtc: DateTime.utc(2026, 9, 18, 9, minute),
      );

  Future<void> applyIn(SyncEnvelope envelope) =>
      database.transaction(() => applier.apply(envelope));

  Matcher refuses(String reason) => throwsA(
    isA<SyncTransportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  Future<List<RotationSchemeRow>> activeSchemes() =>
      (database.select(database.rotationSchemes)..where(
            (RotationSchemes row) => row.supersededJournalSequence.isNull(),
          ))
          .get();

  test('an arriving split becomes the scheme in force', () async {
    await applyIn(upsertOf(split()));

    final active = await activeSchemes();
    expect(active, hasLength(1));
    expect(active.single.id, 'surah-112:scheme:2');
    expect(active.single.version, 2);
    expect(active.single.ayahCountSnapshot, 4);

    final snapshot = await surahs.getRotationSnapshot();
    expect(snapshot.surahById('surah-112').rotationScheme.parts, hasLength(2));
  });

  test('a chained scheme has its baseline recomputed, not imported', () async {
    // Found by a failing assertion rather than by reading: for every scheme
    // after the first in a surah's chain, `rebuildFromJournal` overwrites the
    // baseline with the previous scheme's final state. So those values are
    // derived on the receiving device, and only the *first* scheme's baseline
    // is stored input that nothing could recompute.
    await applyIn(upsertOf(split()));

    final stored = (await activeSchemes()).single;
    expect(
      stored.baselineScore,
      0,
      reason:
          'carried from the default scheme, which has no recitations behind '
          'it — not the 2 the payload carried',
    );
    expect(stored.baselineTotalRecitations, 0);
  });

  test('the scheme it replaces is stood down, not deleted', () async {
    await applyIn(upsertOf(split()));

    final all = await database.select(database.rotationSchemes).get();
    expect(all, hasLength(2), reason: 'the default from addMastered survives');
    expect(
      all.where((row) => row.supersededJournalSequence == null),
      hasLength(1),
      reason:
          'the partial unique index allows exactly one, and so does the '
          'projection, which reads it with getSingle()',
    );
  });

  test('the parts carry their ids, so coverage still points at them', () async {
    await applyIn(upsertOf(split()));

    final parts =
        await (database.select(database.rotationParts)..where(
              (RotationParts row) => row.schemeId.equals('surah-112:scheme:2'),
            ))
            .get();
    expect(<String>[for (final part in parts) part.id]..sort(), <String>[
      'surah-112:scheme:2:part:1',
      'surah-112:scheme:2:part:2',
    ]);
    expect(parts.every((part) => part.cachedRecitationCount == 0), isTrue);
  });

  test('applying it twice changes nothing', () async {
    final envelope = upsertOf(split());
    await applyIn(envelope);

    await applyIn(envelope);

    expect(await activeSchemes(), hasLength(1));
    expect(
      await (database.select(database.rotationParts)..where(
            (RotationParts row) => row.schemeId.equals('surah-112:scheme:2'),
          ))
          .get(),
      hasLength(2),
    );
  });

  test(
    'standing one down alone would orphan the surah, so it does not',
    () async {
      // The default scheme, arriving as superseded, with nothing yet to replace
      // it. Obeying blindly would leave the surah with no scheme in force and the
      // projection's getSingle() would throw on the next read.
      await applyIn(
        upsertOf(
          RotationSchemeSyncRecord(
            id: 'surah-112:scheme:1',
            surahId: 'surah-112',
            version: 1,
            ayahCountSnapshot: 4,
            baselineScore: 0,
            baselineTotalRecitations: 0,
            isActive: false,
            parts: <RotationSchemeSyncPart>[
              RotationSchemeSyncPart(
                id: 'surah-112:scheme:1:part:1',
                ordinal: 1,
                startAyah: 1,
                endAyah: 4,
              ),
            ],
          ),
        ),
      );

      expect(
        await activeSchemes(),
        hasLength(1),
        reason:
            'it stays in force until its successor arrives, which is '
            'self-healing rather than a window with none',
      );
      await expectLater(surahs.getRotationSnapshot(), completes);
    },
  );

  test('a covered part is never dropped', () async {
    await recitations.register(
      SurahRecitationEvent(
        id: 'event-1',
        surahId: 'surah-112',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr),
        createdAtUtc: DateTime.utc(2026, 9, 18, 3),
        localDate: LocalDate(2026, 9, 18),
        rakaatSpanCount: 1,
      ),
    );

    // The same scheme id the recitation covered, but with its parts replaced.
    await expectLater(
      () => applyIn(
        upsertOf(
          RotationSchemeSyncRecord(
            id: 'surah-112:scheme:1',
            surahId: 'surah-112',
            version: 1,
            ayahCountSnapshot: 4,
            baselineScore: 0,
            baselineTotalRecitations: 0,
            isActive: true,
            parts: <RotationSchemeSyncPart>[
              RotationSchemeSyncPart(
                id: 'surah-112:scheme:1:part:renamed',
                ordinal: 1,
                startAyah: 1,
                endAyah: 4,
              ),
            ],
          ),
        ),
      ),
      refuses('remote-scheme-drops-a-covered-part'),
      reason:
          'removing it would orphan the coverage the rotation balance is '
          'built from; re-splitting makes a new version instead',
    );
  });

  test(
    'a scheme for a surah not in the roster is refused, retryably',
    () async {
      await expectLater(
        () => applyIn(
          upsertOf(
            RotationSchemeSyncRecord(
              id: 'surah-108:scheme:1',
              surahId: 'surah-108',
              version: 1,
              ayahCountSnapshot: 3,
              baselineScore: 0,
              baselineTotalRecitations: 0,
              isActive: true,
              parts: <RotationSchemeSyncPart>[
                RotationSchemeSyncPart(
                  id: 'surah-108:scheme:1:part:1',
                  ordinal: 1,
                  startAyah: 1,
                  endAyah: 3,
                ),
              ],
            ),
          ),
        ),
        refuses('remote-scheme-surah-not-in-roster'),
      );
    },
  );

  test('a scheme is never deleted', () async {
    await expectLater(
      () => applyIn(
        SyncEnvelope(
          id: 'envelope-gone',
          deviceId: 'other-device',
          entityType: SyncEntityType.rotationScheme,
          entityId: 'surah-112:scheme:1',
          operation: SyncOperation.delete,
          schemaVersion: 10,
          createdAtUtc: DateTime.utc(2026, 9, 18, 9),
          updatedAtUtc: DateTime.utc(2026, 9, 18, 9),
          idempotencyKey: 'key-gone',
        ),
      ),
      refuses('remote-scheme-cannot-be-deleted'),
      reason:
          'recitations reference it and the schema refuses; "removing" a split '
          'means choosing a different one',
    );
  });

  group('one split under two names', () {
    /// The default scheme of surah 112 as an **older** build named it, which is
    /// how his account holds every one of his: `v1:` in front. The local row is
    /// `surah-112:scheme:1`, the same split under this build's name.
    RotationSchemeSyncRecord underTheOtherName({
      int endAyah = 4,
      int partCount = 1,
    }) => RotationSchemeSyncRecord(
      id: 'v1:surah-112:scheme:1',
      surahId: 'surah-112',
      version: 1,
      ayahCountSnapshot: 4,
      baselineScore: 0,
      baselineTotalRecitations: 0,
      isActive: true,
      parts: <RotationSchemeSyncPart>[
        RotationSchemeSyncPart(
          id: 'v1:surah-112:scheme:1:part:1',
          ordinal: 1,
          startAyah: 1,
          endAyah: endAyah,
        ),
        if (partCount > 1)
          RotationSchemeSyncPart(
            id: 'v1:surah-112:scheme:1:part:2',
            ordinal: 2,
            startAyah: endAyah + 1,
            endAyah: 4,
          ),
      ],
    );

    Future<void> recite() => recitations.register(
      SurahRecitationEvent(
        id: 'event-held',
        surahId: 'surah-112',
        prayerContext: PrayerContext(prayerType: PrayerType.fajr),
        createdAtUtc: DateTime.utc(2026, 9, 18, 3),
        localDate: LocalDate(2026, 9, 18),
        rakaatSpanCount: 1,
      ),
    );

    test('an unreferenced local copy gives way to the account\'s', () async {
      await applyIn(upsertOf(underTheOtherName()));

      final active = await activeSchemes();
      expect(active, hasLength(1));
      expect(
        active.single.id,
        'v1:surah-112:scheme:1',
        reason:
            'the local row was a placeholder this device derived, and his '
            'recitations name the account\'s id',
      );
    });

    test('a referenced local copy is kept, and the arriving one is '
        'recognised as itself', () async {
      await recite();

      await expectLater(
        applyIn(upsertOf(underTheOtherName())),
        completes,
        reason:
            'refusing here stalled the pull forever: the cursor never moved, '
            'the same page came back, and both of his phones would have '
            'stopped receiving anything at all',
      );

      final active = await activeSchemes();
      expect(active, hasLength(1));
      expect(
        active.single.id,
        'surah-112:scheme:1',
        reason: 'the row his recitations point at is the one that stays',
      );
      expect(
        await (database.select(database.rotationSchemes)..where(
              (RotationSchemes row) => row.surahId.equals('surah-112'),
            ))
            .get(),
        hasLength(1),
        reason: 'and it is not joined by a second copy of itself',
      );
      await expectLater(surahs.getRotationSnapshot(), completes);
    });

    test('a genuinely different split under the same version is still '
        'refused', () async {
      await recite();

      await expectLater(
        () => applyIn(upsertOf(underTheOtherName(endAyah: 2, partCount: 2))),
        refuses('remote-scheme-version-already-used'),
        reason:
            'two real splits claiming one version number is a conflict, and '
            'quietly dropping either is the loss this feature prevents',
      );
    });
  });
}
