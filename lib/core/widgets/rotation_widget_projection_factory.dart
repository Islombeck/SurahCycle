import '../application/widget_recitation_action.dart';
import '../domain/domain.dart';
import 'widget_projection_builder.dart';
import 'widget_snapshot.dart';

/// Builds the same rotation rows for foreground and headless widget refreshes.
final class RotationWidgetProjectionFactory {
  const RotationWidgetProjectionFactory({required this.labels});

  final WidgetProjectionLabels labels;

  RotationWidgetProjection build({
    required RotationSnapshot rotation,
    required String contextLabel,
    required String Function() createActionToken,
    required bool actionsEnabled,
    Set<String> markedPartIds = const <String>{},
    String? statusMessage,
  }) {
    final recommendations = const SurahSuggestionService().suggest(rotation);
    final recommendationRanks = <String, int>{
      for (var index = 0; index < recommendations.length; index += 1)
        recommendations[index].surah.id: index,
    };
    final recommendedPartIds = <String, String?>{
      for (final suggestion in recommendations)
        suggestion.surah.id: suggestion.recommendedPart?.id,
    };
    final candidates = <RotationWidgetCandidate>[];
    for (final surah in rotation.activeSurahs) {
      final scheme = surah.rotationScheme;
      if (!scheme.isSplit) {
        final isMarked = scheme.parts.every(
          (part) => markedPartIds.contains(part.id),
        );
        final canMark = actionsEnabled && !isMarked;
        candidates.add(
          RotationWidgetCandidate.whole(
            id: scheme.id,
            surahId: surah.id,
            surahNumber: surah.surah.surahNumber,
            displayName: surah.surah.displayName,
            ayahCount: surah.surah.ayahCount,
            remaining: _nonNegative(
              rotation.rotationTarget - surah.rotationScore,
            ),
            recommendationRank: recommendationRanks[surah.id],
            displayOrder: surah.displayOrder,
            lastUsedAtUtc: surah.lastUsedAtUtc,
            action: canMark
                ? WidgetRecitationAction(
                    actionToken: createActionToken(),
                    surahId: surah.id,
                    rotationSchemeId: scheme.id,
                  )
                : null,
            isMarkedInCurrentPart: isMarked,
            disabledReason: isMarked
                ? 'alreadyMarked'
                : actionsEnabled
                ? null
                : 'prayerContextUnavailable',
          ),
        );
        continue;
      }
      for (final part in scheme.parts) {
        final isMarked = markedPartIds.contains(part.id);
        final canMark = actionsEnabled && !isMarked;
        candidates.add(
          RotationWidgetCandidate.part(
            id: part.id,
            surahId: surah.id,
            surahNumber: surah.surah.surahNumber,
            displayName: surah.surah.displayName,
            partId: part.id,
            partIndex: part.partNumber,
            partCount: scheme.parts.length,
            startAyah: part.ayahRange.startAyah,
            endAyah: part.ayahRange.endAyah,
            remaining: _nonNegative(
              rotation.rotationTarget - part.rotationScore,
            ),
            recommendationRank: recommendedPartIds[surah.id] == part.id
                ? recommendationRanks[surah.id]
                : null,
            displayOrder: surah.displayOrder,
            lastUsedAtUtc: part.lastUsedAtUtc,
            action: canMark
                ? WidgetRecitationAction(
                    actionToken: createActionToken(),
                    surahId: surah.id,
                    rotationSchemeId: scheme.id,
                    partId: part.id,
                  )
                : null,
            isMarkedInCurrentPart: isMarked,
            disabledReason: isMarked
                ? 'alreadyMarked'
                : actionsEnabled
                ? null
                : 'prayerContextUnavailable',
          ),
        );
      }
    }
    return WidgetProjectionBuilder(labels).buildRotation(
      candidates,
      contextLabel: contextLabel,
      statusMessage: statusMessage,
    );
  }
}

int _nonNegative(int value) => value < 0 ? 0 : value;
