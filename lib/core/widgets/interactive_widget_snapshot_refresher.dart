import '../application/recitation_application_service.dart';
import '../data/repositories/surah_repository.dart';
import '../data/repositories/recitation_repository.dart';
import '../domain/domain.dart';
import '../../app/widget_localization.dart';
import 'home_widget_bridge.dart';
import 'rotation_widget_projection_factory.dart';
import 'widget_snapshot.dart';
import 'widget_sync_coordinator.dart';

typedef RotationWidgetPrayerPartLoader =
    Future<RotationWidgetPrayerPartProjection?> Function(
      PrayerContext context,
      LocalDate localDate,
      WidgetLocalization localization,
    );

/// Rebuilds a widget from authoritative local state without loading Quran
/// text, translation, transliteration, HTTP clients, or the Riverpod UI tree.
final class InteractiveWidgetSnapshotRefresher {
  const InteractiveWidgetSnapshotRefresher({
    required this.surahs,
    required this.recitations,
    required this.prayerContextResolver,
    required this.timeProvider,
    required this.createActionToken,
    required this.localDates,
    required this.bridge,
    this.prayerPartLoader,
    this.codec = const WidgetSnapshotCodec(),
  });

  final SurahRepository surahs;
  final RecitationRepository recitations;
  final RecitationPrayerContextResolver prayerContextResolver;
  final TimeProvider timeProvider;
  final String Function() createActionToken;
  final RecitationLocalDateProvider localDates;
  final WidgetSnapshotBridge bridge;
  final RotationWidgetPrayerPartLoader? prayerPartLoader;
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
    final localDate = localDates.today();
    final prayerPart = prayerContext == null || prayerPartLoader == null
        ? null
        : await prayerPartLoader!(prayerContext, localDate, localization);
    final markedPartIds = prayerContext == null
        ? const <String>{}
        : await recitations.getMarkedPartIds(
            context: prayerContext,
            localDate: localDate,
            prayerSessionPartId: prayerPart?.prayerSessionPartId,
          );
    final rebuiltRotation =
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
          markedPartIds: markedPartIds,
          prayerPart: prayerPart,
          statusMessage: actionFailed
              ? localization.l10n.widgetActionNotCompleted
              : null,
        );
    final snapshot = WidgetSnapshot(
      generatedAtUtc: timeProvider.nowUtc(),
      snapshotRevision: rotation.revision,
      locale: localization.languageCode,
      rotation: _preserveVisibleOrder(previous?.rotation, rebuiltRotation),
      // The interaction path does not need Quran content. Preserve the last
      // verified Learning/Prayer projections verbatim while refreshing rotation.
      learning: previous?.learning ?? const LearningWidgetProjection.empty(),
      prayer:
          previous?.prayer ??
          PrayerWidgetProjection.unavailable(
            messageLabel: localization.l10n.widgetOpenAppToLoadText,
          ),
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

RotationWidgetProjection _preserveVisibleOrder(
  RotationWidgetProjection? previous,
  RotationWidgetProjection current,
) {
  if (previous == null || previous.items.isEmpty || current.items.isEmpty) {
    return current;
  }
  final byId = <String, RotationWidgetItem>{
    for (final item in current.items) item.id: item,
  };
  final ordered = <RotationWidgetItem>[];
  for (final oldItem in previous.items) {
    final replacement = byId.remove(oldItem.id);
    if (replacement != null) ordered.add(replacement);
  }
  ordered.addAll(current.items.where((item) => byId.containsKey(item.id)));
  return RotationWidgetProjection(
    items: ordered,
    omittedCount: current.omittedCount,
    contextLabel: current.contextLabel,
    currentPartLabel: current.currentPartLabel,
    slotProgressLabel: current.slotProgressLabel,
    statusMessage: current.statusMessage,
  );
}
