import 'rotation.dart';
import 'rotation_scheme.dart';
import 'surah.dart';

/// Explainable recommendation for a mastered surah.
final class SurahSuggestion {
  SurahSuggestion({
    required this.surah,
    required this.remaining,
    Iterable<SurahRotationPart> recommendedParts = const <SurahRotationPart>[],
  }) : recommendedParts = List<SurahRotationPart>.unmodifiable(
         recommendedParts,
       );

  final MasteredSurah surah;
  final int remaining;
  final List<SurahRotationPart> recommendedParts;

  SurahRotationPart? get recommendedPart =>
      recommendedParts.isEmpty ? null : recommendedParts.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahSuggestion &&
          surah == other.surah &&
          remaining == other.remaining &&
          _sameParts(recommendedParts, other.recommendedParts);

  @override
  int get hashCode =>
      Object.hash(surah, remaining, Object.hashAll(recommendedParts));
}

/// Orders active surahs using deterministic, user-explainable rules.
final class SurahSuggestionService {
  const SurahSuggestionService();

  List<SurahSuggestion> suggest(RotationSnapshot snapshot, {int limit = 3}) {
    if (limit < 0) {
      throw ArgumentError.value(limit, 'limit', 'Must not be negative.');
    }
    if (limit == 0) return const <SurahSuggestion>[];

    final candidates = snapshot.activeSurahs
        .map((MasteredSurah surah) {
          final remaining = snapshot.rotationTarget - surah.rotationScore;
          if (remaining <= 0) return null;
          final parts = surah.rotationScheme.parts.where(
            (SurahRotationPart part) =>
                snapshot.rotationTarget - part.rotationScore == remaining,
          );
          final sortedParts = parts.toList()..sort(_compareParts);
          return SurahSuggestion(
            surah: surah,
            remaining: remaining,
            recommendedParts: sortedParts,
          );
        })
        .whereType<SurahSuggestion>()
        .toList();
    candidates.sort(_compare);
    return List<SurahSuggestion>.unmodifiable(candidates.take(limit));
  }

  int _compare(SurahSuggestion left, SurahSuggestion right) {
    // Greater debt is more urgent.
    final remainingComparison = right.remaining.compareTo(left.remaining);
    if (remainingComparison != 0) return remainingComparison;

    // Never-recited surahs precede every timestamped surah.
    final leftUsed = left.recommendedPart?.lastUsedAtUtc;
    final rightUsed = right.recommendedPart?.lastUsedAtUtc;
    if (leftUsed == null && rightUsed != null) return -1;
    if (leftUsed != null && rightUsed == null) return 1;
    if (leftUsed != null && rightUsed != null) {
      final lastUsedComparison = leftUsed.compareTo(rightUsed);
      if (lastUsedComparison != 0) return lastUsedComparison;
    }

    final orderComparison = left.surah.displayOrder.compareTo(
      right.surah.displayOrder,
    );
    if (orderComparison != 0) return orderComparison;
    return left.surah.id.compareTo(right.surah.id);
  }

  int _compareParts(SurahRotationPart left, SurahRotationPart right) {
    final leftUsed = left.lastUsedAtUtc;
    final rightUsed = right.lastUsedAtUtc;
    if (leftUsed == null && rightUsed != null) return -1;
    if (leftUsed != null && rightUsed == null) return 1;
    if (leftUsed != null && rightUsed != null) {
      final timeOrder = leftUsed.compareTo(rightUsed);
      if (timeOrder != 0) return timeOrder;
    }
    return left.partNumber.compareTo(right.partNumber);
  }
}

bool _sameParts(List<SurahRotationPart> left, List<SurahRotationPart> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
