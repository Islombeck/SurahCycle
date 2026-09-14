import 'dart:convert';

import '../../domain/domain.dart';
import 'settings_repository.dart';

/// The stored batch plus the cycle it belongs to.
final class StoredRecommendationState {
  const StoredRecommendationState({this.batch, required this.cycle});

  final RecommendationBatch? batch;
  final RecommendationCycleState cycle;
}

/// Persists the visible recommendation batch as versioned JSON in AppSettings.
///
/// Deliberately not a Drift table: a batch is a replaceable presentation
/// decision, not user history. Losing it costs one rebuilt batch, so it does
/// not justify a schema migration, and the authoritative record of what was
/// actually recited stays in the recitation journal. Anything unreadable —
/// missing, malformed, or written by a newer schema — is treated as absent and
/// rebuilt rather than guessed at.
final class RecommendationBatchRepository {
  const RecommendationBatchRepository(this.settings);

  static const String settingKey = 'recommendationBatch';
  static const int schemaVersion = 1;

  final AppSettingsRepository settings;

  Future<StoredRecommendationState> load() async {
    final raw = await settings.getString(settingKey);
    return decode(raw);
  }

  Stream<StoredRecommendationState> watch() =>
      settings.watchString(settingKey).map(decode);

  Future<void> save(
    StoredRecommendationState state, {
    required DateTime updatedAtUtc,
  }) => settings.setString(
    settingKey,
    jsonEncode(encode(state)),
    updatedAtUtc: updatedAtUtc,
  );

  static Map<String, Object?> encode(StoredRecommendationState state) =>
      <String, Object?>{
        'schemaVersion': schemaVersion,
        'cycle': <String, Object?>{
          'cycleNumber': state.cycle.cycleNumber,
          'offeredSurahIds': state.cycle.offeredSurahIds.toList(),
        },
        if (state.batch case final batch?)
          'batch': <String, Object?>{
            'localDate': batch.key.localDate.toString(),
            'prayerType': batch.key.prayerType.name,
            'isQada': batch.key.isQada,
            'partStableKey': batch.key.partStableKey,
            'algorithmVersion': batch.key.algorithmVersion,
            'entries': <Map<String, Object?>>[
              for (final entry in batch.entries)
                <String, Object?>{
                  'surahId': entry.surahId,
                  'position': entry.position,
                  'occurrence': entry.occurrence,
                },
            ],
          },
      };

  static StoredRecommendationState decode(String? raw) {
    if (raw == null || raw.isEmpty) return _emptyState;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return _emptyState;
      if (decoded['schemaVersion'] != schemaVersion) return _emptyState;
      return StoredRecommendationState(
        batch: _decodeBatch(decoded['batch']),
        cycle: _decodeCycle(decoded['cycle']),
      );
    } on Object {
      // Corrupt state is never partially trusted: rebuild from scratch.
      return _emptyState;
    }
  }

  static RecommendationCycleState _decodeCycle(Object? raw) {
    if (raw is! Map<String, Object?>) return RecommendationCycleState.empty;
    final cycleNumber = raw['cycleNumber'];
    final offered = raw['offeredSurahIds'];
    if (cycleNumber is! int || cycleNumber < 1 || offered is! List) {
      return RecommendationCycleState.empty;
    }
    return RecommendationCycleState(
      offeredSurahIds: offered.whereType<String>(),
      cycleNumber: cycleNumber,
    );
  }

  static RecommendationBatch? _decodeBatch(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final localDate = raw['localDate'];
    final prayerType = raw['prayerType'];
    final isQada = raw['isQada'];
    final algorithmVersion = raw['algorithmVersion'];
    final entries = raw['entries'];
    if (localDate is! String ||
        prayerType is! String ||
        isQada is! bool ||
        algorithmVersion is! int ||
        entries is! List) {
      return null;
    }
    final partStableKey = raw['partStableKey'];
    if (partStableKey != null && partStableKey is! String) return null;
    final parsedDate = _parseLocalDate(localDate);
    if (parsedDate == null) return null;
    if (!PrayerType.values.any((type) => type.name == prayerType)) return null;

    final decodedEntries = <RecommendationBatchEntry>[];
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) return null;
      final surahId = entry['surahId'];
      final position = entry['position'];
      final occurrence = entry['occurrence'];
      if (surahId is! String || position is! int || occurrence is! int) {
        return null;
      }
      decodedEntries.add(
        RecommendationBatchEntry(
          surahId: surahId,
          position: position,
          occurrence: occurrence,
        ),
      );
    }
    return RecommendationBatch(
      key: RecommendationBatchKey(
        localDate: parsedDate,
        prayerType: PrayerType.values.byName(prayerType),
        isQada: isQada,
        partStableKey: partStableKey as String?,
        algorithmVersion: algorithmVersion,
      ),
      entries: decodedEntries,
    );
  }

  static LocalDate? _parseLocalDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    try {
      return LocalDate(year, month, day);
    } on ArgumentError {
      return null;
    }
  }
}

final StoredRecommendationState _emptyState = StoredRecommendationState(
  cycle: RecommendationCycleState.empty,
);
