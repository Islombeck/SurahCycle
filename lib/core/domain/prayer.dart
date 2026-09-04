enum PrayerType {
  fajr,
  dhuhr,
  jumuah,
  asr,
  maghrib,
  isha,
  witr,
  nafl;

  /// Product capability only; it deliberately makes no theological claim.
  bool get supportsQada => this != PrayerType.nafl && this != PrayerType.jumuah;
}

/// The prayer in which a recitation took place.
///
/// Qada is a mode of a concrete obligatory prayer, not a separate prayer.
final class PrayerContext {
  factory PrayerContext({required PrayerType prayerType, bool isQada = false}) {
    if (isQada && !prayerType.supportsQada) {
      throw ArgumentError.value(
        prayerType,
        'prayerType',
        'This prayer type does not support Qada context.',
      );
    }
    return PrayerContext._(prayerType: prayerType, isQada: isQada);
  }

  const PrayerContext._({required this.prayerType, required this.isQada});

  final PrayerType prayerType;
  final bool isQada;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerContext &&
          prayerType == other.prayerType &&
          isQada == other.isQada;

  @override
  int get hashCode => Object.hash(prayerType, isQada);

  @override
  String toString() =>
      'PrayerContext(prayerType: $prayerType, isQada: $isQada)';
}

/// Optional persisted grouping for recitations made in one prayer context.
final class PrayerSession {
  factory PrayerSession({
    required String id,
    required PrayerContext context,
    required DateTime startedAtUtc,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (!startedAtUtc.isUtc) {
      throw ArgumentError.value(startedAtUtc, 'startedAtUtc', 'Must be UTC.');
    }
    return PrayerSession._(
      id: id,
      context: context,
      startedAtUtc: startedAtUtc,
    );
  }

  const PrayerSession._({
    required this.id,
    required this.context,
    required this.startedAtUtc,
  });

  final String id;
  final PrayerContext context;
  final DateTime startedAtUtc;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerSession &&
          id == other.id &&
          context == other.context &&
          startedAtUtc == other.startedAtUtc;

  @override
  int get hashCode => Object.hash(id, context, startedAtUtc);
}
