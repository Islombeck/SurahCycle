import 'package:drift/drift.dart';

import '../../domain/domain.dart';
import '../database/app_database.dart';
import 'settings_repository.dart';

final class StoredPrayerSession {
  const StoredPrayerSession({required this.session, required this.localDate});

  final PrayerSession session;
  final LocalDate? localDate;
}

final class PrayerRepository {
  PrayerRepository(this.database) : _settings = AppSettingsRepository(database);

  static const String _selectedTypeKey = 'selected_prayer_type';
  static const String _selectedQadaKey = 'selected_prayer_is_qada';

  final AppDatabase database;
  final AppSettingsRepository _settings;

  Future<void> saveSelectedContext(
    PrayerContext context, {
    required DateTime updatedAtUtc,
  }) => database.transaction(() async {
    await _settings.setString(
      _selectedTypeKey,
      context.prayerType.name,
      updatedAtUtc: updatedAtUtc,
    );
    await _settings.setBool(
      _selectedQadaKey,
      context.isQada,
      updatedAtUtc: updatedAtUtc,
    );
  });

  /// The stored manual context, read as one consistent pair.
  ///
  /// The two keys are written together in [saveSelectedContext], but reading
  /// them as two independent awaits let a reader straddle that write and see
  /// the new type with the old flag missing — which threw
  /// `Stored prayer context is incomplete.` at whoever asked. That exception
  /// reaches the prayer-time settings stream, and an errored settings stream
  /// blanks the whole prayer context on Home. Reading inside a transaction
  /// gives the reader one snapshot, so it sees the old pair or the new pair.
  Future<PrayerContext?> getSelectedContext() => database.transaction(() async {
    final type = await _settings.getString(_selectedTypeKey);
    final isQada = await _settings.getBool(_selectedQadaKey);
    if (type == null && isQada == null) return null;
    if (type == null || isQada == null) {
      throw StateError('Stored prayer context is incomplete.');
    }
    return PrayerContext(
      prayerType: PrayerType.values.byName(type),
      isQada: isQada,
    );
  });

  Stream<PrayerContext?> watchSelectedContext() => database
      .customSelect(
        'SELECT 1 AS prayer_context_watch',
        readsFrom: <ResultSetImplementation<Table, Object?>>{
          database.appSettings,
        },
      )
      .watch()
      .asyncMap((List<QueryRow> _) => getSelectedContext());

  Future<void> saveSession(PrayerSession session, {LocalDate? localDate}) =>
      database
          .into(database.prayerSessions)
          .insertOnConflictUpdate(
            PrayerSessionsCompanion.insert(
              id: session.id,
              prayerType: session.context.prayerType.name,
              isQada: Value<bool>(session.context.isQada),
              startedAtUtc: session.startedAtUtc,
              localDate: Value<String?>(localDate?.toString()),
            ),
          );

  Future<StoredPrayerSession?> getSession(String id) async {
    final row = await (database.select(
      database.prayerSessions,
    )..where((PrayerSessions row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Stream<List<StoredPrayerSession>> watchSessions() {
    final query = database.select(database.prayerSessions)
      ..orderBy(<OrderingTerm Function(PrayerSessions)>[
        (PrayerSessions row) => OrderingTerm.desc(row.startedAtUtc),
      ]);
    return query.watch().map(
      (List<PrayerSessionRow> rows) =>
          rows.map(_fromRow).toList(growable: false),
    );
  }

  Future<bool> deleteSession(String id) async =>
      (database.delete(database.prayerSessions)
            ..where((PrayerSessions row) => row.id.equals(id)))
          .go()
          .then((int count) => count == 1);

  StoredPrayerSession _fromRow(PrayerSessionRow row) => StoredPrayerSession(
    session: PrayerSession(
      id: row.id,
      context: PrayerContext(
        prayerType: PrayerType.values.byName(row.prayerType),
        isQada: row.isQada,
      ),
      startedAtUtc: row.startedAtUtc.toUtc(),
    ),
    localDate: row.localDate == null ? null : _parseLocalDate(row.localDate!),
  );
}

LocalDate _parseLocalDate(String value) {
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
