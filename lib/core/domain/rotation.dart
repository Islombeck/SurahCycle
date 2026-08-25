import 'recitation.dart';
import 'rotation_scheme.dart';
import 'surah.dart';
import 'undo_outcome.dart';

/// Explicit score correction used for migration or a confirmed manual fix.
///
/// It is deliberately not a recitation: replay changes [rotationScore] only,
/// leaving historical [MasteredSurah.totalRecitations] untouched.
final class RotationAdjustmentEvent implements RotationJournalEvent {
  factory RotationAdjustmentEvent({
    required String id,
    required String surahId,
    required int delta,
    required String reason,
    required DateTime createdAtUtc,
    String? rotationSchemeId,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (delta == 0) {
      throw ArgumentError.value(delta, 'delta', 'Must not be zero.');
    }
    if (reason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Must not be empty.');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    if (rotationSchemeId != null && rotationSchemeId.isEmpty) {
      throw ArgumentError.value(
        rotationSchemeId,
        'rotationSchemeId',
        'Must be null or non-empty.',
      );
    }
    return RotationAdjustmentEvent._(
      id: id,
      surahId: surahId,
      delta: delta,
      reason: reason,
      createdAtUtc: createdAtUtc,
      rotationSchemeId: rotationSchemeId,
    );
  }

  const RotationAdjustmentEvent._({
    required this.id,
    required this.surahId,
    required this.delta,
    required this.reason,
    required this.createdAtUtc,
    required this.rotationSchemeId,
  });

  @override
  final String id;
  final String surahId;
  final int delta;
  final String reason;
  final String? rotationSchemeId;
  @override
  final DateTime createdAtUtc;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationAdjustmentEvent &&
          id == other.id &&
          surahId == other.surahId &&
          delta == other.delta &&
          reason == other.reason &&
          createdAtUtc == other.createdAtUtc &&
          rotationSchemeId == other.rotationSchemeId;

  @override
  int get hashCode =>
      Object.hash(id, surahId, delta, reason, createdAtUtc, rotationSchemeId);
}

/// A structural journal fact that activates a new immutable partition version.
///
/// During replay its part definitions are rebased to the effective predecessor
/// state. This lets deletion of an older recitation propagate through later
/// scheme versions without rewriting historical coverage.
final class RotationSchemeChangedEvent implements RotationJournalEvent {
  factory RotationSchemeChangedEvent({
    required String id,
    required String surahId,
    required SurahRotationScheme scheme,
    required DateTime createdAtUtc,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (scheme.surahId != surahId) {
      throw ArgumentError.value(
        scheme.surahId,
        'scheme',
        'The scheme must belong to the event surah.',
      );
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    return RotationSchemeChangedEvent._(
      id: id,
      surahId: surahId,
      scheme: scheme,
      createdAtUtc: createdAtUtc,
    );
  }

  const RotationSchemeChangedEvent._({
    required this.id,
    required this.surahId,
    required this.scheme,
    required this.createdAtUtc,
  });

  @override
  final String id;
  final String surahId;
  final SurahRotationScheme scheme;
  @override
  final DateTime createdAtUtc;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationSchemeChangedEvent &&
          id == other.id &&
          surahId == other.surahId &&
          scheme == other.scheme &&
          createdAtUtc == other.createdAtUtc;

  @override
  int get hashCode => Object.hash(id, surahId, scheme, createdAtUtc);
}

bool _sameList<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// Complete derived state of the repetition algorithm at one point in time.
final class RotationSnapshot {
  factory RotationSnapshot({
    int rotationTarget = RotationEngine.initialRotationTarget,
    Iterable<MasteredSurah> surahs = const <MasteredSurah>[],
  }) {
    if (rotationTarget < RotationEngine.initialRotationTarget) {
      throw ArgumentError.value(
        rotationTarget,
        'rotationTarget',
        'Must be at least ${RotationEngine.initialRotationTarget}.',
      );
    }
    final immutableSurahs = List<MasteredSurah>.unmodifiable(surahs);
    final ids = <String>{};
    for (final surah in immutableSurahs) {
      if (!ids.add(surah.id)) {
        throw ArgumentError.value(
          surah.id,
          'surahs',
          'Surah identifiers must be unique.',
        );
      }
    }
    return RotationSnapshot._(
      rotationTarget: rotationTarget,
      surahs: immutableSurahs,
    );
  }

  const RotationSnapshot._({
    required this.rotationTarget,
    required this.surahs,
  });

  final int rotationTarget;
  final List<MasteredSurah> surahs;

  Iterable<MasteredSurah> get activeSurahs =>
      surahs.where((surah) => surah.isActive && surah.surah.isRotationEligible);

  MasteredSurah surahById(String id) {
    for (final surah in surahs) {
      if (surah.id == id) return surah;
    }
    throw StateError('No mastered surah with id "$id".');
  }

  int remainingFor(String surahId) =>
      rotationTarget - surahById(surahId).rotationScore;

  int remainingForPart(String surahId, String partId) => surahById(
    surahId,
  ).rotationScheme.remainingForPart(partId, rotationTarget);

  RotationSnapshot copyWith({
    int? rotationTarget,
    Iterable<MasteredSurah>? surahs,
  }) => RotationSnapshot(
    rotationTarget: rotationTarget ?? this.rotationTarget,
    surahs: surahs ?? this.surahs,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationSnapshot &&
          rotationTarget == other.rotationTarget &&
          _sameList(surahs, other.surahs);

  @override
  int get hashCode => Object.hash(rotationTarget, Object.hashAll(surahs));
}

/// Pure rotation rules. It owns no persistence and mutates no input object.
final class RotationEngine {
  const RotationEngine();

  static const int initialRotationTarget = 1;

  RotationSnapshot addMasteredSurah(
    RotationSnapshot snapshot,
    SurahDescriptor surah, {
    bool activate = true,
    int displayOrder = 0,
    String? rotationSchemeId,
  }) {
    if (snapshot.surahs.any((item) => item.id == surah.id)) {
      throw StateError('Surah "${surah.id}" is already mastered.');
    }

    final shouldActivate = activate && surah.isRotationEligible;
    final mastered = MasteredSurah(
      surah: surah,
      isActive: shouldActivate,
      hasEnteredRotation: shouldActivate,
      displayOrder: displayOrder,
      rotationScheme: SurahRotationScheme.unsplit(
        id: rotationSchemeId ?? '${surah.id}:scheme:1',
        surahId: surah.id,
        version: 1,
        ayahCount: surah.ayahCount,
        baselineRotationScore: shouldActivate ? snapshot.rotationTarget - 1 : 0,
      ),
    );
    return snapshot.copyWith(
      surahs: <MasteredSurah>[...snapshot.surahs, mastered],
    );
  }

  /// Activating or deactivating never changes [RotationSnapshot.rotationTarget].
  /// First activation starts one step behind; reactivation preserves the score.
  RotationSnapshot setSurahActive(
    RotationSnapshot snapshot,
    String surahId, {
    required bool isActive,
  }) {
    final existing = snapshot.surahById(surahId);
    final shouldBeActive = isActive && existing.surah.isRotationEligible;
    if (existing.isActive == shouldBeActive) return snapshot;

    final firstActivation = shouldBeActive && !existing.hasEnteredRotation;
    final activatedScheme = firstActivation
        ? existing.rotationScheme.rebase(
            rotationScore: snapshot.rotationTarget - 1,
            totalRecitations: existing.totalRecitations,
            lastUsedAtUtc: existing.lastUsedAtUtc,
          )
        : existing.rotationScheme;
    final updated = existing.copyWith(
      isActive: shouldBeActive,
      hasEnteredRotation: existing.hasEnteredRotation || shouldBeActive,
      rotationScheme: activatedScheme,
    );
    return _replace(snapshot, updated);
  }

  /// Replaces user-editable state without evaluating a target transition.
  RotationSnapshot updateMasteredSurah(
    RotationSnapshot snapshot,
    MasteredSurah updated,
  ) {
    snapshot.surahById(updated.id);
    final normalized = updated.surah.isRotationEligible || !updated.isActive
        ? updated
        : updated.copyWith(isActive: false);
    return _replace(snapshot, normalized);
  }

  RotationSnapshot registerRecitation(
    RotationSnapshot snapshot,
    SurahRecitationEvent event,
  ) {
    final resolvedEvent = resolveRecitation(snapshot, event);
    final current = snapshot.surahById(resolvedEvent.surahId);
    if (!current.isActive || !current.surah.isRotationEligible) {
      throw StateError(
        'Cannot register a rotation recitation for inactive surah '
        '"${resolvedEvent.surahId}".',
      );
    }

    final coveredPartIds = resolvedEvent.coveredPartIds.toSet();
    final updatedParts = <SurahRotationPart>[
      for (final part in current.rotationScheme.parts)
        coveredPartIds.contains(part.id)
            ? part.copyWith(
                rotationScore: part.rotationScore + 1,
                recitationCount: part.recitationCount + 1,
                lastUsedAtUtc: resolvedEvent.createdAtUtc,
              )
            : part,
    ];
    final recited = current.copyWith(
      rotationScheme: current.rotationScheme.copyWith(parts: updatedParts),
    );
    final withRecitation = _replace(snapshot, recited);

    // A single user action may cross at most one global cycle boundary.
    final active = withRecitation.activeSurahs.toList(growable: false);
    final shouldAdvance =
        active.isNotEmpty &&
        active.every(
          (surah) => surah.rotationScore >= withRecitation.rotationTarget,
        );
    return shouldAdvance
        ? withRecitation.copyWith(
            rotationTarget: withRecitation.rotationTarget + 1,
          )
        : withRecitation;
  }

  /// Applies a confirmed balance correction without changing statistics or
  /// evaluating a target transition.
  RotationSnapshot applyAdjustment(
    RotationSnapshot snapshot,
    RotationAdjustmentEvent event,
  ) {
    final current = snapshot.surahById(event.surahId);
    if (event.rotationSchemeId != null &&
        event.rotationSchemeId != current.rotationScheme.id) {
      throw StateError(
        'Adjustment "${event.id}" targets stale rotation scheme '
        '"${event.rotationSchemeId}".',
      );
    }
    late final SurahRotationScheme adjustedScheme;
    try {
      adjustedScheme = current.rotationScheme.shiftScores(event.delta);
    } on StateError {
      throw StateError(
        'Adjustment "${event.id}" would make a part score negative.',
      );
    }
    return _replace(snapshot, current.copyWith(rotationScheme: adjustedScheme));
  }

  /// Resolves legacy whole-surah input and validates explicit part coverage.
  SurahRecitationEvent resolveRecitation(
    RotationSnapshot snapshot,
    SurahRecitationEvent event,
  ) {
    final current = snapshot.surahById(event.surahId);
    final scheme = current.rotationScheme;
    final coverage = event.coverage;
    if (coverage == null) {
      return event.withCoverage(
        RecitationCoverage(
          rotationSchemeId: scheme.id,
          coveredPartIds: scheme.parts.map((SurahRotationPart part) => part.id),
        ),
      );
    }
    if (coverage.rotationSchemeId != scheme.id) {
      throw StateError(
        'Recitation "${event.id}" targets stale rotation scheme '
        '"${coverage.rotationSchemeId}".',
      );
    }
    for (final partId in coverage.coveredPartIds) {
      scheme.partById(partId);
    }
    return event;
  }

  RotationAdjustmentEvent resolveAdjustment(
    RotationSnapshot snapshot,
    RotationAdjustmentEvent event,
  ) {
    final schemeId = snapshot.surahById(event.surahId).rotationScheme.id;
    if (event.rotationSchemeId != null) {
      if (event.rotationSchemeId != schemeId) {
        throw StateError(
          'Adjustment "${event.id}" targets stale rotation scheme '
          '"${event.rotationSchemeId}".',
        );
      }
      return event;
    }
    return RotationAdjustmentEvent(
      id: event.id,
      surahId: event.surahId,
      delta: event.delta,
      reason: event.reason,
      createdAtUtc: event.createdAtUtc,
      rotationSchemeId: schemeId,
    );
  }

  /// Replaces only the current scheme. The previous immutable value remains
  /// available to historical events and to the caller's previous snapshot.
  RotationSnapshot changeRotationScheme(
    RotationSnapshot snapshot,
    RotationSchemeChangedEvent event,
  ) {
    final current = snapshot.surahById(event.surahId);
    final proposed = event.scheme;
    if (proposed.id == current.rotationScheme.id) {
      throw StateError('A new scheme must have a new identifier.');
    }
    if (proposed.version != current.rotationScheme.version + 1) {
      throw StateError('A scheme version must advance by exactly one.');
    }
    if (proposed.ayahCount != current.surah.ayahCount) {
      throw StateError('A scheme must use verified surah ayahCount.');
    }
    final rebased = proposed.rebase(
      rotationScore: current.rotationScore,
      totalRecitations: current.totalRecitations,
      lastUsedAtUtc: current.lastUsedAtUtc,
    );
    return _replace(snapshot, current.copyWith(rotationScheme: rebased));
  }

  RotationSnapshot applyJournalEvent(
    RotationSnapshot snapshot,
    RotationJournalEvent event,
  ) {
    if (event is SurahRecitationEvent) {
      return registerRecitation(snapshot, event);
    }
    if (event is RotationAdjustmentEvent) {
      return applyAdjustment(snapshot, event);
    }
    if (event is RotationSchemeChangedEvent) {
      return changeRotationScheme(snapshot, event);
    }
    throw StateError(
      'Unsupported rotation journal event: ${event.runtimeType}.',
    );
  }

  RotationSnapshot replay(
    RotationSnapshot baseline,
    Iterable<RotationJournalEvent> events,
  ) {
    var current = baseline;
    for (final event in events) {
      current = applyJournalEvent(current, event);
    }
    return current;
  }

  RotationSnapshot _replace(RotationSnapshot snapshot, MasteredSurah updated) =>
      snapshot.copyWith(
        surahs: snapshot.surahs.map(
          (surah) => surah.id == updated.id ? updated : surah,
        ),
      );
}

/// A replayable baseline plus ordered recitation facts and their derived state.
///
/// The event order is insertion order, not wall-clock order. Persistence must
/// retain that order. Scheme changes are explicit journal facts; activation and
/// mastered-set changes are checkpointed by the surrounding repository.
final class RecitationTimeline {
  const RecitationTimeline._({
    required this.baseline,
    required this.events,
    required this.snapshot,
    required this.undoableEventId,
    required this.preActionSnapshot,
  });

  final RotationSnapshot baseline;
  final List<RotationJournalEvent> events;
  final RotationSnapshot snapshot;

  /// Only a freshly recorded recitation is eligible for snackbar-style Undo.
  final String? undoableEventId;
  final RotationSnapshot? preActionSnapshot;

  bool get canUndoLastRecitation =>
      events.isNotEmpty &&
      events.last is SurahRecitationEvent &&
      events.last.id == undoableEventId &&
      preActionSnapshot != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecitationTimeline &&
          baseline == other.baseline &&
          _sameList(events, other.events) &&
          snapshot == other.snapshot &&
          undoableEventId == other.undoableEventId &&
          preActionSnapshot == other.preActionSnapshot;

  @override
  int get hashCode => Object.hash(
    baseline,
    Object.hashAll(events),
    snapshot,
    undoableEventId,
    preActionSnapshot,
  );
}

final class RecitationDeletionOutcome {
  const RecitationDeletionOutcome({
    required this.timeline,
    required this.didDelete,
    this.deletedEvent,
  });

  final RecitationTimeline timeline;
  final bool didDelete;
  final SurahRecitationEvent? deletedEvent;
}

/// The single entry point for record, deletion and undo operations.
final class RecitationReplayService {
  const RecitationReplayService({this.engine = const RotationEngine()});

  final RotationEngine engine;

  RecitationTimeline create({
    required RotationSnapshot baseline,
    Iterable<RotationJournalEvent> events = const <RotationJournalEvent>[],
  }) {
    final suppliedEvents = List<RotationJournalEvent>.unmodifiable(events);
    _ensureUniqueIds(suppliedEvents);
    var snapshot = baseline;
    final normalizedEvents = <RotationJournalEvent>[];
    for (final event in suppliedEvents) {
      final normalized = switch (event) {
        SurahRecitationEvent value => engine.resolveRecitation(snapshot, value),
        RotationAdjustmentEvent value => engine.resolveAdjustment(
          snapshot,
          value,
        ),
        RotationSchemeChangedEvent value => value,
        _ => throw StateError(
          'Unsupported rotation journal event: ${event.runtimeType}.',
        ),
      };
      snapshot = engine.applyJournalEvent(snapshot, normalized);
      normalizedEvents.add(normalized);
    }
    final immutableEvents = List<RotationJournalEvent>.unmodifiable(
      normalizedEvents,
    );
    return RecitationTimeline._(
      baseline: baseline,
      events: immutableEvents,
      snapshot: snapshot,
      undoableEventId: null,
      preActionSnapshot: null,
    );
  }

  RecitationTimeline record(
    RecitationTimeline timeline,
    SurahRecitationEvent event,
  ) {
    if (timeline.events.any((existing) => existing.id == event.id)) {
      throw StateError('Recitation event "${event.id}" already exists.');
    }
    final resolved = engine.resolveRecitation(timeline.snapshot, event);
    return RecitationTimeline._(
      baseline: timeline.baseline,
      events: List<RotationJournalEvent>.unmodifiable(<RotationJournalEvent>[
        ...timeline.events,
        resolved,
      ]),
      snapshot: engine.registerRecitation(timeline.snapshot, resolved),
      undoableEventId: resolved.id,
      preActionSnapshot: timeline.snapshot,
    );
  }

  RecitationTimeline recordAdjustment(
    RecitationTimeline timeline,
    RotationAdjustmentEvent event,
  ) {
    if (timeline.events.any((existing) => existing.id == event.id)) {
      throw StateError('Rotation event "${event.id}" already exists.');
    }
    final resolved = engine.resolveAdjustment(timeline.snapshot, event);
    return RecitationTimeline._(
      baseline: timeline.baseline,
      events: List<RotationJournalEvent>.unmodifiable(<RotationJournalEvent>[
        ...timeline.events,
        resolved,
      ]),
      snapshot: engine.applyAdjustment(timeline.snapshot, resolved),
      undoableEventId: null,
      preActionSnapshot: null,
    );
  }

  RecitationTimeline recordSchemeChange(
    RecitationTimeline timeline,
    RotationSchemeChangedEvent event,
  ) {
    if (timeline.events.any((existing) => existing.id == event.id)) {
      throw StateError('Rotation event "${event.id}" already exists.');
    }
    final snapshot = engine.changeRotationScheme(timeline.snapshot, event);
    final currentScheme = snapshot.surahById(event.surahId).rotationScheme;
    final normalized = RotationSchemeChangedEvent(
      id: event.id,
      surahId: event.surahId,
      scheme: currentScheme,
      createdAtUtc: event.createdAtUtc,
    );
    return RecitationTimeline._(
      baseline: timeline.baseline,
      events: List<RotationJournalEvent>.unmodifiable(<RotationJournalEvent>[
        ...timeline.events,
        normalized,
      ]),
      snapshot: snapshot,
      undoableEventId: null,
      preActionSnapshot: null,
    );
  }

  RecitationDeletionOutcome deleteEvent(
    RecitationTimeline timeline,
    String eventId,
  ) {
    final index = timeline.events.indexWhere(
      (event) => event is SurahRecitationEvent && event.id == eventId,
    );
    if (index < 0) {
      return RecitationDeletionOutcome(timeline: timeline, didDelete: false);
    }
    final deleted = timeline.events[index] as SurahRecitationEvent;
    final retained = <RotationJournalEvent>[
      for (var i = 0; i < timeline.events.length; i += 1)
        if (i != index) timeline.events[i],
    ];
    final replayed = create(baseline: timeline.baseline, events: retained);
    final targetFloor = timeline.snapshot.rotationTarget;
    final rebuiltSnapshot = replayed.snapshot.rotationTarget < targetFloor
        ? replayed.snapshot.copyWith(rotationTarget: targetFloor)
        : replayed.snapshot;
    return RecitationDeletionOutcome(
      timeline: RecitationTimeline._(
        baseline: replayed.baseline,
        events: replayed.events,
        snapshot: rebuiltSnapshot,
        undoableEventId: null,
        preActionSnapshot: null,
      ),
      didDelete: true,
      deletedEvent: deleted,
    );
  }

  UndoOutcome<RecitationTimeline> undoLast(RecitationTimeline timeline) {
    if (!timeline.canUndoLastRecitation) {
      return UndoOutcome<RecitationTimeline>.nothingToUndo(timeline);
    }
    final event = timeline.events.last as SurahRecitationEvent;
    final restored = RecitationTimeline._(
      baseline: timeline.baseline,
      events: List<RotationJournalEvent>.unmodifiable(
        timeline.events.take(timeline.events.length - 1),
      ),
      snapshot: timeline.preActionSnapshot!,
      undoableEventId: null,
      preActionSnapshot: null,
    );
    return UndoOutcome<RecitationTimeline>.restored(
      restored,
      undoneEventId: event.id,
    );
  }

  void _ensureUniqueIds(List<RotationJournalEvent> events) {
    final ids = <String>{};
    for (final event in events) {
      if (!ids.add(event.id)) {
        throw ArgumentError.value(
          event.id,
          'events',
          'Recitation event identifiers must be unique.',
        );
      }
    }
  }
}
