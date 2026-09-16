import 'prayer.dart';
import 'recitation.dart';

/// What storage knows about one prayer on one day.
///
/// Deliberately raw: the calendar's meaning is decided in one place, by
/// [PrayerCalendarService], rather than by whichever query happened to load
/// the rows.
final class PrayerCalendarFact {
  const PrayerCalendarFact({
    required this.date,
    required this.prayerType,
    required this.isQada,
    required this.hasSession,
    required this.totalPartCount,
    required this.completedPartCount,
    required this.recitationCount,
  });

  final LocalDate date;
  final PrayerType prayerType;
  final bool isQada;

  /// Whether a routine session exists. Without one, "how much of this prayer
  /// is done" is not a question the data can answer.
  final bool hasSession;
  final int totalPartCount;

  /// Parts that are finished, including ones completed by following the imam —
  /// which is exactly why a plain recitation count is not enough to decide
  /// what a day looks like.
  final int completedPartCount;
  final int recitationCount;
}

/// One prayer the calendar will actually draw.
final class PrayerCalendarEntry {
  const PrayerCalendarEntry({
    required this.prayerType,
    required this.isQada,
    required this.hasSession,
    required this.isComplete,
  });

  final PrayerType prayerType;
  final bool isQada;
  final bool hasSession;
  final bool isComplete;

  bool get isPartial => hasSession && !isComplete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerCalendarEntry &&
          prayerType == other.prayerType &&
          isQada == other.isQada &&
          hasSession == other.hasSession &&
          isComplete == other.isComplete;

  @override
  int get hashCode => Object.hash(prayerType, isQada, hasSession, isComplete);

  @override
  String toString() =>
      'PrayerCalendarEntry(${prayerType.name}, qada: $isQada, '
      'complete: $isComplete)';
}

/// One cell of the month grid.
///
/// A day with nothing on it is **"нет отметки"**, never "missed": the app
/// records what the user entered and does not pronounce on whether a prayer
/// was performed. That distinction is the whole reason [hasNoRecord] is named
/// the way it is.
final class PrayerCalendarDay {
  factory PrayerCalendarDay({
    required LocalDate date,
    required Iterable<PrayerCalendarEntry> entries,
  }) => PrayerCalendarDay._(
    date: date,
    entries: List<PrayerCalendarEntry>.unmodifiable(entries),
  );

  const PrayerCalendarDay._({required this.date, required this.entries});

  final LocalDate date;
  final List<PrayerCalendarEntry> entries;

  int get ordinaryCount => entries.where((entry) => !entry.isQada).length;

  int get qadaCount => entries.where((entry) => entry.isQada).length;

  bool get hasOrdinary => ordinaryCount > 0;

  bool get hasQada => qadaCount > 0;

  /// A session that exists and is unfinished. A prayer with no session is not
  /// partial — it is simply not measurable — so one surah never paints a whole
  /// day as done, and an absent routine never paints it as half done either.
  bool get hasPartial => entries.any((entry) => entry.isPartial);

  bool get hasNoRecord => entries.isEmpty;
}

/// Turns stored facts into what a month grid shows.
final class PrayerCalendarService {
  const PrayerCalendarService();

  /// [days] is given rather than derived so the caller decides which month —
  /// and so a day with no facts at all still produces a cell.
  List<PrayerCalendarDay> build({
    required Iterable<LocalDate> days,
    required Iterable<PrayerCalendarFact> facts,
  }) {
    final byDate = <LocalDate, List<PrayerCalendarEntry>>{};
    for (final fact in facts) {
      final entry = _entryOf(fact);
      if (entry == null) continue;
      (byDate[fact.date] ??= <PrayerCalendarEntry>[]).add(entry);
    }
    for (final entries in byDate.values) {
      entries.sort((left, right) {
        final byQada = (left.isQada ? 1 : 0).compareTo(right.isQada ? 1 : 0);
        if (byQada != 0) return byQada;
        return left.prayerType.index.compareTo(right.prayerType.index);
      });
    }
    return List<PrayerCalendarDay>.unmodifiable(<PrayerCalendarDay>[
      for (final date in days)
        PrayerCalendarDay(
          date: date,
          entries: byDate[date] ?? const <PrayerCalendarEntry>[],
        ),
    ]);
  }

  /// A prayer appears only once something was actually registered for it.
  ///
  /// An empty session — created merely because the user opened the app during
  /// that prayer's window — is not a record of anything and must not colour a
  /// day.
  PrayerCalendarEntry? _entryOf(PrayerCalendarFact fact) {
    final recorded = fact.completedPartCount > 0 || fact.recitationCount > 0;
    if (!recorded) return null;
    return PrayerCalendarEntry(
      prayerType: fact.prayerType,
      isQada: fact.isQada,
      hasSession: fact.hasSession,
      isComplete: fact.hasSession
          ? fact.totalPartCount > 0 &&
                fact.completedPartCount >= fact.totalPartCount
          : true,
    );
  }
}
