import 'package:flutter/material.dart';

import '../application/quran_reading_repository.dart';
import '../domain/quran_display_preferences.dart';
import 'tanzil_transliteration_text.dart';

/// Keeps Arabic, transliteration and translation aligned per ayah.
///
/// This is deliberately one structured widget instead of three independent
/// lists, so cumulative learning stages cannot accidentally pair content from
/// different Quran coordinates.
final class QuranAyahLayers extends StatelessWidget {
  const QuranAyahLayers({
    required this.ayah,
    required this.preferences,
    this.translationFallback,
    this.transliterationFallback,
    this.compact = false,
    this.keyPrefix = 'quran',
    super.key,
  });

  final QuranReadingAyah ayah;
  final QuranDisplayPreferences preferences;
  final String? translationFallback;
  final String? transliterationFallback;
  final bool compact;
  final String keyPrefix;

  String get _coordinate => '${ayah.surahNumber}-${ayah.ayahNumber}';

  @override
  Widget build(BuildContext context) {
    final showArabic = preferences.showArabic;
    final showTransliteration =
        preferences.showTransliteration &&
        (ayah.transliteration != null || transliterationFallback != null);
    final showTranslation =
        preferences.showTranslation &&
        (ayah.translation != null || translationFallback != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showArabic)
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              ayah.arabicText,
              key: ValueKey<String>('$keyPrefix-arabic-$_coordinate'),
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
              textAlign: TextAlign.right,
              style:
                  (compact
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineSmall)
                      ?.copyWith(height: compact ? 1.7 : 1.8),
            ),
          ),
        if (showTransliteration) ...<Widget>[
          if (showArabic) SizedBox(height: compact ? 8 : 10),
          if (ayah.transliteration case final exactText?)
            TanzilTransliterationText(
              exactText,
              key: ValueKey<String>('$keyPrefix-transliteration-$_coordinate'),
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            )
          else
            Text(
              transliterationFallback!,
              key: ValueKey<String>(
                '$keyPrefix-transliteration-unavailable-$_coordinate',
              ),
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (showTranslation) ...<Widget>[
          if (showArabic || showTransliteration)
            SizedBox(height: compact ? 6 : 10),
          Text(
            ayah.translation ?? translationFallback!,
            key: ValueKey<String>('$keyPrefix-translation-$_coordinate'),
            maxLines: compact ? 1 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
            style: compact
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
