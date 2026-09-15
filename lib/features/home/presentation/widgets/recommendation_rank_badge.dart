import 'package:flutter/material.dart';

import '../../../../app/localization_extensions.dart';

/// A fixed-size, optically centred priority marker for recommendations.
///
/// This deliberately lives inside the chip label instead of using [Chip.avatar].
/// Material's avatar slot applies its own sizing and padding, which made the
/// circle and its digit appear misaligned on physical Android devices.
final class RecommendationRankBadge extends StatelessWidget {
  const RecommendationRankBadge({
    required this.rank,
    this.isCompleted = false,
    super.key,
  }) : assert(rank >= 1 && rank <= 8);

  static const double dimension = 24;

  final int rank;

  /// A completed position turns green and keeps its place, so the batch never
  /// shrinks as surahs are marked.
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.recommendationRank(rank),
      container: true,
      excludeSemantics: true,
      child: SizedBox.square(
        key: ValueKey<String>('recommendation-rank-badge-$rank'),
        dimension: dimension,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isCompleted
                ? colors.primaryContainer
                : colors.tertiaryContainer,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted
                  ? colors.primary
                  : colors.tertiary.withValues(alpha: 0.45),
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$rank',
                key: ValueKey<String>('recommendation-rank-text-$rank'),
                maxLines: 1,
                strutStyle: const StrutStyle(
                  fontSize: 12,
                  height: 1,
                  forceStrutHeight: true,
                ),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isCompleted
                      ? colors.onPrimaryContainer
                      : colors.onTertiaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
