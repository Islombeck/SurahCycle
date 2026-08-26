import 'package:flutter/material.dart';

/// Renders the small, documented markup vocabulary embedded in Tanzil's
/// `en.transliteration` dataset.
///
/// The repository continues to retain and return [exactSourceText] verbatim.
/// This widget only interprets `<u>`, `<b>`, `<strong>`, and `<i>` while
/// painting; it does not transliterate, rewrite, normalize, or persist a
/// derived string.
final class TanzilTransliterationText extends StatelessWidget {
  const TanzilTransliterationText(
    this.exactSourceText, {
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String exactSourceText;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        TextSpan(
          style: effectiveStyle,
          children: TanzilTransliterationMarkup.parse(exactSourceText),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

abstract final class TanzilTransliterationMarkup {
  static final RegExp _tag = RegExp(
    r'</?(?:u|b|strong|i)>',
    caseSensitive: false,
  );

  /// Converts only presentation tags into spans. Source text is never changed
  /// in storage or in the Quran repository boundary.
  static List<InlineSpan> parse(String exactSourceText) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    var underlineDepth = 0;
    var boldDepth = 0;
    var italicDepth = 0;

    void append(String value) {
      if (value.isEmpty) return;
      spans.add(
        TextSpan(
          text: value,
          style: TextStyle(
            decoration: underlineDepth > 0
                ? TextDecoration.underline
                : TextDecoration.none,
            fontWeight: boldDepth > 0 ? FontWeight.w700 : null,
            fontStyle: italicDepth > 0 ? FontStyle.italic : null,
          ),
        ),
      );
    }

    for (final match in _tag.allMatches(exactSourceText)) {
      append(exactSourceText.substring(cursor, match.start));
      final tag = match.group(0)!.toLowerCase();
      final closing = tag.startsWith('</');
      final name = tag.replaceAll(RegExp(r'[</>]'), '');
      switch (name) {
        case 'u':
          underlineDepth = _updatedDepth(underlineDepth, closing: closing);
        case 'b' || 'strong':
          boldDepth = _updatedDepth(boldDepth, closing: closing);
        case 'i':
          italicDepth = _updatedDepth(italicDepth, closing: closing);
      }
      cursor = match.end;
    }
    append(exactSourceText.substring(cursor));
    return List<InlineSpan>.unmodifiable(spans);
  }

  /// Display-only plain text for renderers that cannot consume Flutter spans
  /// (for example a native home widget). The exact provider string remains
  /// available on the domain record and is never overwritten by this value.
  static String toPlainText(String exactSourceText) =>
      exactSourceText.replaceAll(_tag, '');

  static int _updatedDepth(int current, {required bool closing}) {
    if (closing) return current > 0 ? current - 1 : 0;
    return current == 0 ? 1 : current;
  }
}
