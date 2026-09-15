import 'rotation.dart';
import 'suggestion.dart';
import 'surah.dart';

/// Everything [ContextualSurahSuggestionService] needs beyond the rotation
/// snapshot, resolved once so Home and the native-widget projection always
/// rank surahs identically for the same current prayer context/part.
final class ContextualRecommendationInputs {
  const ContextualRecommendationInputs({
    this.alreadyFilledInCurrentPartSurahIds = const <String>{},
    this.lastUsedInExactPart = const <String, DateTime>{},
    this.lastUsedInPrayerType = const <String, DateTime>{},
    this.recallNeedsReviewSurahIds = const <String>{},
  });

  static const ContextualRecommendationInputs empty =
      ContextualRecommendationInputs();

  final Set<String> alreadyFilledInCurrentPartSurahIds;
  final Map<String, DateTime> lastUsedInExactPart;
  final Map<String, DateTime> lastUsedInPrayerType;

  /// Surahs whose most recent memory check did not go cleanly.
  ///
  /// This is a tie-break only. It never makes a surah eligible, never changes
  /// how overdue anything is, and a later clean check removes the surah from
  /// the set — so a single bad day cannot pin a surah to the top.
  final Set<String> recallNeedsReviewSurahIds;

  /// Value equality matters here: this is rebuilt from several streams, and
  /// without it every unrelated emission would look like a change and force
  /// dependents — including the recommendation batch — to rebuild and
  /// resubscribe needlessly.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextualRecommendationInputs &&
          _sameSet(
            alreadyFilledInCurrentPartSurahIds,
            other.alreadyFilledInCurrentPartSurahIds,
          ) &&
          _sameMap(lastUsedInExactPart, other.lastUsedInExactPart) &&
          _sameMap(lastUsedInPrayerType, other.lastUsedInPrayerType) &&
          _sameSet(recallNeedsReviewSurahIds, other.recallNeedsReviewSurahIds);

  @override
  int get hashCode => Object.hash(
    alreadyFilledInCurrentPartSurahIds.length,
    lastUsedInExactPart.length,
    lastUsedInPrayerType.length,
    recallNeedsReviewSurahIds.length,
  );
}

bool _sameSet(Set<String> left, Set<String> right) =>
    identical(left, right) ||
    (left.length == right.length && left.containsAll(right));

bool _sameMap(Map<String, DateTime> left, Map<String, DateTime> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

/// Ranks due, rotation-eligible surahs for one specific prayer/part.
///
/// This layers two contextual tie-break tiers on top of the exact global
/// [SurahSuggestionService] ordering, without changing what makes a surah
/// eligible or how urgent it is: urgency ([RotationSnapshot]'s remaining
/// balance) always stays the primary sort key.
///
/// Ranking, most to least significant:
/// 1. Only mastered/active rotation-eligible surahs (delegated, unchanged).
/// 2. A surah already used to fill a slot in the *current* prayer part is
///    excluded from a *new* recommendation for that same part's remaining
///    slots (it stays visible and markable in the active list; only its
///    rank badge is withheld).
/// 3. Globally overdue surahs keep priority (delegated `remaining`,
///    unchanged).
/// 4. Within a tied urgency tier, the surah read least recently in this
///    exact routine-part slot (matched by [PrayerSessionPart.stableKey])
///    rises higher. Never read in this exact part sorts first.
/// 5. Still tied: the surah read least recently anywhere in this prayer
///    type (matching [isQada]) rises higher. Never read in this prayer
///    type sorts first.
/// 6. Still tied: a surah whose last memory check was imperfect rises above
///    one whose last check was clean or which was never checked. This is the
///    only effect a recall attempt has on anything, and it is deliberately
///    the weakest contextual tier: it cannot outrank urgency, and it is
///    undone by one clean check.
/// 7. Still tied: the existing global tie-break chain (recommended part's
///    own last-used time, display order, surah number, stable id).
///
/// With empty [lastUsedInExactPart]/[lastUsedInPrayerType] maps and empty
/// [alreadyFilledInCurrentPartSurahIds]/[recallNeedsReviewSurahIds] sets —
/// the state before any prayer context, contextual history or memory check
/// exists — every inserted tier compares equal for every candidate, so the
/// result is byte-for-byte identical to calling [suggestionService] directly.
/// That is the intended "no context yet" fallback; there is no separate
/// branch for it.
///
/// Ordinary and Qada occurrences must never be mixed: callers are
/// responsible for building [lastUsedInExactPart] and [lastUsedInPrayerType]
/// from data already scoped to one `isQada` value (see
/// `RecitationRepository.getLastUsedByRoutinePart` and
/// `RecitationRepository.getStats(prayerType:, isQada:)`).
final class ContextualSurahSuggestionService {
  const ContextualSurahSuggestionService({
    this.suggestionService = const SurahSuggestionService(),
  });

  final SurahSuggestionService suggestionService;

  List<SurahSuggestion> suggest(
    RotationSnapshot snapshot, {
    Set<String> alreadyFilledInCurrentPartSurahIds = const <String>{},
    Map<String, DateTime> lastUsedInExactPart = const <String, DateTime>{},
    Map<String, DateTime> lastUsedInPrayerType = const <String, DateTime>{},
    Set<String> recallNeedsReviewSurahIds = const <String>{},
    int limit = maxRecommendationCount,
  }) {
    return suggestionService.suggest(
      snapshot,
      limit: limit,
      excludedSurahIds: alreadyFilledInCurrentPartSurahIds,
      contextualTiebreak: (MasteredSurah left, MasteredSurah right) {
        final exactPartComparison = compareNullableLastUsed(
          lastUsedInExactPart[left.id],
          lastUsedInExactPart[right.id],
        );
        if (exactPartComparison != 0) return exactPartComparison;
        final prayerTypeComparison = compareNullableLastUsed(
          lastUsedInPrayerType[left.id],
          lastUsedInPrayerType[right.id],
        );
        if (prayerTypeComparison != 0) return prayerTypeComparison;
        return _compareRecall(left, right, recallNeedsReviewSurahIds);
      },
    );
  }

  /// A surah whose last check was imperfect sorts first among equals.
  static int _compareRecall(
    MasteredSurah left,
    MasteredSurah right,
    Set<String> needsReview,
  ) {
    final leftNeedsReview = needsReview.contains(left.id);
    if (leftNeedsReview == needsReview.contains(right.id)) return 0;
    return leftNeedsReview ? -1 : 1;
  }

  /// The whole eligible pool in the same contextual order, for a batch that
  /// needs more candidates than the product ceiling exposes.
  List<String> rankedCandidateIdsWith(
    RotationSnapshot snapshot,
    ContextualRecommendationInputs inputs,
  ) => suggestionService.rankedCandidateIds(
    snapshot,
    excludedSurahIds: inputs.alreadyFilledInCurrentPartSurahIds,
    contextualTiebreak: (MasteredSurah left, MasteredSurah right) =>
        _contextualCompare(left, right, inputs),
  );

  int _contextualCompare(
    MasteredSurah left,
    MasteredSurah right,
    ContextualRecommendationInputs inputs,
  ) {
    final exactPartComparison = compareNullableLastUsed(
      inputs.lastUsedInExactPart[left.id],
      inputs.lastUsedInExactPart[right.id],
    );
    if (exactPartComparison != 0) return exactPartComparison;
    final prayerTypeComparison = compareNullableLastUsed(
      inputs.lastUsedInPrayerType[left.id],
      inputs.lastUsedInPrayerType[right.id],
    );
    if (prayerTypeComparison != 0) return prayerTypeComparison;
    return _compareRecall(left, right, inputs.recallNeedsReviewSurahIds);
  }

  /// Convenience overload taking a resolved [ContextualRecommendationInputs]
  /// bundle, so Home and the widget projection factory pass the exact same
  /// value through without re-unpacking its three fields at each call site.
  List<SurahSuggestion> suggestWith(
    RotationSnapshot snapshot,
    ContextualRecommendationInputs inputs, {
    int limit = maxRecommendationCount,
  }) => suggest(
    snapshot,
    alreadyFilledInCurrentPartSurahIds:
        inputs.alreadyFilledInCurrentPartSurahIds,
    lastUsedInExactPart: inputs.lastUsedInExactPart,
    lastUsedInPrayerType: inputs.lastUsedInPrayerType,
    recallNeedsReviewSurahIds: inputs.recallNeedsReviewSurahIds,
    limit: limit,
  );
}
