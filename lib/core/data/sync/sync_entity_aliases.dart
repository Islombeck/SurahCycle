/// One identifier that means another on this device.
///
/// A rotation scheme arriving from another device can turn out to be the split
/// this one already holds under a different name — his Al-Humazah is
/// `v1:surah-104:scheme:1` in the account and `surah-104:scheme:1` here,
/// because two builds named the same derived split differently. The applier
/// recognises that and keeps the local row, which is right: it is the one his
/// recitations point at and it cannot be removed.
///
/// **But the arriving id does not stop existing when that happens.** Every
/// record the other device sends names it — a recitation's coverage names the
/// scheme *and* each part it covered. Before this existed those records could
/// never be placed, and the pull stalled on them one at a time.
///
/// So the absorption is written down, and every path that resolves an incoming
/// identifier goes through here first.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// What an alias is about. A scheme and its parts are resolved in different
/// places, and confusing the two would point a recitation's coverage at a
/// scheme.
enum SyncAliasKind {
  rotationScheme,
  rotationPart;

  String get stored => name;
}

final class SyncAliasMap {
  SyncAliasMap(this._database);

  final AppDatabase _database;

  /// Records that [aliasId] names the same thing as [canonicalId] here.
  ///
  /// Idempotent, and silent when the two are equal: an absorption can be
  /// replayed by a second pull of the same page, and a self-alias is both
  /// meaningless and refused by the table.
  Future<void> remember({
    required String aliasId,
    required String canonicalId,
    required SyncAliasKind kind,
    required DateTime recordedAtUtc,
  }) async {
    if (aliasId == canonicalId || aliasId.isEmpty || canonicalId.isEmpty) {
      return;
    }
    if (!recordedAtUtc.isUtc) {
      throw ArgumentError.value(recordedAtUtc, 'recordedAtUtc', 'Must be UTC.');
    }
    await _database
        .into(_database.syncEntityAliases)
        .insertOnConflictUpdate(
          SyncEntityAliasesCompanion.insert(
            aliasId: aliasId,
            canonicalId: canonicalId,
            kind: kind.stored,
            recordedAtUtc: recordedAtUtc,
          ),
        );
  }

  /// The id this device stores [id] under, or [id] itself.
  ///
  /// One hop, not a chain. An alias always points at a row that exists here, so
  /// a chain would mean this device had absorbed something into a row it had
  /// itself absorbed away — which the applier cannot produce, and following one
  /// would make a cycle possible.
  Future<String> resolve(String id, SyncAliasKind kind) async {
    final row =
        await (_database.select(_database.syncEntityAliases)..where(
              (SyncEntityAliases row) =>
                  row.aliasId.equals(id) & row.kind.equals(kind.stored),
            ))
            .getSingleOrNull();
    return row?.canonicalId ?? id;
  }

  /// [resolve] for a whole coverage, preserving order.
  Future<List<String>> resolveAll(
    Iterable<String> ids,
    SyncAliasKind kind,
  ) async => <String>[for (final id in ids) await resolve(id, kind)];
}
