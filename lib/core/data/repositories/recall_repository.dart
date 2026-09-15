import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';

/// How often each result appeared for one surah, used to explain review
/// priority to the user rather than to score them.
final class RecallSurahSummary {
  const RecallSurahSummary({
    required this.surahId,
    required this.recalled,
    required this.recalledWithMistake,
    required this.notRecalled,
    required this.lastAttemptAtUtc,
    required this.lastResult,
  });

  final String surahId;
  final int recalled;
  final int recalledWithMistake;
  final int notRecalled;
  final DateTime? lastAttemptAtUtc;

  /// The most recent attempt's result, by insertion order.
  final RecallResult? lastResult;

  int get total => recalled + recalledWithMistake + notRecalled;
  int get imperfect => recalledWithMistake + notRecalled;

  /// True when the last check did not go cleanly.
  ///
  /// Only the latest attempt counts, so a clean check clears the flag and an
  /// old mistake cannot keep a surah at the front of the queue forever.
  bool get needsReview =>
      lastResult != null && lastResult != RecallResult.recalled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallSurahSummary &&
          surahId == other.surahId &&
          recalled == other.recalled &&
          recalledWithMistake == other.recalledWithMistake &&
          notRecalled == other.notRecalled &&
          lastAttemptAtUtc == other.lastAttemptAtUtc &&
          lastResult == other.lastResult;

  @override
  int get hashCode => Object.hash(
    surahId,
    recalled,
    recalledWithMistake,
    notRecalled,
    lastAttemptAtUtc,
    lastResult,
  );
}

/// The recall journal: append-only, and never rewritten.
///
/// Attempts are a record of what the user could remember at a moment in time.
/// Editing or deleting them would turn an honest history into a flattering
/// one, so this repository offers no update and no delete.
final class RecallRepository {
  const RecallRepository(this.database);

  final AppDatabase database;

  Future<void> append(RecallAttempt attempt) async {
    await database
        .into(database.recallAttempts)
        .insert(
          RecallAttemptsCompanion.insert(
            id: attempt.id,
            surahId: attempt.surahId,
            ayahStart: attempt.ayahStart,
            ayahEnd: attempt.ayahEnd,
            learningCycle: Value<int>(attempt.learningCycle),
            result: attempt.result.name,
            createdAtUtc: attempt.createdAtUtc,
            localDate: attempt.localDate.toString(),
            source: attempt.source.name,
          ),
        );
  }

  Future<List<RecallAttempt>> getHistory({String? surahId, int limit = 50}) {
    final query = database.select(database.recallAttempts);
    if (surahId != null) {
      query.where((RecallAttempts row) => row.surahId.equals(surahId));
    }
    query
      ..orderBy(<OrderingTerm Function(RecallAttempts)>[
        (RecallAttempts row) => OrderingTerm.desc(row.sequence),
      ])
      ..limit(limit);
    return query.map(_fromRow).get();
  }

  Stream<List<RecallAttempt>> watchHistory({String? surahId, int limit = 50}) =>
      database
          .customSelect(
            // Drift keys cached query streams by SQL text and variables only,
            // so this watch needs text no other stream uses.
            'SELECT 1 AS recall_history_watch',
            readsFrom: <ResultSetImplementation<Table, Object?>>{
              database.recallAttempts,
            },
          )
          .watch()
          .asyncMap(
            (List<QueryRow> _) => getHistory(surahId: surahId, limit: limit),
          );

  /// Per-surah counts for every surah that has ever been checked.
  Future<Map<String, RecallSurahSummary>> getSummaries() async {
    final rows = await database
        .customSelect(
          '''
      SELECT
        attempts.surah_id AS surah_id,
        SUM(CASE WHEN result = 'recalled' THEN 1 ELSE 0 END) AS recalled,
        SUM(CASE WHEN result = 'recalledWithMistake' THEN 1 ELSE 0 END)
          AS with_mistake,
        SUM(CASE WHEN result = 'notRecalled' THEN 1 ELSE 0 END)
          AS not_recalled,
        MAX(created_at_utc) AS last_attempt,
        (
          SELECT latest.result FROM recall_attempts AS latest
          WHERE latest.surah_id = attempts.surah_id
          ORDER BY latest.sequence DESC
          LIMIT 1
        ) AS last_result
      FROM recall_attempts AS attempts
      GROUP BY attempts.surah_id
    ''',
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            database.recallAttempts,
          },
        )
        .get();
    return <String, RecallSurahSummary>{
      for (final row in rows)
        row.read<String>('surah_id'): RecallSurahSummary(
          surahId: row.read<String>('surah_id'),
          recalled: row.read<int>('recalled'),
          recalledWithMistake: row.read<int>('with_mistake'),
          notRecalled: row.read<int>('not_recalled'),
          lastAttemptAtUtc: switch (row.read<int?>('last_attempt')) {
            final seconds? => DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000,
              isUtc: true,
            ),
            null => null,
          },
          lastResult: switch (row.read<String?>('last_result')) {
            final name? => RecallResult.values.byName(name),
            null => null,
          },
        ),
    };
  }

  Stream<Map<String, RecallSurahSummary>> watchSummaries() => database
      .customSelect(
        'SELECT 1 AS recall_summary_watch',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.recallAttempts,
        },
      )
      .watch()
      .asyncMap((List<QueryRow> _) => getSummaries());

  static RecallAttempt _fromRow(RecallAttemptRow row) => RecallAttempt(
    id: row.id,
    surahId: row.surahId,
    ayahStart: row.ayahStart,
    ayahEnd: row.ayahEnd,
    learningCycle: row.learningCycle,
    result: RecallResult.values.byName(row.result),
    createdAtUtc: row.createdAtUtc.toUtc(),
    localDate: _parseLocalDate(row.localDate),
    source: RecallSource.values.byName(row.source),
  );

  static LocalDate _parseLocalDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw StateError('Stored local date "$value" is malformed.');
    }
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
