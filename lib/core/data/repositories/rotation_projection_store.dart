import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';

/// Maps the authoritative versioned journal to the cached rotation snapshot.
final class RotationProjectionStore {
  const RotationProjectionStore(this.database);

  static const int projectionVersion = 2;

  final AppDatabase database;

  Future<RotationStateRow> loadRotationState() async {
    final query = database.select(database.rotationStates)
      ..where((RotationStates row) => row.singletonId.equals(1));
    final existing = await query.getSingleOrNull();
    if (existing != null) return existing;

    await database
        .into(database.rotationStates)
        .insert(
          RotationStatesCompanion.insert(
            projectionVersion: const Value<int>(projectionVersion),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return query.getSingle();
  }

  Future<RotationSnapshot> loadSnapshot() async {
    final state = await loadRotationState();
    final masteredQuery = database.select(database.masteredSurahs)
      ..orderBy(<OrderingTerm Function(MasteredSurahs)>[
        (MasteredSurahs row) => OrderingTerm.asc(row.displayOrder),
        (MasteredSurahs row) => OrderingTerm.asc(row.surahId),
      ]);
    final masteredRows = await masteredQuery.get();
    final metadataRows = await database.select(database.surahMetadata).get();
    final schemeQuery = database.select(database.rotationSchemes)
      ..where((RotationSchemes row) => row.supersededJournalSequence.isNull());
    final schemeRows = await schemeQuery.get();
    final partRows = await database.select(database.rotationParts).get();

    final metadataById = <String, SurahMetadataRow>{
      for (final row in metadataRows) row.id: row,
    };
    final schemeBySurahId = <String, RotationSchemeRow>{
      for (final row in schemeRows) row.surahId: row,
    };
    final partsBySchemeId = <String, List<RotationPartRow>>{};
    for (final part in partRows) {
      partsBySchemeId
          .putIfAbsent(part.schemeId, () => <RotationPartRow>[])
          .add(part);
    }

    return RotationSnapshot(
      rotationTarget: state.rotationTarget,
      surahs: masteredRows.map((MasteredSurahRow row) {
        final metadata = metadataById[row.surahId];
        final scheme = schemeBySurahId[row.surahId];
        if (metadata == null) {
          throw StateError(
            'Mastered surah "${row.surahId}" has no catalog metadata.',
          );
        }
        if (scheme == null) {
          throw StateError(
            'Mastered surah "${row.surahId}" has no active rotation scheme.',
          );
        }
        final parts = partsBySchemeId[scheme.id] ?? <RotationPartRow>[];
        parts.sort(
          (RotationPartRow left, RotationPartRow right) =>
              left.ordinal.compareTo(right.ordinal),
        );
        return MasteredSurah(
          surah: SurahDescriptor(
            id: metadata.id,
            surahNumber: metadata.surahNumber,
            officialName: metadata.officialName,
            ayahCount: metadata.ayahCount,
            alias: row.alias,
          ),
          isActive: row.isActive,
          hasEnteredRotation: row.hasEnteredRotation,
          displayOrder: row.displayOrder,
          rotationScheme: _schemeFromRows(scheme, parts),
        );
      }),
    );
  }

  Stream<RotationSnapshot> watchSnapshot() => database
      .customSelect(
        'SELECT 1',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.rotationStates,
          database.masteredSurahs,
          database.surahMetadata,
          database.rotationSchemes,
          database.rotationParts,
        },
      )
      .watch()
      .asyncMap((List<QueryRow> _) => loadSnapshot());

  Future<int> nextJournalSequence() async =>
      (await loadRotationState()).lastJournalSequence + 1;

  Future<void> writeSnapshot(
    RotationSnapshot snapshot, {
    int? lastJournalSequence,
  }) async {
    final currentRows = await database.select(database.masteredSurahs).get();
    final currentIds = currentRows.map((row) => row.surahId).toSet();
    final snapshotIds = snapshot.surahs.map((surah) => surah.id).toSet();
    if (currentIds.length != snapshotIds.length ||
        !currentIds.containsAll(snapshotIds)) {
      throw StateError(
        'A rotation projection can only update the current mastered set.',
      );
    }

    for (final surah in snapshot.surahs) {
      final scheme = await _activeSchemeRow(surah.id);
      if (scheme.id != surah.rotationScheme.id) {
        throw StateError(
          'Snapshot scheme "${surah.rotationScheme.id}" is not active.',
        );
      }
      for (final part in surah.rotationScheme.parts) {
        final updated =
            await (database.update(database.rotationParts)..where(
                  (RotationParts row) =>
                      row.id.equals(part.id) & row.schemeId.equals(scheme.id),
                ))
                .write(
                  RotationPartsCompanion(
                    cachedScore: Value<int>(part.rotationScore),
                    cachedRecitationCount: Value<int>(part.recitationCount),
                    cachedLastUsedAtUtc: Value<DateTime?>(part.lastUsedAtUtc),
                  ),
                );
        if (updated != 1) {
          throw StateError('Failed to update rotation part "${part.id}".');
        }
      }
      final updated =
          await (database.update(
            database.masteredSurahs,
          )..where((MasteredSurahs row) => row.surahId.equals(surah.id))).write(
            MasteredSurahsCompanion(
              isActive: Value<bool>(surah.isActive),
              hasEnteredRotation: Value<bool>(surah.hasEnteredRotation),
              cachedRotationScore: Value<int>(surah.rotationScore),
              cachedTotalRecitations: Value<int>(surah.totalRecitations),
              cachedLastUsedAtUtc: Value<DateTime?>(surah.lastUsedAtUtc),
              alias: Value<String?>(surah.surah.alias),
              displayOrder: Value<int>(surah.displayOrder),
            ),
          );
      if (updated != 1) {
        throw StateError('Failed to update mastered surah "${surah.id}".');
      }
    }

    final updatedState =
        await (database.update(
          database.rotationStates,
        )..where((RotationStates row) => row.singletonId.equals(1))).write(
          RotationStatesCompanion(
            rotationTarget: Value<int>(snapshot.rotationTarget),
            lastJournalSequence: lastJournalSequence == null
                ? const Value<int>.absent()
                : Value<int>(lastJournalSequence),
            projectionVersion: const Value<int>(projectionVersion),
          ),
        );
    if (updatedState != 1) {
      throw StateError('The singleton rotation state is missing.');
    }
  }

  /// Rebuilds every scheme in version order and propagates changed carry state
  /// into successor baselines. Historical scheme boundaries remain immutable.
  Future<RotationSnapshot> rebuildFromJournal({
    required int targetFloor,
  }) async {
    if (targetFloor < RotationEngine.initialRotationTarget) {
      throw ArgumentError.value(targetFloor, 'targetFloor');
    }

    final masteredRows = await database.select(database.masteredSurahs).get();
    final schemeRows = await database.select(database.rotationSchemes).get();
    final partRows = await database.select(database.rotationParts).get();
    final recitationQuery = database.select(database.recitationEvents)
      ..where((RecitationEvents row) => row.deletedAtUtc.isNull());
    final recitations = await recitationQuery.get();
    final adjustmentQuery = database.select(database.rotationAdjustments)
      ..where((RotationAdjustments row) => row.deletedAtUtc.isNull());
    final adjustments = await adjustmentQuery.get();
    final coverageRows = await database
        .select(database.recitationEventParts)
        .get();

    final coverageByEventId = <String, List<String>>{};
    for (final coverage in coverageRows) {
      coverageByEventId
          .putIfAbsent(coverage.eventId, () => <String>[])
          .add(coverage.partId);
    }
    final partsBySchemeId = <String, List<RotationPartRow>>{};
    for (final part in partRows) {
      partsBySchemeId
          .putIfAbsent(part.schemeId, () => <RotationPartRow>[])
          .add(part);
    }
    final schemesBySurahId = <String, List<RotationSchemeRow>>{};
    for (final scheme in schemeRows) {
      schemesBySurahId
          .putIfAbsent(scheme.surahId, () => <RotationSchemeRow>[])
          .add(scheme);
    }

    for (final mastered in masteredRows) {
      final schemes =
          schemesBySurahId[mastered.surahId] ?? <RotationSchemeRow>[];
      schemes.sort((left, right) => left.version.compareTo(right.version));
      if (schemes.isEmpty) {
        throw StateError('Mastered surah "${mastered.surahId}" has no scheme.');
      }

      _SchemeCarry? carry;
      for (var index = 0; index < schemes.length; index += 1) {
        final scheme = schemes[index];
        final baseline =
            carry ??
            _SchemeCarry(
              score: scheme.baselineScore,
              total: scheme.baselineTotalRecitations,
              lastUsedAtUtc: scheme.baselineLastUsedAtUtc?.toUtc(),
            );
        if (index > 0) {
          await (database.update(
            database.rotationSchemes,
          )..where((RotationSchemes row) => row.id.equals(scheme.id))).write(
            RotationSchemesCompanion(
              baselineScore: Value<int>(baseline.score),
              baselineTotalRecitations: Value<int>(baseline.total),
              baselineLastUsedAtUtc: Value<DateTime?>(baseline.lastUsedAtUtc),
            ),
          );
        }

        final storedParts = partsBySchemeId[scheme.id] ?? <RotationPartRow>[];
        storedParts.sort(
          (left, right) => left.ordinal.compareTo(right.ordinal),
        );
        final states = <String, _PartProjection>{
          for (final part in storedParts)
            part.id: _PartProjection(
              score: baseline.score,
              count: baseline.total,
              lastUsedAtUtc: baseline.lastUsedAtUtc,
            ),
        };
        if (states.isEmpty) {
          throw StateError('Rotation scheme "${scheme.id}" has no parts.');
        }

        final journal = <_StoredJournalEntry>[
          for (final event in recitations)
            if (event.rotationSchemeId == scheme.id)
              _StoredJournalEntry.recitation(event),
          for (final adjustment in adjustments)
            if (adjustment.rotationSchemeId == scheme.id)
              _StoredJournalEntry.adjustment(adjustment),
        ]..sort((left, right) => left.sequence.compareTo(right.sequence));

        for (final entry in journal) {
          final event = entry.recitation;
          if (event != null) {
            final coveredIds = coverageByEventId[event.id] ?? const <String>[];
            if (coveredIds.isEmpty) {
              throw StateError('Recitation "${event.id}" has no coverage.');
            }
            for (final partId in coveredIds) {
              final state = states[partId];
              if (state == null) {
                throw StateError(
                  'Recitation "${event.id}" references a foreign part.',
                );
              }
              state
                ..score += 1
                ..count += 1
                ..lastUsedAtUtc = event.createdAtUtc.toUtc();
            }
            continue;
          }
          final adjustment = entry.adjustment!;
          for (final state in states.values) {
            state.score += adjustment.delta;
            if (state.score < 0) {
              throw StateError(
                'Adjustment "${adjustment.id}" makes a part score negative.',
              );
            }
          }
        }

        for (final part in storedParts) {
          final state = states[part.id]!;
          await (database.update(
            database.rotationParts,
          )..where((RotationParts row) => row.id.equals(part.id))).write(
            RotationPartsCompanion(
              cachedScore: Value<int>(state.score),
              cachedRecitationCount: Value<int>(state.count),
              cachedLastUsedAtUtc: Value<DateTime?>(state.lastUsedAtUtc),
            ),
          );
        }
        carry = _SchemeCarry(
          score: states.values.map((state) => state.score).reduce(math.min),
          total: states.values.map((state) => state.count).reduce(math.min),
          lastUsedAtUtc: _latest(
            states.values.map((state) => state.lastUsedAtUtc),
          ),
        );
      }

      final activeScheme = schemes.singleWhere(
        (scheme) => scheme.supersededJournalSequence == null,
      );
      final activeParts =
          await (database.select(database.rotationParts)..where(
                (RotationParts row) => row.schemeId.equals(activeScheme.id),
              ))
              .get();
      final score = activeParts
          .map((part) => part.cachedScore)
          .reduce(math.min);
      final total = activeParts
          .map((part) => part.cachedRecitationCount)
          .reduce(math.min);
      final lastUsed = _latest(
        activeParts.map((part) => part.cachedLastUsedAtUtc?.toUtc()),
      );
      await (database.update(database.masteredSurahs)..where(
            (MasteredSurahs row) => row.surahId.equals(mastered.surahId),
          ))
          .write(
            MasteredSurahsCompanion(
              cachedRotationScore: Value<int>(score),
              cachedTotalRecitations: Value<int>(total),
              cachedLastUsedAtUtc: Value<DateTime?>(lastUsed),
            ),
          );
    }

    final state = await loadRotationState();
    await (database.update(
      database.rotationStates,
    )..where((RotationStates row) => row.singletonId.equals(1))).write(
      RotationStatesCompanion(
        rotationTarget: Value<int>(math.max(targetFloor, state.rotationTarget)),
        projectionVersion: const Value<int>(projectionVersion),
      ),
    );
    return loadSnapshot();
  }

  Future<RotationSchemeRow> _activeSchemeRow(String surahId) =>
      (database.select(database.rotationSchemes)..where(
            (RotationSchemes row) =>
                row.surahId.equals(surahId) &
                row.supersededJournalSequence.isNull(),
          ))
          .getSingle();

  SurahRotationScheme _schemeFromRows(
    RotationSchemeRow scheme,
    List<RotationPartRow> parts,
  ) => SurahRotationScheme(
    id: scheme.id,
    surahId: scheme.surahId,
    version: scheme.version,
    ayahCount: scheme.ayahCountSnapshot,
    baselineRotationScore: scheme.baselineScore,
    baselineTotalRecitations: scheme.baselineTotalRecitations,
    baselineLastUsedAtUtc: scheme.baselineLastUsedAtUtc?.toUtc(),
    parts: <SurahRotationPart>[
      for (final part in parts)
        SurahRotationPart(
          id: part.id,
          schemeId: part.schemeId,
          partNumber: part.ordinal,
          ayahRange: AyahRange(
            startAyah: part.startAyah,
            endAyah: part.endAyah,
          ),
          rotationScore: part.cachedScore,
          recitationCount: part.cachedRecitationCount,
          lastUsedAtUtc: part.cachedLastUsedAtUtc?.toUtc(),
        ),
    ],
  );
}

final class _SchemeCarry {
  const _SchemeCarry({
    required this.score,
    required this.total,
    required this.lastUsedAtUtc,
  });

  final int score;
  final int total;
  final DateTime? lastUsedAtUtc;
}

final class _PartProjection {
  _PartProjection({
    required this.score,
    required this.count,
    required this.lastUsedAtUtc,
  });

  int score;
  int count;
  DateTime? lastUsedAtUtc;
}

final class _StoredJournalEntry {
  const _StoredJournalEntry._({
    required this.sequence,
    this.recitation,
    this.adjustment,
  });

  factory _StoredJournalEntry.recitation(RecitationEventRow row) =>
      _StoredJournalEntry._(sequence: row.journalSequence, recitation: row);

  factory _StoredJournalEntry.adjustment(RotationAdjustmentRow row) =>
      _StoredJournalEntry._(sequence: row.journalSequence, adjustment: row);

  final int sequence;
  final RecitationEventRow? recitation;
  final RotationAdjustmentRow? adjustment;
}

DateTime? _latest(Iterable<DateTime?> values) {
  DateTime? latest;
  for (final value in values) {
    if (value != null && (latest == null || value.isAfter(latest))) {
      latest = value;
    }
  }
  return latest;
}
