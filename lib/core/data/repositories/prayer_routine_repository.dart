import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';

typedef PrayerSessionPartIdFactory =
    String Function(PrayerRoutinePartTemplate sourcePart);

/// Raised when an editor attempts to overwrite a newer routine revision.
final class PrayerRoutineRevisionConflict implements Exception {
  const PrayerRoutineRevisionConflict({
    required this.prayerType,
    required this.expectedRevision,
    required this.actualRevision,
  });

  final PrayerType prayerType;
  final int expectedRevision;
  final int actualRevision;

  @override
  String toString() =>
      'PrayerRoutineRevisionConflict('
      'prayerType: $prayerType, '
      'expectedRevision: $expectedRevision, '
      'actualRevision: $actualRevision)';
}

/// A capability tied to one exact followed-imam completion.
///
/// It is deliberately repository-owned and cannot be forged by a caller.
final class FollowedImamUndoToken {
  const FollowedImamUndoToken._(
    this._owner, {
    required this.prayerSessionPartId,
    required this.completedAtUtc,
  });

  final Object _owner;
  final String prayerSessionPartId;
  final DateTime completedAtUtc;
}

final class FollowedImamCompletion {
  const FollowedImamCompletion({
    required this.part,
    required this.didComplete,
    required this.undoToken,
  });

  final PrayerSessionPart part;
  final bool didComplete;
  final FollowedImamUndoToken? undoToken;
}

final class PrayerSessionPartProgress {
  PrayerSessionPartProgress({
    required this.part,
    required Iterable<int> occupiedSlotIndexes,
  }) : occupiedSlotIndexes = Set<int>.unmodifiable(occupiedSlotIndexes) {
    for (final slotIndex in this.occupiedSlotIndexes) {
      if (slotIndex < 0 || slotIndex >= part.requiredSurahSlots) {
        throw StateError(
          'Stored slot $slotIndex is outside prayer part "${part.id}".',
        );
      }
    }
  }

  final PrayerSessionPart part;
  final Set<int> occupiedSlotIndexes;

  int get completedSlotCount => occupiedSlotIndexes.length;

  int? get nextSlotIndex {
    if (part.isCompleted ||
        part.completionMode == PrayerPartCompletionMode.followedImam) {
      return null;
    }
    for (var index = 0; index < part.requiredSurahSlots; index += 1) {
      if (!occupiedSlotIndexes.contains(index)) return index;
    }
    return null;
  }
}

final class PrayerRoutineSessionSnapshot {
  PrayerRoutineSessionSnapshot({
    required this.session,
    required this.localDate,
    required Iterable<PrayerSessionPartProgress> parts,
  }) : parts = List<PrayerSessionPartProgress>.unmodifiable(parts);

  final PrayerSession session;
  final LocalDate? localDate;
  final List<PrayerSessionPartProgress> parts;

  PrayerSessionPartProgress? get currentPart {
    for (final progress in parts) {
      if (!progress.part.isCompleted) return progress;
    }
    return null;
  }

  bool get isCompleted => parts.isNotEmpty && currentPart == null;
}

/// Product defaults for a part explicitly created by the user.
///
/// This is not a madhhab preset. It only makes the Jumuah Fard action
/// discoverable, while every value remains editable before persistence.
abstract final class PrayerRoutineDefaults {
  static PrayerRoutinePartTemplate newUserPart({
    required PrayerType prayerType,
    required String id,
    required String stableKey,
    required int orderIndex,
    required PrayerRoutinePartKind kind,
    String? customLabel,
    required int rakaatCount,
    required int requiredSurahSlots,
    bool? allowsFollowingImam,
    PrayerPartCompletionMode defaultCompletionMode =
        PrayerPartCompletionMode.recitations,
  }) => PrayerRoutinePartTemplate(
    id: id,
    stableKey: stableKey,
    orderIndex: orderIndex,
    kind: kind,
    customLabel: customLabel,
    rakaatCount: rakaatCount,
    requiredSurahSlots: requiredSurahSlots,
    allowsFollowingImam:
        allowsFollowingImam ??
        (prayerType == PrayerType.jumuah && kind == PrayerRoutinePartKind.fard),
    defaultCompletionMode: defaultCompletionMode,
  );
}

/// Persists editable prayer routines and immutable per-session snapshots.
final class PrayerRoutineRepository {
  PrayerRoutineRepository(this.database);

  final AppDatabase database;
  final Object _followedImamUndoOwner = Object();

  Future<List<PrayerRoutineTemplate>> getTemplates() async {
    final rows =
        await (database.select(database.prayerRoutineTemplates)
              ..orderBy(<OrderingTerm Function(PrayerRoutineTemplates)>[
                (PrayerRoutineTemplates row) =>
                    OrderingTerm.asc(row.prayerType),
              ]))
            .get();
    final templates = <PrayerRoutineTemplate>[];
    for (final row in rows) {
      templates.add(await _templateFromRow(row));
    }
    return List<PrayerRoutineTemplate>.unmodifiable(templates);
  }

  Future<PrayerRoutineTemplate> getTemplate(PrayerType prayerType) async {
    final row =
        await (database.select(database.prayerRoutineTemplates)..where(
              (PrayerRoutineTemplates row) =>
                  row.prayerType.equals(prayerType.name),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw StateError('Missing routine template for ${prayerType.name}.');
    }
    return _templateFromRow(row);
  }

  Stream<PrayerRoutineTemplate> watchTemplate(PrayerType prayerType) => database
      .customSelect(
        'SELECT 1',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.prayerRoutineTemplates,
          database.prayerRoutinePartTemplates,
        },
      )
      .watch()
      .asyncMap((_) => getTemplate(prayerType));

  /// Replaces the editable projection and advances its revision exactly once.
  ///
  /// Existing [PrayerSessionPart] rows are intentionally never updated.
  Future<PrayerRoutineTemplate> replaceTemplate({
    required PrayerType prayerType,
    required int expectedRevision,
    required String displayName,
    required bool enabled,
    required Iterable<PrayerRoutinePartTemplate> parts,
  }) => database.transaction(() async {
    final current = await getTemplate(prayerType);
    if (current.revision != expectedRevision) {
      throw PrayerRoutineRevisionConflict(
        prayerType: prayerType,
        expectedRevision: expectedRevision,
        actualRevision: current.revision,
      );
    }
    final next = PrayerRoutineTemplate(
      id: current.id,
      prayerType: prayerType,
      displayName: displayName,
      enabled: enabled,
      revision: current.revision + 1,
      parts: parts,
    );
    final updated =
        await (database.update(database.prayerRoutineTemplates)..where(
              (PrayerRoutineTemplates row) =>
                  row.id.equals(current.id) &
                  row.revision.equals(expectedRevision),
            ))
            .write(
              PrayerRoutineTemplatesCompanion(
                displayName: Value<String>(next.displayName),
                enabled: Value<bool>(next.enabled),
                revision: Value<int>(next.revision),
              ),
            );
    if (updated != 1) {
      final actual = await getTemplate(prayerType);
      throw PrayerRoutineRevisionConflict(
        prayerType: prayerType,
        expectedRevision: expectedRevision,
        actualRevision: actual.revision,
      );
    }
    await (database.delete(database.prayerRoutinePartTemplates)..where(
          (PrayerRoutinePartTemplates row) =>
              row.routineTemplateId.equals(current.id),
        ))
        .go();
    for (final part in next.parts) {
      await database
          .into(database.prayerRoutinePartTemplates)
          .insert(_partCompanion(current.id, part));
    }
    return getTemplate(prayerType);
  });

  Future<PrayerRoutineTemplate> addPart({
    required PrayerType prayerType,
    required int expectedRevision,
    required PrayerRoutinePartTemplate part,
    int? atIndex,
  }) async {
    final current = await getTemplate(prayerType);
    _requireRevision(current, expectedRevision);
    final insertionIndex = atIndex ?? current.parts.length;
    if (insertionIndex < 0 || insertionIndex > current.parts.length) {
      throw RangeError.range(
        insertionIndex,
        0,
        current.parts.length,
        'atIndex',
      );
    }
    final parts = current.parts.toList();
    parts.insert(insertionIndex, part);
    return replaceTemplate(
      prayerType: prayerType,
      expectedRevision: expectedRevision,
      displayName: current.displayName,
      enabled: current.enabled,
      parts: _normalizeOrder(parts),
    );
  }

  Future<PrayerRoutineTemplate> updatePart({
    required PrayerType prayerType,
    required int expectedRevision,
    required PrayerRoutinePartTemplate replacement,
  }) async {
    final current = await getTemplate(prayerType);
    _requireRevision(current, expectedRevision);
    final index = current.parts.indexWhere((part) => part.id == replacement.id);
    if (index < 0) {
      throw StateError('Unknown routine part "${replacement.id}".');
    }
    if (replacement.stableKey != current.parts[index].stableKey) {
      throw ArgumentError.value(
        replacement.stableKey,
        'replacement.stableKey',
        'A routine part stable key cannot be changed.',
      );
    }
    final parts = current.parts.toList();
    parts[index] = _copyPart(replacement, orderIndex: index);
    return replaceTemplate(
      prayerType: prayerType,
      expectedRevision: expectedRevision,
      displayName: current.displayName,
      enabled: current.enabled,
      parts: parts,
    );
  }

  Future<PrayerRoutineTemplate> deletePart({
    required PrayerType prayerType,
    required int expectedRevision,
    required String partId,
  }) async {
    final current = await getTemplate(prayerType);
    _requireRevision(current, expectedRevision);
    final parts = current.parts.where((part) => part.id != partId).toList();
    if (parts.length == current.parts.length) {
      throw StateError('Unknown routine part "$partId".');
    }
    return replaceTemplate(
      prayerType: prayerType,
      expectedRevision: expectedRevision,
      displayName: current.displayName,
      enabled: current.enabled,
      parts: _normalizeOrder(parts),
    );
  }

  Future<PrayerRoutineTemplate> reorderParts({
    required PrayerType prayerType,
    required int expectedRevision,
    required List<String> orderedPartIds,
  }) async {
    final current = await getTemplate(prayerType);
    _requireRevision(current, expectedRevision);
    final expectedIds = current.parts.map((part) => part.id).toSet();
    final suppliedIds = orderedPartIds.toSet();
    if (orderedPartIds.length != suppliedIds.length ||
        suppliedIds.length != expectedIds.length ||
        !suppliedIds.containsAll(expectedIds)) {
      throw ArgumentError.value(
        orderedPartIds,
        'orderedPartIds',
        'Must contain every routine part exactly once.',
      );
    }
    final byId = <String, PrayerRoutinePartTemplate>{
      for (final part in current.parts) part.id: part,
    };
    final ordered = <PrayerRoutinePartTemplate>[
      for (var index = 0; index < orderedPartIds.length; index += 1)
        _copyPart(byId[orderedPartIds[index]]!, orderIndex: index),
    ];
    return replaceTemplate(
      prayerType: prayerType,
      expectedRevision: expectedRevision,
      displayName: current.displayName,
      enabled: current.enabled,
      parts: ordered,
    );
  }

  Future<PrayerRoutineTemplate> setTemplateEnabled({
    required PrayerType prayerType,
    required int expectedRevision,
    required bool enabled,
  }) async {
    final current = await getTemplate(prayerType);
    _requireRevision(current, expectedRevision);
    return replaceTemplate(
      prayerType: prayerType,
      expectedRevision: expectedRevision,
      displayName: current.displayName,
      enabled: enabled,
      parts: current.parts,
    );
  }

  /// Creates a prayer session and snapshots its current enabled routine.
  Future<List<PrayerSessionPart>> startSession({
    required PrayerSession session,
    LocalDate? localDate,
    required PrayerSessionPartIdFactory createPartId,
  }) => database.transaction(() async {
    final template = await getTemplate(session.context.prayerType);
    final sourceParts = template.enabled
        ? _qadaEligibleParts(session.context, template.parts)
        : const <PrayerRoutinePartTemplate>[];
    final partIds = <String>[
      for (final sourcePart in sourceParts) createPartId(sourcePart),
    ];
    if (partIds.any((id) => id.isEmpty) ||
        partIds.toSet().length != partIds.length) {
      throw ArgumentError.value(
        partIds,
        'createPartId',
        'Must create a unique non-empty ID for every session part.',
      );
    }
    await database
        .into(database.prayerSessions)
        .insert(
          PrayerSessionsCompanion.insert(
            id: session.id,
            prayerType: session.context.prayerType.name,
            isQada: Value<bool>(session.context.isQada),
            startedAtUtc: session.startedAtUtc,
            localDate: Value<String?>(localDate?.toString()),
          ),
        );
    for (var index = 0; index < sourceParts.length; index += 1) {
      final source = sourceParts[index];
      await database
          .into(database.prayerSessionParts)
          .insert(
            PrayerSessionPartsCompanion.insert(
              id: partIds[index],
              prayerSessionId: session.id,
              sourceTemplatePartId: Value<String?>(source.id),
              templateRevision: Value<int?>(template.revision),
              stableKey: source.stableKey,
              orderIndex: source.orderIndex,
              label: source.displayLabel,
              kind: source.kind.name,
              rakaatCount: source.rakaatCount,
              requiredSurahSlots: source.requiredSurahSlots,
              allowsFollowingImam: source.allowsFollowingImam,
              completionMode: Value<String>(source.defaultCompletionMode.name),
              completedAtUtc:
                  source.requiredSurahSlots == 0 &&
                      source.defaultCompletionMode ==
                          PrayerPartCompletionMode.recitations
                  ? Value<DateTime?>(session.startedAtUtc)
                  : const Value<DateTime?>.absent(),
            ),
          );
    }
    return getSessionParts(session.id);
  });

  Future<List<PrayerSessionPart>> getSessionParts(
    String prayerSessionId,
  ) async {
    if (prayerSessionId.isEmpty) {
      throw ArgumentError.value(prayerSessionId, 'prayerSessionId');
    }
    final rows =
        await (database.select(database.prayerSessionParts)
              ..where(
                (PrayerSessionParts row) =>
                    row.prayerSessionId.equals(prayerSessionId),
              )
              ..orderBy(<OrderingTerm Function(PrayerSessionParts)>[
                (PrayerSessionParts row) => OrderingTerm.asc(row.orderIndex),
              ]))
            .get();
    return List<PrayerSessionPart>.unmodifiable(rows.map(_sessionPartFromRow));
  }

  Future<PrayerSessionPart?> getSessionPart(String id) async {
    final row = await (database.select(
      database.prayerSessionParts,
    )..where((PrayerSessionParts row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _sessionPartFromRow(row);
  }

  Stream<List<PrayerSessionPart>> watchSessionParts(String prayerSessionId) =>
      (database.select(database.prayerSessionParts)
            ..where(
              (PrayerSessionParts row) =>
                  row.prayerSessionId.equals(prayerSessionId),
            )
            ..orderBy(<OrderingTerm Function(PrayerSessionParts)>[
              (PrayerSessionParts row) => OrderingTerm.asc(row.orderIndex),
            ]))
          .watch()
          .map(
            (rows) => List<PrayerSessionPart>.unmodifiable(
              rows.map(_sessionPartFromRow),
            ),
          );

  /// Loads an existing current routine or atomically snapshots a new one.
  ///
  /// The latest same-context/date session with parts is reused even when its
  /// parts are already complete. A disabled or empty template never creates
  /// an empty session. Deterministic identifiers make foreground and widget
  /// callers converge on the same rows.
  Future<PrayerRoutineSessionSnapshot?> ensureCurrentSession({
    required PrayerContext context,
    required LocalDate localDate,
    required DateTime startedAtUtc,
  }) => database.transaction(() async {
    if (!startedAtUtc.isUtc) {
      throw ArgumentError.value(startedAtUtc, 'startedAtUtc', 'Must be UTC.');
    }
    final dateValue = localDate.toString();
    final candidates =
        await (database.select(database.prayerSessions)
              ..where(
                (PrayerSessions row) =>
                    row.prayerType.equals(context.prayerType.name) &
                    row.isQada.equals(context.isQada) &
                    row.localDate.equals(dateValue),
              )
              ..orderBy(<OrderingTerm Function(PrayerSessions)>[
                (PrayerSessions row) => OrderingTerm.desc(row.startedAtUtc),
              ]))
            .get();
    for (final candidate in candidates) {
      final parts = await getSessionParts(candidate.id);
      if (parts.isNotEmpty) {
        return _routineSessionFromRow(candidate, parts: parts);
      }
    }

    final template = await getTemplate(context.prayerType);
    if (!template.enabled) return null;
    // A Qada context keeps only the obligatory part. If nothing remains the
    // routine has nothing to track, so the ordinary slotless flow stays.
    final sourceParts = _qadaEligibleParts(context, template.parts);
    if (sourceParts.isEmpty) return null;

    final sessionId = _routineSessionId(context, localDate);
    await database
        .into(database.prayerSessions)
        .insert(
          PrayerSessionsCompanion.insert(
            id: sessionId,
            prayerType: context.prayerType.name,
            isQada: Value<bool>(context.isQada),
            startedAtUtc: startedAtUtc,
            localDate: Value<String?>(dateValue),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    for (final source in sourceParts) {
      await database
          .into(database.prayerSessionParts)
          .insert(
            PrayerSessionPartsCompanion.insert(
              id: '$sessionId:part:${source.stableKey}',
              prayerSessionId: sessionId,
              sourceTemplatePartId: Value<String?>(source.id),
              templateRevision: Value<int?>(template.revision),
              stableKey: source.stableKey,
              orderIndex: source.orderIndex,
              label: source.displayLabel,
              kind: source.kind.name,
              rakaatCount: source.rakaatCount,
              requiredSurahSlots: source.requiredSurahSlots,
              allowsFollowingImam: source.allowsFollowingImam,
              completionMode: Value<String>(source.defaultCompletionMode.name),
              completedAtUtc:
                  source.requiredSurahSlots == 0 &&
                      source.defaultCompletionMode ==
                          PrayerPartCompletionMode.recitations
                  ? Value<DateTime?>(startedAtUtc)
                  : const Value<DateTime?>.absent(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    final sessionRow = await (database.select(
      database.prayerSessions,
    )..where((PrayerSessions row) => row.id.equals(sessionId))).getSingle();
    final parts = await getSessionParts(sessionId);
    if (parts.length != sourceParts.length) {
      throw StateError('Current prayer routine snapshot is incomplete.');
    }
    return _routineSessionFromRow(sessionRow, parts: parts);
  });

  Future<PrayerRoutineSessionSnapshot?> getRoutineSession(String id) async {
    final row =
        await (database.select(database.prayerSessions)
              ..where((PrayerSessions session) => session.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return null;
    final parts = await getSessionParts(id);
    if (parts.isEmpty) return null;
    return _routineSessionFromRow(row, parts: parts);
  }

  /// Reactively resolves the one current routine snapshot for a local prayer.
  ///
  /// Template edits can create the first snapshot, while later edits never
  /// rewrite it. Session-part completion and occupied-slot changes are read
  /// from the authoritative database on every relevant table emission.
  Stream<PrayerRoutineSessionSnapshot?> watchCurrentSession({
    required PrayerContext context,
    required LocalDate localDate,
    required DateTime Function() startedAtUtc,
  }) => database
      .customSelect(
        'SELECT 1',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.prayerRoutineTemplates,
          database.prayerRoutinePartTemplates,
          database.prayerSessions,
          database.prayerSessionParts,
          database.recitationEvents,
        },
      )
      .watch()
      .asyncMap(
        (_) => ensureCurrentSession(
          context: context,
          localDate: localDate,
          startedAtUtc: startedAtUtc(),
        ),
      );

  /// Completes an eligible Fard part without creating recitation history.
  Future<FollowedImamCompletion> completeByFollowingImam({
    required String prayerSessionPartId,
    required DateTime completedAtUtc,
  }) => database.transaction(() async {
    if (!completedAtUtc.isUtc) {
      throw ArgumentError.value(
        completedAtUtc,
        'completedAtUtc',
        'Must be UTC.',
      );
    }
    final row = await _requireSessionPartRow(prayerSessionPartId);
    if (row.kind != PrayerRoutinePartKind.fard.name ||
        !row.allowsFollowingImam) {
      throw StateError('This prayer part cannot be completed with an imam.');
    }
    if (row.completedAtUtc != null) {
      final part = _sessionPartFromRow(row);
      if (part.wasFollowedImam) {
        return FollowedImamCompletion(
          part: part,
          didComplete: false,
          undoToken: null,
        );
      }
      throw StateError('This prayer part is already completed.');
    }
    final earlierIncomplete =
        await (database.select(database.prayerSessionParts)
              ..where(
                (PrayerSessionParts part) =>
                    part.prayerSessionId.equals(row.prayerSessionId) &
                    part.orderIndex.isSmallerThanValue(row.orderIndex) &
                    part.completedAtUtc.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (earlierIncomplete != null) {
      throw StateError('Only the current prayer part can be completed.');
    }
    if (await _hasActiveRecitation(<String>[row.id])) {
      throw StateError(
        'A part with recitation history cannot follow the imam.',
      );
    }
    final updated =
        await (database.update(database.prayerSessionParts)..where(
              (PrayerSessionParts part) =>
                  part.id.equals(row.id) & part.completedAtUtc.isNull(),
            ))
            .write(
              PrayerSessionPartsCompanion(
                completionMode: Value<String>(
                  PrayerPartCompletionMode.followedImam.name,
                ),
                completedAtUtc: Value<DateTime?>(completedAtUtc),
              ),
            );
    if (updated != 1) {
      throw StateError('The prayer part changed concurrently.');
    }
    final part = _sessionPartFromRow(
      await _requireSessionPartRow(prayerSessionPartId),
    );
    return FollowedImamCompletion(
      part: part,
      didComplete: true,
      undoToken: FollowedImamUndoToken._(
        _followedImamUndoOwner,
        prayerSessionPartId: prayerSessionPartId,
        completedAtUtc: completedAtUtc,
      ),
    );
  });

  /// Reopens the exact action only while no later part history depends on it.
  Future<bool> undoFollowedImam(FollowedImamUndoToken token) =>
      database.transaction(() async {
        if (!identical(token._owner, _followedImamUndoOwner)) return false;
        final row =
            await (database.select(database.prayerSessionParts)..where(
                  (PrayerSessionParts part) =>
                      part.id.equals(token.prayerSessionPartId),
                ))
                .getSingleOrNull();
        if (row == null ||
            row.completionMode != PrayerPartCompletionMode.followedImam.name ||
            row.completedAtUtc?.toUtc() != token.completedAtUtc) {
          return false;
        }
        final laterRows =
            await (database.select(database.prayerSessionParts)..where(
                  (PrayerSessionParts part) =>
                      part.prayerSessionId.equals(row.prayerSessionId) &
                      part.orderIndex.isBiggerThanValue(row.orderIndex),
                ))
                .get();
        if (laterRows.any((part) => part.completedAtUtc != null) ||
            await _hasActiveRecitation(<String>[
              row.id,
              ...laterRows.map((part) => part.id),
            ])) {
          return false;
        }
        final updated =
            await (database.update(database.prayerSessionParts)..where(
                  (PrayerSessionParts part) =>
                      part.id.equals(row.id) &
                      part.completionMode.equals(
                        PrayerPartCompletionMode.followedImam.name,
                      ),
                ))
                .write(
                  const PrayerSessionPartsCompanion(
                    completionMode: Value<String>('recitations'),
                    completedAtUtc: Value<DateTime?>(null),
                  ),
                );
        return updated == 1;
      });

  Future<PrayerRoutineTemplate> _templateFromRow(
    PrayerRoutineTemplateRow row,
  ) async {
    final partRows =
        await (database.select(database.prayerRoutinePartTemplates)
              ..where(
                (PrayerRoutinePartTemplates part) =>
                    part.routineTemplateId.equals(row.id),
              )
              ..orderBy(<OrderingTerm Function(PrayerRoutinePartTemplates)>[
                (PrayerRoutinePartTemplates part) =>
                    OrderingTerm.asc(part.orderIndex),
              ]))
            .get();
    return PrayerRoutineTemplate(
      id: row.id,
      prayerType: PrayerType.values.byName(row.prayerType),
      displayName: row.displayName,
      enabled: row.enabled,
      revision: row.revision,
      parts: partRows.map(_partFromRow),
    );
  }

  PrayerRoutinePartTemplate _partFromRow(PrayerRoutinePartTemplateRow row) =>
      PrayerRoutinePartTemplate(
        id: row.id,
        stableKey: row.stableKey,
        orderIndex: row.orderIndex,
        kind: PrayerRoutinePartKind.values.byName(row.kind),
        customLabel: row.customLabel,
        rakaatCount: row.rakaatCount,
        requiredSurahSlots: row.requiredSurahSlots,
        allowsFollowingImam: row.allowsFollowingImam,
        defaultCompletionMode: PrayerPartCompletionMode.values.byName(
          row.defaultCompletionMode,
        ),
      );

  PrayerRoutinePartTemplatesCompanion _partCompanion(
    String routineTemplateId,
    PrayerRoutinePartTemplate part,
  ) => PrayerRoutinePartTemplatesCompanion.insert(
    id: part.id,
    routineTemplateId: routineTemplateId,
    stableKey: part.stableKey,
    orderIndex: part.orderIndex,
    kind: part.kind.name,
    customLabel: Value<String?>(part.customLabel),
    rakaatCount: part.rakaatCount,
    requiredSurahSlots: part.requiredSurahSlots,
    allowsFollowingImam: Value<bool>(part.allowsFollowingImam),
    defaultCompletionMode: Value<String>(part.defaultCompletionMode.name),
  );

  PrayerSessionPart _sessionPartFromRow(PrayerSessionPartRow row) =>
      PrayerSessionPart(
        id: row.id,
        prayerSessionId: row.prayerSessionId,
        sourceTemplatePartId: row.sourceTemplatePartId,
        templateRevision: row.templateRevision,
        stableKey: row.stableKey,
        orderIndex: row.orderIndex,
        label: row.label,
        kind: PrayerRoutinePartKind.values.byName(row.kind),
        rakaatCount: row.rakaatCount,
        requiredSurahSlots: row.requiredSurahSlots,
        allowsFollowingImam: row.allowsFollowingImam,
        completionMode: PrayerPartCompletionMode.values.byName(
          row.completionMode,
        ),
        completedAtUtc: row.completedAtUtc?.toUtc(),
      );

  Future<PrayerSessionPartRow> _requireSessionPartRow(String id) async {
    final row =
        await (database.select(database.prayerSessionParts)
              ..where((PrayerSessionParts part) => part.id.equals(id)))
            .getSingleOrNull();
    if (row == null) throw StateError('Unknown prayer session part "$id".');
    return row;
  }

  Future<PrayerRoutineSessionSnapshot> _routineSessionFromRow(
    PrayerSessionRow row, {
    required List<PrayerSessionPart> parts,
  }) async {
    final occupiedByPart = <String, Set<int>>{};
    final partIds = parts.map((part) => part.id).toList(growable: false);
    if (partIds.isNotEmpty) {
      final events =
          await (database.select(database.recitationEvents)..where(
                (RecitationEvents event) =>
                    event.prayerSessionPartId.isIn(partIds) &
                    event.slotIndex.isNotNull() &
                    event.deletedAtUtc.isNull(),
              ))
              .get();
      for (final event in events) {
        final partId = event.prayerSessionPartId;
        final slotIndex = event.slotIndex;
        if (partId != null && slotIndex != null) {
          (occupiedByPart[partId] ??= <int>{}).add(slotIndex);
        }
      }
    }
    return PrayerRoutineSessionSnapshot(
      session: PrayerSession(
        id: row.id,
        context: PrayerContext(
          prayerType: PrayerType.values.byName(row.prayerType),
          isQada: row.isQada,
        ),
        startedAtUtc: row.startedAtUtc.toUtc(),
      ),
      localDate: row.localDate == null
          ? null
          : _parseStoredLocalDate(row.localDate!),
      parts: <PrayerSessionPartProgress>[
        for (final part in parts)
          PrayerSessionPartProgress(
            part: part,
            occupiedSlotIndexes: occupiedByPart[part.id] ?? const <int>{},
          ),
      ],
    );
  }

  Future<bool> _hasActiveRecitation(Iterable<String> sessionPartIds) async {
    final ids = sessionPartIds.toList(growable: false);
    if (ids.isEmpty) return false;
    final row =
        await (database.select(database.recitationEvents)
              ..where(
                (RecitationEvents event) =>
                    event.prayerSessionPartId.isIn(ids) &
                    event.deletedAtUtc.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }
}

void _requireRevision(PrayerRoutineTemplate current, int expectedRevision) {
  if (current.revision != expectedRevision) {
    throw PrayerRoutineRevisionConflict(
      prayerType: current.prayerType,
      expectedRevision: expectedRevision,
      actualRevision: current.revision,
    );
  }
}

/// Keeps only the parts a [context] may actually contain.
///
/// Ordinary prayers keep every configured part. A Qada context keeps only the
/// obligatory one, so a missed Fard never drags its Sunnah parts along.
List<PrayerRoutinePartTemplate> _qadaEligibleParts(
  PrayerContext context,
  Iterable<PrayerRoutinePartTemplate> parts,
) => <PrayerRoutinePartTemplate>[
  for (final part in parts)
    if (PrayerQadaPolicy.allowsPartKind(context: context, kind: part.kind))
      part,
];

List<PrayerRoutinePartTemplate> _normalizeOrder(
  Iterable<PrayerRoutinePartTemplate> parts,
) {
  var index = 0;
  return <PrayerRoutinePartTemplate>[
    for (final part in parts) _copyPart(part, orderIndex: index++),
  ];
}

PrayerRoutinePartTemplate _copyPart(
  PrayerRoutinePartTemplate part, {
  required int orderIndex,
}) => PrayerRoutinePartTemplate(
  id: part.id,
  stableKey: part.stableKey,
  orderIndex: orderIndex,
  kind: part.kind,
  customLabel: part.customLabel,
  rakaatCount: part.rakaatCount,
  requiredSurahSlots: part.requiredSurahSlots,
  allowsFollowingImam: part.allowsFollowingImam,
  defaultCompletionMode: part.defaultCompletionMode,
);

String _routineSessionId(PrayerContext context, LocalDate localDate) =>
    'routine-session:$localDate:${context.prayerType.name}:'
    '${context.isQada ? 'qada' : 'ordinary'}';

LocalDate _parseStoredLocalDate(String value) {
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
