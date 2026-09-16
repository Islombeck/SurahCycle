import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';

/// Reads what the month grid needs, and nothing more.
///
/// The status of a day is derived from sessions, their parts **and**
/// recitation events together, because each alone gets it wrong: a prayer
/// completed by following the imam has no recitations, and a recitation
/// registered through the slotless flow has no session.
final class PrayerCalendarRepository {
  PrayerCalendarRepository(this.database);

  final AppDatabase database;

  /// Every day of [month], oldest first, including days with no record.
  Stream<List<PrayerCalendarDay>> watchMonth({
    required int year,
    required int month,
  }) => database
      .customSelect(
        // Unique per watch query: see the note in SurahRepository.watchCatalog.
        'SELECT 1 AS prayer_calendar_month_watch',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.prayerSessions,
          database.prayerSessionParts,
          database.recitationEvents,
        },
      )
      .watch()
      .asyncMap((_) => getMonth(year: year, month: month));

  Future<List<PrayerCalendarDay>> getMonth({
    required int year,
    required int month,
  }) async {
    final days = daysOfMonth(year, month);
    final from = days.first.toString();
    final to = days.last.toString();

    final sessions =
        await (database.select(database.prayerSessions)..where(
              (PrayerSessions row) =>
                  row.localDate.isBiggerOrEqualValue(from) &
                  row.localDate.isSmallerOrEqualValue(to),
            ))
            .get();
    final facts = <String, _MutableFact>{};
    for (final session in sessions) {
      final localDate = session.localDate;
      if (localDate == null) continue;
      final parts =
          await (database.select(database.prayerSessionParts)..where(
                (PrayerSessionParts row) =>
                    row.prayerSessionId.equals(session.id),
              ))
              .get();
      // An empty session is not a record of anything; it is left out entirely
      // rather than counted as a prayer with zero parts.
      if (parts.isEmpty) continue;
      final key = '$localDate|${session.prayerType}|${session.isQada}';
      final fact = facts.putIfAbsent(
        key,
        () => _MutableFact(
          date: _parseDate(localDate),
          prayerType: PrayerType.values.byName(session.prayerType),
          isQada: session.isQada,
        ),
      );
      fact.hasSession = true;
      // Several sessions for one prayer and day are possible in old data; the
      // fuller one decides, rather than the last one read.
      fact.totalPartCount = fact.totalPartCount < parts.length
          ? parts.length
          : fact.totalPartCount;
      final completed = parts
          .where((part) => part.completedAtUtc != null)
          .length;
      if (completed > fact.completedPartCount) {
        fact.completedPartCount = completed;
      }
    }

    final events =
        await (database.select(database.recitationEvents)..where(
              (RecitationEvents row) =>
                  row.localDate.isBiggerOrEqualValue(from) &
                  row.localDate.isSmallerOrEqualValue(to) &
                  row.deletedAtUtc.isNull(),
            ))
            .get();
    for (final event in events) {
      final key = '${event.localDate}|${event.prayerType}|${event.isQada}';
      final fact = facts.putIfAbsent(
        key,
        () => _MutableFact(
          date: _parseDate(event.localDate),
          prayerType: PrayerType.values.byName(event.prayerType),
          isQada: event.isQada,
        ),
      );
      fact.recitationCount += 1;
    }

    return const PrayerCalendarService().build(
      days: days,
      facts: <PrayerCalendarFact>[
        for (final fact in facts.values) fact.toFact(),
      ],
    );
  }

  static List<LocalDate> daysOfMonth(int year, int month) {
    final first = DateTime.utc(year, month);
    final next = DateTime.utc(month == 12 ? year + 1 : year, month % 12 + 1);
    final count = next.difference(first).inDays;
    return List<LocalDate>.unmodifiable(<LocalDate>[
      for (var day = 1; day <= count; day += 1) LocalDate(year, month, day),
    ]);
  }
}

final class _MutableFact {
  _MutableFact({
    required this.date,
    required this.prayerType,
    required this.isQada,
  });

  final LocalDate date;
  final PrayerType prayerType;
  final bool isQada;
  bool hasSession = false;
  int totalPartCount = 0;
  int completedPartCount = 0;
  int recitationCount = 0;

  PrayerCalendarFact toFact() => PrayerCalendarFact(
    date: date,
    prayerType: prayerType,
    isQada: isQada,
    hasSession: hasSession,
    totalPartCount: totalPartCount,
    completedPartCount: completedPartCount,
    recitationCount: recitationCount,
  );
}

LocalDate _parseDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw StateError('Invalid stored local date "$value".');
  }
  return LocalDate(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
