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
/// A thin formatting and assembly layer, with one real decision in it: how
/// the day divides into stretches of time and which row is current in each.
/// That decision belongs here rather than on the platform, and it is the
/// whole reason the widget can be right while the app is closed.
///
/// Two parts of it are not obvious and are the reason it is not left to a
/// comparison on the other side:
///
/// - **Before Fajr you are in last night's Isha.** The resolver has always
///   known this; the widget shows today's rows, so the first stretch of the
///   day points at the Isha row. The alternative — nothing highlighted until
///   dawn — would be wrong every single night.
/// - **Sunrise is not a prayer.** The stretch between Sunrise and Dhuhr has
///   no current prayer at all, and says so with an index of -1 rather than
///   leaving the platform to notice that one of the six rows is special.
final class PrayerWidgetProjectionFactory {
  const PrayerWidgetProjectionFactory();

  PrayerWidgetProjection unavailable(String messageLabel) =>
      PrayerWidgetProjection.unavailable(messageLabel: messageLabel);

  /// [localMidnightUtc] is the instant the shown day begins where the user
  /// is — midnight on that date, already shifted by the offset in force
  /// there. Every boundary is that instant plus its wall clock, so the whole
  /// day is expressed without the platform knowing anything about time zones.
  PrayerWidgetProjection available({
    required String dateLabel,
    required String regionLabel,
    required String providerLabel,
    required List<PrayerWidgetBoundary> boundaries,
    required DateTime localMidnightUtc,
    bool isStale = false,
    String? staleLabel,
  }) {
    if (!localMidnightUtc.isUtc) {
      throw ArgumentError.value(
        localMidnightUtc,
        'localMidnightUtc',
        'Must be a UTC instant.',
      );
    }
    final entries = <PrayerWidgetTimeEntry>[
      for (final boundary in boundaries)
        PrayerWidgetTimeEntry(
          label: boundary.label,
          timeLabel: _formatTime(boundary.hour, boundary.minute),
          isBoundaryOnly: boundary.prayerType == null,
        ),
    ];

    final dayStart = localMidnightUtc.millisecondsSinceEpoch;
    final dayEnd = localMidnightUtc
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    final starts = <int>[
      for (final boundary in boundaries)
        localMidnightUtc
            .add(Duration(hours: boundary.hour, minutes: boundary.minute))
            .millisecondsSinceEpoch,
    ];

    // The index of the last row that is a prayer: the one the night belongs
    // to before the day's first boundary, and after its last.
    final lastPrayerIndex = boundaries.lastIndexWhere(
      (boundary) => boundary.prayerType != null,
    );

    final windows = <PrayerWidgetWindow>[
      if (starts.first > dayStart)
        PrayerWidgetWindow(
          startUtcMs: dayStart,
          endUtcMs: starts.first,
          entryIndex: lastPrayerIndex,
        ),
      for (var index = 0; index < boundaries.length; index += 1)
        PrayerWidgetWindow(
          startUtcMs: starts[index],
          endUtcMs: index + 1 < starts.length ? starts[index + 1] : dayEnd,
          entryIndex: boundaries[index].prayerType == null ? -1 : index,
        ),
    ];

    return PrayerWidgetProjection.available(
      dateLabel: dateLabel,
      regionLabel: regionLabel,
      providerLabel: providerLabel,
      entries: entries,
      windows: windows,
      isStale: isStale,
      staleLabel: staleLabel,
    );
  }

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
