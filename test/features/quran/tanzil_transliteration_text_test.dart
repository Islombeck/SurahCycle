import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/presentation/tanzil_transliteration_text.dart';

void main() {
  test('markup rendering is derived without rewriting source text', () {
    const source =
        'Bismi All<u>a</U>hi a<b>l</B>rra<u>h</U>m<i>a</i>ni '
        '<strong>test</strong>';
    final spans = TanzilTransliterationMarkup.parse(source);
    final root = TextSpan(children: spans);

    expect(root.toPlainText(), 'Bismi Allahi alrrahmani test');
    expect(source, contains('<u>a</U>'));
    expect(
      spans.whereType<TextSpan>().any(
        (span) => span.style?.decoration == TextDecoration.underline,
      ),
      isTrue,
    );
    expect(
      spans.whereType<TextSpan>().any(
        (span) => span.style?.fontWeight == FontWeight.w700,
      ),
      isTrue,
    );
    expect(
      spans.whereType<TextSpan>().any(
        (span) => span.style?.fontStyle == FontStyle.italic,
      ),
      isTrue,
    );
    expect(
      TanzilTransliterationMarkup.toPlainText(source),
      'Bismi Allahi alrrahmani test',
    );
    expect(
      TanzilTransliterationMarkup.toPlainText('keep <unknown>tag</unknown>'),
      'keep <unknown>tag</unknown>',
    );
  });

  testWidgets('transliteration is LTR and supports compact ellipsis', (
    tester,
  ) async {
    const source = 'Bismi All<u>a</U>hi alrraheemi';
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 80,
          child: TanzilTransliterationText(
            source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).last);
    expect(richText.textDirection, TextDirection.ltr);
    expect(richText.maxLines, 1);
    expect(richText.overflow, TextOverflow.ellipsis);
    expect(richText.text.toPlainText(), 'Bismi Allahi alrraheemi');
    expect(tester.takeException(), isNull);
  });
}
