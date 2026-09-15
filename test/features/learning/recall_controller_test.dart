import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/application/application.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/learning/application/recall_controller.dart';
import 'package:uuid/uuid.dart';

/// The controller is what the buttons talk to, so it carries the rules the
/// screen must not be able to break.
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
      ],
      sourceId: 'verified-test-source',
      sourceVersion: 'test-v1',
    );
  });

  tearDown(() => database.close());

  RecallController controllerOf({
    RecallRepository? overrideRepository,
    String surahId = 'surah-112',
    int start = 1,
    int end = 3,
  }) {
    final controller = RecallController(
      session: RecallSession(
        surahId: surahId,
        surahNumber: 112,
        ayahStart: start,
        ayahEnd: end,
      ),
      repository: overrideRepository ?? repository,
      timeProvider: const _FixedTimeProvider(),
      localDateProvider: const _FixedLocalDateProvider(),
      uuid: const Uuid(),
      learningCycle: 2,
      source: RecallSource.learning,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('a check starts hidden and ungradable', () {
    final controller = controllerOf();

    expect(controller.state.session.isRevealed, isFalse);
    expect(controller.state.session.canGrade, isFalse);
    expect(controller.state.tally, RecallTally.empty);
  });

  test(
    'grading before the reveal stores nothing and changes nothing',
    () async {
      final controller = controllerOf();
      final before = controller.state;

      await controller.grade(RecallResult.recalled);

      expect(controller.state, before);
      expect(await repository.getHistory(), isEmpty);
    },
  );

  test('a graded ayah is stored and the next one is hidden again', () async {
    final controller = controllerOf();

    controller.reveal();
    await controller.grade(RecallResult.recalledWithMistake);

    final stored = await repository.getHistory();
    expect(stored, hasLength(1));
    expect(stored.single.ayahStart, 1);
    expect(stored.single.ayahEnd, 1);
    expect(stored.single.result, RecallResult.recalledWithMistake);
    expect(stored.single.learningCycle, 2);
    expect(stored.single.source, RecallSource.learning);
    expect(controller.state.session.currentAyah, 2);
    expect(controller.state.session.isRevealed, isFalse);
    expect(controller.state.tally.recalledWithMistake, 1);
  });

  test('skipping records nothing', () async {
    final controller = controllerOf();

    controller.reveal();
    controller.skip();

    expect(controller.state.session.currentAyah, 2);
    expect(controller.state.session.isRevealed, isFalse);
    expect(controller.state.tally, RecallTally.empty);
    expect(await repository.getHistory(), isEmpty);
  });

  test('the tally follows every stored grade', () async {
    final controller = controllerOf();

    for (final result in <RecallResult>[
      RecallResult.recalled,
      RecallResult.notRecalled,
      RecallResult.recalled,
    ]) {
      controller.reveal();
      await controller.grade(result);
    }

    expect(controller.state.session.isComplete, isTrue);
    expect(controller.state.tally.recalled, 2);
    expect(controller.state.tally.notRecalled, 1);
    expect(controller.state.tally.graded, 3);
    expect(await repository.getHistory(), hasLength(3));
  });

  test('a failed write keeps the step in place instead of losing it', () async {
    // A real failure: the surah the check refers to is not in the catalog, so
    // the foreign key rejects the attempt.
    final controller = controllerOf(
      overrideRepository: RecallRepository(database),
      surahId: 'surah-missing',
    );

    controller.reveal();
    await controller.grade(RecallResult.recalled);

    expect(controller.state.saveFailed, isTrue);
    expect(controller.state.isSaving, isFalse);
    expect(
      controller.state.session.currentAyah,
      1,
      reason: 'the user must be able to retry the same ayah',
    );
    expect(controller.state.session.isRevealed, isTrue);
    expect(controller.state.tally, RecallTally.empty);
  });

  test('a later successful write clears the failure', () async {
    final controller = controllerOf();
    controller.reveal();

    await controller.grade(RecallResult.recalled);

    expect(controller.state.saveFailed, isFalse);
  });

  test('a finished check refuses further grades', () async {
    final controller = controllerOf(start: 2, end: 2);

    controller.reveal();
    await controller.grade(RecallResult.recalled);
    expect(controller.state.session.isComplete, isTrue);

    await controller.grade(RecallResult.notRecalled);
    controller.reveal();
    controller.skip();

    expect(await repository.getHistory(), hasLength(1));
    expect(controller.state.tally.graded, 1);
  });

  test('every attempt gets its own id', () async {
    final controller = controllerOf();

    for (var index = 0; index < 3; index += 1) {
      controller.reveal();
      await controller.grade(RecallResult.recalled);
    }

    final stored = await repository.getHistory();
    expect(stored.map((attempt) => attempt.id).toSet(), hasLength(3));
    expect(stored.map((attempt) => attempt.ayahStart).toList(), <int>[3, 2, 1]);
  });
}

final class _FixedTimeProvider implements TimeProvider {
  const _FixedTimeProvider();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 15, 5);
}

final class _FixedLocalDateProvider implements RecitationLocalDateProvider {
  const _FixedLocalDateProvider();

  @override
  LocalDate today() => LocalDate(2026, 9, 15);
}
