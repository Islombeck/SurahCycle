import '../../domain/quran_models.dart';
import 'quran_enc_provider.dart';

part 'known_official_quran_enc_translations.g.dart';

/// A QuranEnc translation that is currently omitted from the public RU list,
/// but whose key, identity, public endpoint, and exact content were verified
/// against official QuranEnc surfaces.
///
/// [technicalRevision] is deliberately not presented as an upstream version.
/// It pins the exact API corpus observed on [lastVerifiedDateIso8601].
final class KnownOfficialQuranEncTranslation {
  const KnownOfficialQuranEncTranslation({
    required this.key,
    required this.languageCode,
    required this.title,
    required this.translatorOrPublisher,
    required this.expectedSource,
    required this.officialVersion,
    required this.lastVerifiedDateIso8601,
    required this.provenance,
    required this.technicalRevision,
    required this.corpusSha256,
  });

  final String key;
  final String languageCode;
  final String title;
  final String translatorOrPublisher;
  final String expectedSource;

  /// Version displayed by QuranEnc's official catalog page at audit time.
  /// The current direct API response does not repeat this value.
  final String? officialVersion;

  final String lastVerifiedDateIso8601;
  final Uri provenance;

  /// App-owned content identity, never an inferred QuranEnc version number.
  final String technicalRevision;
  final String corpusSha256;

  DateTime get lastVerifiedAtUtc =>
      DateTime.parse('${lastVerifiedDateIso8601}T00:00:00Z');

  QuranTranslation toTranslation() => QuranTranslation(
    source: expectedSource,
    key: key,
    languageCode: languageCode,
    version: technicalRevision,
    title: title,
    description:
        '$translatorOrPublisher. '
        '${officialVersion == null ? 'No upstream version was confirmed.' : 'Official QuranEnc identity page version observed during audit: $officialVersion.'} '
        'Runtime-verified direct QuranEnc fallback; '
        'the revision is a Murajaah integrity pin, not an upstream version.',
    direction: 'ltr',
  );

  String expectedSurahSha256(int surahNumber) {
    if (surahNumber < 1 || surahNumber > 114) {
      throw RangeError.range(surahNumber, 1, 114, 'surahNumber');
    }
    final hashes = _knownQuranEncSurahSha256[key];
    if (hashes == null || hashes.length != 114) {
      throw StateError('Known QuranEnc integrity manifest is incomplete.');
    }
    return hashes[surahNumber - 1];
  }
}

/// Audited direct keys only. This registry is discovery metadata, not a
/// default or theological recommendation. A provider must runtime-revalidate
/// a candidate before returning it as available.
abstract final class KnownOfficialQuranEncTranslations {
  static const String verificationMethod =
      'All 114 documented public sura endpoints were checked for exact '
      'ordered coordinates and 6,236 total ayahs. Translation and footnote '
      'strings were hashed verbatim with coordinate framing.';

  static final List<KnownOfficialQuranEncTranslation>
  russian = List<KnownOfficialQuranEncTranslation>.unmodifiable(
    <KnownOfficialQuranEncTranslation>[
      KnownOfficialQuranEncTranslation(
        key: 'russian_rwwad',
        languageCode: 'ru',
        title: 'Russian Translation - Rowwad Translation Center',
        translatorOrPublisher: 'Rowwad Translation Center',
        expectedSource: QuranEncProvider.sourceId,
        officialVersion: 'V1.0.1',
        lastVerifiedDateIso8601: '2026-08-25',
        provenance: Uri.parse(
          'https://old.quranenc.com/en/browse/russian_rwwad/1',
        ),
        technicalRevision:
            'quranenc-direct-2026-08-25-sha256-'
            'c58986174045d030df67ec6b8f15ebe2fdeae74c092e73a7630c08acf742542a',
        corpusSha256:
            'c58986174045d030df67ec6b8f15ebe2fdeae74c092e73a7630c08acf742542a',
      ),
      KnownOfficialQuranEncTranslation(
        key: 'russian_aboadel',
        languageCode: 'ru',
        title: 'Russian Translation - Abu Adel',
        translatorOrPublisher: 'Abu Adel',
        expectedSource: QuranEncProvider.sourceId,
        officialVersion: 'V1.0.0',
        lastVerifiedDateIso8601: '2026-08-25',
        provenance: Uri.parse(
          'https://old.quranenc.com/en/browse/russian_aboadel/1',
        ),
        technicalRevision:
            'quranenc-direct-2026-08-25-sha256-'
            'ac9387c90b5cf90939f0a527702f4d1c5d025269cf705e2f6b2594b4f803a3ff',
        corpusSha256:
            'ac9387c90b5cf90939f0a527702f4d1c5d025269cf705e2f6b2594b4f803a3ff',
      ),
    ],
  );

  static KnownOfficialQuranEncTranslation? byKey(String key) {
    for (final translation in russian) {
      if (translation.key == key) return translation;
    }
    return null;
  }
}
