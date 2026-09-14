import 'prayer.dart';
import 'recitation.dart';
import 'suggestion.dart';

/// Bumped whenever the batch-building rules change, so persisted batches from
/// an older rule set are rebuilt instead of being shown with stale semantics.
const int recommendationBatchAlgorithmVersion = 1;

/// Identifies the one occurrence a batch belongs to.
///
/// Including the prayer and its routine part is what stops Fajr and Asr from
/// being handed the same surahs purely because they share one global
/// `remaining` ordering.
final class RecommendationBatchKey {
  const RecommendationBatchKey({
    required this.localDate,
    required this.prayerType,
    required this.isQada,
    this.partStableKey,
    this.algorithmVersion = recommendationBatchAlgorithmVersion,
  });

  final LocalDate localDate;
  final PrayerType prayerType;
  final bool isQada;

  /// Null when this prayer has no configured routine, so the whole prayer is
  /// one occurrence rather than a sequence of parts.
  final String? partStableKey;
  final int algorithmVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationBatchKey &&
          localDate == other.localDate &&
          prayerType == other.prayerType &&
          isQada == other.isQada &&
          partStableKey == other.partStableKey &&
          algorithmVersion == other.algorithmVersion;

  @override
  int get hashCode => Object.hash(
    localDate,
    prayerType,
    isQada,
    partStableKey,
    algorithmVersion,
  );

  @override
  String toString() =>
      'RecommendationBatchKey($localDate, ${prayerType.name}, '
      'isQada: $isQada, part: $partStableKey, v$algorithmVersion)';
}

/// One position in a batch.
final class RecommendationBatchEntry {
  factory RecommendationBatchEntry({
    required String surahId,
    required int position,
    int occurrence = 1,
  }) {
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (position < 0 || position >= maxRecommendationCount) {
      throw ArgumentError.value(position, 'position');
    }
    if (occurrence < 1) {
      throw ArgumentError.value(occurrence, 'occurrence', 'Starts at one.');
    }
    return RecommendationBatchEntry._(
      surahId: surahId,
      position: position,
      occurrence: occurrence,
    );
  }

  const RecommendationBatchEntry._({
    required this.surahId,
    required this.position,
    required this.occurrence,
  });

  final String surahId;
  final int position;

  /// How many times this surah has been offered in the current cycle. Two
  /// means the pool wrapped and it is honestly shown as `2×`; it never
  /// doubles a recitation event or affects statistics.
  final int occurrence;

  bool get isRepeat => occurrence > 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationBatchEntry &&
          surahId == other.surahId &&
          position == other.position &&
          occurrence == other.occurrence;

  @override
  int get hashCode => Object.hash(surahId, position, occurrence);

  @override
  String toString() =>
      'RecommendationBatchEntry($surahId @$position x$occurrence)';
}

/// A stable, ordered set of recommendations that survives marking.
///
/// A marked surah keeps its position and is shown as completed instead of
/// dropping out, which is what stops the block from shrinking to a single
/// remaining surah after a few marks.
final class RecommendationBatch {
  factory RecommendationBatch({
    required RecommendationBatchKey key,
    required Iterable<RecommendationBatchEntry> entries,
  }) {
    final ordered = List<RecommendationBatchEntry>.unmodifiable(entries);
    for (var index = 0; index < ordered.length; index += 1) {
      if (ordered[index].position != index) {
        throw ArgumentError.value(
          entries,
          'entries',
          'Batch positions must be contiguous from zero.',
        );
      }
    }
    if (ordered.map((entry) => entry.surahId).toSet().length !=
        ordered.length) {
      throw ArgumentError.value(
        entries,
        'entries',
        'A surah may appear at most once in one batch.',
      );
    }
    return RecommendationBatch._(key: key, entries: ordered);
  }

  const RecommendationBatch._({required this.key, required this.entries});

  final RecommendationBatchKey key;
  final List<RecommendationBatchEntry> entries;

  bool get isEmpty => entries.isEmpty;

  Iterable<String> get surahIds => entries.map((entry) => entry.surahId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationBatch &&
          key == other.key &&
          _sameEntries(entries, other.entries);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(entries));
}

/// Progress through one pass over the eligible pool.
///
/// The offered set is deliberately global rather than per prayer, so a surah
/// handed to Fajr is not handed to Asr again until the pool is exhausted.
final class RecommendationCycleState {
  factory RecommendationCycleState({
    Iterable<String> offeredSurahIds = const <String>[],
    int cycleNumber = 1,
  }) {
    if (cycleNumber < 1) {
      throw ArgumentError.value(cycleNumber, 'cycleNumber', 'Starts at one.');
    }
    return RecommendationCycleState._(
      offeredSurahIds: Set<String>.unmodifiable(offeredSurahIds),
      cycleNumber: cycleNumber,
    );
  }

  const RecommendationCycleState._({
    required this.offeredSurahIds,
    required this.cycleNumber,
  });

  static final RecommendationCycleState empty = RecommendationCycleState();

  final Set<String> offeredSurahIds;
  final int cycleNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationCycleState &&
          cycleNumber == other.cycleNumber &&
          offeredSurahIds.length == other.offeredSurahIds.length &&
          offeredSurahIds.containsAll(other.offeredSurahIds);

  @override
  int get hashCode => Object.hash(cycleNumber, Object.hashAll(offeredSurahIds));
}

/// The batch to show plus the cycle state to persist alongside it.
final class RecommendationBatchPlan {
  const RecommendationBatchPlan({required this.batch, required this.cycle});

  final RecommendationBatch batch;
  final RecommendationCycleState cycle;
}

/// Builds a stable batch, or reuses the stored one unchanged.
final class RecommendationBatchService {
  const RecommendationBatchService();

  /// [rankedEligibleSurahIds] is the full ranked candidate pool for this
  /// occurrence, already ordered by the existing suggestion rules.
  ///
  /// An [existing] batch for the same key is returned untouched: a batch is
  /// never recomputed or reordered because a surah in it was marked. Only a
  /// different day, prayer, part or algorithm version starts a new one.
  RecommendationBatchPlan plan({
    required RecommendationBatchKey key,
    required List<String> rankedEligibleSurahIds,
    RecommendationCycleState? cycle,
    RecommendationBatch? existing,
    int size = maxRecommendationCount,
  }) {
    if (size < 0 || size > maxRecommendationCount) {
      throw ArgumentError.value(size, 'size');
    }
    final currentCycle = cycle ?? RecommendationCycleState.empty;
    if (existing != null && existing.key == key) {
      return RecommendationBatchPlan(batch: existing, cycle: currentCycle);
    }

    final chosen = <RecommendationBatchEntry>[];
    final takenIds = <String>{};
    var offered = Set<String>.of(currentCycle.offeredSurahIds);
    var cycleNumber = currentCycle.cycleNumber;

    void take(String surahId, int occurrence) {
      chosen.add(
        RecommendationBatchEntry(
          surahId: surahId,
          position: chosen.length,
          occurrence: occurrence,
        ),
      );
      takenIds.add(surahId);
      offered.add(surahId);
    }

    // First pass: surahs this cycle has not offered yet.
    for (final surahId in rankedEligibleSurahIds) {
      if (chosen.length == size) break;
      if (offered.contains(surahId) || takenIds.contains(surahId)) continue;
      take(surahId, 1);
    }

    // The cycle ran out before the batch was full: start a new round and top
    // it up, marking those entries honestly as a repeat.
    if (chosen.length < size && rankedEligibleSurahIds.length > chosen.length) {
      cycleNumber += 1;
      offered = <String>{...takenIds};
      for (final surahId in rankedEligibleSurahIds) {
        if (chosen.length == size) break;
        if (takenIds.contains(surahId)) continue;
        take(surahId, 2);
      }
    }

    return RecommendationBatchPlan(
      batch: RecommendationBatch(key: key, entries: chosen),
      cycle: RecommendationCycleState(
        offeredSurahIds: offered,
        cycleNumber: cycleNumber,
      ),
    );
  }
}

bool _sameEntries(
  List<RecommendationBatchEntry> left,
  List<RecommendationBatchEntry> right,
) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
