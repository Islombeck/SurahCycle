import '../domain/quran_models.dart';

final class QuranContentCacheKey {
  factory QuranContentCacheKey({
    required String providerId,
    required String translationKey,
    required String version,
    required int surahNumber,
  }) {
    if (providerId.isEmpty || translationKey.isEmpty || version.isEmpty) {
      throw ArgumentError('Quran cache identity fields must not be empty.');
    }
    if (surahNumber <= 0) {
      throw ArgumentError.value(
        surahNumber,
        'surahNumber',
        'Must be positive.',
      );
    }
    return QuranContentCacheKey._(
      providerId: providerId,
      translationKey: translationKey,
      version: version,
      surahNumber: surahNumber,
    );
  }

  const QuranContentCacheKey._({
    required this.providerId,
    required this.translationKey,
    required this.version,
    required this.surahNumber,
  });

  final String providerId;
  final String translationKey;
  final String version;
  final int surahNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranContentCacheKey &&
          providerId == other.providerId &&
          translationKey == other.translationKey &&
          version == other.version &&
          surahNumber == other.surahNumber;

  @override
  int get hashCode =>
      Object.hash(providerId, translationKey, version, surahNumber);
}

/// Exact-value cache boundary. Implementations must not normalize, translate,
/// concatenate, or otherwise alter any provider string.
abstract interface class QuranContentCache {
  Future<QuranSurahContent?> readSurah(QuranContentCacheKey key);

  Future<void> writeSurah(QuranContentCacheKey key, QuranSurahContent content);
}
