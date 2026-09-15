import 'rotation.dart';
import 'rotation_scheme.dart';
import 'surah.dart';

/// Product-level ceiling shared by Home and widget recommendation projections.
const int maxRecommendationCount = 8;

/// Explainable, ranked recommendation for a mastered surah.
final class SurahSuggestion {
  SurahSuggestion({
    required this.surah,
    required this.remaining,
    required this.recommendationRank,
    Iterable<SurahRotationPart> recommendedParts = const <SurahRotationPart>[],
  }) : recommendedParts = List<SurahRotationPart>.unmodifiable(
         recommendedParts,
       ) {
    if (remaining <= 0) {
      throw ArgumentError.value(remaining, 'remaining', 'Must be positive.');
    }
    if (recommendationRank < 0 ||
        recommendationRank >= maxRecommendationCount) {
      throw ArgumentError.value(
        recommendationRank,
        'recommendationRank',
        'Must be between zero and ${maxRecommendationCount - 1}.',
      );
    }
  }

  final MasteredSurah surah;
  final int remaining;

  /// Zero-based stable rank within the current recommendation projection.
  final int recommendationRank;
  final List<SurahRotationPart> recommendedParts;

  SurahRotationPart? get recommendedPart =>
      recommendedParts.isEmpty ? null : recommendedParts.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahSuggestion &&
          surah == other.surah &&
          remaining == other.remaining &&
          recommendationRank == other.recommendationRank &&
          _sameParts(recommendedParts, other.recommendedParts);

  @override
  int get hashCode => Object.hash(
    surah,
    remaining,
    recommendationRank,
    Object.hashAll(recommendedParts),
  );
}

/// Orders due, rotation-eligible surahs using deterministic product rules.
final class SurahSuggestionService {
  const SurahSuggestionService();

  /// Every eligible candidate in ranked order, with no product ceiling.
  ///
  /// [suggest] is capped at [maxRecommendationCount] because a
  /// [SurahSuggestion] carries a bounded rank. A recommendation batch needs
  /// the whole ordered pool to pick from, so it reads the ranking through
  /// this instead of re-deriving it.
  /// The whole ranked pool, for a recommendation batch that needs more
  /// candidates than the product ceiling exposes.
  ///
  /// [includeSatisfied] widens the pool to surahs that have already reached the
  /// rotation target. They sort after every still-due surah, so the visible
  /// order is unchanged — they only become available once the due ones run out.
  /// A batch needs this: without it the pool shrinks as the user recites, and a
  /// newly planned batch cannot reach eight entries even though eight eligible
  /// surahs exist. That is what "at 2× the count drops" was.
  List<String> rankedCandidateIds(
    RotationSnapshot snapshot, {
    Set<String> excludedSurahIds = const <String>{},
    int Function(MasteredSurah left, MasteredSurah right)? contextualTiebreak,
    bool includeSatisfied = false,
  }) => List<String>.unmodifiable(
    _rankedCandidates(
      snapshot,
      excludedSurahIds: excludedSurahIds,
      contextualTiebreak: contextualTiebreak,
      includeSatisfied: includeSatisfied,
    ).map((candidate) => candidate.surah.id),
  );

  List<SurahSuggestion> suggest(
    RotationSnapshot snapshot, {
    int limit = maxRecommendationCount,
    Set<String> excludedSurahIds = const <String>{},
    int Function(MasteredSurah left, MasteredSurah right)? contextualTiebreak,
  }) {
    if (limit < 0) {
      throw ArgumentError.value(limit, 'limit', 'Must not be negative.');
    }
    if (limit == 0) return const <SurahSuggestion>[];

    final candidates = _rankedCandidates(
      snapshot,
      excludedSurahIds: excludedSurahIds,
      contextualTiebreak: contextualTiebreak,
    );

    final effectiveLimit = limit < maxRecommendationCount
        ? limit
        : maxRecommendationCount;
    final selected = candidates.take(effectiveLimit).toList(growable: false);
    return List<SurahSuggestion>.unmodifiable(<SurahSuggestion>[
      for (var index = 0; index < selected.length; index += 1)
        SurahSuggestion(
          surah: selected[index].surah,
          remaining: selected[index].remaining,
          recommendationRank: index,
          recommendedParts: selected[index].recommendedParts,
        ),
    ]);
  }

  List<_SuggestionCandidate> _rankedCandidates(
    RotationSnapshot snapshot, {
    required Set<String> excludedSurahIds,
    int Function(MasteredSurah left, MasteredSurah right)? contextualTiebreak,
    bool includeSatisfied = false,
  }) {
    final candidates = snapshot.activeSurahs
        .map((MasteredSurah surah) {
          if (excludedSurahIds.contains(surah.id)) return null;
          final remaining = snapshot.rotationTarget - surah.rotationScore;
          // `suggest()` keeps its due-only meaning; only a batch pool widens.
          if (remaining <= 0 && !includeSatisfied) return null;
          final parts = surah.rotationScheme.parts.where(
            (SurahRotationPart part) =>
                snapshot.rotationTarget - part.rotationScore == remaining,
          );
          final sortedParts = parts.toList()..sort(_compareParts);
          return _SuggestionCandidate(
            surah: surah,
            remaining: remaining,
            recommendedParts: sortedParts,
          );
        })
        .whereType<_SuggestionCandidate>()
        .toList();
    candidates.sort((left, right) => _compare(left, right, contextualTiebreak));
    return candidates;
  }

  int _compare(
    _SuggestionCandidate left,
    _SuggestionCandidate right,
    int Function(MasteredSurah left, MasteredSurah right)? contextualTiebreak,
  ) {
    final remainingComparison = right.remaining.compareTo(left.remaining);
    if (remainingComparison != 0) return remainingComparison;

    if (contextualTiebreak != null) {
      final contextualComparison = contextualTiebreak(left.surah, right.surah);
      if (contextualComparison != 0) return contextualComparison;
    }

    final usedComparison = compareNullableLastUsed(
      left.recommendedPart?.lastUsedAtUtc,
      right.recommendedPart?.lastUsedAtUtc,
    );
    if (usedComparison != 0) return usedComparison;

    final orderComparison = left.surah.displayOrder.compareTo(
      right.surah.displayOrder,
    );
    if (orderComparison != 0) return orderComparison;
    final numberComparison = left.surah.surah.surahNumber.compareTo(
      right.surah.surah.surahNumber,
    );
    if (numberComparison != 0) return numberComparison;
    return left.surah.id.compareTo(right.surah.id);
  }

  int _compareParts(SurahRotationPart left, SurahRotationPart right) {
    final usedComparison = compareNullableLastUsed(
      left.lastUsedAtUtc,
      right.lastUsedAtUtc,
    );
    if (usedComparison != 0) return usedComparison;
    return left.partNumber.compareTo(right.partNumber);
  }
}

/// Produces the dynamic Home ordering without mutating persisted display order.
///
/// Recommendations are first in rank order. Every other active surah follows
/// by descending remaining balance (due, exact, then increasingly ahead),
/// oldest use, display order, surah number, and stable identifier.
final class SurahOperationalOrderService {
  const SurahOperationalOrderService({
    this.suggestionService = const SurahSuggestionService(),
  });

  final SurahSuggestionService suggestionService;

  List<MasteredSurah> order(
    RotationSnapshot snapshot, {
    Iterable<SurahSuggestion>? recommendations,
  }) {
    final resolvedRecommendations = List<SurahSuggestion>.unmodifiable(
      recommendations ?? suggestionService.suggest(snapshot),
    );
    final ranks = <String, int>{};
    for (final suggestion in resolvedRecommendations) {
      if (!ranks.containsKey(suggestion.surah.id)) {
        ranks[suggestion.surah.id] = suggestion.recommendationRank;
      } else {
        throw ArgumentError.value(
          resolvedRecommendations,
          'recommendations',
          'A surah may have only one recommendation rank.',
        );
      }
    }

    final active = snapshot.activeSurahs.toList(growable: false);
    active.sort(
      (MasteredSurah left, MasteredSurah right) =>
          compare(snapshot, left, right, recommendationRanks: ranks),
    );
    return List<MasteredSurah>.unmodifiable(active);
  }

  int compare(
    RotationSnapshot snapshot,
    MasteredSurah left,
    MasteredSurah right, {
    required Map<String, int> recommendationRanks,
  }) {
    final leftRank = recommendationRanks[left.id];
    final rightRank = recommendationRanks[right.id];
    if (leftRank != null && rightRank == null) return -1;
    if (leftRank == null && rightRank != null) return 1;
    if (leftRank != null && rightRank != null) {
      final rankComparison = leftRank.compareTo(rightRank);
      if (rankComparison != 0) return rankComparison;
    }

    final remainingComparison = snapshot
        .remainingFor(right.id)
        .compareTo(snapshot.remainingFor(left.id));
    if (remainingComparison != 0) return remainingComparison;

    final usedComparison = compareNullableLastUsed(
      left.lastUsedAtUtc,
      right.lastUsedAtUtc,
    );
    if (usedComparison != 0) return usedComparison;

    final displayOrderComparison = left.displayOrder.compareTo(
      right.displayOrder,
    );
    if (displayOrderComparison != 0) return displayOrderComparison;

    final surahNumberComparison = left.surah.surahNumber.compareTo(
      right.surah.surahNumber,
    );
    if (surahNumberComparison != 0) return surahNumberComparison;
    return left.id.compareTo(right.id);
  }
}

/// Null means never used and therefore sorts before every recorded timestamp.
int compareNullableLastUsed(DateTime? left, DateTime? right) {
  if (left == null && right != null) return -1;
  if (left != null && right == null) return 1;
  if (left != null && right != null) return left.compareTo(right);
  return 0;
}

final class _SuggestionCandidate {
  const _SuggestionCandidate({
    required this.surah,
    required this.remaining,
    required this.recommendedParts,
  });

  final MasteredSurah surah;
  final int remaining;
  final List<SurahRotationPart> recommendedParts;

  SurahRotationPart? get recommendedPart =>
      recommendedParts.isEmpty ? null : recommendedParts.first;
}

bool _sameParts(List<SurahRotationPart> left, List<SurahRotationPart> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
