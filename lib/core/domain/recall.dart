import 'recitation.dart';

/// How the user graded their own recall once the exact text was revealed.
///
/// This is a self-assessment only. Nothing here inspects or verifies the
/// recitation: the app makes no claim of automatic correctness checking.
enum RecallResult { recalled, recalledWithMistake, notRecalled }

/// Where a check was started from, kept so history stays explainable.
enum RecallSource { learning, surah }

/// An append-only record of one self-check attempt.
///
/// A recall attempt is deliberately *not* a recitation: it never creates,
/// cancels or substitutes a recitation-in-prayer event, and it never affects
/// rotation credit or recitation statistics.
final class RecallAttempt {
  factory RecallAttempt({
    required String id,
    required String surahId,
    required int ayahStart,
    required int ayahEnd,
    required int learningCycle,
    required RecallResult result,
    required DateTime createdAtUtc,
    required LocalDate localDate,
    required RecallSource source,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (ayahStart < 1) {
      throw ArgumentError.value(ayahStart, 'ayahStart', 'Starts at one.');
    }
    if (ayahEnd < ayahStart) {
      throw ArgumentError.value(
        ayahEnd,
        'ayahEnd',
        'Must not precede ayahStart.',
      );
    }
    if (learningCycle < 1) {
      throw ArgumentError.value(learningCycle, 'learningCycle');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    return RecallAttempt._(
      id: id,
      surahId: surahId,
      ayahStart: ayahStart,
      ayahEnd: ayahEnd,
      learningCycle: learningCycle,
      result: result,
      createdAtUtc: createdAtUtc,
      localDate: localDate,
      source: source,
    );
  }

  const RecallAttempt._({
    required this.id,
    required this.surahId,
    required this.ayahStart,
    required this.ayahEnd,
    required this.learningCycle,
    required this.result,
    required this.createdAtUtc,
    required this.localDate,
    required this.source,
  });

  final String id;
  final String surahId;
  final int ayahStart;
  final int ayahEnd;
  final int learningCycle;
  final RecallResult result;
  final DateTime createdAtUtc;
  final LocalDate localDate;
  final RecallSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallAttempt &&
          id == other.id &&
          surahId == other.surahId &&
          ayahStart == other.ayahStart &&
          ayahEnd == other.ayahEnd &&
          learningCycle == other.learningCycle &&
          result == other.result &&
          createdAtUtc == other.createdAtUtc &&
          localDate == other.localDate &&
          source == other.source;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    ayahStart,
    ayahEnd,
    learningCycle,
    result,
    createdAtUtc,
    localDate,
    source,
  );
}

/// Running counts for one pass, shown in the summary at the end.
final class RecallTally {
  const RecallTally({
    this.recalled = 0,
    this.recalledWithMistake = 0,
    this.notRecalled = 0,
  });

  static const RecallTally empty = RecallTally();

  final int recalled;
  final int recalledWithMistake;
  final int notRecalled;

  int get graded => recalled + recalledWithMistake + notRecalled;

  RecallTally add(RecallResult result) => switch (result) {
    RecallResult.recalled => RecallTally(
      recalled: recalled + 1,
      recalledWithMistake: recalledWithMistake,
      notRecalled: notRecalled,
    ),
    RecallResult.recalledWithMistake => RecallTally(
      recalled: recalled,
      recalledWithMistake: recalledWithMistake + 1,
      notRecalled: notRecalled,
    ),
    RecallResult.notRecalled => RecallTally(
      recalled: recalled,
      recalledWithMistake: recalledWithMistake,
      notRecalled: notRecalled + 1,
    ),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallTally &&
          recalled == other.recalled &&
          recalledWithMistake == other.recalledWithMistake &&
          notRecalled == other.notRecalled;

  @override
  int get hashCode => Object.hash(recalled, recalledWithMistake, notRecalled);
}

/// One pass over a chosen range, one ayah at a time.
///
/// The exact text stays hidden until [reveal] is called, and [grade] refuses
/// to produce an attempt before that: the whole point of the mode is to
/// recall first and compare afterwards, so a result recorded before seeing
/// the text would mean nothing.
final class RecallSession {
  factory RecallSession({
    required String surahId,
    required int surahNumber,
    required int ayahStart,
    required int ayahEnd,
    int? currentAyah,
    bool isRevealed = false,
  }) {
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (surahNumber < 1 || surahNumber > 114) {
      throw ArgumentError.value(surahNumber, 'surahNumber');
    }
    if (ayahStart < 1) {
      throw ArgumentError.value(ayahStart, 'ayahStart', 'Starts at one.');
    }
    if (ayahEnd < ayahStart) {
      throw ArgumentError.value(
        ayahEnd,
        'ayahEnd',
        'Must not precede ayahStart.',
      );
    }
    final resolved = currentAyah ?? ayahStart;
    if (resolved < ayahStart || resolved > ayahEnd + 1) {
      throw ArgumentError.value(resolved, 'currentAyah', 'Outside the range.');
    }
    return RecallSession._(
      surahId: surahId,
      surahNumber: surahNumber,
      ayahStart: ayahStart,
      ayahEnd: ayahEnd,
      currentAyah: resolved,
      isRevealed: isRevealed,
    );
  }

  const RecallSession._({
    required this.surahId,
    required this.surahNumber,
    required this.ayahStart,
    required this.ayahEnd,
    required this.currentAyah,
    required this.isRevealed,
  });

  final String surahId;
  final int surahNumber;
  final int ayahStart;
  final int ayahEnd;

  /// One past [ayahEnd] once the range is finished.
  final int currentAyah;
  final bool isRevealed;

  bool get isComplete => currentAyah > ayahEnd;
  bool get canGrade => isRevealed && !isComplete;
  int get totalAyahCount => ayahEnd - ayahStart + 1;
  int get completedAyahCount => currentAyah - ayahStart;

  RecallSession reveal() {
    if (isComplete) return this;
    return RecallSession._(
      surahId: surahId,
      surahNumber: surahNumber,
      ayahStart: ayahStart,
      ayahEnd: ayahEnd,
      currentAyah: currentAyah,
      isRevealed: true,
    );
  }

  /// Moves to the next ayah with the text hidden again.
  RecallSession advance() {
    if (isComplete) return this;
    return RecallSession._(
      surahId: surahId,
      surahNumber: surahNumber,
      ayahStart: ayahStart,
      ayahEnd: ayahEnd,
      currentAyah: currentAyah + 1,
      isRevealed: false,
    );
  }

  /// Produces the attempt for the current ayah.
  ///
  /// Throws unless the text has been revealed, which is the rule that keeps
  /// the mode honest.
  RecallAttempt grade({
    required RecallResult result,
    required String id,
    required int learningCycle,
    required DateTime createdAtUtc,
    required LocalDate localDate,
    required RecallSource source,
  }) {
    if (isComplete) {
      throw StateError('The recall range is already finished.');
    }
    if (!isRevealed) {
      throw StateError('An ayah must be revealed before it can be graded.');
    }
    return RecallAttempt(
      id: id,
      surahId: surahId,
      ayahStart: currentAyah,
      ayahEnd: currentAyah,
      learningCycle: learningCycle,
      result: result,
      createdAtUtc: createdAtUtc,
      localDate: localDate,
      source: source,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallSession &&
          surahId == other.surahId &&
          surahNumber == other.surahNumber &&
          ayahStart == other.ayahStart &&
          ayahEnd == other.ayahEnd &&
          currentAyah == other.currentAyah &&
          isRevealed == other.isRevealed;

  @override
  int get hashCode => Object.hash(
    surahId,
    surahNumber,
    ayahStart,
    ayahEnd,
    currentAyah,
    isRevealed,
  );
}
