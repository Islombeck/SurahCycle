enum QuranTransliterationScript { latin, cyrillic }

enum QuranTransliterationProfileAvailability { bundledOffline, unavailable }

/// Selectable metadata for one transliteration source.
///
/// A profile describes source availability only. It never converts, rewrites,
/// or normalizes Quran text.
final class QuranTransliterationProfile {
  const QuranTransliterationProfile._({
    required this.id,
    required this.displayName,
    required this.script,
    required this.languageCode,
    required this.source,
    required this.version,
    required this.attribution,
    required this.availability,
    required this.unavailabilityExplanation,
  });

  final String id;
  final String displayName;
  final QuranTransliterationScript script;
  final String? languageCode;
  final String? source;
  final String? version;
  final String? attribution;
  final QuranTransliterationProfileAvailability availability;

  /// A factual explanation for profiles that cannot be selected.
  final String? unavailabilityExplanation;

  bool get isAvailableOffline =>
      availability == QuranTransliterationProfileAvailability.bundledOffline;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranTransliterationProfile &&
          id == other.id &&
          displayName == other.displayName &&
          script == other.script &&
          languageCode == other.languageCode &&
          source == other.source &&
          version == other.version &&
          attribution == other.attribution &&
          availability == other.availability &&
          unavailabilityExplanation == other.unavailabilityExplanation;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    script,
    languageCode,
    source,
    version,
    attribution,
    availability,
    unavailabilityExplanation,
  );
}

/// Canonical, closed registry of transliteration choices exposed by Murajaah.
final class QuranTransliterationProfileRegistry {
  const QuranTransliterationProfileRegistry();

  static const String tanzilLatinId = 'tanzil.en.transliteration.latin';
  static const String verifiedCyrillicId = 'verified.cyrillic.transliteration';

  static const QuranTransliterationProfile tanzilLatin =
      QuranTransliterationProfile._(
        id: tanzilLatinId,
        displayName: 'Latin — Tanzil',
        script: QuranTransliterationScript.latin,
        languageCode: 'en',
        source: 'tanzil.net',
        version:
            'tanzil-en.transliteration-2010-09-06-sha256-'
            '8c20d95e484534e921cd2e0d2546aab7f5300090c0bd76697095b3ca1db1e01d',
        attribution: 'English Transliteration — source: Tanzil.net',
        availability: QuranTransliterationProfileAvailability.bundledOffline,
        unavailabilityExplanation: null,
      );

  static const QuranTransliterationProfile cyrillicUnavailable =
      QuranTransliterationProfile._(
        id: verifiedCyrillicId,
        displayName: 'Cyrillic',
        script: QuranTransliterationScript.cyrillic,
        languageCode: null,
        source: null,
        version: null,
        attribution: null,
        availability: QuranTransliterationProfileAvailability.unavailable,
        unavailabilityExplanation:
            'No verified Cyrillic Quran transliteration dataset is bundled. '
            'Murajaah does not automatically convert the exact Tanzil Latin '
            'text because generated transliteration could alter pronunciation.',
      );

  static const List<QuranTransliterationProfile> profiles =
      <QuranTransliterationProfile>[tanzilLatin, cyrillicUnavailable];

  QuranTransliterationProfile get defaultProfile => tanzilLatin;

  QuranTransliterationProfile? byId(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  QuranTransliterationProfile requireById(String id) {
    final profile = byId(id);
    if (profile == null) {
      throw StateError('Unknown Quran transliteration profile "$id".');
    }
    return profile;
  }
}
