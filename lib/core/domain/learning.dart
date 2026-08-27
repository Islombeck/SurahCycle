import 'dart:math' as math;

import 'rotation.dart';
import 'rotation_scheme.dart';
import 'surah.dart';
import 'time_provider.dart';
import 'undo_outcome.dart';

const Object _learningNotProvided = Object();

enum LearningPlanKind { classicCumulative, chunked }

enum LearningStageKind {
  newAyah,
  cumulative,
  reviewRange,
  bridge,
  sectionReview,
  finalReview,
}

/// One immutable item in a deterministic learning plan.
final class LearningStage {
  factory LearningStage.newAyah(
    int ayahNumber, {
    int? blockIndex,
    int sequenceIndex = -1,
  }) => LearningStage._validated(
    kind: LearningStageKind.newAyah,
    startAyah: ayahNumber,
    endAyah: ayahNumber,
    blockIndex: blockIndex,
    sequenceIndex: sequenceIndex,
  );

  /// Backward-compatible name for the classic cumulative review stage.
  factory LearningStage.cumulative(
    int endAyah, {
    int startAyah = 1,
    int sequenceIndex = -1,
  }) => LearningStage._validated(
    kind: LearningStageKind.cumulative,
    startAyah: startAyah,
    endAyah: endAyah,
    sequenceIndex: sequenceIndex,
  );

  factory LearningStage.reviewRange({
    required int startAyah,
    required int endAyah,
    required int blockIndex,
    int sequenceIndex = -1,
  }) => LearningStage._validated(
    kind: LearningStageKind.reviewRange,
    startAyah: startAyah,
    endAyah: endAyah,
    blockIndex: blockIndex,
    sequenceIndex: sequenceIndex,
  );

  factory LearningStage.bridge({
    required int startAyah,
    required int endAyah,
    required int blockIndex,
    int sequenceIndex = -1,
  }) => LearningStage._validated(
    kind: LearningStageKind.bridge,
    startAyah: startAyah,
    endAyah: endAyah,
    blockIndex: blockIndex,
    sequenceIndex: sequenceIndex,
  );

  factory LearningStage.sectionReview({
    required int startAyah,
    required int endAyah,
    required int blockIndex,
    int sequenceIndex = -1,
  }) => LearningStage._validated(
    kind: LearningStageKind.sectionReview,
    startAyah: startAyah,
    endAyah: endAyah,
    blockIndex: blockIndex,
    sequenceIndex: sequenceIndex,
  );

  factory LearningStage.finalReview({
    required int startAyah,
    required int endAyah,
    int sequenceIndex = -1,
  }) => LearningStage._validated(
    kind: LearningStageKind.finalReview,
    startAyah: startAyah,
    endAyah: endAyah,
    sequenceIndex: sequenceIndex,
  );

  factory LearningStage.persisted({
    required LearningStageKind kind,
    required int startAyah,
    required int endAyah,
  }) => LearningStage._validated(
    kind: kind,
    startAyah: startAyah,
    endAyah: endAyah,
  );

  factory LearningStage._validated({
    required LearningStageKind kind,
    required int startAyah,
    required int endAyah,
    int? blockIndex,
    int sequenceIndex = -1,
  }) {
    if (startAyah <= 0) {
      throw ArgumentError.value(startAyah, 'startAyah', 'Must be positive.');
    }
    if (endAyah < startAyah) {
      throw ArgumentError.value(
        endAyah,
        'endAyah',
        'Must not precede startAyah.',
      );
    }
    if (kind == LearningStageKind.newAyah && startAyah != endAyah) {
      throw ArgumentError('A new-ayah stage must contain exactly one ayah.');
    }
    if (blockIndex != null && blockIndex <= 0) {
      throw ArgumentError.value(blockIndex, 'blockIndex', 'Must be positive.');
    }
    if (sequenceIndex < -1) {
      throw ArgumentError.value(
        sequenceIndex,
        'sequenceIndex',
        'Must be -1 or non-negative.',
      );
    }
    return LearningStage._(
      kind: kind,
      startAyah: startAyah,
      endAyah: endAyah,
      blockIndex: blockIndex,
      sequenceIndex: sequenceIndex,
    );
  }

  const LearningStage._({
    required this.kind,
    required this.startAyah,
    required this.endAyah,
    required this.blockIndex,
    required this.sequenceIndex,
  });

  final LearningStageKind kind;
  final int startAyah;
  final int endAyah;
  final int? blockIndex;
  final int sequenceIndex;

  int get ayahNumber => endAyah;

  bool hasSameIdentity(LearningStage other) =>
      kind == other.kind &&
      startAyah == other.startAyah &&
      endAyah == other.endAyah;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningStage && hasSameIdentity(other);

  @override
  int get hashCode => Object.hash(kind, startAyah, endAyah);

  @override
  String toString() => switch (kind) {
    LearningStageKind.newAyah => 'NEW_AYAH($endAyah)',
    LearningStageKind.cumulative => 'CUMULATIVE($startAyah..$endAyah)',
    LearningStageKind.reviewRange => 'REVIEW($startAyah..$endAyah)',
    LearningStageKind.bridge => 'BRIDGE($startAyah..$endAyah)',
    LearningStageKind.sectionReview => 'SECTION_REVIEW($startAyah..$endAyah)',
    LearningStageKind.finalReview => 'FINAL_REVIEW($startAyah..$endAyah)',
  };
}

/// Immutable snapshot of how one learning cycle is organized.
final class LearningPlan {
  factory LearningPlan.classicCumulative({
    required int targetStartAyah,
    required int targetEndAyah,
  }) => LearningPlan._validated(
    kind: LearningPlanKind.classicCumulative,
    targetStartAyah: targetStartAyah,
    targetEndAyah: targetEndAyah,
  );

  factory LearningPlan.chunked({
    required int targetStartAyah,
    required int targetEndAyah,
    required int blockSize,
  }) => LearningPlan._validated(
    kind: LearningPlanKind.chunked,
    targetStartAyah: targetStartAyah,
    targetEndAyah: targetEndAyah,
    blockSize: blockSize,
  );

  factory LearningPlan({
    required LearningPlanKind kind,
    required int targetStartAyah,
    required int targetEndAyah,
    int? blockSize,
  }) => LearningPlan._validated(
    kind: kind,
    targetStartAyah: targetStartAyah,
    targetEndAyah: targetEndAyah,
    blockSize: blockSize,
  );

  factory LearningPlan._validated({
    required LearningPlanKind kind,
    required int targetStartAyah,
    required int targetEndAyah,
    int? blockSize,
  }) {
    if (targetStartAyah <= 0) {
      throw ArgumentError.value(
        targetStartAyah,
        'targetStartAyah',
        'Must be positive.',
      );
    }
    if (targetEndAyah < targetStartAyah) {
      throw ArgumentError.value(
        targetEndAyah,
        'targetEndAyah',
        'Must not precede targetStartAyah.',
      );
    }
    if (kind == LearningPlanKind.chunked &&
        (blockSize == null || blockSize <= 0)) {
      throw ArgumentError.value(
        blockSize,
        'blockSize',
        'Chunked learning requires a positive block size.',
      );
    }
    if (kind == LearningPlanKind.classicCumulative && blockSize != null) {
      throw ArgumentError.value(
        blockSize,
        'blockSize',
        'Classic learning does not use blocks.',
      );
    }
    return LearningPlan._(
      kind: kind,
      targetStartAyah: targetStartAyah,
      targetEndAyah: targetEndAyah,
      blockSize: blockSize,
    );
  }

  const LearningPlan._({
    required this.kind,
    required this.targetStartAyah,
    required this.targetEndAyah,
    required this.blockSize,
  });

  static const int sectionBlockCount = 4;

  final LearningPlanKind kind;
  final int targetStartAyah;
  final int targetEndAyah;
  final int? blockSize;

  int get targetLength => targetEndAyah - targetStartAyah + 1;

  List<LearningStage> get stages => switch (kind) {
    LearningPlanKind.classicCumulative => _classicStages(),
    LearningPlanKind.chunked => _chunkedStages(),
  };

  LearningStage canonicalStage(LearningStage stage) {
    for (final candidate in stages) {
      if (candidate.hasSameIdentity(stage)) return candidate;
    }
    throw ArgumentError.value(stage, 'stage', 'Stage is absent from the plan.');
  }

  int indexOf(LearningStage stage) {
    final values = stages;
    for (var index = 0; index < values.length; index += 1) {
      if (values[index].hasSameIdentity(stage)) return index;
    }
    return -1;
  }

  List<LearningStage> _classicStages() {
    final values = <LearningStage>[];
    void add(LearningStage stage) {
      values.add(
        LearningStage._validated(
          kind: stage.kind,
          startAyah: stage.startAyah,
          endAyah: stage.endAyah,
          sequenceIndex: values.length,
        ),
      );
    }

    add(LearningStage.newAyah(targetStartAyah));
    if (targetLength == 1) {
      add(LearningStage.cumulative(targetEndAyah, startAyah: targetStartAyah));
      return List<LearningStage>.unmodifiable(values);
    }
    add(LearningStage.newAyah(targetStartAyah + 1));
    add(
      LearningStage.cumulative(targetStartAyah + 1, startAyah: targetStartAyah),
    );
    for (var ayah = targetStartAyah + 2; ayah <= targetEndAyah; ayah += 1) {
      add(LearningStage.newAyah(ayah));
      add(LearningStage.cumulative(ayah, startAyah: targetStartAyah));
    }
    return List<LearningStage>.unmodifiable(values);
  }

  List<LearningStage> _chunkedStages() {
    final resolvedBlockSize = blockSize!;
    final values = <LearningStage>[];
    void add(LearningStage stage) {
      values.add(
        LearningStage._validated(
          kind: stage.kind,
          startAyah: stage.startAyah,
          endAyah: stage.endAyah,
          blockIndex: stage.blockIndex,
          sequenceIndex: values.length,
        ),
      );
    }

    var blockIndex = 1;
    for (
      var blockStart = targetStartAyah;
      blockStart <= targetEndAyah;
      blockStart += resolvedBlockSize, blockIndex += 1
    ) {
      final blockEnd = math.min(
        targetEndAyah,
        blockStart + resolvedBlockSize - 1,
      );
      add(LearningStage.newAyah(blockStart, blockIndex: blockIndex));
      if (blockStart == blockEnd) {
        add(
          LearningStage.reviewRange(
            startAyah: blockStart,
            endAyah: blockEnd,
            blockIndex: blockIndex,
          ),
        );
        if (blockIndex > 1) {
          add(
            LearningStage.bridge(
              startAyah: math.max(targetStartAyah, blockStart - 2),
              endAyah: blockEnd,
              blockIndex: blockIndex,
            ),
          );
        }
      } else {
        add(LearningStage.newAyah(blockStart + 1, blockIndex: blockIndex));
        add(
          LearningStage.reviewRange(
            startAyah: blockStart,
            endAyah: blockStart + 1,
            blockIndex: blockIndex,
          ),
        );
        if (blockIndex > 1) {
          add(
            LearningStage.bridge(
              startAyah: math.max(targetStartAyah, blockStart - 2),
              endAyah: blockStart + 1,
              blockIndex: blockIndex,
            ),
          );
        }
        for (var ayah = blockStart + 2; ayah <= blockEnd; ayah += 1) {
          add(LearningStage.newAyah(ayah, blockIndex: blockIndex));
          add(
            LearningStage.reviewRange(
              startAyah: blockStart,
              endAyah: ayah,
              blockIndex: blockIndex,
            ),
          );
        }
      }

      if (blockIndex % sectionBlockCount == 0) {
        final sectionStart = math.max(
          targetStartAyah,
          blockStart - (sectionBlockCount - 1) * resolvedBlockSize,
        );
        add(
          LearningStage.sectionReview(
            startAyah: sectionStart,
            endAyah: blockEnd,
            blockIndex: blockIndex,
          ),
        );
      }
    }
    add(
      LearningStage.finalReview(
        startAyah: targetStartAyah,
        endAyah: targetEndAyah,
      ),
    );
    return List<LearningStage>.unmodifiable(values);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningPlan &&
          kind == other.kind &&
          targetStartAyah == other.targetStartAyah &&
          targetEndAyah == other.targetEndAyah &&
          blockSize == other.blockSize;

  @override
  int get hashCode =>
      Object.hash(kind, targetStartAyah, targetEndAyah, blockSize);
}

enum LearningStatus { active, completed }

/// Independent progress for one surah and its current relearning cycle.
final class LearningSurahState {
  factory LearningSurahState({
    required String id,
    required String surahId,
    required int ayahCount,
    required LearningStage stage,
    LearningPlan? plan,
    int learningCycle = 1,
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
    if (learningCycle <= 0) {
      throw ArgumentError.value(
        learningCycle,
        'learningCycle',
        'Must be positive.',
      );
    }
    final resolvedPlan =
        plan ??
        LearningPlan.classicCumulative(
          targetStartAyah: 1,
          targetEndAyah: ayahCount,
        );
    if (resolvedPlan.targetEndAyah > ayahCount) {
      throw ArgumentError.value(
        resolvedPlan,
        'plan',
        'Target exceeds the verified ayah count.',
      );
    }
    final canonicalStage = resolvedPlan.canonicalStage(stage);
    _requireUtcOrNull(lastLearningActivityAtUtc, 'lastLearningActivityAtUtc');
    _requireUtcOrNull(
      inactivityRollbackForActivityAtUtc,
      'inactivityRollbackForActivityAtUtc',
    );
    return LearningSurahState._(
      id: id,
      surahId: surahId,
      ayahCount: ayahCount,
      plan: resolvedPlan,
      stage: canonicalStage,
      learningCycle: learningCycle,
      status: status,
      lastLearningActivityAtUtc: lastLearningActivityAtUtc,
      inactivityRollbackForActivityAtUtc: inactivityRollbackForActivityAtUtc,
    );
  }

  const LearningSurahState._({
    required this.id,
    required this.surahId,
    required this.ayahCount,
    required this.plan,
    required this.stage,
    required this.learningCycle,
    required this.status,
    required this.lastLearningActivityAtUtc,
    required this.inactivityRollbackForActivityAtUtc,
  });

  final String id;
  final String surahId;
  final int ayahCount;
  final LearningPlan plan;
  final LearningStage stage;
  final int learningCycle;
  final LearningStatus status;
  final DateTime? lastLearningActivityAtUtc;
  final DateTime? inactivityRollbackForActivityAtUtc;

  bool get isCompleted => status == LearningStatus.completed;
  bool get isFullSurahTarget =>
      plan.targetStartAyah == 1 && plan.targetEndAyah == ayahCount;

  LearningSurahState copyWith({
    LearningPlan? plan,
    LearningStage? stage,
    int? learningCycle,
    LearningStatus? status,
    Object? lastLearningActivityAtUtc = _learningNotProvided,
    Object? inactivityRollbackForActivityAtUtc = _learningNotProvided,
  }) => LearningSurahState(
    id: id,
    surahId: surahId,
    ayahCount: ayahCount,
    plan: plan ?? this.plan,
    stage: stage ?? this.stage,
    learningCycle: learningCycle ?? this.learningCycle,
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
          plan == other.plan &&
          stage == other.stage &&
          learningCycle == other.learningCycle &&
          status == other.status &&
          lastLearningActivityAtUtc == other.lastLearningActivityAtUtc &&
          inactivityRollbackForActivityAtUtc ==
              other.inactivityRollbackForActivityAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    ayahCount,
    plan,
    stage,
    learningCycle,
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

enum LearningEventType {
  repeated,
  learned,
  inactivityRollback,
  completed,
  restarted,
  planChanged,
}

/// Auditable fact emitted by a learning transition.
final class LearningEvent {
  factory LearningEvent({
    required String id,
    required String learningSurahId,
    required LearningEventType type,
    required DateTime createdAtUtc,
    required int learningCycle,
    required LearningPlan fromPlan,
    required LearningStage fromStage,
    required LearningPlan toPlan,
    required LearningStage toStage,
    String? reason,
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
    if (learningCycle <= 0) {
      throw ArgumentError.value(learningCycle, 'learningCycle');
    }
    if (reason != null && reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Must be null or non-empty.');
    }
    return LearningEvent._(
      id: id,
      learningSurahId: learningSurahId,
      type: type,
      createdAtUtc: createdAtUtc,
      learningCycle: learningCycle,
      fromPlan: fromPlan,
      fromStage: fromStage,
      toPlan: toPlan,
      toStage: toStage,
      reason: reason,
    );
  }

  const LearningEvent._({
    required this.id,
    required this.learningSurahId,
    required this.type,
    required this.createdAtUtc,
    required this.learningCycle,
    required this.fromPlan,
    required this.fromStage,
    required this.toPlan,
    required this.toStage,
    required this.reason,
  });

  final String id;
  final String learningSurahId;
  final LearningEventType type;
  final DateTime createdAtUtc;
  final int learningCycle;
  final LearningPlan fromPlan;
  final LearningStage fromStage;
  final LearningPlan toPlan;
  final LearningStage toStage;
  final String? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningEvent &&
          id == other.id &&
          learningSurahId == other.learningSurahId &&
          type == other.type &&
          createdAtUtc == other.createdAtUtc &&
          learningCycle == other.learningCycle &&
          fromPlan == other.fromPlan &&
          fromStage == other.fromStage &&
          toPlan == other.toPlan &&
          toStage == other.toStage &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(
    id,
    learningSurahId,
    type,
    createdAtUtc,
    learningCycle,
    fromPlan,
    fromStage,
    toPlan,
    toStage,
    reason,
  );
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

/// Deterministic state machine driven by one generic ordered stage list.
final class LearningStateMachine {
  const LearningStateMachine({required this.timeProvider});

  static const Duration inactivityThreshold = Duration(hours: 72);

  final TimeProvider timeProvider;

  LearningSurahState start({
    required String id,
    required String surahId,
    required int ayahCount,
    LearningPlan? plan,
    int learningCycle = 1,
  }) {
    final resolvedPlan =
        plan ??
        LearningPlan.classicCumulative(
          targetStartAyah: 1,
          targetEndAyah: ayahCount,
        );
    return LearningSurahState(
      id: id,
      surahId: surahId,
      ayahCount: ayahCount,
      plan: resolvedPlan,
      stage: resolvedPlan.stages.first,
      learningCycle: learningCycle,
      lastLearningActivityAtUtc: _nowUtc(),
    );
  }

  LearningActionOutcome restart(
    LearningSurahState state, {
    required LearningPlan plan,
    required String eventId,
    required String reason,
    bool planChanged = false,
  }) {
    final now = _nowUtc();
    final restarted = LearningSurahState(
      id: state.id,
      surahId: state.surahId,
      ayahCount: state.ayahCount,
      plan: plan,
      stage: plan.stages.first,
      learningCycle: state.learningCycle + 1,
      lastLearningActivityAtUtc: now,
    );
    return _outcome(
      previous: state,
      updated: restarted,
      eventId: eventId,
      type: planChanged
          ? LearningEventType.planChanged
          : LearningEventType.restarted,
      createdAtUtc: now,
      reason: reason,
    );
  }

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
    final stages = state.plan.stages;
    final index = state.plan.indexOf(state.stage);
    if (index < 0) throw StateError('Current stage is absent from its plan.');
    final completionRequired = index == stages.length - 1;
    final updated = state.copyWith(
      stage: completionRequired ? state.stage : stages[index + 1],
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
    final index = state.plan.indexOf(state.stage);
    if (index != state.plan.stages.length - 1) {
      throw StateError('The final review stage has not been learned yet.');
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

  /// One continuous inactivity period rolls back at most one ordered stage.
  LearningActionOutcome applyInactivityRollback(
    LearningSurahState state, {
    required String rollbackEventId,
  }) {
    final now = _nowUtc();
    final lastActivity = state.lastLearningActivityAtUtc;
    if (state.isCompleted ||
        lastActivity == null ||
        now.isBefore(lastActivity) ||
        state.inactivityRollbackForActivityAtUtc == lastActivity ||
        now.difference(lastActivity) < inactivityThreshold) {
      return _unchanged(state);
    }
    final index = state.plan.indexOf(state.stage);
    if (index <= 0) return _unchanged(state);
    final rolledBack = state.copyWith(
      stage: state.plan.stages[index - 1],
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
    String? reason,
  }) => LearningActionOutcome(
    previousState: previous,
    state: updated,
    completionRequired: completionRequired,
    event: LearningEvent(
      id: eventId,
      learningSurahId: previous.id,
      type: type,
      createdAtUtc: createdAtUtc,
      learningCycle: updated.learningCycle,
      fromPlan: previous.plan,
      fromStage: previous.stage,
      toPlan: updated.plan,
      toStage: updated.stage,
      reason: reason,
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
}

/// Atomic domain result for accepting a full-surah completion prompt.
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

/// Coordinates full-surah completion with semantic mastery and optional
/// rotation activation. Historical schemes and counters remain immutable.
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
    bool addToRotation = true,
    String? rotationSchemeId,
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
    if (!learningState.isFullSurahTarget) {
      throw StateError('A partial learning range cannot master a full surah.');
    }
    final learning = learningStateMachine.complete(
      learningState,
      eventId: completionEventId,
    );
    MasteredSurah? existing;
    for (final mastered in rotationSnapshot.surahs) {
      if (mastered.id == surah.id) {
        existing = mastered;
        break;
      }
    }

    late final RotationSnapshot rotation;
    if (existing == null) {
      rotation = rotationEngine.addMasteredSurah(
        rotationSnapshot,
        surah,
        activate: addToRotation && surah.isRotationEligible,
        displayOrder: displayOrder,
        rotationSchemeId: rotationSchemeId,
      );
    } else {
      if (existing.isCurrentlyMastered && !surah.isAlFatiha) {
        throw StateError('Surah "${surah.id}" is already currently mastered.');
      }
      final shouldActivate = addToRotation && surah.isRotationEligible;
      var updated = existing.copyWith(
        isCurrentlyMastered: true,
        isActive: false,
      );
      if (surah.isRotationEligible) {
        final nextScheme = SurahRotationScheme.fromRanges(
          id:
              rotationSchemeId ??
              '${surah.id}:scheme:${existing.rotationScheme.version + 1}',
          surahId: surah.id,
          version: existing.rotationScheme.version + 1,
          ayahCount: surah.ayahCount,
          ranges: existing.rotationScheme.parts.map((part) => part.ayahRange),
          baselineRotationScore: rotationSnapshot.rotationTarget - 1,
          baselineTotalRecitations: existing.totalRecitations,
          baselineLastUsedAtUtc: existing.lastUsedAtUtc,
          resetsRotationBaseline: true,
        );
        updated = updated.copyWith(
          isActive: shouldActivate,
          hasEnteredRotation: shouldActivate,
          rotationScheme: nextScheme,
        );
      }
      rotation = rotationEngine.updateMasteredSurah(rotationSnapshot, updated);
    }
    return LearningCompletionOutcome(
      learning: learning,
      rotationSnapshot: rotation,
    );
  }
}
