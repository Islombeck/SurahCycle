import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Deleting a recitation used to be final. It is not a destructive write —
/// the row stays, carrying `deleted_at_utc` — but nothing in the app could put
/// it back, so a mis-tap in History cost a real recitation permanently. It cost
/// the owner two.
///
/// These tests are about the one property that makes a restore trustworthy: it
/// is the mirror image of the deletion, reusing the same reconciliation and the
/// same projection rebuild, so the balance it lands on is the balance that
/// would have been there had the deletion never happened.
void main() {
  late AppDatabase database;
  late SurahRepository surahs;
  late RecitationRepository recitations;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    surahs = SurahRepository(database);
    recitations = RecitationRepository(database);
    await surahs.upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'test-a',
          surahNumber: 2,
          officialName: 'Test A',
          ayahCount: 3,
        ),
        SurahDescriptor(
          id: 'test-b',
          surahNumber: 3,
          officialName: 'Test B',
          ayahCount: 3,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
    await surahs.addMastered('test-a');
    await surahs.addMastered('test-b');
  });

  tearDown(() => database.close());

  SurahRecitationEvent event(String id, String surahId, int hour) =>
      SurahRecitationEvent(
        id: id,
        surahId: surahId,
        prayerContext: PrayerContext(prayerType: PrayerType.asr),
        createdAtUtc: DateTime.utc(2026, 9, 17, hour),
        localDate: LocalDate(2026, 9, 17),
        rakaatSpanCount: 1,
      );

  test('a restored entry lands on exactly the pre-deletion balance', () async {
    final first = event('00000000-0000-4000-8000-000000000001', 'test-a', 10);
    final second = event('00000000-0000-4000-8000-000000000002', 'test-b', 11);
    await recitations.register(first);
    await recitations.register(second);
    final beforeDeletion = await surahs.getRotationSnapshot();

    await recitations.deleteRecitation(
      first.id,
      deletedAtUtc: DateTime.utc(2026, 9, 17, 12),
    );
    expect(
      (await surahs.getRotationSnapshot()).surahById('test-a').totalRecitations,
      0,
    );

    final restored = await recitations.restoreRecitation(first.id);

    expect(restored.didRestore, isTrue);
    expect(
      await surahs.getRotationSnapshot(),
      beforeDeletion,
      reason:
          'the balance is rebuilt from the journal, not patched back by hand, '
          'so it has to be identical rather than merely close',
    );
    expect((await recitations.getStats()).total, 2);
  });

  test('it comes back as the same recitation, not a new one', () async {
    final original = event(
      '00000000-0000-4000-8000-000000000003',
      'test-a',
      10,
    );
    final registration = await recitations.register(original);
    final sequence = registration.event;
    await recitations.deleteRecitation(
      original.id,
      deletedAtUtc: DateTime.utc(2026, 9, 18, 9),
    );

    await recitations.restoreRecitation(original.id);

    final entry = (await recitations.getHistory()).single;
    expect(entry.event.id, original.id);
    expect(
      entry.event.localDate,
      LocalDate(2026, 9, 17),
      reason:
          'the day it belongs to is the day it was prayed, not the day it was '
          'put back — a restore that re-dated it would move a prayer',
    );
    expect(entry.event.createdAtUtc, sequence.createdAtUtc);
    expect(entry.event.prayerContext.prayerType, PrayerType.asr);
    expect(entry.isDeleted, isFalse);
  });

  test('history hides a deleted entry unless asked for it', () async {
    final only = event('00000000-0000-4000-8000-000000000004', 'test-a', 10);
    await recitations.register(only);
    await recitations.deleteRecitation(
      only.id,
      deletedAtUtc: DateTime.utc(2026, 9, 18, 9),
    );

    expect(
      await recitations.getHistory(),
      isEmpty,
      reason: 'the default must never leak a withdrawn entry into a count',
    );

    final withDeleted = await recitations.getHistory(includeDeleted: true);
    expect(withDeleted, hasLength(1));
    expect(withDeleted.single.isDeleted, isTrue);
    expect(
      withDeleted.single.deletedAtUtc,
      DateTime.utc(2026, 9, 18, 9),
      reason: 'the screen offering to undo this needs to say when it happened',
    );
    expect(
      (await recitations.getStats()).total,
      0,
      reason: 'statistics are a separate path and must stay unaffected',
    );
  });

  test('restoring twice is a no-op, not a second restoration', () async {
    final only = event('00000000-0000-4000-8000-000000000005', 'test-a', 10);
    await recitations.register(only);
    await recitations.deleteRecitation(
      only.id,
      deletedAtUtc: DateTime.utc(2026, 9, 18, 9),
    );
    await recitations.restoreRecitation(only.id);

    final second = await recitations.restoreRecitation(only.id);

    expect(second.didRestore, isFalse);
    expect(
      (await recitations.getStats()).total,
      1,
      reason: 'a double tap must not count the recitation twice',
    );
  });

  test('an unknown id restores nothing rather than guessing', () async {
    final result = await recitations.restoreRecitation(
      '00000000-0000-4000-8000-00000000ffff',
    );

    expect(result.didRestore, isFalse);
    expect(await recitations.getHistory(), isEmpty);
  });

  test('a deleted entry stops blocking its own rotation part', () async {
    // The part coverage is what the rotation balance is built from, so a
    // restore that forgot it would leave the surah scored as if the recitation
    // had never come back.
    final only = event('00000000-0000-4000-8000-000000000006', 'test-a', 10);
    await recitations.register(only);
    final scored = (await surahs.getRotationSnapshot())
        .surahById('test-a')
        .rotationScore;
    await recitations.deleteRecitation(
      only.id,
      deletedAtUtc: DateTime.utc(2026, 9, 18, 9),
    );

    await recitations.restoreRecitation(only.id);

    final entry = (await recitations.getHistory()).single;
    expect(entry.coveredParts, isNotEmpty);
    expect(
      (await surahs.getRotationSnapshot()).surahById('test-a').rotationScore,
      scored,
    );
  });
}
