/// Controls presentation only. Disabling a layer never deletes its data.
final class QuranDisplayPreferences {
  const QuranDisplayPreferences({
    this.showArabic = true,
    this.showTransliteration = true,
    this.showTranslation = true,
  });

  static const QuranDisplayPreferences defaults = QuranDisplayPreferences();

  final bool showArabic;
  final bool showTransliteration;
  final bool showTranslation;

  QuranDisplayPreferences copyWith({
    bool? showArabic,
    bool? showTransliteration,
    bool? showTranslation,
  }) => QuranDisplayPreferences(
    showArabic: showArabic ?? this.showArabic,
    showTransliteration: showTransliteration ?? this.showTransliteration,
    showTranslation: showTranslation ?? this.showTranslation,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranDisplayPreferences &&
          showArabic == other.showArabic &&
          showTransliteration == other.showTransliteration &&
          showTranslation == other.showTranslation;

  @override
  int get hashCode =>
      Object.hash(showArabic, showTransliteration, showTranslation);
}
