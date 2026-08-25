import '../database/app_database.dart';

enum SettingValueType { string, boolean, integer, decimal }

/// Small typed facade over AppSettings. Unknown or mismatched types are errors
/// instead of silently coercing persisted values.
final class AppSettingsRepository {
  const AppSettingsRepository(this.database);

  final AppDatabase database;

  Future<String?> getString(String key) =>
      _read(key, expectedType: SettingValueType.string);

  Future<bool?> getBool(String key) async {
    final value = await _read(key, expectedType: SettingValueType.boolean);
    if (value == null) return null;
    if (value == 'true') return true;
    if (value == 'false') return false;
    throw StateError('Setting "$key" has an invalid boolean value.');
  }

  Future<int?> getInt(String key) async {
    final value = await _read(key, expectedType: SettingValueType.integer);
    if (value == null) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) throw StateError('Setting "$key" is not an integer.');
    return parsed;
  }

  Future<double?> getDouble(String key) async {
    final value = await _read(key, expectedType: SettingValueType.decimal);
    if (value == null) return null;
    final parsed = double.tryParse(value);
    if (parsed == null) throw StateError('Setting "$key" is not a decimal.');
    return parsed;
  }

  Future<void> setString(
    String key,
    String value, {
    required DateTime updatedAtUtc,
  }) => _write(key, value, SettingValueType.string, updatedAtUtc);

  Future<void> setBool(
    String key,
    bool value, {
    required DateTime updatedAtUtc,
  }) => _write(key, value.toString(), SettingValueType.boolean, updatedAtUtc);

  Future<void> setInt(
    String key,
    int value, {
    required DateTime updatedAtUtc,
  }) => _write(key, value.toString(), SettingValueType.integer, updatedAtUtc);

  Future<void> setDouble(
    String key,
    double value, {
    required DateTime updatedAtUtc,
  }) => _write(key, value.toString(), SettingValueType.decimal, updatedAtUtc);

  Stream<String?> watchString(String key) =>
      _watch(key, expectedType: SettingValueType.string);

  Stream<bool?> watchBool(String key) =>
      _watch(key, expectedType: SettingValueType.boolean).map((String? value) {
        if (value == null) return null;
        if (value == 'true') return true;
        if (value == 'false') return false;
        throw StateError('Setting "$key" has an invalid boolean value.');
      });

  Future<bool> remove(String key) async =>
      (database.delete(database.appSettings)
            ..where((AppSettings row) => row.key.equals(key)))
          .go()
          .then((int count) => count == 1);

  Future<String?> _read(
    String key, {
    required SettingValueType expectedType,
  }) async {
    _requireKey(key);
    final row = await (database.select(
      database.appSettings,
    )..where((AppSettings row) => row.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    _requireType(row, expectedType);
    return row.value;
  }

  Stream<String?> _watch(String key, {required SettingValueType expectedType}) {
    _requireKey(key);
    final query = database.select(database.appSettings)
      ..where((AppSettings row) => row.key.equals(key));
    return query.watchSingleOrNull().map((AppSettingRow? row) {
      if (row == null) return null;
      _requireType(row, expectedType);
      return row.value;
    });
  }

  Future<void> _write(
    String key,
    String value,
    SettingValueType type,
    DateTime updatedAtUtc,
  ) async {
    _requireKey(key);
    _requireUtc(updatedAtUtc);
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            valueType: _storedType(type),
            updatedAtUtc: updatedAtUtc,
          ),
        );
  }

  void _requireType(AppSettingRow row, SettingValueType expected) {
    final expectedName = _storedType(expected);
    if (row.valueType != expectedName) {
      throw StateError(
        'Setting "${row.key}" is ${row.valueType}, expected $expectedName.',
      );
    }
  }

  String _storedType(SettingValueType type) => switch (type) {
    SettingValueType.string => 'string',
    SettingValueType.boolean => 'bool',
    SettingValueType.integer => 'int',
    SettingValueType.decimal => 'double',
  };

  void _requireKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'Must not be empty.');
    }
  }

  void _requireUtc(DateTime value) {
    if (!value.isUtc) {
      throw ArgumentError.value(value, 'updatedAtUtc', 'Must be UTC.');
    }
  }
}
