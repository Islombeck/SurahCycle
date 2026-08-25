import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/database/quran_cache_database.dart'
    show QuranCacheDatabase;
import 'package:murajaah/core/data/repositories/quran_cache_repository.dart'
    show QuranCacheRepository;
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test('Quran cache v1 to v2 preserves exact cached content', () async {
    final executor = NativeDatabase.memory(
      setup: (rawDatabase) {
        rawDatabase.execute('PRAGMA foreign_keys = ON');
        rawDatabase.execute('''
          CREATE TABLE quran_source_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            provider TEXT NOT NULL,
            dataset_type TEXT NOT NULL,
            version TEXT NOT NULL,
            language_code TEXT,
            translation_key TEXT,
            source_uri TEXT,
            attribution TEXT,
            license TEXT,
            fetched_at_utc INTEGER NOT NULL
          )
        ''');
        rawDatabase.execute('''
          CREATE TABLE quran_ayah_cache (
            source_id TEXT NOT NULL REFERENCES quran_source_metadata(id)
              ON DELETE CASCADE,
            surah_number INTEGER NOT NULL,
            ayah_number INTEGER NOT NULL,
            provider_ayah_id TEXT,
            arabic_text TEXT,
            translation TEXT,
            PRIMARY KEY (source_id, surah_number, ayah_number)
          )
        ''');
        rawDatabase.execute('''
          CREATE TABLE quran_word_cache (
            source_id TEXT NOT NULL REFERENCES quran_source_metadata(id)
              ON DELETE CASCADE,
            surah_number INTEGER NOT NULL,
            ayah_number INTEGER NOT NULL,
            position INTEGER NOT NULL,
            provider_word_id TEXT,
            arabic_text TEXT,
            translation TEXT,
            PRIMARY KEY (source_id, surah_number, ayah_number, position)
          )
        ''');
        rawDatabase.execute('''
          INSERT INTO quran_source_metadata (
            id, provider, dataset_type, version, language_code,
            translation_key, source_uri, attribution, license, fetched_at_utc
          ) VALUES (
            'legacy', 'quranenc.com', 'full_translation', 'legacy-v1', 'ru',
            'legacy-key', 'https://quranenc.com/', 'QuranEnc.com',
            'Legacy terms', 0
          )
        ''');
        rawDatabase.execute('''
          INSERT INTO quran_ayah_cache (
            source_id, surah_number, ayah_number, translation
          ) VALUES ('legacy', 1, 1, '  Legacy exact translation  ')
        ''');
        rawDatabase.userVersion = 1;
      },
    );
    final database = QuranCacheDatabase(executor);
    addTearDown(database.close);

    final cached = await QuranCacheRepository(
      database,
    ).getAyah(sourceId: 'legacy', surahNumber: 1, ayahNumber: 1);

    expect(database.schemaVersion, 2);
    expect(cached!.translation, '  Legacy exact translation  ');
    expect(cached.translationFootnotes, isNull);
    expect(
      await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      2,
    );
  });

  group('DriftQuranContentCache', () {
    late QuranCacheDatabase database;
    late DriftQuranContentCache cache;

    setUp(() {
      database = QuranCacheDatabase(NativeDatabase.memory());
      cache = DriftQuranContentCache(QuranCacheRepository(database));
    });

    tearDown(() => database.close());

    test('round-trips exact translation and footnote strings', () async {
      const translation = '  Exact provider translation\nkept unchanged  ';
      const footnotes = '  Exact provider footnote\nkept unchanged  ';
      final key = _key(surahNumber: 1);
      final content = _content(
        surahNumber: 1,
        translations: const <String>[translation],
        footnotes: const <String?>[footnotes],
      );

      await cache.writeSurah(key, content);
      final restored = await cache.readSurah(key);

      expect(restored, isNotNull);
      expect(restored!.ayahs.single.fullTranslation, translation);
      expect(restored.ayahs.single.translationFootnotes, footnotes);
      expect(restored.sourceMetadata.translationKey, key.translationKey);
      expect(restored.sourceMetadata.version, key.version);
      expect(restored.sourceMetadata.licenseUsageInformation, 'Test terms');
    });

    test(
      'replacing one surah retains other surahs from the same version',
      () async {
        final firstKey = _key(surahNumber: 1);
        final secondKey = _key(surahNumber: 2);
        await cache.writeSurah(
          firstKey,
          _content(surahNumber: 1, translations: const <String>['First surah']),
        );
        await cache.writeSurah(
          secondKey,
          _content(
            surahNumber: 2,
            translations: const <String>[
              'Second surah one',
              'Second surah two',
            ],
          ),
        );

        final first = await cache.readSurah(firstKey);
        final second = await cache.readSurah(secondKey);

        expect(first!.ayahs.single.fullTranslation, 'First surah');
        expect(second!.ayahs.map((ayah) => ayah.fullTranslation), <String>[
          'Second surah one',
          'Second surah two',
        ]);
        expect(
          first.sourceMetadata.sourceUri,
          Uri.parse('https://example.test/translation/test-translation/1'),
        );
        expect(
          second.sourceMetadata.sourceUri,
          Uri.parse('https://example.test/translation/test-translation/2'),
        );
      },
    );

    test(
      'different provider versions coexist under separate identities',
      () async {
        final oldKey = _key(surahNumber: 1, version: 'test-v1');
        final newKey = _key(surahNumber: 1, version: 'test-v2');
        await cache.writeSurah(
          oldKey,
          _content(
            surahNumber: 1,
            version: 'test-v1',
            translations: const <String>['Old exact value'],
          ),
        );
        await cache.writeSurah(
          newKey,
          _content(
            surahNumber: 1,
            version: 'test-v2',
            translations: const <String>['New exact value'],
          ),
        );

        expect(
          (await cache.readSurah(oldKey))!.ayahs.single.fullTranslation,
          'Old exact value',
        );
        expect(
          (await cache.readSurah(newKey))!.ayahs.single.fullTranslation,
          'New exact value',
        );
      },
    );
  });
}

QuranContentCacheKey _key({
  required int surahNumber,
  String version = 'test-v1',
}) => QuranContentCacheKey(
  providerId: 'test-provider',
  translationKey: 'test-translation',
  version: version,
  surahNumber: surahNumber,
);

QuranSurahContent _content({
  required int surahNumber,
  required List<String> translations,
  List<String?>? footnotes,
  String version = 'test-v1',
}) => QuranSurahContent(
  surahNumber: surahNumber,
  sourceMetadata: QuranSourceMetadata(
    source: 'test-provider',
    translationKey: 'test-translation',
    version: version,
    language: 'xx',
    fetchedAtUtc: DateTime.utc(2026, 8, 25),
    attribution: 'Test provider',
    licenseUsageInformation: 'Test terms',
    sourceUri: Uri.parse(
      'https://example.test/translation/test-translation/$surahNumber',
    ),
  ),
  capabilities: const QuranContentCapabilities(
    hasSurahMetadata: false,
    hasArabicText: false,
    hasFullTranslation: true,
    hasWordTranslation: false,
  ),
  ayahs: <Ayah>[
    for (var index = 0; index < translations.length; index += 1)
      Ayah(
        surahNumber: surahNumber,
        ayahNumber: index + 1,
        fullTranslation: translations[index],
        translationSource: 'test-provider',
        translationVersion: version,
        translationFootnotes: footnotes?[index],
      ),
  ],
);
