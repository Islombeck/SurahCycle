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
  });

  static const ContextualRecommendationInputs empty =
      ContextualRecommendationInputs();

  final Set<String> alreadyFilledInCurrentPartSurahIds;
  final Map<String, DateTime> lastUsedInExactPart;
  final Map<String, DateTime> lastUsedInPrayerType;
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
/// 6. Still tied: the existing global tie-break chain (recommended part's
///    own last-used time, display order, surah number, stable id).
///
/// With empty [lastUsedInExactPart]/[lastUsedInPrayerType] maps and an empty
/// [alreadyFilledInCurrentPartSurahIds] set — the state before any prayer
/// context or contextual history exists — every inserted tier compares
/// equal for every candidate, so the result is byte-for-byte identical to
/// calling [suggestionService] directly. That is the intended "no context
/// yet" fallback; there is no separate branch for it.
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
        return compareNullableLastUsed(
          lastUsedInPrayerType[left.id],
          lastUsedInPrayerType[right.id],
        );
      },
    );
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
    return compareNullableLastUsed(
      inputs.lastUsedInPrayerType[left.id],
      inputs.lastUsedInPrayerType[right.id],
    );
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
    limit: limit,
  );
}
