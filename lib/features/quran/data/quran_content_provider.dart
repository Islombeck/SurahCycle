import '../domain/quran_models.dart';

enum QuranProviderFailure {
  network,
  invalidResponse,
  rejectedRequest,
  credentialsRequireBackend,
}

/// Provider failures never include response bodies, which may contain Quran
/// content and must not leak into diagnostics.
final class QuranProviderException implements Exception {
  const QuranProviderException({
    required this.failure,
    required this.code,
    this.statusCode,
  });

  final QuranProviderFailure failure;
  final String code;
  final int? statusCode;

  @override
  String toString() => 'QuranProviderException($code)';
}

/// Source adapter contract. Strings returned by an implementation must be
/// provider values preserved verbatim.
abstract interface class QuranContentProvider {
  String get providerId;

  QuranContentCapabilities get capabilities;

  Future<List<QuranTranslation>> listTranslations({
    String? languageCode,
    String? localizationLanguageCode,
  });

  Future<QuranSurahContent> fetchSurahTranslation({
    required QuranTranslation translation,
    required int surahNumber,
  });
}
