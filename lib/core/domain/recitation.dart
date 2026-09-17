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
    String? prayerSessionPartId,
    int? slotIndex,
    RecitationCoverage? coverage,
    String? rotationSchemeId,
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
    bool qadaOriginIsUnknown = false,
    LocalDate? qadaFulfilledLocalDate,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    // Only a Qada is made up. An ordinary record happened on its own day, and
    // a second date there would describe nothing.
    if (qadaFulfilledLocalDate != null && !prayerContext.isQada) {
      throw ArgumentError.value(
        qadaFulfilledLocalDate,
        'qadaFulfilledLocalDate',
        'Only a Qada recitation has a make-up day.',
      );
    }
    // A prayer cannot be made up before it was due. When the original day is
    // unknown, [localDate] already *is* the make-up day, so the two are equal
    // and this still holds.
    if (qadaFulfilledLocalDate != null &&
        qadaFulfilledLocalDate.compareTo(localDate) < 0) {
      throw ArgumentError.value(
        qadaFulfilledLocalDate,
        'qadaFulfilledLocalDate',
        'A prayer cannot be made up before the day it belongs to.',
      );
    }
    // Only a Qada can have an unknown origin. An ordinary record always knows
    // the day it belongs to, because the user picked it.
    if (qadaOriginIsUnknown && !prayerContext.isQada) {
      throw ArgumentError.value(
        qadaOriginIsUnknown,
        'qadaOriginIsUnknown',
        'Only a Qada recitation can have an unknown original day.',
      );
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
    if (prayerSessionPartId != null && prayerSessionPartId.isEmpty) {
      throw ArgumentError.value(prayerSessionPartId, 'prayerSessionPartId');
    }
    if (prayerSessionPartId != null && prayerSessionId == null) {
      throw ArgumentError(
        'prayerSessionPartId requires a concrete prayerSessionId.',
      );
    }
    if (slotIndex != null && (slotIndex < 0 || prayerSessionPartId == null)) {
      throw ArgumentError.value(slotIndex, 'slotIndex');
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
      prayerSessionPartId: prayerSessionPartId,
      slotIndex: slotIndex,
      coverage: resolvedCoverage,
      rakaatSpanCount: rakaatSpanCount,
      qadaOriginIsUnknown: qadaOriginIsUnknown,
      qadaFulfilledLocalDate: qadaFulfilledLocalDate,
    );
  }

  const SurahRecitationEvent._({
    required this.id,
    required this.surahId,
    required this.prayerContext,
    required this.createdAtUtc,
    required this.localDate,
    required this.prayerSessionId,
    required this.prayerSessionPartId,
    required this.slotIndex,
    required this.coverage,
    required this.rakaatSpanCount,
    required this.qadaOriginIsUnknown,
    required this.qadaFulfilledLocalDate,
  });

  @override
  final String id;
  final String surahId;
  final PrayerContext prayerContext;
  @override
  final DateTime createdAtUtc;
  final LocalDate localDate;
  final String? prayerSessionId;
  final String? prayerSessionPartId;
  final int? slotIndex;
  final RecitationCoverage? coverage;
  final int rakaatSpanCount;

  /// The user is making up a prayer whose day he cannot name — someone closing
  /// very old debts from before he began praying regularly. [localDate] then
  /// means the day the make-up was entered for, and every screen says so
  /// instead of placing the debt on a day nothing supports.
  final bool qadaOriginIsUnknown;

  /// The day the make-up was actually performed.
  ///
  /// [localDate] says which prayer is being made up; this says when it was
  /// prayed, and [createdAtUtc] says when it was typed in. All three are
  /// different questions, and only conflating them loses information: a debt
  /// reconstructed a week later has three distinct dates and every one of them
  /// is true.
  ///
  /// Null means not recorded, which is every row written before schema v9. It
  /// is never derived from [createdAtUtc], because that would turn "we do not
  /// know" into a date the user never gave.
  final LocalDate? qadaFulfilledLocalDate;

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
        prayerSessionPartId: prayerSessionPartId,
        slotIndex: slotIndex,
        coverage: coverage,
        rakaatSpanCount: rakaatSpanCount,
        qadaOriginIsUnknown: qadaOriginIsUnknown,
        qadaFulfilledLocalDate: qadaFulfilledLocalDate,
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
          prayerSessionPartId == other.prayerSessionPartId &&
          slotIndex == other.slotIndex &&
          coverage == other.coverage &&
          rakaatSpanCount == other.rakaatSpanCount &&
          qadaOriginIsUnknown == other.qadaOriginIsUnknown &&
          qadaFulfilledLocalDate == other.qadaFulfilledLocalDate;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    prayerContext,
    createdAtUtc,
    localDate,
    prayerSessionId,
    prayerSessionPartId,
    slotIndex,
    coverage,
    rakaatSpanCount,
    qadaOriginIsUnknown,
    qadaFulfilledLocalDate,
  );
}
