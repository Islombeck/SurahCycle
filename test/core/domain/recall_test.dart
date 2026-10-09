import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

/// The recall mode is a self-check: the user tries to remember, then reveals
/// the exact text, then grades themselves. These tests pin the order, because
/// a grade recorded before the reveal would carry no information at all.
void main() {
  RecallSession sessionOf({int start = 1, int end = 3}) => RecallSession(
    surahId: 'surah-112',
    surahNumber: 112,
    ayahStart: start,
    ayahEnd: end,
  );

  RecallAttempt gradeOf(
    RecallSession session, {
    RecallResult result = RecallResult.recalled,
    String id = 'attempt-1',
  }) => session.grade(
    result: result,
    id: id,
    learningCycle: 1,
    createdAtUtc: DateTime.utc(2026, 9, 15, 5),
    localDate: LocalDate(2026, 9, 15),
    source: RecallSource.learning,
  );

  group('reveal gate', () {
    test('a fresh step hides the text', () {
      final session = sessionOf();

      expect(session.isRevealed, isFalse);
      expect(session.canGrade, isFalse);
    });

    test('grading before the reveal is refused', () {
      final session = sessionOf();

      expect(() => gradeOf(session), throwsStateError);
    });

    test('grading is allowed once the ayah is revealed', () {
      final session = sessionOf().reveal();

      expect(session.canGrade, isTrue);
      final attempt = gradeOf(session);
      expect(attempt.ayahStart, 1);
      expect(attempt.ayahEnd, 1);
      expect(attempt.result, RecallResult.recalled);
    });

    test('advancing hides the text again', () {
      final session = sessionOf().reveal().advance();

      expect(session.currentAyah, 2);
      expect(session.isRevealed, isFalse);
      expect(() => gradeOf(session), throwsStateError);
    });

    test('grading does not advance on its own', () {
      final session = sessionOf().reveal();

      gradeOf(session);

      expect(
        session.currentAyah,
        1,
        reason: 'the session is immutable; the caller advances explicitly',
      );
    });
  });

  group('range walk', () {
    test('the range completes after the last ayah', () {
      var session = sessionOf(start: 2, end: 4);

      expect(session.totalAyahCount, 3);
      for (var index = 0; index < 3; index += 1) {
        expect(session.isComplete, isFalse);
        expect(session.completedAyahCount, index);
        session = session.reveal().advance();
      }

      expect(session.isComplete, isTrue);
      expect(session.completedAyahCount, 3);
      expect(session.canGrade, isFalse);
    });

    test('a finished range cannot be graded or advanced further', () {
      final session = sessionOf(start: 1, end: 1).reveal().advance();

      expect(session.isComplete, isTrue);
      expect(() => gradeOf(session), throwsStateError);
      expect(session.reveal(), session, reason: 'reveal is a no-op when done');
      expect(session.advance(), session);
    });

    test('a single-ayah range is valid', () {
      final session = sessionOf(start: 7, end: 7);

      expect(session.totalAyahCount, 1);
      expect(session.currentAyah, 7);
    });

    test('a resumed session keeps its position and hidden state', () {
      final session = RecallSession(
        surahId: 'surah-2',
        surahNumber: 2,
        ayahStart: 10,
        ayahEnd: 20,
        currentAyah: 15,
        isRevealed: true,
      );

      expect(session.currentAyah, 15);
      expect(session.canGrade, isTrue);
      expect(session.completedAyahCount, 5);
    });
  });

  group('range coordinates', () {
    test('a reversed range is refused', () {
      expect(
        () => RecallSession(
          surahId: 'surah-112',
          surahNumber: 112,
          ayahStart: 4,
          ayahEnd: 2,
        ),
        throwsArgumentError,
      );
    });

    test('an ayah before the first one is refused', () {
      expect(
        () => RecallSession(
          surahId: 'surah-112',
          surahNumber: 112,
          ayahStart: 0,
          ayahEnd: 2,
        ),
        throwsArgumentError,
      );
    });

    test('a position outside the range is refused', () {
      expect(
        () => RecallSession(
          surahId: 'surah-112',
          surahNumber: 112,
          ayahStart: 2,
          ayahEnd: 4,
          currentAyah: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => RecallSession(
          surahId: 'surah-112',
          surahNumber: 112,
          ayahStart: 2,
          ayahEnd: 4,
          currentAyah: 6,
        ),
        throwsArgumentError,
      );
    });

    test('a surah number outside the mushaf is refused', () {
      expect(
        () => RecallSession(
          surahId: 'surah-x',
          surahNumber: 115,
          ayahStart: 1,
          ayahEnd: 1,
        ),
        throwsArgumentError,
      );
    });

    test('the attempt carries the exact ayah it graded', () {
      final session = sessionOf(start: 5, end: 9).reveal().advance();
      final attempt = gradeOf(session.reveal());

      expect(attempt.ayahStart, 6);
      expect(attempt.ayahEnd, 6);
      expect(attempt.surahId, 'surah-112');
    });
  });

  group('attempt invariants', () {
    test('a local timestamp is refused', () {
      final session = sessionOf().reveal();

      expect(
        () => session.grade(
          result: RecallResult.recalled,
          id: 'attempt-1',
          learningCycle: 1,
          createdAtUtc: DateTime(2026, 9, 15, 5),
          localDate: LocalDate(2026, 9, 15),
          source: RecallSource.learning,
        ),
        throwsArgumentError,
      );
    });

    test('an empty id is refused', () {
      final session = sessionOf().reveal();

      expect(() => gradeOf(session, id: ''), throwsArgumentError);
    });

    test('every result is representable', () {
      final session = sessionOf().reveal();

      for (final result in RecallResult.values) {
        expect(gradeOf(session, result: result).result, result);
      }
    });

    test('attempts compare by value', () {
      final session = sessionOf().reveal();

      expect(gradeOf(session), gradeOf(session));
      expect(gradeOf(session).hashCode, gradeOf(session).hashCode);
      expect(
        gradeOf(session),
        isNot(gradeOf(session, result: RecallResult.notRecalled)),
      );
    });
  });
}
