import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'quran_cache_database.g.dart';

@DataClassName('QuranSourceMetadataRow')
class QuranSourceMetadata extends Table {
  @override
  String get tableName => 'quran_source_metadata';

  TextColumn get id => text()();
  TextColumn get provider => text()();
  TextColumn get datasetType => text()();
  TextColumn get version => text()();
  TextColumn get languageCode => text().nullable()();
  TextColumn get translationKey => text().nullable()();
  TextColumn get sourceUri => text().nullable()();
  TextColumn get attribution => text().nullable()();
  TextColumn get license => text().nullable()();
  DateTimeColumn get fetchedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(id) > 0)',
    'CHECK (length(provider) > 0)',
    'CHECK (length(dataset_type) > 0)',
    'CHECK (length(version) > 0)',
  ];
}

@DataClassName('QuranAyahCacheRow')
class QuranAyahCache extends Table {
  @override
  String get tableName => 'quran_ayah_cache';

  TextColumn get sourceId => text().references(
    QuranSourceMetadata,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get surahNumber => integer()();
  IntColumn get ayahNumber => integer()();
  TextColumn get providerAyahId => text().nullable()();
  TextColumn get arabicText => text().nullable()();
  TextColumn get translation => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    sourceId,
    surahNumber,
    ayahNumber,
  };

  @override
  List<String> get customConstraints => <String>[
    'CHECK (surah_number > 0)',
    'CHECK (ayah_number > 0)',
    'CHECK (arabic_text IS NOT NULL OR translation IS NOT NULL)',
  ];
}

@DataClassName('QuranWordCacheRow')
class QuranWordCache extends Table {
  @override
  String get tableName => 'quran_word_cache';

  TextColumn get sourceId => text().references(
    QuranSourceMetadata,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get surahNumber => integer()();
  IntColumn get ayahNumber => integer()();
  IntColumn get position => integer()();
  TextColumn get providerWordId => text().nullable()();
  TextColumn get arabicText => text().nullable()();
  TextColumn get translation => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    sourceId,
    surahNumber,
    ayahNumber,
    position,
  };

  @override
  List<String> get customConstraints => <String>[
    'CHECK (surah_number > 0)',
    'CHECK (ayah_number > 0)',
    'CHECK (position > 0)',
    'CHECK (arabic_text IS NOT NULL OR translation IS NOT NULL)',
  ];
}

@DriftDatabase(
  tables: <Type>[QuranSourceMetadata, QuranAyahCache, QuranWordCache],
)
class QuranCacheDatabase extends _$QuranCacheDatabase {
  QuranCacheDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'murajaah_quran_cache'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _createVersionOneIndexes();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from == to) return;
      throw StateError('Unsupported Quran cache migration from $from to $to.');
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createVersionOneIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quran_ayah_lookup '
      'ON quran_ayah_cache (surah_number, ayah_number, source_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quran_word_lookup '
      'ON quran_word_cache '
      '(surah_number, ayah_number, position, source_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_quran_source_provider '
      'ON quran_source_metadata (provider, dataset_type, language_code)',
    );
  }
}
