import 'rotation.dart';
import 'surah.dart';
import 'time_provider.dart';
import 'undo_outcome.dart';

const Object _learningNotProvided = Object();

enum LearningStageKind { newAyah, cumulative }

/// One item in the deterministic learning sequence.
final class LearningStage {
  factory LearningStage.newAyah(int ayahNumber) {
    if (ayahNumber <= 0) {
      throw ArgumentError.value(ayahNumber, 'ayahNumber', 'Must be positive.');
    }
    return LearningStage._(
      kind: LearningStageKind.newAyah,
      endAyah: ayahNumber,
    );
  }

  factory LearningStage.cumulative(int endAyah) {
    if (endAyah <= 0) {
      throw ArgumentError.value(endAyah, 'endAyah', 'Must be positive.');
    }
    return LearningStage._(
      kind: LearningStageKind.cumulative,
      endAyah: endAyah,
    );
  }

  const LearningStage._({required this.kind, required this.endAyah});

  final LearningStageKind kind;
  final int endAyah;

  int get startAyah => kind == LearningStageKind.cumulative ? 1 : endAyah;
  int get ayahNumber => endAyah;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningStage && kind == other.kind && endAyah == other.endAyah;

  @override
  int get hashCode => Object.hash(kind, endAyah);

  @override
  String toString() => kind == LearningStageKind.newAyah
      ? 'NEW_AYAH($endAyah)'
      : 'CUMULATIVE(1..$endAyah)';
}

enum LearningStatus { active, completed }

/// Independent learning progress for one selected surah.
final class LearningSurahState {
  factory LearningSurahState({
    required String id,
    required String surahId,
    required int ayahCount,
    required LearningStage stage,
    LearningStatus status = LearningStatus.active,
    DateTime? lastLearningActivityAtUtc,
    DateTime? inactivityRollbackForActivityAtUtc,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (ayahCount <= 0) {
      throw ArgumentError.value(ayahCount, 'ayahCount', 'Must be positive.');
    }
    if (stage.endAyah > ayahCount) {
      throw ArgumentError.value(
        stage,
        'stage',
        'Stage exceeds the supplied verified ayah count.',
      );
    }
    _requireUtcOrNull(lastLearningActivityAtUtc, 'lastLearningActivityAtUtc');
    _requireUtcOrNull(
      inactivityRollbackForActivityAtUtc,
      'inactivityRollbackForActivityAtUtc',
    );
    return LearningSurahState._(
      id: id,
      surahId: surahId,
      ayahCount: ayahCount,
      stage: stage,
      status: status,
      lastLearningActivityAtUtc: lastLearningActivityAtUtc,
      inactivityRollbackForActivityAtUtc: inactivityRollbackForActivityAtUtc,
    );
  }

  const LearningSurahState._({
    required this.id,
    required this.surahId,
    required this.ayahCount,
    required this.stage,
    required this.status,
    required this.lastLearningActivityAtUtc,
    required this.inactivityRollbackForActivityAtUtc,
  });

  final String id;
  final String surahId;
  final int ayahCount;
  final LearningStage stage;
  final LearningStatus status;
  final DateTime? lastLearningActivityAtUtc;

  /// Identifies the activity timestamp for which inactivity was already
  /// handled. It prevents multiple rollbacks during one continuous period.
  final DateTime? inactivityRollbackForActivityAtUtc;

  bool get isCompleted => status == LearningStatus.completed;

  LearningSurahState copyWith({
    LearningStage? stage,
    LearningStatus? status,
    Object? lastLearningActivityAtUtc = _learningNotProvided,
    Object? inactivityRollbackForActivityAtUtc = _learningNotProvided,
  }) => LearningSurahState(
    id: id,
    surahId: surahId,
    ayahCount: ayahCount,
    stage: stage ?? this.stage,
    status: status ?? this.status,
    lastLearningActivityAtUtc:
        identical(lastLearningActivityAtUtc, _learningNotProvided)
        ? this.lastLearningActivityAtUtc
        : lastLearningActivityAtUtc as DateTime?,
    inactivityRollbackForActivityAtUtc:
        identical(inactivityRollbackForActivityAtUtc, _learningNotProvided)
        ? this.inactivityRollbackForActivityAtUtc
        : inactivityRollbackForActivityAtUtc as DateTime?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningSurahState &&
          id == other.id &&
          surahId == other.surahId &&
          ayahCount == other.ayahCount &&
          stage == other.stage &&
          status == other.status &&
          lastLearningActivityAtUtc == other.lastLearningActivityAtUtc &&
          inactivityRollbackForActivityAtUtc ==
              other.inactivityRollbackForActivityAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    ayahCount,
    stage,
    status,
    lastLearningActivityAtUtc,
    inactivityRollbackForActivityAtUtc,
  );
}

void _requireUtcOrNull(DateTime? value, String name) {
  if (value != null && !value.isUtc) {
    throw ArgumentError.value(value, name, 'Must be UTC.');
  }
}

enum LearningEventType { repeated, learned, inactivityRollback, completed }

/// Auditable fact emitted by a learning transition.
final class LearningEvent {
  factory LearningEvent({
    required String id,
    required String learningSurahId,
    required LearningEventType type,
    required DateTime createdAtUtc,
    required LearningStage fromStage,
    required LearningStage toStage,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (learningSurahId.isEmpty) {
      throw ArgumentError.value(
        learningSurahId,
        'learningSurahId',
        'Must not be empty.',
      );
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    return LearningEvent._(
      id: id,
      learningSurahId: learningSurahId,
      type: type,
      createdAtUtc: createdAtUtc,
      fromStage: fromStage,
      toStage: toStage,
    );
  }

  const LearningEvent._({
    required this.id,
    required this.learningSurahId,
    required this.type,
    required this.createdAtUtc,
    required this.fromStage,
    required this.toStage,
  });

  final String id;
  final String learningSurahId;
  final LearningEventType type;
  final DateTime createdAtUtc;
  final LearningStage fromStage;
  final LearningStage toStage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningEvent &&
          id == other.id &&
          learningSurahId == other.learningSurahId &&
          type == other.type &&
          createdAtUtc == other.createdAtUtc &&
          fromStage == other.fromStage &&
          toStage == other.toStage;

  @override
  int get hashCode =>
      Object.hash(id, learningSurahId, type, createdAtUtc, fromStage, toStage);
}

final class LearningActionOutcome {
  const LearningActionOutcome({
    required this.previousState,
    required this.state,
    required this.completionRequired,
    this.event,
  });

  final LearningSurahState previousState;
  final LearningSurahState state;
  final LearningEvent? event;
  final bool completionRequired;

  bool get didChangeStage => previousState.stage != state.stage;
  bool get didRollback => event?.type == LearningEventType.inactivityRollback;
}

/// Deterministic state machine for NEW_AYAH/CUMULATIVE learning stages.
final class LearningStateMachine {
  const LearningStateMachine({required this.timeProvider});

  static const Duration inactivityThreshold = Duration(hours: 72);

  final TimeProvider timeProvider;

  LearningSurahState start({
    required String id,
    required String surahId,
    required int ayahCount,
  }) => LearningSurahState(
    id: id,
    surahId: surahId,
    ayahCount: ayahCount,
    stage: LearningStage.newAyah(1),
    lastLearningActivityAtUtc: _nowUtc(),
  );

  LearningActionOutcome markRepeated(
    LearningSurahState state, {
    required String eventId,
  }) {
    _requireActive(state);
    final now = _nowUtc();
    final updated = state.copyWith(
      lastLearningActivityAtUtc: now,
      inactivityRollbackForActivityAtUtc: null,
    );
    return _outcome(
      previous: state,
      updated: updated,
      eventId: eventId,
      type: LearningEventType.repeated,
      createdAtUtc: now,
    );
  }

  LearningActionOutcome markLearned(
    LearningSurahState state, {
    required String eventId,
  }) {
    _requireActive(state);
    final now = _nowUtc();
    final next = _nextStage(state.stage, ayahCount: state.ayahCount);
    final completionRequired = next == null;
    final updated = state.copyWith(
      stage: next ?? state.stage,
      lastLearningActivityAtUtc: now,
      inactivityRollbackForActivityAtUtc: null,
    );
    return _outcome(
      previous: state,
      updated: updated,
      eventId: eventId,
      type: LearningEventType.learned,
      createdAtUtc: now,
      completionRequired: completionRequired,
    );
  }

  LearningActionOutcome complete(
    LearningSurahState state, {
    required String eventId,
  }) {
    _requireActive(state);
    if (!_isFinalCumulative(state)) {
      throw StateError('The final cumulative stage has not been learned yet.');
    }
    final now = _nowUtc();
    final completed = state.copyWith(
      status: LearningStatus.completed,
      lastLearningActivityAtUtc: now,
      inactivityRollbackForActivityAtUtc: null,
    );
    return _outcome(
      previous: state,
      updated: completed,
      eventId: eventId,
      type: LearningEventType.completed,
      createdAtUtc: now,
    );
  }

  /// Evaluates inactivity without mutating the input state.
  ///
  /// No event is emitted before 72 hours, at the first stage, for completed
  /// learning, or when this same inactivity period was already handled.
  LearningActionOutcome applyInactivityRollback(
    LearningSurahState state, {
    required String rollbackEventId,
  }) {
    final now = _nowUtc();
    final lastActivity = state.lastLearningActivityAtUtc;
    if (state.isCompleted ||
        lastActivity == null ||
        now.isBefore(lastActivity)) {
      return _unchanged(state);
    }
    if (state.inactivityRollbackForActivityAtUtc == lastActivity) {
      return _unchanged(state);
    }
    if (now.difference(lastActivity) < inactivityThreshold) {
      return _unchanged(state);
    }

    final previousStage = _previousStage(state.stage);
    if (previousStage == null) return _unchanged(state);

    final rolledBack = state.copyWith(
      stage: previousStage,
      inactivityRollbackForActivityAtUtc: lastActivity,
    );
    return _outcome(
      previous: state,
      updated: rolledBack,
      eventId: rollbackEventId,
      type: LearningEventType.inactivityRollback,
      createdAtUtc: now,
    );
  }

  /// Restores the stage changed by an action.
  ///
  /// Undoing an inactivity rollback retains its period marker. Otherwise the
  /// same continuous inactivity period would immediately roll back again.
  UndoOutcome<LearningSurahState> undo(LearningActionOutcome outcome) {
    final event = outcome.event;
    if (event == null) {
      return UndoOutcome<LearningSurahState>.nothingToUndo(outcome.state);
    }
    if (event.type == LearningEventType.inactivityRollback) {
      final restored = outcome.previousState.copyWith(
        inactivityRollbackForActivityAtUtc:
            outcome.state.inactivityRollbackForActivityAtUtc,
      );
      return UndoOutcome<LearningSurahState>.restored(
        restored,
        undoneEventId: event.id,
      );
    }
    return UndoOutcome<LearningSurahState>.restored(
      outcome.previousState,
      undoneEventId: event.id,
    );
  }

  LearningActionOutcome _outcome({
    required LearningSurahState previous,
    required LearningSurahState updated,
    required String eventId,
    required LearningEventType type,
    required DateTime createdAtUtc,
    bool completionRequired = false,
  }) => LearningActionOutcome(
    previousState: previous,
    state: updated,
    completionRequired: completionRequired,
    event: LearningEvent(
      id: eventId,
      learningSurahId: previous.id,
      type: type,
      createdAtUtc: createdAtUtc,
      fromStage: previous.stage,
      toStage: updated.stage,
    ),
  );

  LearningActionOutcome _unchanged(LearningSurahState state) =>
      LearningActionOutcome(
        previousState: state,
        state: state,
        completionRequired: false,
      );

  DateTime _nowUtc() {
    final value = timeProvider.nowUtc();
    if (!value.isUtc) {
      throw StateError('TimeProvider.nowUtc() must return a UTC DateTime.');
    }
    return value;
  }

  void _requireActive(LearningSurahState state) {
    if (state.isCompleted) {
      throw StateError('Completed learning progress cannot be advanced.');
    }
  }

  bool _isFinalCumulative(LearningSurahState state) =>
      state.stage.kind == LearningStageKind.cumulative &&
      state.stage.endAyah == state.ayahCount;

  LearningStage? _nextStage(LearningStage current, {required int ayahCount}) {
    if (current.kind == LearningStageKind.newAyah) {
      if (current.endAyah == 1 && ayahCount > 1) {
        return LearningStage.newAyah(2);
      }
      return LearningStage.cumulative(current.endAyah);
    }
    if (current.endAyah == ayahCount) return null;
    return LearningStage.newAyah(current.endAyah + 1);
  }

  LearningStage? _previousStage(LearningStage current) {
    if (current.kind == LearningStageKind.newAyah) {
      if (current.endAyah == 1) return null;
      if (current.endAyah == 2) return LearningStage.newAyah(1);
      return LearningStage.cumulative(current.endAyah - 1);
    }
    return LearningStage.newAyah(current.endAyah);
  }
}

/// Atomic domain result for accepting the completion prompt.
final class LearningCompletionOutcome {
  const LearningCompletionOutcome({
    required this.learning,
    required this.rotationSnapshot,
  });

  final LearningActionOutcome learning;
  final RotationSnapshot rotationSnapshot;

  MasteredSurah get masteredSurah =>
      rotationSnapshot.surahById(learning.state.surahId);
}

/// Coordinates completion with first activation in the mastered rotation.
final class LearningCompletionService {
  const LearningCompletionService({
    required this.learningStateMachine,
    this.rotationEngine = const RotationEngine(),
  });

  final LearningStateMachine learningStateMachine;
  final RotationEngine rotationEngine;

  LearningCompletionOutcome completeAndAddToRotation({
    required LearningSurahState learningState,
    required SurahDescriptor surah,
    required RotationSnapshot rotationSnapshot,
    required String completionEventId,
    int displayOrder = 0,
  }) {
    if (learningState.surahId != surah.id) {
      throw ArgumentError(
        'Learning state and descriptor must reference one surah.',
      );
    }
    if (learningState.ayahCount != surah.ayahCount) {
      throw ArgumentError(
        'Learning state must use the descriptor\'s verified ayah count.',
      );
    }
    final learning = learningStateMachine.complete(
      learningState,
      eventId: completionEventId,
    );
    final rotation = rotationEngine.addMasteredSurah(
      rotationSnapshot,
      surah,
      activate: true,
      displayOrder: displayOrder,
    );
    return LearningCompletionOutcome(
      learning: learning,
      rotationSnapshot: rotation,
    );
  }
}
