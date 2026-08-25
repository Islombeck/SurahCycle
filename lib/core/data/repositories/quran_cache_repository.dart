import 'package:drift/drift.dart';

import '../database/quran_cache_database.dart';

final class QuranSourceRecord {
  const QuranSourceRecord({
    required this.id,
    required this.provider,
    required this.datasetType,
    required this.version,
    required this.fetchedAtUtc,
    this.languageCode,
    this.translationKey,
    this.sourceUri,
    this.attribution,
    this.license,
  });

  final String id;
  final String provider;
  final String datasetType;
  final String version;
  final String? languageCode;
  final String? translationKey;
  final String? sourceUri;
  final String? attribution;
  final String? license;
  final DateTime fetchedAtUtc;
}

final class CachedQuranAyah {
  const CachedQuranAyah({
    required this.sourceId,
    required this.surahNumber,
    required this.ayahNumber,
    this.providerAyahId,
    this.arabicText,
    this.translation,
    this.translationFootnotes,
  });

  final String sourceId;
  final int surahNumber;
  final int ayahNumber;
  final String? providerAyahId;
  final String? arabicText;
  final String? translation;
  final String? translationFootnotes;
}

final class CachedQuranWord {
  const CachedQuranWord({
    required this.sourceId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.position,
    this.providerWordId,
    this.arabicText,
    this.translation,
  });

  final String sourceId;
  final int surahNumber;
  final int ayahNumber;
  final int position;
  final String? providerWordId;
  final String? arabicText;
  final String? translation;
}

/// Exact-value cache facade. It never transliterates, translates, normalizes,
/// or synthesizes Quran content received from a verified provider.
final class QuranCacheRepository {
  const QuranCacheRepository(this.database);

  final QuranCacheDatabase database;

  Future<void> replaceSource({
    required QuranSourceRecord source,
    Iterable<CachedQuranAyah> ayahs = const <CachedQuranAyah>[],
    Iterable<CachedQuranWord> words = const <CachedQuranWord>[],
  }) => database.transaction(() async {
    _validateSource(source);
    final ayahList = ayahs.toList(growable: false);
    final wordList = words.toList(growable: false);
    for (final CachedQuranAyah ayah in ayahList) {
      _validateAyah(ayah, source.id);
    }
    for (final CachedQuranWord word in wordList) {
      _validateWord(word, source.id);
    }

    await (database.delete(
      database.quranSourceMetadata,
    )..where((QuranSourceMetadata row) => row.id.equals(source.id))).go();
    await database
        .into(database.quranSourceMetadata)
        .insert(
          QuranSourceMetadataCompanion.insert(
            id: source.id,
            provider: source.provider,
            datasetType: source.datasetType,
            version: source.version,
            languageCode: Value<String?>(source.languageCode),
            translationKey: Value<String?>(source.translationKey),
            sourceUri: Value<String?>(source.sourceUri),
            attribution: Value<String?>(source.attribution),
            license: Value<String?>(source.license),
            fetchedAtUtc: source.fetchedAtUtc,
          ),
        );
    for (final CachedQuranAyah ayah in ayahList) {
      await database
          .into(database.quranAyahCache)
          .insert(
            QuranAyahCacheCompanion.insert(
              sourceId: ayah.sourceId,
              surahNumber: ayah.surahNumber,
              ayahNumber: ayah.ayahNumber,
              providerAyahId: Value<String?>(ayah.providerAyahId),
              arabicText: Value<String?>(ayah.arabicText),
              translation: Value<String?>(ayah.translation),
              translationFootnotes: Value<String?>(ayah.translationFootnotes),
            ),
          );
    }
    for (final CachedQuranWord word in wordList) {
      await database
          .into(database.quranWordCache)
          .insert(
            QuranWordCacheCompanion.insert(
              sourceId: word.sourceId,
              surahNumber: word.surahNumber,
              ayahNumber: word.ayahNumber,
              position: word.position,
              providerWordId: Value<String?>(word.providerWordId),
              arabicText: Value<String?>(word.arabicText),
              translation: Value<String?>(word.translation),
            ),
          );
    }
  });

  /// Atomically replaces one surah while retaining every other cached surah
  /// belonging to the same immutable source/version.
  Future<void> replaceSurah({
    required QuranSourceRecord source,
    required int surahNumber,
    required Iterable<CachedQuranAyah> ayahs,
  }) => database.transaction(() async {
    _validateSource(source);
    if (surahNumber <= 0) {
      throw ArgumentError.value(
        surahNumber,
        'surahNumber',
        'Must be positive.',
      );
    }
    final ayahList = ayahs.toList(growable: false);
    if (ayahList.isEmpty) {
      throw ArgumentError.value(ayahs, 'ayahs', 'Must not be empty.');
    }
    final coordinates = <int>{};
    for (final ayah in ayahList) {
      _validateAyah(ayah, source.id);
      if (ayah.surahNumber != surahNumber ||
          !coordinates.add(ayah.ayahNumber)) {
        throw ArgumentError(
          'Every ayah must have a unique coordinate in the replaced surah.',
        );
      }
    }

    final existing = await getSource(source.id);
    if (existing != null) _validateCompatibleSource(existing, source);
    await database
        .into(database.quranSourceMetadata)
        .insertOnConflictUpdate(
          QuranSourceMetadataCompanion.insert(
            id: source.id,
            provider: source.provider,
            datasetType: source.datasetType,
            version: source.version,
            languageCode: Value<String?>(source.languageCode),
            translationKey: Value<String?>(source.translationKey),
            sourceUri: Value<String?>(source.sourceUri),
            attribution: Value<String?>(source.attribution),
            license: Value<String?>(source.license),
            fetchedAtUtc: source.fetchedAtUtc,
          ),
        );
    await (database.delete(database.quranAyahCache)..where(
          (QuranAyahCache row) =>
              row.sourceId.equals(source.id) &
              row.surahNumber.equals(surahNumber),
        ))
        .go();
    await database.batch((batch) {
      batch.insertAll(database.quranAyahCache, <QuranAyahCacheCompanion>[
        for (final ayah in ayahList)
          QuranAyahCacheCompanion.insert(
            sourceId: ayah.sourceId,
            surahNumber: ayah.surahNumber,
            ayahNumber: ayah.ayahNumber,
            providerAyahId: Value<String?>(ayah.providerAyahId),
            arabicText: Value<String?>(ayah.arabicText),
            translation: Value<String?>(ayah.translation),
            translationFootnotes: Value<String?>(ayah.translationFootnotes),
          ),
      ]);
    });
  });

  Future<QuranSourceRecord?> getSource(String sourceId) async {
    if (sourceId.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'Must not be empty.');
    }
    final row =
        await (database.select(database.quranSourceMetadata)
              ..where((QuranSourceMetadata table) => table.id.equals(sourceId)))
            .getSingleOrNull();
    return row == null ? null : _sourceFromRow(row);
  }

  Future<List<QuranSourceRecord>> getSources() async {
    final query = database.select(database.quranSourceMetadata)
      ..orderBy(<OrderingTerm Function(QuranSourceMetadata)>[
        (QuranSourceMetadata row) => OrderingTerm.asc(row.provider),
        (QuranSourceMetadata row) => OrderingTerm.asc(row.datasetType),
      ]);
    final rows = await query.get();
    return rows.map(_sourceFromRow).toList(growable: false);
  }

  Stream<List<QuranSourceRecord>> watchSources() {
    final query = database.select(database.quranSourceMetadata)
      ..orderBy(<OrderingTerm Function(QuranSourceMetadata)>[
        (QuranSourceMetadata row) => OrderingTerm.asc(row.provider),
        (QuranSourceMetadata row) => OrderingTerm.asc(row.datasetType),
      ]);
    return query.watch().map(
      (List<QuranSourceMetadataRow> rows) =>
          rows.map(_sourceFromRow).toList(growable: false),
    );
  }

  Future<CachedQuranAyah?> getAyah({
    required String sourceId,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final row =
        await (database.select(database.quranAyahCache)..where(
              (QuranAyahCache table) =>
                  table.sourceId.equals(sourceId) &
                  table.surahNumber.equals(surahNumber) &
                  table.ayahNumber.equals(ayahNumber),
            ))
            .getSingleOrNull();
    return row == null ? null : _ayahFromRow(row);
  }

  Future<List<CachedQuranAyah>> getAyahs({
    required String sourceId,
    required int surahNumber,
  }) async {
    if (sourceId.isEmpty || surahNumber <= 0) {
      throw ArgumentError('Quran source and surah coordinates are invalid.');
    }
    final query = database.select(database.quranAyahCache)
      ..where(
        (QuranAyahCache table) =>
            table.sourceId.equals(sourceId) &
            table.surahNumber.equals(surahNumber),
      )
      ..orderBy(<OrderingTerm Function(QuranAyahCache)>[
        (QuranAyahCache row) => OrderingTerm.asc(row.ayahNumber),
      ]);
    final rows = await query.get();
    return rows.map(_ayahFromRow).toList(growable: false);
  }

  Future<List<CachedQuranWord>> getWords({
    required String sourceId,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final query = database.select(database.quranWordCache)
      ..where(
        (QuranWordCache table) =>
            table.sourceId.equals(sourceId) &
            table.surahNumber.equals(surahNumber) &
            table.ayahNumber.equals(ayahNumber),
      )
      ..orderBy(<OrderingTerm Function(QuranWordCache)>[
        (QuranWordCache row) => OrderingTerm.asc(row.position),
      ]);
    final rows = await query.get();
    return rows.map(_wordFromRow).toList(growable: false);
  }

  Future<bool> clearSource(String sourceId) async =>
      (database.delete(database.quranSourceMetadata)
            ..where((QuranSourceMetadata row) => row.id.equals(sourceId)))
          .go()
          .then((int count) => count == 1);

  Future<void> clearAll() => database.transaction(() async {
    // Child rows are removed by the enabled foreign-key cascade.
    await database.delete(database.quranSourceMetadata).go();
  });

  QuranSourceRecord _sourceFromRow(QuranSourceMetadataRow row) =>
      QuranSourceRecord(
        id: row.id,
        provider: row.provider,
        datasetType: row.datasetType,
        version: row.version,
        languageCode: row.languageCode,
        translationKey: row.translationKey,
        sourceUri: row.sourceUri,
        attribution: row.attribution,
        license: row.license,
        fetchedAtUtc: row.fetchedAtUtc.toUtc(),
      );

  CachedQuranAyah _ayahFromRow(QuranAyahCacheRow row) => CachedQuranAyah(
    sourceId: row.sourceId,
    surahNumber: row.surahNumber,
    ayahNumber: row.ayahNumber,
    providerAyahId: row.providerAyahId,
    arabicText: row.arabicText,
    translation: row.translation,
    translationFootnotes: row.translationFootnotes,
  );

  CachedQuranWord _wordFromRow(QuranWordCacheRow row) => CachedQuranWord(
    sourceId: row.sourceId,
    surahNumber: row.surahNumber,
    ayahNumber: row.ayahNumber,
    position: row.position,
    providerWordId: row.providerWordId,
    arabicText: row.arabicText,
    translation: row.translation,
  );

  void _validateSource(QuranSourceRecord source) {
    if (source.id.isEmpty ||
        source.provider.isEmpty ||
        source.datasetType.isEmpty ||
        source.version.isEmpty) {
      throw ArgumentError('Quran source identity fields must not be empty.');
    }
    if (!source.fetchedAtUtc.isUtc) {
      throw ArgumentError.value(
        source.fetchedAtUtc,
        'fetchedAtUtc',
        'Must be UTC.',
      );
    }
  }

  void _validateCompatibleSource(
    QuranSourceRecord existing,
    QuranSourceRecord replacement,
  ) {
    if (existing.provider != replacement.provider ||
        existing.datasetType != replacement.datasetType ||
        existing.version != replacement.version ||
        existing.languageCode != replacement.languageCode ||
        existing.translationKey != replacement.translationKey) {
      throw StateError(
        'A Quran source id cannot be reused for another dataset identity.',
      );
    }
  }

  void _validateAyah(CachedQuranAyah ayah, String sourceId) {
    if (ayah.sourceId != sourceId) {
      throw ArgumentError('Every ayah must reference the replaced source.');
    }
    if (ayah.surahNumber <= 0 || ayah.ayahNumber <= 0) {
      throw ArgumentError('Quran coordinates must be positive.');
    }
    if (ayah.translationFootnotes != null && ayah.translation == null) {
      throw ArgumentError(
        'Translation footnotes require a translation from the same source.',
      );
    }
    if (!_hasContent(ayah.arabicText, ayah.translation)) {
      throw ArgumentError('An ayah cache row must contain provider content.');
    }
  }

  void _validateWord(CachedQuranWord word, String sourceId) {
    if (word.sourceId != sourceId) {
      throw ArgumentError('Every word must reference the replaced source.');
    }
    if (word.surahNumber <= 0 || word.ayahNumber <= 0 || word.position <= 0) {
      throw ArgumentError('Quran word coordinates must be positive.');
    }
    if (!_hasContent(word.arabicText, word.translation)) {
      throw ArgumentError('A word cache row must contain provider content.');
    }
  }

  bool _hasContent(String? arabic, String? translation) =>
      (arabic != null && arabic.isNotEmpty) ||
      (translation != null && translation.isNotEmpty);
}
