import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/quran_audio_models.dart';

final class Mp3QuranAudioProvider implements QuranAudioProvider {
  Mp3QuranAudioProvider({required this.client, Uri? apiRoot})
    : apiRoot = apiRoot ?? Uri.https('www.mp3quran.net', '/api/v3/');

  static const sourceName = 'MP3Quran.net';
  static const sourceUrl = 'https://mp3quran.net/';
  static const apiDocumentationUrl = 'https://mp3quran.net/api';
  static const int hafsRiwayaId = 1;
  static const Duration timeout = Duration(seconds: 15);
  static const int maxCatalogBytes = 4 * 1024 * 1024;
  static const int maxTimingBytes = 1024 * 1024;

  final http.Client client;
  final Uri apiRoot;

  @override
  Future<List<QuranReciter>> listHafsReciters({
    String languageCode = 'eng',
  }) async {
    final reciters = await _getJson(
      apiRoot.resolve(
        'reciters?language=${Uri.encodeQueryComponent(languageCode)}',
      ),
      maxCatalogBytes,
    );
    Object? timingReads = const <Object?>[];
    try {
      timingReads = await _getJson(
        apiRoot.resolve('ayat_timing/reads'),
        maxCatalogBytes,
      );
    } on QuranAudioProviderException {
      // Timing is an optional capability. A temporary timing-service failure
      // must not remove verified full-surah streaming from the catalog.
    }
    return Mp3QuranParser.parseHafsCatalog(reciters, timingReads);
  }

  @override
  Future<List<AyahTiming>> loadAyahTimings({
    required int readId,
    required int surahNumber,
  }) async {
    if (readId <= 0 || surahNumber < 1 || surahNumber > 114) {
      throw const QuranAudioProviderException(
        'invalid_request',
        'Read and surah identifiers are invalid.',
      );
    }
    final decoded = await _getJson(
      apiRoot.resolve('ayat_timing?surah=$surahNumber&read=$readId'),
      maxTimingBytes,
    );
    return Mp3QuranParser.parseTimings(decoded);
  }

  @override
  QuranAudioTrack trackFor({
    required List<QuranReciter> catalog,
    required int reciterId,
    required int moshafId,
    required int surahNumber,
  }) {
    final reciter = catalog.where((value) => value.id == reciterId).firstOrNull;
    if (reciter == null) {
      throw const QuranAudioProviderException(
        'unknown_reciter',
        'The selected reciter is absent from the current catalog.',
      );
    }
    final moshaf = reciter.moshafs
        .where((value) => value.id == moshafId)
        .firstOrNull;
    if (moshaf == null) {
      throw const QuranAudioProviderException(
        'unknown_moshaf',
        'The selected moshaf is absent from the current catalog.',
      );
    }
    if (!moshaf.hasSurah(surahNumber)) {
      throw const QuranAudioProviderException(
        'unknown_surah',
        'The selected recording does not include this surah.',
      );
    }
    final filename = '${surahNumber.toString().padLeft(3, '0')}.mp3';
    return QuranAudioTrack(
      reciterId: reciter.id,
      reciterName: reciter.displayName,
      moshaf: moshaf,
      surahNumber: surahNumber,
      uri: moshaf.server.resolve(filename),
    );
  }

  Future<Object?> _getJson(Uri uri, int maxBytes) async {
    late http.Response response;
    try {
      response = await client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(timeout);
    } on Object catch (error) {
      throw QuranAudioProviderException(
        'network',
        'Could not reach the Quran audio provider.',
        cause: error,
      );
    }
    if (response.statusCode != 200) {
      throw QuranAudioProviderException(
        'http',
        'The Quran audio provider returned a non-success status.',
        statusCode: response.statusCode,
      );
    }
    final contentType = response.headers['content-type']?.toLowerCase();
    if (contentType == null || !contentType.contains('application/json')) {
      throw const QuranAudioProviderException(
        'content_type',
        'The Quran audio provider did not return JSON.',
      );
    }
    if (response.bodyBytes.length > maxBytes) {
      throw const QuranAudioProviderException(
        'response_too_large',
        'The Quran audio response exceeded the safe limit.',
      );
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on Object catch (error) {
      throw QuranAudioProviderException(
        'invalid_json',
        'The Quran audio provider returned invalid JSON.',
        cause: error,
      );
    }
  }
}

abstract final class Mp3QuranParser {
  static List<QuranReciter> parseHafsCatalog(
    Object? recitersPayload,
    Object? timingReadsPayload,
  ) {
    try {
      final root = _map(recitersPayload);
      final timingByFolder = <String, int>{};
      for (final item in _list(timingReadsPayload)) {
        final row = _map(item);
        final folder = _httpsUri(row['folder_url']);
        timingByFolder[_normalizedFolder(folder)] = _integer(row['id']);
      }
      final result = <QuranReciter>[];
      for (final value in _list(root['reciters'])) {
        final row = _map(value);
        final moshafs = <QuranMoshaf>[];
        for (final moshafValue in _list(row['moshaf'])) {
          final item = _map(moshafValue);
          final riwayaId = _integer(item['rewaya_id']);
          if (riwayaId != Mp3QuranAudioProvider.hafsRiwayaId) continue;
          final server = _httpsUri(item['server']);
          final surahs = _surahList(item['surah_list']);
          if (_integer(item['surah_total']) != surahs.length) {
            throw const FormatException('surah_total mismatch');
          }
          moshafs.add(
            QuranMoshaf(
              id: _integer(item['id']),
              name: _string(item['name']),
              riwayaId: riwayaId,
              riwayaName: _riwayaName(_string(item['name'])),
              server: server,
              availableSurahs: surahs,
              timingReadId: timingByFolder[_normalizedFolder(server)],
            ),
          );
        }
        if (moshafs.isNotEmpty) {
          result.add(
            QuranReciter(
              id: _integer(row['id']),
              displayName: _string(row['name']),
              moshafs: List.unmodifiable(moshafs),
            ),
          );
        }
      }
      result.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return List.unmodifiable(result);
    } on QuranAudioProviderException {
      rethrow;
    } on Object catch (error) {
      throw QuranAudioProviderException(
        'invalid_catalog',
        'The Quran audio catalog failed validation.',
        cause: error,
      );
    }
  }

  static List<AyahTiming> parseTimings(Object? payload) {
    try {
      final result = <AyahTiming>[];
      var previousEnd = Duration.zero;
      for (final value in _list(payload)) {
        final row = _map(value);
        final ayah = _integer(row['ayah']);
        if (ayah == 0) continue;
        final timing = AyahTiming(
          ayahNumber: ayah,
          start: Duration(milliseconds: _integer(row['start_time'])),
          end: Duration(milliseconds: _integer(row['end_time'])),
        );
        if (timing.start < previousEnd) {
          throw const FormatException('overlapping timings');
        }
        previousEnd = timing.end;
        result.add(timing);
      }
      if (result.isEmpty) throw const FormatException('empty timing');
      return List.unmodifiable(result);
    } on Object catch (error) {
      throw QuranAudioProviderException(
        'invalid_timing',
        'Ayah timing failed validation.',
        cause: error,
      );
    }
  }

  static String _riwayaName(String moshafName) =>
      moshafName.split(' - ').first.trim();
  static String _normalizedFolder(Uri value) =>
      '${value.scheme}://${value.host}${value.path.endsWith('/') ? value.path : '${value.path}/'}'
          .toLowerCase();
  static Map<String, Object?> _map(Object? value) =>
      value is Map<String, Object?>
      ? value
      : throw const FormatException('expected object');
  static List<Object?> _list(Object? value) => value is List<Object?>
      ? value
      : throw const FormatException('expected list');
  static int _integer(Object? value) => value is int
      ? value
      : value is String
      ? int.parse(value)
      : throw const FormatException('expected integer');
  static String _string(Object? value) =>
      value is String && value.trim().isNotEmpty
      ? value.trim()
      : throw const FormatException('expected string');
  static Uri _httpsUri(Object? value) {
    final uri = Uri.parse(_string(value));
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('expected HTTPS URI');
    }
    return uri;
  }

  static Set<int> _surahList(Object? value) {
    final result = _string(value).split(',').map(int.parse).toSet();
    if (result.isEmpty || result.any((number) => number < 1 || number > 114)) {
      throw const FormatException('invalid surah list');
    }
    return result;
  }
}
