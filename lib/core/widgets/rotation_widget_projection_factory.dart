import '../application/widget_recitation_action.dart';
import '../domain/domain.dart';
import 'widget_projection_builder.dart';
import 'widget_snapshot.dart';

/// Display-ready current prayer-part state supplied by the application layer.
///
/// The labels are already localized. [nextSlotIndex] is the one exact slot an
/// interactive widget action may fill; null keeps the part visible but makes
/// direct marking unavailable (for example, after completion or for a
/// zero-slot/followed-imam part).
final class RotationWidgetPrayerPartProjection {
  factory RotationWidgetPrayerPartProjection({
    required String prayerSessionId,
    required String prayerSessionPartId,
    required int completedSlots,
    required int requiredSlots,
    required String currentPartLabel,
    required String slotProgressLabel,
    int? nextSlotIndex,
  }) {
    if (prayerSessionId.isEmpty || prayerSessionPartId.isEmpty) {
      throw ArgumentError('Prayer session projection IDs must not be empty.');
    }
    if (completedSlots < 0 ||
        requiredSlots < 0 ||
        completedSlots > requiredSlots) {
      throw ArgumentError('Prayer slot progress is invalid.');
    }
    if (currentPartLabel.isEmpty || slotProgressLabel.isEmpty) {
      throw ArgumentError('Localized prayer-part labels must not be empty.');
    }
    if (nextSlotIndex != null &&
        (nextSlotIndex < 0 ||
            nextSlotIndex >= requiredSlots ||
            nextSlotIndex > maxWidgetPrayerSlotIndex)) {
      throw ArgumentError.value(nextSlotIndex, 'nextSlotIndex');
    }
    return RotationWidgetPrayerPartProjection._(
      prayerSessionId: prayerSessionId,
      prayerSessionPartId: prayerSessionPartId,
      completedSlots: completedSlots,
      requiredSlots: requiredSlots,
      currentPartLabel: currentPartLabel,
      slotProgressLabel: slotProgressLabel,
      nextSlotIndex: nextSlotIndex,
    );
  }

  const RotationWidgetPrayerPartProjection._({
    required this.prayerSessionId,
    required this.prayerSessionPartId,
    required this.completedSlots,
    required this.requiredSlots,
    required this.currentPartLabel,
    required this.slotProgressLabel,
    required this.nextSlotIndex,
  });

  final String prayerSessionId;
  final String prayerSessionPartId;
  final int completedSlots;
  final int requiredSlots;
  final String currentPartLabel;
  final String slotProgressLabel;
  final int? nextSlotIndex;

  bool get canFillSlot => nextSlotIndex != null;
}

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
    RotationWidgetPrayerPartProjection? prayerPart,
    String? statusMessage,
    ContextualRecommendationInputs contextualInputs =
        ContextualRecommendationInputs.empty,
  }) {
    final recommendations = const ContextualSurahSuggestionService()
        .suggestWith(rotation, contextualInputs);
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
        final canMark =
            actionsEnabled && !isMarked && (prayerPart?.canFillSlot ?? true);
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
                ? _action(
                    createActionToken: createActionToken,
                    surahId: surah.id,
                    rotationSchemeId: scheme.id,
                    prayerPart: prayerPart,
                  )
                : null,
            isMarkedInCurrentPart: isMarked,
            disabledReason: isMarked
                ? 'alreadyMarked'
                : actionsEnabled
                ? prayerPart != null && !prayerPart.canFillSlot
                      ? 'prayerPartUnavailable'
                      : null
                : 'prayerContextUnavailable',
          ),
        );
        continue;
      }
      for (final part in scheme.parts) {
        final isMarked = markedPartIds.contains(part.id);
        final canMark =
            actionsEnabled && !isMarked && (prayerPart?.canFillSlot ?? true);
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
                ? _action(
                    createActionToken: createActionToken,
                    surahId: surah.id,
                    rotationSchemeId: scheme.id,
                    partId: part.id,
                    prayerPart: prayerPart,
                  )
                : null,
            isMarkedInCurrentPart: isMarked,
            disabledReason: isMarked
                ? 'alreadyMarked'
                : actionsEnabled
                ? prayerPart != null && !prayerPart.canFillSlot
                      ? 'prayerPartUnavailable'
                      : null
                : 'prayerContextUnavailable',
          ),
        );
      }
    }
    return WidgetProjectionBuilder(labels).buildRotation(
      candidates,
      contextLabel: contextLabel,
      currentPartLabel: prayerPart?.currentPartLabel,
      slotProgressLabel: prayerPart?.slotProgressLabel,
      statusMessage: statusMessage,
    );
  }
}

WidgetRecitationAction _action({
  required String Function() createActionToken,
  required String surahId,
  required String rotationSchemeId,
  String? partId,
  RotationWidgetPrayerPartProjection? prayerPart,
}) => WidgetRecitationAction(
  actionToken: createActionToken(),
  surahId: surahId,
  rotationSchemeId: rotationSchemeId,
  partId: partId,
  prayerSessionId: prayerPart?.prayerSessionId,
  prayerSessionPartId: prayerPart?.prayerSessionPartId,
  slotIndex: prayerPart?.nextSlotIndex,
);

int _nonNegative(int value) => value < 0 ? 0 : value;
