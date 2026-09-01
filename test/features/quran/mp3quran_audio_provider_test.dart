import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  group('Mp3QuranAudioProvider', () {
    test(
      'parses Hafs catalog, surah list, riwaya and matching timing read',
      () async {
        final provider = Mp3QuranAudioProvider(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/reciters')) {
              return _json(_catalog);
            }
            if (request.url.path.endsWith('/ayat_timing/reads')) {
              return _json(_reads);
            }
            fail('Unexpected request: ${request.url}');
          }),
        );

        final catalog = await provider.listHafsReciters();

        expect(catalog, hasLength(1));
        expect(catalog.single.displayName, 'Alijon Qori');
        expect(catalog.single.moshafs.single.riwayaId, 1);
        expect(
          catalog.single.moshafs.single.riwayaName,
          "Rewayat Hafs A'n Assem",
        );
        expect(catalog.single.moshafs.single.availableSurahs, {1, 2, 114});
        expect(catalog.single.moshafs.single.timingReadId, 41);
        expect(
          catalog.single.moshafs.single.capabilities,
          contains(AudioCapability.ayahTiming),
        );
      },
    );

    test('does not mix another riwaya into default catalog', () async {
      final catalog = Mp3QuranParser.parseHafsCatalog(_catalog, _reads);
      expect(catalog.single.moshafs, hasLength(1));
      expect(catalog.single.moshafs.single.id, 10917);
    });

    test('parses timing and ignores API ayah zero prelude', () async {
      final provider = Mp3QuranAudioProvider(
        client: MockClient(
          (_) async => _json([
            {'ayah': 0, 'start_time': 0, 'end_time': 100},
            {'ayah': 1, 'start_time': 100, 'end_time': 900},
            {'ayah': 2, 'start_time': 900, 'end_time': 1800},
          ]),
        ),
      );
      final values = await provider.loadAyahTimings(readId: 41, surahNumber: 1);
      expect(values.map((value) => value.ayahNumber), [1, 2]);
      expect(values.last.end, const Duration(milliseconds: 1800));
    });

    test('missing timing is a validated provider failure', () {
      expect(
        () => Mp3QuranParser.parseTimings([]),
        throwsA(
          isA<QuranAudioProviderException>().having(
            (e) => e.code,
            'code',
            'invalid_timing',
          ),
        ),
      );
    });

    test('bad response is rejected', () {
      expect(
        () => Mp3QuranParser.parseHafsCatalog({'reciters': 'bad'}, []),
        throwsA(
          isA<QuranAudioProviderException>().having(
            (e) => e.code,
            'code',
            'invalid_catalog',
          ),
        ),
      );
    });

    test('HTTP failure does not expose body', () async {
      final provider = Mp3QuranAudioProvider(
        client: MockClient((_) async => http.Response('secret body', 503)),
      );
      await expectLater(
        provider.listHafsReciters(),
        throwsA(
          isA<QuranAudioProviderException>()
              .having((e) => e.statusCode, 'status', 503)
              .having((e) => e.toString(), 'text', isNot(contains('secret'))),
        ),
      );
    });

    test('network failure is mapped without leaking the cause', () async {
      final provider = Mp3QuranAudioProvider(
        client: MockClient(
          (_) async => throw StateError('private network detail'),
        ),
      );
      await expectLater(
        provider.listHafsReciters(),
        throwsA(
          isA<QuranAudioProviderException>()
              .having((error) => error.code, 'code', 'network')
              .having(
                (error) => error.toString(),
                'text',
                isNot(contains('private')),
              ),
        ),
      );
    });

    test(
      'timing service failure keeps full-surah streaming available',
      () async {
        final provider = Mp3QuranAudioProvider(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/reciters')) {
              return _json(_catalog);
            }
            return http.Response('temporarily unavailable', 503);
          }),
        );

        final catalog = await provider.listHafsReciters();

        expect(catalog, hasLength(1));
        expect(catalog.single.moshafs.single.timingReadId, isNull);
        expect(
          catalog.single.moshafs.single.capabilities,
          isNot(contains(AudioCapability.ayahTiming)),
        );
      },
    );

    test('unknown reciter and unavailable surah fail closed', () {
      final provider = Mp3QuranAudioProvider(
        client: MockClient((_) async => _json({})),
      );
      final catalog = Mp3QuranParser.parseHafsCatalog(_catalog, _reads);
      expect(
        () => provider.trackFor(
          catalog: catalog,
          reciterId: 999,
          moshafId: 10917,
          surahNumber: 1,
        ),
        throwsA(
          isA<QuranAudioProviderException>().having(
            (e) => e.code,
            'code',
            'unknown_reciter',
          ),
        ),
      );
      expect(
        () => provider.trackFor(
          catalog: catalog,
          reciterId: 21196,
          moshafId: 10917,
          surahNumber: 3,
        ),
        throwsA(
          isA<QuranAudioProviderException>().having(
            (e) => e.code,
            'code',
            'unknown_surah',
          ),
        ),
      );
    });
  });
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

const _catalog = {
  'reciters': [
    {
      'id': 21196,
      'name': 'Alijon Qori',
      'moshaf': [
        {
          'id': 10917,
          'name': "Rewayat Hafs A'n Assem - Murattal",
          'rewaya_id': 1,
          'server':
              'https://server16.mp3quran.net/Alijon/Rewayat-Hafs-A-n-Assem/',
          'surah_total': 3,
          'surah_list': '1,2,114',
        },
        {
          'id': 20000,
          'name': "Rewayat Warsh A'n Nafi'",
          'rewaya_id': 2,
          'server': 'https://server.example/warsh/',
          'surah_total': 1,
          'surah_list': '1',
        },
      ],
    },
  ],
};
const _reads = [
  {
    'id': 41,
    'name': 'Alijon Qori',
    'rewaya': 'Hafs',
    'folder_url':
        'https://server16.mp3quran.net/Alijon/Rewayat-Hafs-A-n-Assem/',
    'soar_count': 3,
  },
];
