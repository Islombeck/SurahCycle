import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';
import 'rotation_projection_store.dart';

final class CatalogSurah {
  const CatalogSurah({
    required this.surah,
    required this.isMastered,
    required this.isActive,
  });

  final SurahDescriptor surah;
  final bool isMastered;
  final bool isActive;
}

/// Persists verified catalog metadata and the user's mastered-surah selection.
final class SurahRepository {
  SurahRepository(this.database, {this._engine = const RotationEngine()})
    : _projection = RotationProjectionStore(database);

  final AppDatabase database;
  final RotationEngine _engine;
  final RotationProjectionStore _projection;

  Future<void> upsertCatalog(
    Iterable<SurahDescriptor> descriptors, {
    String? sourceId,
    String? sourceVersion,
  }) => database.transaction(() async {
    for (final SurahDescriptor descriptor in descriptors) {
      await database
          .into(database.surahMetadata)
          .insertOnConflictUpdate(
            SurahMetadataCompanion.insert(
              id: descriptor.id,
              surahNumber: descriptor.surahNumber,
              officialName: descriptor.officialName,
              ayahCount: descriptor.ayahCount,
              sourceId: Value<String?>(sourceId),
              sourceVersion: Value<String?>(sourceVersion),
            ),
          );
    }
  });

  Future<List<CatalogSurah>> getCatalog({String query = ''}) async {
    final metadataQuery = database.select(database.surahMetadata)
      ..orderBy(<OrderingTerm Function(SurahMetadata)>[
        (SurahMetadata row) => OrderingTerm.asc(row.surahNumber),
      ]);
    final metadata = await metadataQuery.get();
    final mastered = await database.select(database.masteredSurahs).get();
    final masteredById = <String, MasteredSurahRow>{
      for (final MasteredSurahRow row in mastered) row.surahId: row,
    };
    final normalizedQuery = query.trim().toLowerCase();

    return <CatalogSurah>[
      for (final SurahMetadataRow row in metadata)
        if (_matches(row, masteredById[row.id], normalizedQuery))
          CatalogSurah(
            surah: SurahDescriptor(
              id: row.id,
              surahNumber: row.surahNumber,
              officialName: row.officialName,
              ayahCount: row.ayahCount,
              alias: masteredById[row.id]?.alias,
            ),
            isMastered: masteredById[row.id]?.isCurrentlyMastered ?? false,
            isActive: masteredById[row.id]?.isActive ?? false,
          ),
    ];
  }

  Stream<List<CatalogSurah>> watchCatalog({String query = ''}) => database
      .customSelect(
        // Drift keys cached query streams by SQL text and variables only, so
        // every watch query in the app needs its own text. Reusing a bare
        // 'SELECT 1' makes unrelated streams share one subscription and the
        // `readsFrom` set of whichever registered first.
        'SELECT 1 AS surah_catalog_watch',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.surahMetadata,
          database.masteredSurahs,
        },
      )
      .watch()
      .asyncMap((List<QueryRow> _) => getCatalog(query: query));

  Future<RotationSnapshot> getRotationSnapshot() => _projection.loadSnapshot();

  Future<int> getRotationRevision() async =>
      (await _projection.loadRotationState()).lastJournalSequence;

  Stream<RotationSnapshot> watchRotationSnapshot() =>
      _projection.watchSnapshot();

  Future<RotationSnapshot> addMastered(
    String surahId, {
    bool activate = true,
    int? displayOrder,
  }) => database.transaction(() async {
    final metadata = await (database.select(
      database.surahMetadata,
    )..where((SurahMetadata row) => row.id.equals(surahId))).getSingleOrNull();
    if (metadata == null) {
      throw StateError('Surah "$surahId" is absent from the catalog.');
    }
    final existing =
        await (database.select(database.masteredSurahs)
              ..where((MasteredSurahs row) => row.surahId.equals(surahId)))
            .getSingleOrNull();
    if (existing != null) {
      if (existing.isCurrentlyMastered) {
        throw StateError('Surah "$surahId" is already currently mastered.');
      }
      return _restoreMastery(
        surahId,
        activate: activate,
        rotationSchemeId: '$surahId:scheme:restored',
      );
    }
    final before = await _projection.loadSnapshot();
    final order = displayOrder ?? before.surahs.length;
    final descriptor = SurahDescriptor(
      id: metadata.id,
      surahNumber: metadata.surahNumber,
      officialName: metadata.officialName,
      ayahCount: metadata.ayahCount,
    );
    final after = _engine.addMasteredSurah(
      before,
      descriptor,
      activate: activate,
      displayOrder: order,
      rotationSchemeId: '$surahId:scheme:1',
    );
    final added = after.surahById(surahId);
    await database
        .into(database.masteredSurahs)
        .insert(
          MasteredSurahsCompanion.insert(
            surahId: surahId,
            isCurrentlyMastered: const Value<bool>(true),
            isActive: Value<bool>(added.isActive),
            hasEnteredRotation: Value<bool>(added.hasEnteredRotation),
            activationBaselineScore: Value<int?>(
              added.hasEnteredRotation ? added.rotationScore : null,
            ),
            cachedRotationScore: Value<int>(added.rotationScore),
            cachedTotalRecitations: Value<int>(added.totalRecitations),
            displayOrder: Value<int>(added.displayOrder),
          ),
        );
    await _insertScheme(
      added.rotationScheme,
      activatedJournalSequence:
          (await _projection.loadRotationState()).lastJournalSequence,
    );
    return _projection.loadSnapshot();
  });

  Future<RotationSnapshot> setActive(
    String surahId, {
    required bool isActive,
  }) => database.transaction(() async {
    final before = await _projection.loadSnapshot();
    final previous = before.surahById(surahId);
    final after = _engine.setSurahActive(before, surahId, isActive: isActive);
    final updated = after.surahById(surahId);
    if (updated == previous) return before;
    final firstActivation =
        updated.hasEnteredRotation && !previous.hasEnteredRotation;
    await (database.update(
      database.masteredSurahs,
    )..where((MasteredSurahs row) => row.surahId.equals(surahId))).write(
      MasteredSurahsCompanion(
        isActive: Value<bool>(updated.isActive),
        hasEnteredRotation: Value<bool>(updated.hasEnteredRotation),
        cachedRotationScore: Value<int>(updated.rotationScore),
        activationBaselineScore: firstActivation
            ? Value<int?>(updated.rotationScore)
            : const Value<int?>.absent(),
      ),
    );
    if (firstActivation) {
      await (database.update(database.rotationSchemes)..where(
            (RotationSchemes row) => row.id.equals(updated.rotationScheme.id),
          ))
          .write(
            RotationSchemesCompanion(
              baselineScore: Value<int>(updated.rotationScore),
              baselineTotalRecitations: Value<int>(updated.totalRecitations),
              baselineLastUsedAtUtc: Value<DateTime?>(updated.lastUsedAtUtc),
            ),
          );
    }
    await _projection.writeSnapshot(after);
    return _projection.loadSnapshot();
  });

  /// Keeps all history and immutable schemes while returning a surah to the
  /// learning candidates. This is the normal user-facing removal operation.
  Future<RotationSnapshot> returnToLearning(String surahId) =>
      database.transaction(() async {
        final before = await _projection.loadSnapshot();
        final current = before.surahById(surahId);
        if (!current.isCurrentlyMastered) return before;
        final after = _engine.updateMasteredSurah(
          before,
          current.copyWith(isCurrentlyMastered: false, isActive: false),
        );
        await _projection.writeSnapshot(after);
        return _projection.loadSnapshot();
      });

  /// Restores semantic mastery. Optional rotation activation starts a fresh
  /// immutable scheme one step behind the current target, while carrying only
  /// historical totals and last-used time (never accumulated score debt).
  Future<RotationSnapshot> restoreMastery(
    String surahId, {
    required bool activate,
    required String rotationSchemeId,
  }) => database.transaction(
    () => _restoreMastery(
      surahId,
      activate: activate,
      rotationSchemeId: rotationSchemeId,
    ),
  );

  Future<RotationSnapshot> _restoreMastery(
    String surahId, {
    required bool activate,
    required String rotationSchemeId,
  }) async {
    final before = await _projection.loadSnapshot();
    final current = before.surahById(surahId);
    if (current.isCurrentlyMastered) {
      throw StateError('Surah "$surahId" is already currently mastered.');
    }
    final shouldActivate = activate && current.surah.isRotationEligible;
    var updated = current.copyWith(isCurrentlyMastered: true, isActive: false);
    if (current.surah.isRotationEligible) {
      final state = await _projection.loadRotationState();
      final resolvedSchemeId = rotationSchemeId == '$surahId:scheme:restored'
          ? '$surahId:scheme:${current.rotationScheme.version + 1}:restored'
          : rotationSchemeId;
      final nextScheme = SurahRotationScheme.fromRanges(
        id: resolvedSchemeId,
        surahId: surahId,
        version: current.rotationScheme.version + 1,
        ayahCount: current.surah.ayahCount,
        ranges: current.rotationScheme.parts.map((part) => part.ayahRange),
        baselineRotationScore: before.rotationTarget - 1,
        baselineTotalRecitations: current.totalRecitations,
        baselineLastUsedAtUtc: current.lastUsedAtUtc,
        resetsRotationBaseline: true,
      );
      final superseded =
          await (database.update(database.rotationSchemes)..where(
                (RotationSchemes row) =>
                    row.id.equals(current.rotationScheme.id) &
                    row.supersededJournalSequence.isNull(),
              ))
              .write(
                RotationSchemesCompanion(
                  supersededJournalSequence: Value<int?>(
                    state.lastJournalSequence,
                  ),
                ),
              );
      if (superseded != 1) {
        throw StateError('The current rotation scheme changed concurrently.');
      }
      await _insertScheme(
        nextScheme,
        activatedJournalSequence: state.lastJournalSequence,
      );
      updated = updated.copyWith(
        isActive: shouldActivate,
        // This describes whether the current lifecycle scheme has entered
        // rotation. Historical schemes continue to record older membership.
        hasEnteredRotation: shouldActivate,
        rotationScheme: nextScheme,
      );
    }
    final after = _engine.updateMasteredSurah(before, updated);
    await _projection.writeSnapshot(after);
    await (database.update(
      database.masteredSurahs,
    )..where((MasteredSurahs row) => row.surahId.equals(surahId))).write(
      MasteredSurahsCompanion(
        activationBaselineScore: Value<int?>(
          shouldActivate ? after.surahById(surahId).rotationScore : null,
        ),
      ),
    );
    return _projection.loadSnapshot();
  }

  /// Activates a new immutable segmentation version without rewriting history.
  Future<RotationSnapshot> changeRotationScheme({
    required String surahId,
    required SurahRotationScheme proposedScheme,
    required DateTime createdAtUtc,
  }) => database.transaction(() async {
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'Must be UTC.');
    }
    final before = await _projection.loadSnapshot();
    final current = before.surahById(surahId);
    final after = _engine.changeRotationScheme(
      before,
      RotationSchemeChangedEvent(
        id: proposedScheme.id,
        surahId: surahId,
        scheme: proposedScheme,
        createdAtUtc: createdAtUtc,
      ),
    );
    final updated = after.surahById(surahId);
    final state = await _projection.loadRotationState();
    final superseded =
        await (database.update(database.rotationSchemes)..where(
              (RotationSchemes row) =>
                  row.id.equals(current.rotationScheme.id) &
                  row.supersededJournalSequence.isNull(),
            ))
            .write(
              RotationSchemesCompanion(
                supersededJournalSequence: Value<int?>(
                  state.lastJournalSequence,
                ),
              ),
            );
    if (superseded != 1) {
      throw StateError('The current rotation scheme changed concurrently.');
    }
    await _insertScheme(
      updated.rotationScheme,
      activatedJournalSequence: state.lastJournalSequence,
    );
    await _projection.writeSnapshot(after);
    return _projection.loadSnapshot();
  });

  Future<void> setAlias(String surahId, String? alias) async {
    final value = alias == null || alias.isEmpty ? null : alias;
    final count =
        await (database.update(database.masteredSurahs)
              ..where((MasteredSurahs row) => row.surahId.equals(surahId)))
            .write(MasteredSurahsCompanion(alias: Value<String?>(value)));
    if (count != 1) throw StateError('Unknown mastered surah "$surahId".');
  }

  Future<void> reorder(List<String> orderedSurahIds) =>
      database.transaction(() async {
        final rows =
            await (database.select(database.masteredSurahs)..where(
                  (MasteredSurahs row) => row.isCurrentlyMastered.equals(true),
                ))
                .get();
        final existingIds = rows
            .map((MasteredSurahRow row) => row.surahId)
            .toSet();
        final suppliedIds = orderedSurahIds.toSet();
        if (orderedSurahIds.length != suppliedIds.length ||
            existingIds.length != suppliedIds.length ||
            !existingIds.containsAll(suppliedIds)) {
          throw ArgumentError.value(
            orderedSurahIds,
            'orderedSurahIds',
            'Must contain every mastered surah exactly once.',
          );
        }
        for (var index = 0; index < orderedSurahIds.length; index += 1) {
          await (database.update(database.masteredSurahs)..where(
                (MasteredSurahs row) =>
                    row.surahId.equals(orderedSurahIds[index]),
              ))
              .write(MasteredSurahsCompanion(displayOrder: Value<int>(index)));
        }
      });

  /// Physical removal is intentionally restricted by foreign keys once the
  /// surah owns history, adjustments, or learning references.
  Future<bool> removeMastered(String surahId) async {
    final deleted = await (database.delete(
      database.masteredSurahs,
    )..where((MasteredSurahs row) => row.surahId.equals(surahId))).go();
    return deleted == 1;
  }

  bool _matches(
    SurahMetadataRow metadata,
    MasteredSurahRow? mastered,
    String query,
  ) {
    if (query.isEmpty) return true;
    return metadata.surahNumber.toString() == query ||
        metadata.officialName.toLowerCase().contains(query) ||
        (mastered?.alias?.toLowerCase().contains(query) ?? false);
  }

  Future<void> _insertScheme(
    SurahRotationScheme scheme, {
    required int activatedJournalSequence,
  }) async {
    await database
        .into(database.rotationSchemes)
        .insert(
          RotationSchemesCompanion.insert(
            id: scheme.id,
            surahId: scheme.surahId,
            version: scheme.version,
            ayahCountSnapshot: scheme.ayahCount,
            baselineScore: scheme.baselineRotationScore,
            baselineTotalRecitations: scheme.baselineTotalRecitations,
            baselineLastUsedAtUtc: Value<DateTime?>(
              scheme.baselineLastUsedAtUtc,
            ),
            resetsRotationBaseline: Value<bool>(scheme.resetsRotationBaseline),
            activatedJournalSequence: activatedJournalSequence,
            supersededJournalSequence: const Value<int?>.absent(),
          ),
        );
    for (final part in scheme.parts) {
      await database
          .into(database.rotationParts)
          .insert(
            RotationPartsCompanion.insert(
              id: part.id,
              schemeId: scheme.id,
              ordinal: part.partNumber,
              startAyah: part.ayahRange.startAyah,
              endAyah: part.ayahRange.endAyah,
              cachedScore: part.rotationScore,
              cachedRecitationCount: part.recitationCount,
              cachedLastUsedAtUtc: Value<DateTime?>(part.lastUsedAtUtc),
            ),
          );
    }
  }
}
