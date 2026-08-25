import 'prayer.dart';

/// Common shape for ordered facts used to rebuild a rotation snapshot.
abstract interface class RotationJournalEvent {
  String get id;
  DateTime get createdAtUtc;
}

/// The immutable set of rotation parts credited by one recitation action.
///
/// The scheme identifier makes historical coverage stable when a surah is
/// repartitioned later.
final class RecitationCoverage {
  factory RecitationCoverage({
    required String rotationSchemeId,
    required Iterable<String> coveredPartIds,
  }) {
    if (rotationSchemeId.isEmpty) {
      throw ArgumentError.value(
        rotationSchemeId,
        'rotationSchemeId',
        'Must not be empty.',
      );
    }
    final immutablePartIds = List<String>.unmodifiable(coveredPartIds);
    if (immutablePartIds.isEmpty) {
      throw ArgumentError.value(
        immutablePartIds,
        'coveredPartIds',
        'At least one part must be covered.',
      );
    }
    final uniqueIds = <String>{};
    for (final id in immutablePartIds) {
      if (id.isEmpty) {
        throw ArgumentError.value(id, 'coveredPartIds', 'Must not be empty.');
      }
      if (!uniqueIds.add(id)) {
        throw ArgumentError.value(
          id,
          'coveredPartIds',
          'Covered part IDs must be unique.',
        );
      }
    }
    return RecitationCoverage._(
      rotationSchemeId: rotationSchemeId,
      coveredPartIds: immutablePartIds,
    );
  }

  const RecitationCoverage._({
    required this.rotationSchemeId,
    required this.coveredPartIds,
  });

  final String rotationSchemeId;
  final List<String> coveredPartIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RecitationCoverage ||
        rotationSchemeId != other.rotationSchemeId ||
        coveredPartIds.length != other.coveredPartIds.length) {
      return false;
    }
    for (var index = 0; index < coveredPartIds.length; index += 1) {
      if (coveredPartIds[index] != other.coveredPartIds[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(rotationSchemeId, Object.hashAll(coveredPartIds));
}

/// Calendar date captured in the user's locale when an event is created.
///
/// It intentionally has no time zone or time-of-day semantics.
final class LocalDate implements Comparable<LocalDate> {
  factory LocalDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError.value(
        '$year-$month-$day',
        'date',
        'Must be a valid calendar date.',
      );
    }
    return LocalDate._(year, month, day);
  }

  factory LocalDate.fromLocalDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  const LocalDate._(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  int compareTo(LocalDate other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) return yearComparison;
    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) return monthComparison;
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Immutable fact that a user registered one surah recitation.
///
/// UUID generation belongs to the application/infrastructure boundary; this
/// domain object accepts the generated identifier and preserves it verbatim.
final class SurahRecitationEvent implements RotationJournalEvent {
  factory SurahRecitationEvent({
    required String id,
    required String surahId,
    required PrayerContext prayerContext,
    required DateTime createdAtUtc,
    required LocalDate localDate,
    String? prayerSessionId,
    RecitationCoverage? coverage,
    String? rotationSchemeId,
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    if (prayerSessionId != null && prayerSessionId.isEmpty) {
      throw ArgumentError.value(
        prayerSessionId,
        'prayerSessionId',
        'Must be null or non-empty.',
      );
    }
    if (rakaatSpanCount < 1) {
      throw ArgumentError.value(
        rakaatSpanCount,
        'rakaatSpanCount',
        'Must be at least one.',
      );
    }
    if (coverage != null &&
        (rotationSchemeId != null || coveredPartIds != null)) {
      throw ArgumentError(
        'Provide either coverage or raw scheme/part fields, not both.',
      );
    }
    if ((rotationSchemeId == null) != (coveredPartIds == null)) {
      throw ArgumentError(
        'rotationSchemeId and coveredPartIds must be provided together.',
      );
    }
    final resolvedCoverage =
        coverage ??
        (rotationSchemeId == null
            ? null
            : RecitationCoverage(
                rotationSchemeId: rotationSchemeId,
                coveredPartIds: coveredPartIds!,
              ));
    return SurahRecitationEvent._(
      id: id,
      surahId: surahId,
      prayerContext: prayerContext,
      createdAtUtc: createdAtUtc,
      localDate: localDate,
      prayerSessionId: prayerSessionId,
      coverage: resolvedCoverage,
      rakaatSpanCount: rakaatSpanCount,
    );
  }

  const SurahRecitationEvent._({
    required this.id,
    required this.surahId,
    required this.prayerContext,
    required this.createdAtUtc,
    required this.localDate,
    required this.prayerSessionId,
    required this.coverage,
    required this.rakaatSpanCount,
  });

  @override
  final String id;
  final String surahId;
  final PrayerContext prayerContext;
  @override
  final DateTime createdAtUtc;
  final LocalDate localDate;
  final String? prayerSessionId;
  final RecitationCoverage? coverage;
  final int rakaatSpanCount;

  PrayerType get prayerType => prayerContext.prayerType;
  bool get isQada => prayerContext.isQada;
  String? get rotationSchemeId => coverage?.rotationSchemeId;
  List<String> get coveredPartIds =>
      coverage?.coveredPartIds ?? const <String>[];
  bool get hasExplicitCoverage => coverage != null;

  SurahRecitationEvent withCoverage(RecitationCoverage coverage) =>
      SurahRecitationEvent(
        id: id,
        surahId: surahId,
        prayerContext: prayerContext,
        createdAtUtc: createdAtUtc,
        localDate: localDate,
        prayerSessionId: prayerSessionId,
        coverage: coverage,
        rakaatSpanCount: rakaatSpanCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahRecitationEvent &&
          id == other.id &&
          surahId == other.surahId &&
          prayerContext == other.prayerContext &&
          createdAtUtc == other.createdAtUtc &&
          localDate == other.localDate &&
          prayerSessionId == other.prayerSessionId &&
          coverage == other.coverage &&
          rakaatSpanCount == other.rakaatSpanCount;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    prayerContext,
    createdAtUtc,
    localDate,
    prayerSessionId,
    coverage,
    rakaatSpanCount,
  );
}
