import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  group('QuranEncProvider', () {
    test(
      'loads the translation catalog without choosing a hardcoded key',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/translations/list/xx');
          expect(request.url.queryParameters['localization'], 'yy');
          return _jsonResponse(<String, Object?>{
            'translations': <Object?>[
              <String, Object?>{
                'key': 'selected-test-key',
                'language_iso_code': 'xx',
                'version': 'test-v7',
                'last_update': 123456,
                'title': '  Synthetic catalog title  ',
                'description': 'Synthetic catalog description',
                'direction': 'ltr',
              },
            ],
          });
        });
        final provider = QuranEncProvider(client: client);

        final translations = await provider.listTranslations(
          languageCode: 'xx',
          localizationLanguageCode: 'yy',
        );

        expect(translations, hasLength(1));
        expect(translations.single.key, 'selected-test-key');
        expect(translations.single.version, 'test-v7');
        expect(translations.single.title, '  Synthetic catalog title  ');
        expect(translations.single.source, QuranEncProvider.sourceId);
        expect(
          () => translations.add(translations.single),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'fetches an exact translation and explicitly ignores Arabic field',
      () async {
        const exactTranslation = '  Synthetic translation\nkept exactly  ';
        final client = MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/translation/sura/selected-test-key/9',
          );
          return _jsonResponse(<String, Object?>{
            'result': <Object?>[
              <String, Object?>{
                'id': 'synthetic-id',
                'sura': '9',
                'aya': '1',
                'arabic_text': 'Synthetic field that is outside this adapter',
                'translation': exactTranslation,
                'footnotes': '',
              },
            ],
          });
        });
        final fetchedAt = DateTime.utc(2026, 8, 24, 12);
        final provider = QuranEncProvider(
          client: client,
          nowUtc: () => fetchedAt,
        );
        final selected = _selectedTranslation();

        final content = await provider.fetchSurahTranslation(
          translation: selected,
          surahNumber: 9,
        );

        expect(content.ayahs.single.fullTranslation, exactTranslation);
        expect(content.ayahs.single.translationFootnotes, '');
        expect(content.ayahs.single.arabicText, isNull);
        expect(content.capabilities.hasArabicText, isFalse);
        expect(content.capabilities.hasFullTranslation, isTrue);
        expect(content.surah, isNull);
        expect(content.words, isEmpty);
        expect(content.sourceMetadata.source, QuranEncProvider.sourceId);
        expect(content.sourceMetadata.translationKey, selected.key);
        expect(content.sourceMetadata.version, selected.version);
        expect(content.sourceMetadata.fetchedAtUtc, fetchedAt);
        expect(
          content.sourceMetadata.licenseUsageInformation,
          contains(QuranEncProvider.termsUrl),
        );
      },
    );

    test('rejects a catalog entry outside the requested language', () async {
      final client = MockClient(
        (request) async => _jsonResponse(<String, Object?>{
          'translations': <Object?>[
            <String, Object?>{
              'key': 'wrong-language-key',
              'language_iso_code': 'en',
              'version': 'test-v1',
              'title': 'Wrong language fixture',
            },
          ],
        }),
      );
      final provider = QuranEncProvider(client: client);

      await expectLater(
        provider.listTranslations(languageCode: 'ru'),
        throwsA(
          isA<QuranProviderException>().having(
            (error) => error.code,
            'code',
            'quranenc_translation_language_mismatch',
          ),
        ),
      );
    });

    test(
      'rejects malformed coordinates without exposing response content',
      () async {
        final client = MockClient(
          (request) async => _jsonResponse(<String, Object?>{
            'result': <Object?>[
              <String, Object?>{
                'sura': '10',
                'aya': '1',
                'translation': 'Synthetic mismatched translation',
                'footnotes': '',
              },
            ],
          }),
        );
        final provider = QuranEncProvider(client: client);

        await expectLater(
          provider.fetchSurahTranslation(
            translation: _selectedTranslation(),
            surahNumber: 9,
          ),
          throwsA(
            isA<QuranProviderException>().having(
              (error) => error.code,
              'code',
              'quranenc_ayah_coordinates_invalid',
            ),
          ),
        );
      },
    );

    test('maps non-success status without retaining response body', () async {
      final client = MockClient(
        (request) async => http.Response(
          'Synthetic body that must not enter the exception',
          503,
        ),
      );
      final provider = QuranEncProvider(client: client);

      try {
        await provider.listTranslations();
        fail('Expected QuranProviderException.');
      } on QuranProviderException catch (error) {
        expect(error.statusCode, 503);
        expect(error.toString(), isNot(contains('Synthetic body')));
      }
    });
  });
}

QuranTranslation _selectedTranslation() => QuranTranslation(
  source: QuranEncProvider.sourceId,
  key: 'selected-test-key',
  languageCode: 'xx',
  version: 'test-v7',
  title: 'Synthetic selected translation',
);

http.Response _jsonResponse(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);
