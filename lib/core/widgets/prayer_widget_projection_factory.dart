import '../domain/domain.dart';
import 'widget_snapshot.dart';

/// One of the six daily boundaries, already resolved to its effective local
/// time. [prayerType] is null only for Sunrise, which is a boundary, never a
/// [PrayerType].
final class PrayerWidgetBoundary {
  const PrayerWidgetBoundary({
    required this.label,
    required this.hour,
    required this.minute,
    this.prayerType,
  });

  final String label;
  final int hour;
  final int minute;
  final PrayerType? prayerType;
}

/// Builds the display-ready Prayer Times widget projection.
///
/// This is deliberately a thin formatting/assembly layer: which prayer is
/// current/next and whether the schedule is stale are decided once by the
/// existing schedule/context resolvers and passed in already resolved.
/// Nothing here re-derives that business logic, matching the rule that
/// native code (and this factory) must never own a second resolver.
final class PrayerWidgetProjectionFactory {
  const PrayerWidgetProjectionFactory();

  PrayerWidgetProjection unavailable(String messageLabel) =>
      PrayerWidgetProjection.unavailable(messageLabel: messageLabel);

  PrayerWidgetProjection available({
    required String dateLabel,
    required String regionLabel,
    required String providerLabel,
    required List<PrayerWidgetBoundary> boundaries,
    PrayerType? currentPrayerType,
    PrayerType? nextPrayerType,
    String? currentLabel,
    String? nextLabel,
    bool isStale = false,
    String? staleLabel,
  }) {
    final entries = boundaries.map(
      (boundary) => PrayerWidgetTimeEntry(
        label: boundary.label,
        timeLabel: _formatTime(boundary.hour, boundary.minute),
        isBoundaryOnly: boundary.prayerType == null,
        isCurrent:
            boundary.prayerType != null &&
            boundary.prayerType == currentPrayerType,
        isNext:
            boundary.prayerType != null &&
            boundary.prayerType == nextPrayerType,
      ),
    );
    return PrayerWidgetProjection.available(
      dateLabel: dateLabel,
      regionLabel: regionLabel,
      providerLabel: providerLabel,
      entries: entries,
      currentLabel: currentLabel,
      nextLabel: nextLabel,
      isStale: isStale,
      staleLabel: staleLabel,
    );
  }

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
