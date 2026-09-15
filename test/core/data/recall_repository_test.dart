import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';

/// The recall journal must keep exactly what happened, in order, and must not
/// offer any way to rewrite it.
void main() {
  late AppDatabase database;
  late RecallRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = RecallRepository(database);
    await SurahRepository(database).upsertCatalog(
      <SurahDescriptor>[
        SurahDescriptor(
          id: 'surah-112',
          surahNumber: 112,
          officialName: 'Test 112',
          ayahCount: 4,
        ),
        SurahDescriptor(
          id: 'surah-113',
          surahNumber: 113,
          officialName: 'Test 113',
          ayahCount: 5,
        ),
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
  });

  tearDown(() => database.close());

  RecallAttempt attemptOf({
    required String id,
    String surahId = 'surah-112',
    int ayah = 1,
    RecallResult result = RecallResult.recalled,
    int minute = 0,
    RecallSource source = RecallSource.learning,
    int learningCycle = 1,
  }) => RecallAttempt(
    id: id,
    surahId: surahId,
    ayahStart: ayah,
    ayahEnd: ayah,
    learningCycle: learningCycle,
    result: result,
    createdAtUtc: DateTime.utc(2026, 9, 15, 5, minute),
    localDate: LocalDate(2026, 9, 15),
    source: source,
  );

  test('an appended attempt comes back exactly as it was written', () async {
    final attempt = attemptOf(
      id: 'attempt-1',
      ayah: 3,
      result: RecallResult.recalledWithMistake,
      source: RecallSource.surah,
      learningCycle: 2,
    );

    await repository.append(attempt);

    expect(await repository.getHistory(), <RecallAttempt>[attempt]);
  });

  test('history is newest first', () async {
    await repository.append(attemptOf(id: 'a', minute: 1));
    await repository.append(attemptOf(id: 'b', minute: 2));
    await repository.append(attemptOf(id: 'c', minute: 3));

    expect(
      (await repository.getHistory()).map((attempt) => attempt.id),
      <String>['c', 'b', 'a'],
    );
  });

  test('history can be scoped to one surah', () async {
    await repository.append(attemptOf(id: 'a', surahId: 'surah-112'));
    await repository.append(attemptOf(id: 'b', surahId: 'surah-113'));

    expect(
      (await repository.getHistory(
        surahId: 'surah-113',
      )).map((attempt) => attempt.id),
      <String>['b'],
    );
  });

  test('a repeated id is refused instead of overwriting', () async {
    await repository.append(attemptOf(id: 'attempt-1'));

    await expectLater(
      repository.append(
        attemptOf(id: 'attempt-1', result: RecallResult.notRecalled),
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      (await repository.getHistory()).single.result,
      RecallResult.recalled,
      reason: 'the original attempt must survive the rejected write',
    );
  });

  test('an attempt for an unknown surah is refused', () async {
    await expectLater(
      repository.append(attemptOf(id: 'attempt-1', surahId: 'surah-missing')),
      throwsA(isA<Exception>()),
    );
  });

  test('summaries count every result kind per surah', () async {
    await repository.append(attemptOf(id: 'a', minute: 1));
    await repository.append(
      attemptOf(id: 'b', minute: 2, result: RecallResult.recalledWithMistake),
    );
    await repository.append(
      attemptOf(id: 'c', minute: 3, result: RecallResult.notRecalled),
    );
    await repository.append(
      attemptOf(id: 'd', minute: 4, result: RecallResult.notRecalled),
    );
    await repository.append(
      attemptOf(id: 'e', minute: 9, surahId: 'surah-113'),
    );

    final summaries = await repository.getSummaries();

    expect(summaries.keys.toSet(), <String>{'surah-112', 'surah-113'});
    final first = summaries['surah-112']!;
    expect(first.recalled, 1);
    expect(first.recalledWithMistake, 1);
    expect(first.notRecalled, 2);
    expect(first.total, 4);
    expect(first.imperfect, 3);
    expect(first.lastAttemptAtUtc, DateTime.utc(2026, 9, 15, 5, 4));
    expect(summaries['surah-113']!.total, 1);
  });

  test('summaries are empty before anything is checked', () async {
    expect(await repository.getSummaries(), isEmpty);
  });

  test('the review flag follows the latest check, not the worst one', () async {
    await repository.append(
      attemptOf(id: 'a', minute: 1, result: RecallResult.notRecalled),
    );

    var summaries = await repository.getSummaries();
    expect(summaries['surah-112']!.lastResult, RecallResult.notRecalled);
    expect(summaries['surah-112']!.needsReview, isTrue);

    await repository.append(attemptOf(id: 'b', minute: 2));

    summaries = await repository.getSummaries();
    expect(summaries['surah-112']!.lastResult, RecallResult.recalled);
    expect(
      summaries['surah-112']!.needsReview,
      isFalse,
      reason: 'one clean check must undo the nudge',
    );
    expect(
      summaries['surah-112']!.notRecalled,
      1,
      reason: 'the history itself is never rewritten',
    );
  });

  test('a mistake after a clean check raises the flag again', () async {
    await repository.append(attemptOf(id: 'a', minute: 1));
    await repository.append(
      attemptOf(id: 'b', minute: 2, result: RecallResult.recalledWithMistake),
    );

    final summary = (await repository.getSummaries())['surah-112']!;
    expect(summary.lastResult, RecallResult.recalledWithMistake);
    expect(summary.needsReview, isTrue);
  });

  test('each surah keeps its own review flag', () async {
    await repository.append(
      attemptOf(id: 'a', result: RecallResult.notRecalled),
    );
    await repository.append(attemptOf(id: 'b', surahId: 'surah-113'));

    final summaries = await repository.getSummaries();
    expect(summaries['surah-112']!.needsReview, isTrue);
    expect(summaries['surah-113']!.needsReview, isFalse);
  });

  test('watching history emits after every append', () async {
    final seen = <int>[];
    final subscription = repository.watchHistory().listen(
      (attempts) => seen.add(attempts.length),
    );
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    await repository.append(attemptOf(id: 'a', minute: 1));
    await pumpEventQueue();
    await repository.append(attemptOf(id: 'b', minute: 2));
    await pumpEventQueue();

    expect(seen.last, 2);
    expect(seen.first, 0);
  });
}
