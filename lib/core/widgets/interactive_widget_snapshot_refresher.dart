import '../application/recitation_application_service.dart';
import '../data/repositories/surah_repository.dart';
import '../domain/domain.dart';
import '../../app/widget_localization.dart';
import 'home_widget_bridge.dart';
import 'rotation_widget_projection_factory.dart';
import 'widget_snapshot.dart';
import 'widget_sync_coordinator.dart';

/// Rebuilds a widget from authoritative local state without loading Quran
/// text, translation, transliteration, HTTP clients, or the Riverpod UI tree.
final class InteractiveWidgetSnapshotRefresher {
  const InteractiveWidgetSnapshotRefresher({
    required this.surahs,
    required this.prayerContextResolver,
    required this.timeProvider,
    required this.createActionToken,
    required this.bridge,
    this.codec = const WidgetSnapshotCodec(),
  });

  final SurahRepository surahs;
  final RecitationPrayerContextResolver prayerContextResolver;
  final TimeProvider timeProvider;
  final String Function() createActionToken;
  final WidgetSnapshotBridge bridge;
  final WidgetSnapshotCodec codec;

  Future<WidgetSnapshot> refresh({bool actionFailed = false}) async {
    final previousResult = codec.decode(await bridge.loadSnapshotJson());
    final previous = previousResult is WidgetSnapshotDecoded
        ? previousResult.snapshot
        : null;
    final localization = WidgetLocalization.forLanguageCode(
      previous?.locale ?? 'ru',
    );
    final details =
        prayerContextResolver is DetailedRecitationPrayerContextResolver
        ? await (prayerContextResolver
                  as DetailedRecitationPrayerContextResolver)
              .resolveDetails()
        : RecitationPrayerContextDetails(
            context: await prayerContextResolver.resolve(),
            isAutomatic: false,
          );
    final prayerContext = details.context;
    final rotation = await surahs.getRotationSnapshot();
    final snapshot = WidgetSnapshot(
      generatedAtUtc: timeProvider.nowUtc(),
      locale: localization.languageCode,
      rotation:
          RotationWidgetProjectionFactory(
            labels: localization.projectionLabels,
          ).build(
            rotation: rotation,
            contextLabel: localization.prayerContextLabel(
              prayerContext,
              isAutomatic: details.isAutomatic,
              startsAt: details.startsAt,
              endsAt: details.endsAt,
            ),
            createActionToken: createActionToken,
            actionsEnabled: prayerContext != null,
            statusMessage: actionFailed
                ? localization.l10n.widgetActionNotCompleted
                : null,
          ),
      // The interaction path does not need Quran content. Preserve the last
      // verified Learning projection verbatim while refreshing rotation.
      learning: previous?.learning ?? const LearningWidgetProjection.empty(),
    );
    final coordinator = WidgetSyncCoordinator(
      bridge: bridge,
      debounce: Duration.zero,
    );
    try {
      await coordinator.syncNow(snapshot);
    } finally {
      coordinator.dispose();
    }
    return snapshot;
  }
}
