import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../domain/quran_models.dart';
import '../quran_content_provider.dart';
import 'known_official_quran_enc_translations.dart';

DateTime _systemUtcNow() => DateTime.now().toUtc();

typedef QuranEncDiagnosticsSink =
    void Function(QuranEncCatalogDiagnostics diagnostics);

void _logQuranEncDiagnostics(QuranEncCatalogDiagnostics diagnostics) {
  developer.log(
    jsonEncode(<String, Object?>{
      'catalogUri': diagnostics.catalogUri.toString(),
      'httpStatus': diagnostics.httpStatus,
      'contentType': diagnostics.contentType,
      'responseByteLength': diagnostics.responseByteLength,
      'parsedTranslationCount': diagnostics.parsedTranslationCount,
      'origin': diagnostics.origin.name,
      'knownProbes': <Object?>[
        for (final probe in diagnostics.knownProbes)
          <String, Object?>{
            'key': probe.key,
            'status': probe.status.name,
            'code': probe.code,
            'httpStatus': probe.httpStatus,
            'responseByteLength': probe.responseByteLength,
            'contentType': probe.contentType,
          },
      ],
    }),
    name: 'murajaah.quranenc.discovery',
  );
}

enum QuranEncDiscoveryOrigin {
  officialCatalog,
  officialCatalogAugmented,
  knownOfficialDirectFallback,
}

enum QuranEncKnownProbeStatus {
  available,
  networkFailure,
  rejectedRequest,
  invalidResponse,
  contentRevisionMismatch,
}

/// Body-free HTTP diagnostics safe for developer logs and support screens.
final class QuranEncCatalogDiagnostics {
  QuranEncCatalogDiagnostics({
    required this.catalogUri,
    required this.httpStatus,
    required this.contentType,
    required this.responseByteLength,
    required this.parsedTranslationCount,
    required this.origin,
    required Iterable<QuranEncKnownTranslationProbe> knownProbes,
  }) : knownProbes = List<QuranEncKnownTranslationProbe>.unmodifiable(
         knownProbes,
       );

  final Uri catalogUri;
  final int httpStatus;
  final String? contentType;
  final int responseByteLength;
  final int parsedTranslationCount;
  final QuranEncDiscoveryOrigin origin;
  final List<QuranEncKnownTranslationProbe> knownProbes;
}

final class QuranEncKnownTranslationProbe {
  const QuranEncKnownTranslationProbe({
    required this.key,
    required this.status,
    required this.code,
    this.httpStatus,
    this.responseByteLength,
    this.contentType,
  });

  final String key;
  final QuranEncKnownProbeStatus status;
  final String code;
  final int? httpStatus;
  final int? responseByteLength;
  final String? contentType;
}

final class QuranEncTranslationDiscovery {
  QuranEncTranslationDiscovery({
    required Iterable<QuranTranslation> translations,
    required this.diagnostics,
  }) : translations = List<QuranTranslation>.unmodifiable(translations);

  final List<QuranTranslation> translations;
  final QuranEncCatalogDiagnostics diagnostics;
}

final class _QuranEncJsonResponse {
  const _QuranEncJsonResponse({
    required this.root,
    required this.statusCode,
    required this.contentType,
    required this.byteLength,
  });

  final Map<String, Object?> root;
  final int statusCode;
  final String? contentType;
  final int byteLength;
}

final class _ParsedQuranEncSurah {
  const _ParsedQuranEncSurah({required this.ayahs, required this.sha256});

  final List<Ayah> ayahs;
  final String sha256;
}

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
    QuranEncDiagnosticsSink? diagnosticsSink,
    this.requestTimeout = const Duration(seconds: 20),
    this.maxResponseBytes = 8 * 1024 * 1024,
  }) : _client = client, // ignore: prefer_initializing_formals
       _baseUri = baseUri ?? Uri.parse('https://quranenc.com/api/v1/'),
       _nowUtc = nowUtc ?? _systemUtcNow,
       _diagnosticsSink = diagnosticsSink ?? _logQuranEncDiagnostics {
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
  final QuranEncDiagnosticsSink _diagnosticsSink;
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
  }) async => (await discoverTranslations(
    languageCode: languageCode,
    localizationLanguageCode: localizationLanguageCode,
  )).translations;

  /// Discovers the normal catalog and runtime-probes only narrowly audited
  /// direct keys that the language-specific policy permits.
  ///
  /// Russian keeps its original failover-only behavior: known keys are probed
  /// only when its catalog is empty. Uzbek catalog results are augmented with
  /// runtime-verified known keys that the current catalog omitted.
  ///
  /// Returning a fallback candidate never selects it. The caller still owns
  /// the explicit user choice. Response bodies and Quran strings are omitted
  /// from [QuranEncCatalogDiagnostics].
  Future<QuranEncTranslationDiscovery> discoverTranslations({
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

    final catalogResponse = await _getObjectResponse(uri);
    final rawTranslations = catalogResponse.root['translations'];
    if (rawTranslations is! List<Object?>) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_translations_missing',
      );
    }

    final translations = <QuranTranslation>[];
    final seenKeys = <String>{};
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
      if (!seenKeys.add(key)) {
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
      final version = _requiredString(
        item,
        'version',
        code: 'quranenc_translation_version_invalid',
      );
      final translation = QuranTranslation(
        source: sourceId,
        key: key,
        languageCode: entryLanguageCode,
        version: version,
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
      );
      final known = KnownOfficialQuranEncTranslations.byKey(key);
      if (known != null) {
        if (known.languageCode != entryLanguageCode) {
          throw const QuranProviderException(
            failure: QuranProviderFailure.invalidResponse,
            code: 'quranenc_known_translation_language_mismatch',
          );
        }
        // Never expose a known theological translation under a revision that
        // has not completed the corpus audit. The direct runtime probe below
        // may still expose the last pinned revision if its hashes are intact.
        if (!known.matchesOfficialVersion(version)) continue;
      }
      keys.add(key);
      translations.add(translation);
    }
    final shouldProbeKnown = switch (languageCode) {
      'ru' => translations.isEmpty,
      'uz' => true,
      _ => false,
    };
    final missingKnown = shouldProbeKnown
        ? KnownOfficialQuranEncTranslations.byLanguage(
            languageCode!,
          ).where((known) => !keys.contains(known.key)).toList(growable: false)
        : const <KnownOfficialQuranEncTranslation>[];
    if (missingKnown.isEmpty) {
      final discovery = QuranEncTranslationDiscovery(
        translations: translations,
        diagnostics: QuranEncCatalogDiagnostics(
          catalogUri: uri,
          httpStatus: catalogResponse.statusCode,
          contentType: catalogResponse.contentType,
          responseByteLength: catalogResponse.byteLength,
          parsedTranslationCount: translations.length,
          origin: QuranEncDiscoveryOrigin.officialCatalog,
          knownProbes: const <QuranEncKnownTranslationProbe>[],
        ),
      );
      _diagnosticsSink(discovery.diagnostics);
      return discovery;
    }

    final probes = await Future.wait(missingKnown.map(_probeKnownTranslation));
    final available = <QuranTranslation>[...translations];
    for (var index = 0; index < probes.length; index += 1) {
      if (probes[index].status == QuranEncKnownProbeStatus.available) {
        available.add(missingKnown[index].toTranslation());
      }
    }
    final discovery = QuranEncTranslationDiscovery(
      translations: available,
      diagnostics: QuranEncCatalogDiagnostics(
        catalogUri: uri,
        httpStatus: catalogResponse.statusCode,
        contentType: catalogResponse.contentType,
        responseByteLength: catalogResponse.byteLength,
        parsedTranslationCount: translations.length,
        origin: translations.isEmpty
            ? QuranEncDiscoveryOrigin.knownOfficialDirectFallback
            : QuranEncDiscoveryOrigin.officialCatalogAugmented,
        knownProbes: probes,
      ),
    );
    _diagnosticsSink(discovery.diagnostics);
    return discovery;
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
    if (surahNumber < 1 || surahNumber > 114) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.rejectedRequest,
        code: 'quranenc_surah_number_invalid',
      );
    }

    final uri = _baseUri.resolve(
      'translation/sura/${Uri.encodeComponent(translation.key)}/$surahNumber',
    );
    final response = await _getObjectResponse(uri);
    final parsed = _parseSurah(
      response.root,
      surahNumber: surahNumber,
      translationVersion: translation.version,
    );
    final known = KnownOfficialQuranEncTranslations.byKey(translation.key);
    final isPinnedDirectRevision = translation.version.startsWith(
      'quranenc-direct-',
    );
    final isPinnedOfficialRevision =
        known?.matchesOfficialVersion(translation.version) ?? false;
    if (known != null || isPinnedDirectRevision) {
      if (known == null ||
          (isPinnedDirectRevision &&
              translation.version != known.technicalRevision) ||
          (!isPinnedDirectRevision && !isPinnedOfficialRevision) ||
          translation.languageCode != known.languageCode ||
          parsed.sha256 != known.expectedSurahSha256(surahNumber)) {
        throw const QuranProviderException(
          failure: QuranProviderFailure.invalidResponse,
          code: 'quranenc_known_content_revision_mismatch',
        );
      }
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
      ayahs: parsed.ayahs,
    );
  }

  Future<QuranEncKnownTranslationProbe> _probeKnownTranslation(
    KnownOfficialQuranEncTranslation translation,
  ) async {
    final uri = _baseUri.resolve(
      'translation/sura/${Uri.encodeComponent(translation.key)}/1',
    );
    try {
      final response = await _getObjectResponse(uri);
      final parsed = _parseSurah(
        response.root,
        surahNumber: 1,
        translationVersion: translation.technicalRevision,
      );
      if (parsed.sha256 != translation.expectedSurahSha256(1)) {
        return QuranEncKnownTranslationProbe(
          key: translation.key,
          status: QuranEncKnownProbeStatus.contentRevisionMismatch,
          code: 'quranenc_known_content_revision_mismatch',
          httpStatus: response.statusCode,
          responseByteLength: response.byteLength,
          contentType: response.contentType,
        );
      }
      return QuranEncKnownTranslationProbe(
        key: translation.key,
        status: QuranEncKnownProbeStatus.available,
        code: 'quranenc_known_translation_available',
        httpStatus: response.statusCode,
        responseByteLength: response.byteLength,
        contentType: response.contentType,
      );
    } on QuranProviderException catch (error) {
      final status = switch (error.failure) {
        QuranProviderFailure.network => QuranEncKnownProbeStatus.networkFailure,
        QuranProviderFailure.rejectedRequest =>
          QuranEncKnownProbeStatus.rejectedRequest,
        QuranProviderFailure.invalidResponse ||
        QuranProviderFailure.credentialsRequireBackend =>
          QuranEncKnownProbeStatus.invalidResponse,
      };
      return QuranEncKnownTranslationProbe(
        key: translation.key,
        status: status,
        code: error.code,
        httpStatus: error.statusCode,
      );
    }
  }

  _ParsedQuranEncSurah _parseSurah(
    Map<String, Object?> root, {
    required int surahNumber,
    required String translationVersion,
  }) {
    final rawAyahs = root['result'];
    if (rawAyahs is! List<Object?> || rawAyahs.isEmpty) {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_surah_result_invalid',
      );
    }

    final ayahs = <Ayah>[];
    final canonical = StringBuffer();
    for (var index = 0; index < rawAyahs.length; index += 1) {
      final item = _asStringMap(rawAyahs[index], code: 'quranenc_ayah_invalid');
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
      if (responseSurahNumber != surahNumber || ayahNumber != index + 1) {
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
      if (_containsHashFramingCharacter(exactTranslation) ||
          (exactFootnotes != null &&
              _containsHashFramingCharacter(exactFootnotes))) {
        throw const QuranProviderException(
          failure: QuranProviderFailure.invalidResponse,
          code: 'quranenc_ayah_framing_character_invalid',
        );
      }

      canonical
        ..write(surahNumber)
        ..write('\u001f')
        ..write(ayahNumber)
        ..write('\u001f')
        ..write(exactTranslation)
        ..write('\u001f')
        ..write(exactFootnotes == null ? '0' : '1$exactFootnotes')
        ..write('\u001e');
      ayahs.add(
        Ayah(
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
          // `arabic_text`, if present, is outside this translation adapter.
          arabicText: null,
          fullTranslation: exactTranslation,
          translationSource: sourceId,
          translationVersion: translationVersion,
          translationFootnotes: exactFootnotes,
        ),
      );
    }
    return _ParsedQuranEncSurah(
      ayahs: List<Ayah>.unmodifiable(ayahs),
      sha256: sha256.convert(utf8.encode(canonical.toString())).toString(),
    );
  }

  bool _containsHashFramingCharacter(String value) =>
      value.contains('\u001f') || value.contains('\u001e');

  Future<_QuranEncJsonResponse> _getObjectResponse(Uri uri) async {
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

    final rawContentType = response.headers['content-type'];
    final contentType = rawContentType?.split(';').first.trim().toLowerCase();
    if (contentType != 'application/json') {
      throw const QuranProviderException(
        failure: QuranProviderFailure.invalidResponse,
        code: 'quranenc_content_type_invalid',
      );
    }

    try {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: false),
      );
      return _QuranEncJsonResponse(
        root: _asStringMap(decoded, code: 'quranenc_json_root_invalid'),
        statusCode: response.statusCode,
        contentType: rawContentType,
        byteLength: response.bodyBytes.length,
      );
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
