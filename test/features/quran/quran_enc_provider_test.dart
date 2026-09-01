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

    test(
      'uses audited direct probes only after an empty Russian catalog',
      () async {
        final requestedPaths = <String>[];
        final emittedDiagnostics = <QuranEncCatalogDiagnostics>[];
        final client = MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path == '/api/v1/translations/list/ru') {
            return _jsonResponse(<String, Object?>{
              'translations': <Object?>[],
            });
          }
          if (request.url.path.endsWith('/russian_rwwad/1')) {
            // Structurally valid but intentionally not the audited QuranEnc
            // revision. It must never become an available translation.
            return _jsonResponse(<String, Object?>{
              'result': <Object?>[
                <String, Object?>{
                  'sura': '1',
                  'aya': '1',
                  'translation': 'Synthetic mismatch',
                  'footnotes': null,
                },
              ],
            });
          }
          if (request.url.path.endsWith('/russian_aboadel/1')) {
            return http.Response('', 404);
          }
          fail('Unexpected request: ${request.url}');
        });
        final provider = QuranEncProvider(
          client: client,
          diagnosticsSink: emittedDiagnostics.add,
        );

        final discovery = await provider.discoverTranslations(
          languageCode: 'ru',
          localizationLanguageCode: 'ru',
        );

        expect(discovery.translations, isEmpty);
        expect(
          discovery.diagnostics.origin,
          QuranEncDiscoveryOrigin.knownOfficialDirectFallback,
        );
        expect(discovery.diagnostics.httpStatus, 200);
        expect(
          discovery.diagnostics.contentType,
          'application/json; charset=utf-8',
        );
        expect(discovery.diagnostics.responseByteLength, greaterThan(0));
        expect(discovery.diagnostics.parsedTranslationCount, 0);
        expect(discovery.diagnostics.knownProbes, hasLength(2));
        expect(emittedDiagnostics, <QuranEncCatalogDiagnostics>[
          discovery.diagnostics,
        ]);
        expect(
          discovery.diagnostics.knownProbes[0].status,
          QuranEncKnownProbeStatus.contentRevisionMismatch,
        );
        expect(
          discovery.diagnostics.knownProbes[1].status,
          QuranEncKnownProbeStatus.rejectedRequest,
        );
        expect(
          requestedPaths,
          containsAll(<String>[
            '/api/v1/translation/sura/russian_rwwad/1',
            '/api/v1/translation/sura/russian_aboadel/1',
          ]),
        );
      },
    );

    test(
      'augments Uzbek catalog by probing only known keys it omitted',
      () async {
        final requestedPaths = <String>[];
        final client = MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path == '/api/v1/translations/list/uz') {
            return _jsonResponse(<String, Object?>{
              'translations': <Object?>[
                <String, Object?>{
                  'key': 'uzbek_rwwad',
                  'language_iso_code': 'uz',
                  'version': '1.0.4',
                  'title': 'Uzbek Translation - Rowwad Translation Center',
                },
                <String, Object?>{
                  'key': 'uzbek_mansour',
                  'language_iso_code': 'uz',
                  'version': '1.0.0',
                  'title': 'Uzbek Translation - Alaauddin Mansour',
                },
              ],
            });
          }
          if (request.url.path.endsWith('/uzbek_sadiq/1')) {
            return _jsonResponse(<String, Object?>{
              'result': <Object?>[
                <String, Object?>{
                  'sura': '1',
                  'aya': '1',
                  'translation': 'Synthetic revision mismatch',
                  'footnotes': null,
                },
              ],
            });
          }
          fail('Unexpected request: ${request.url}');
        });
        final provider = QuranEncProvider(client: client);

        final discovery = await provider.discoverTranslations(
          languageCode: 'uz',
          localizationLanguageCode: 'uz',
        );

        expect(
          discovery.translations.map((translation) => translation.key),
          <String>['uzbek_rwwad', 'uzbek_mansour'],
        );
        expect(
          discovery.diagnostics.origin,
          QuranEncDiscoveryOrigin.officialCatalogAugmented,
        );
        expect(discovery.diagnostics.parsedTranslationCount, 2);
        expect(discovery.diagnostics.knownProbes, hasLength(1));
        expect(
          discovery.diagnostics.knownProbes.single.status,
          QuranEncKnownProbeStatus.contentRevisionMismatch,
        );
        expect(requestedPaths, <String>[
          '/api/v1/translations/list/uz',
          '/api/v1/translation/sura/uzbek_sadiq/1',
        ]);
      },
    );

    test(
      'does not expose an unaudited version of a known catalog key',
      () async {
        final provider = QuranEncProvider(
          client: MockClient((request) async {
            if (request.url.path == '/api/v1/translations/list/uz') {
              return _jsonResponse(<String, Object?>{
                'translations': <Object?>[
                  <String, Object?>{
                    'key': 'uzbek_rwwad',
                    'language_iso_code': 'uz',
                    'version': '9.9.9',
                    'title': 'Unaudited upstream revision',
                  },
                ],
              });
            }
            return _jsonResponse(<String, Object?>{
              'result': <Object?>[
                <String, Object?>{
                  'sura': '1',
                  'aya': '1',
                  'translation': 'Synthetic revision mismatch',
                  'footnotes': null,
                },
              ],
            });
          }),
        );

        final discovery = await provider.discoverTranslations(
          languageCode: 'uz',
          localizationLanguageCode: 'uz',
        );

        expect(discovery.translations, isEmpty);
        expect(
          discovery.diagnostics.origin,
          QuranEncDiscoveryOrigin.knownOfficialDirectFallback,
        );
        expect(discovery.diagnostics.knownProbes, hasLength(3));
        expect(
          discovery.diagnostics.knownProbes.every(
            (probe) =>
                probe.status ==
                QuranEncKnownProbeStatus.contentRevisionMismatch,
          ),
          isTrue,
        );
      },
    );

    test('never probes known keys for a non-Russian empty catalog', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests += 1;
        return _jsonResponse(<String, Object?>{'translations': <Object?>[]});
      });
      final provider = QuranEncProvider(client: client);

      final discovery = await provider.discoverTranslations(languageCode: 'en');

      expect(discovery.translations, isEmpty);
      expect(
        discovery.diagnostics.origin,
        QuranEncDiscoveryOrigin.officialCatalog,
      );
      expect(discovery.diagnostics.knownProbes, isEmpty);
      expect(requests, 1);
    });

    test(
      'never probes known keys when the Russian catalog has entries',
      () async {
        var requests = 0;
        final client = MockClient((request) async {
          requests += 1;
          return _jsonResponse(<String, Object?>{
            'translations': <Object?>[
              <String, Object?>{
                'key': 'catalog-key',
                'language_iso_code': 'ru',
                'version': 'catalog-v1',
                'title': 'Catalog fixture',
              },
            ],
          });
        });
        final provider = QuranEncProvider(client: client);

        final discovery = await provider.discoverTranslations(
          languageCode: 'ru',
        );

        expect(discovery.translations.single.key, 'catalog-key');
        expect(
          discovery.diagnostics.origin,
          QuranEncDiscoveryOrigin.officialCatalog,
        );
        expect(discovery.diagnostics.knownProbes, isEmpty);
        expect(requests, 1);
      },
    );

    test('rejects HTML even when the response status is successful', () async {
      final provider = QuranEncProvider(
        client: MockClient(
          (request) async => http.Response(
            '<html>Synthetic provider error</html>',
            200,
            headers: const <String, String>{'content-type': 'text/html'},
          ),
        ),
      );

      await expectLater(
        provider.listTranslations(languageCode: 'ru'),
        throwsA(
          isA<QuranProviderException>().having(
            (error) => error.code,
            'code',
            'quranenc_content_type_invalid',
          ),
        ),
      );
    });

    test(
      'direct fallback content must match its pinned surah revision',
      () async {
        final known = KnownOfficialQuranEncTranslations.russian.first;
        final provider = QuranEncProvider(
          client: MockClient(
            (request) async => _jsonResponse(<String, Object?>{
              'result': <Object?>[
                <String, Object?>{
                  'sura': '1',
                  'aya': '1',
                  'translation': 'Synthetic mismatch',
                  'footnotes': null,
                },
              ],
            }),
          ),
        );

        await expectLater(
          provider.fetchSurahTranslation(
            translation: known.toTranslation(),
            surahNumber: 1,
          ),
          throwsA(
            isA<QuranProviderException>().having(
              (error) => error.code,
              'code',
              'quranenc_known_content_revision_mismatch',
            ),
          ),
        );
      },
    );

    test(
      'known official catalog version must match its pinned surah revision',
      () async {
        final known = KnownOfficialQuranEncTranslations.uzbek.first;
        final provider = QuranEncProvider(
          client: MockClient(
            (request) async => _jsonResponse(<String, Object?>{
              'result': <Object?>[
                <String, Object?>{
                  'sura': '1',
                  'aya': '1',
                  'translation': 'Synthetic catalog revision mismatch',
                  'footnotes': null,
                },
              ],
            }),
          ),
        );

        await expectLater(
          provider.fetchSurahTranslation(
            translation: QuranTranslation(
              source: QuranEncProvider.sourceId,
              key: known.key,
              languageCode: known.languageCode,
              version: known.officialVersion!.substring(1),
              title: known.title,
            ),
            surahNumber: 1,
          ),
          throwsA(
            isA<QuranProviderException>().having(
              (error) => error.code,
              'code',
              'quranenc_known_content_revision_mismatch',
            ),
          ),
        );
      },
    );

    test(
      'known key rejects a catalog version that has not been audited',
      () async {
        final known = KnownOfficialQuranEncTranslations.uzbek.first;
        final provider = QuranEncProvider(
          client: MockClient(
            (request) async => _jsonResponse(<String, Object?>{
              'result': <Object?>[
                <String, Object?>{
                  'sura': '1',
                  'aya': '1',
                  'translation': 'Synthetic unaudited revision',
                  'footnotes': null,
                },
              ],
            }),
          ),
        );

        await expectLater(
          provider.fetchSurahTranslation(
            translation: QuranTranslation(
              source: QuranEncProvider.sourceId,
              key: known.key,
              languageCode: known.languageCode,
              version: '9.9.9',
              title: known.title,
            ),
            surahNumber: 1,
          ),
          throwsA(
            isA<QuranProviderException>().having(
              (error) => error.code,
              'code',
              'quranenc_known_content_revision_mismatch',
            ),
          ),
        );
      },
    );

    test('known registry carries complete truthful audit metadata', () {
      expect(KnownOfficialQuranEncTranslations.russian, hasLength(2));
      expect(KnownOfficialQuranEncTranslations.uzbek, hasLength(3));
      expect(KnownOfficialQuranEncTranslations.all, hasLength(5));
      expect(
        KnownOfficialQuranEncTranslations.byLanguage('ru'),
        KnownOfficialQuranEncTranslations.russian,
      );
      expect(
        KnownOfficialQuranEncTranslations.byLanguage('uz'),
        KnownOfficialQuranEncTranslations.uzbek,
      );
      expect(KnownOfficialQuranEncTranslations.byLanguage('xx'), isEmpty);
      expect(
        KnownOfficialQuranEncTranslations.byKey('uzbek_sadiq')?.languageCode,
        'uz',
      );
      expect(
        () => KnownOfficialQuranEncTranslations.byLanguage(
          'uz',
        ).add(KnownOfficialQuranEncTranslations.uzbek.first),
        throwsUnsupportedError,
      );
      expect(
        KnownOfficialQuranEncTranslations.all.map((known) => known.key).toSet(),
        hasLength(5),
      );
      for (final known in KnownOfficialQuranEncTranslations.all) {
        expect(known.languageCode, anyOf('ru', 'uz'));
        expect(known.expectedSource, QuranEncProvider.sourceId);
        expect(known.officialVersion, startsWith('V'));
        expect(known.provenance.scheme, 'https');
        expect(known.lastVerifiedAtUtc.isUtc, isTrue);
        expect(known.corpusSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(
          known.technicalRevision,
          'quranenc-direct-${known.lastVerifiedDateIso8601}-sha256-'
          '${known.corpusSha256}',
        );
        expect(
          known.expectedSurahSha256(1),
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
        expect(
          known.expectedSurahSha256(114),
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
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
