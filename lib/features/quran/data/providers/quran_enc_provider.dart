import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/quran_models.dart';
import '../quran_content_provider.dart';

DateTime _systemUtcNow() => DateTime.now().toUtc();

/// Adapter for QuranEnc's documented public translation endpoints.
///
/// The endpoint currently also emits an `arabic_text` field. This adapter
/// deliberately ignores it: Sprint 1 has approved QuranEnc only as a
/// translation source, so Arabic availability remains explicit and false.
final class QuranEncProvider implements QuranContentProvider {
  QuranEncProvider({
    required http.Client client,
    Uri? baseUri,
    DateTime Function()? nowUtc,
    this.requestTimeout = const Duration(seconds: 20),
    this.maxResponseBytes = 8 * 1024 * 1024,
  }) : _client = client, // ignore: prefer_initializing_formals
       _baseUri = baseUri ?? Uri.parse('https://quranenc.com/api/v1/'),
       _nowUtc = nowUtc ?? _systemUtcNow {
    if (_baseUri.scheme != 'https' || !_baseUri.hasAuthority) {
      throw ArgumentError.value(
        _baseUri,
        'baseUri',
        'QuranEnc transport must use an absolute HTTPS URI.',
      );
    }
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be positive.',
      );
    }
    if (maxResponseBytes <= 0) {
      throw ArgumentError.value(
        maxResponseBytes,
        'maxResponseBytes',
        'Must be positive.',
      );
    }
  }

  static const String sourceId = 'quranenc.com';
  static const String attribution = 'QuranEnc.com';
  static const String termsUrl = 'https://quranenc.com/en/home/api';
  static const String licenseUsageInformation =
      'QuranEnc content must be reproduced without modification, with the '
      'publisher, QuranEnc.com source, version, and transcript information '
      'retained; notes must be reported to QuranEnc.com, updates must use the '
      'latest reviewed version, and inappropriate advertising is prohibited. '
      'Terms: $termsUrl';

  final http.Client _client;
  final Uri _baseUri;
  final DateTime Function() _nowUtc;
  final Duration requestTimeout;
  final int maxResponseBytes;

  @override
  String get providerId => sourceId;

  @override
  QuranContentCapabilities get capabilities => const QuranContentCapabilities(
    hasSurahMetadata: false,
    hasArabicText: false,
    hasFullTranslation: true,
    hasWordTranslation: false,
  );

  @override
  Future<List<QuranTranslation>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  }) async {
    _validateOptionalPathValue(languageCode, 'languageCode');
    _validateOptionalPathValue(
      localizationLanguageCode,
      'localizationLanguageCode',
    );
    final languageSuffix = languageCode == null
        ? ''
        : '/${Uri.encodeComponent(languageCode)}';
    var uri = _baseUri.resolve('translations/list$languageSuffix');
    if (localizationLanguageCode != null) {
      uri = uri.replace(
        queryParameters: <String, String>{
          'localization': localizationLanguageCode,
        },
      );
    }

    final root = await _getObject(uri);
    final rawTranslations = root['translations'];
    if (rawTranslations is! List<Object?>) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_translations_missing',
      );
    }

    final translations = <QuranTranslation>[];
    final keys = <String>{};
    for (final rawTranslation in rawTranslations) {
      final item = _asStringMap(
        rawTranslation,
        code: 'quranenc_translation_invalid',
      );
      final key = _requiredString(
        item,
        'key',
        code: 'quranenc_translation_key_invalid',
      );
      if (!keys.add(key)) {
        throw const QuranProviderException(
          failure: QuranProviderFailure.invalidResponse,
          code: 'quranenc_translation_key_duplicate',
        );
      }
      final entryLanguageCode = _requiredString(
        item,
        'language_iso_code',
        code: 'quranenc_translation_language_invalid',
      );
      if (languageCode != null && entryLanguageCode != languageCode) {
        throw const QuranProviderException(
          failure: QuranProviderFailure.invalidResponse,
          code: 'quranenc_translation_language_mismatch',
        );
      }
      translations.add(
        QuranTranslation(
          source: sourceId,
          key: key,
          languageCode: entryLanguageCode,
          version: _requiredString(
            item,
            'version',
            code: 'quranenc_translation_version_invalid',
          ),
          title: _requiredString(
            item,
            'title',
            code: 'quranenc_translation_title_invalid',
          ),
          description: _optionalString(
            item,
            'description',
            code: 'quranenc_translation_description_invalid',
          ),
          direction: _optionalString(
            item,
            'direction',
            code: 'quranenc_translation_direction_invalid',
          ),
          lastUpdateEpochSeconds: _optionalInteger(
            item,
            'last_update',
            code: 'quranenc_translation_last_update_invalid',
          ),
        ),
      );
    }
    return List<QuranTranslation>.unmodifiable(translations);
  }

  @override
  Future<QuranSurahContent> fetchSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
  }) async {
    if (translation.source != sourceId) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.rejectedRequest,
        code: 'quranenc_translation_source_mismatch',
      );
    }
    if (translation.key.isEmpty || translation.version.isEmpty) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.rejectedRequest,
        code: 'quranenc_translation_identity_missing',
      );
    }
    if (surahNumber <= 0) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.rejectedRequest,
        code: 'quranenc_surah_number_invalid',
      );
    }

    final uri = _baseUri.resolve(
      'translation/sura/${Uri.encodeComponent(translation.key)}/$surahNumber',
    );
    final root = await _getObject(uri);
    final rawAyahs = root['result'];
    if (rawAyahs is! List<Object?> || rawAyahs.isEmpty) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_surah_result_invalid',
      );
    }

    final ayahs = <Ayah>[];
    final ayahNumbers = <int>{};
    for (final rawAyah in rawAyahs) {
      final item = _asStringMap(rawAyah, code: 'quranenc_ayah_invalid');
      final responseSurahNumber = _requiredInteger(
        item,
        'sura',
        code: 'quranenc_ayah_surah_invalid',
      );
      final ayahNumber = _requiredInteger(
        item,
        'aya',
        code: 'quranenc_ayah_number_invalid',
      );
      if (responseSurahNumber != surahNumber ||
          ayahNumber <= 0 ||
          !ayahNumbers.add(ayahNumber)) {
        throw const QuranProviderException(
          failure: QuranProviderFailure.invalidResponse,
          code: 'quranenc_ayah_coordinates_invalid',
        );
      }
      final exactTranslation = _requiredString(
        item,
        'translation',
        code: 'quranenc_ayah_translation_invalid',
      );
      final exactFootnotes = _optionalString(
        item,
        'footnotes',
        code: 'quranenc_ayah_footnotes_invalid',
      );

      ayahs.add(
        Ayah(
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
          // `arabic_text`, if present in the response, is intentionally not
          // accepted from this translation-only adapter.
          arabicText: null,
          fullTranslation: exactTranslation,
          translationSource: sourceId,
          translationVersion: translation.version,
          translationFootnotes: exactFootnotes,
        ),
      );
    }

    final fetchedAt = _nowUtc();
    if (!fetchedAt.isUtc) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_clock_not_utc',
      );
    }
    return QuranSurahContent(
      surahNumber: surahNumber,
      sourceMetadata: QuranSourceMetadata(
        source: sourceId,
        translationKey: translation.key,
        version: translation.version,
        language: translation.languageCode,
        fetchedAtUtc: fetchedAt,
        attribution: attribution,
        licenseUsageInformation: licenseUsageInformation,
        sourceUri: uri,
      ),
      capabilities: capabilities,
      ayahs: ayahs,
    );
  }

  Future<Map<String, Object?>> _getObject(Uri uri) async {
    late http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const QuranProviderException(
        failure: QuranProviderFailure.network,
        code: 'quranenc_request_timeout',
      );
    } on http.ClientException {
      throw const QuranProviderException(
        failure: QuranProviderFailure.network,
        code: 'quranenc_network_failure',
      );
    }

    if (response.statusCode != 200) {
      throw QuranProviderException(
        failure: QuranProviderFailure.rejectedRequest,
        code: 'quranenc_http_status',
        statusCode: response.statusCode,
      );
    }
    if (response.bodyBytes.length > maxResponseBytes) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_response_too_large',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _asStringMap(decoded, code: 'quranenc_json_root_invalid');
    } on QuranProviderException {
      rethrow;
    } on FormatException {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_json_invalid',
      );
    }
  }

  Map<String, Object?> _asStringMap(Object? value, {required String code}) {
    if (value is! Map<Object?, Object?>) {
      throw QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: code,
      );
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw QuranProviderException(
          failure: QuranProviderFailure.invalidResponse,
          code: code,
        );
      }
      result[key] = entry.value;
    }
    return result;
  }

  String _requiredString(
    Map<String, Object?> item,
    String key, {
    required String code,
  }) {
    final value = item[key];
    if (value is! String || value.isEmpty) {
      throw QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: code,
      );
    }
    return value;
  }

  String? _optionalString(
    Map<String, Object?> item,
    String key, {
    required String code,
  }) {
    final value = item[key];
    if (value == null) return null;
    if (value is! String) {
      throw QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: code,
      );
    }
    return value;
  }

  int _requiredInteger(
    Map<String, Object?> item,
    String key, {
    required String code,
  }) {
    final value = _optionalInteger(item, key, code: code);
    if (value == null) {
      throw QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: code,
      );
    }
    return value;
  }

  int? _optionalInteger(
    Map<String, Object?> item,
    String key, {
    required String code,
  }) {
    final value = item[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw QuranProviderException(
      failure: QuranProviderFailure.invalidResponse,
      code: code,
    );
  }

  void _validateOptionalPathValue(String? value, String name) {
    if (value != null && value.isEmpty) {
      throw ArgumentError.value(value, name, 'Must be null or non-empty.');
    }
  }
}
