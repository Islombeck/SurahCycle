import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test('persists exact pinned selection metadata with no default', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = QuranTranslationSelectionRepository(
      AppSettingsRepository(database),
    );
    final fetchedAt = DateTime.utc(2026, 8, 25, 10);
    final selected = QuranTranslationSelection.fromCatalog(
      translation: QuranTranslation(
        source: 'quranenc.com',
        key: 'synthetic-key',
        languageCode: 'ru',
        version: 'test-v1',
        title: '  Exact provider title  ',
        description: 'Exact provider description',
        direction: 'ltr',
        lastUpdateEpochSeconds: 123,
      ),
      fetchedAtUtc: fetchedAt,
      attribution: 'QuranEnc.com',
      sourceUri: Uri.parse('https://quranenc.com/'),
    );

    expect(await repository.getSelected(), isNull);
    await repository.save(selected, updatedAtUtc: fetchedAt);

    expect(await repository.getSelected(), selected);
    expect((await repository.getSelected())!.title, '  Exact provider title  ');
    expect(
      selected.hasUpdateIn(<QuranTranslation>[
        QuranTranslation(
          source: 'quranenc.com',
          key: 'synthetic-key',
          languageCode: 'ru',
          version: 'test-v2',
          title: 'Updated catalog title',
        ),
      ]),
      isTrue,
    );
    expect(await repository.clear(), isTrue);
    expect(await repository.getSelected(), isNull);
  });
}
