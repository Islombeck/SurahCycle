import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/widgets/widget_deep_link.dart';

void main() {
  test('parses every supported widget destination', () {
    expect(
      WidgetDeepLink.tryParse('murajaah://app/home'),
      const WidgetHomeDeepLink(),
    );
    expect(
      WidgetDeepLink.tryParse('murajaah://app/learning'),
      const WidgetLearningRootDeepLink(),
    );
    expect(
      WidgetDeepLink.tryParse('murajaah://app/surah/2'),
      WidgetSurahDeepLink(surahId: '2'),
    );
    expect(
      WidgetDeepLink.tryParse('murajaah://app/surah/2?part=part-2'),
      WidgetSurahDeepLink(surahId: '2', partId: 'part-2'),
    );
    expect(
      WidgetDeepLink.tryParse('murajaah://app/learning/112'),
      WidgetLearningDeepLink('112'),
    );
  });

  test('builders percent-safe known identifiers', () {
    expect(
      WidgetSurahDeepLink(surahId: 'surah_2', partId: 'part-2').uri.toString(),
      'murajaah://app/surah/surah_2?part=part-2',
    );
  });

  test('domain scheme part IDs with colons round-trip safely', () {
    final original = WidgetSurahDeepLink(
      surahId: '2',
      partId: '550e8400-e29b-41d4-a716-446655440000:part:1',
    );

    expect(WidgetDeepLink.parse(original.uri), original);
    expect(WidgetDeepLink.tryParse(original.uri.toString()), original);
  });

  test('rejects malformed, ambiguous, and out-of-contract links', () {
    for (final source in <String>[
      '',
      'https://surah/2',
      'murajaah://unknown',
      'murajaah://home',
      'murajaah://surah/2',
      'murajaah://app',
      'murajaah://app/home/',
      'murajaah://app/home?extra=1',
      'murajaah://app/surah',
      'murajaah://app/surah/2/',
      'murajaah://app/surah/2/extra',
      'murajaah://app/surah/2?extra=1',
      'murajaah://app/surah/2?part=a&part=b',
      'murajaah://app/surah/2?part=',
      'murajaah://app/learning/112?part=x',
      'murajaah://app/learning/112#fragment',
      'murajaah://user@app/learning/112',
      'murajaah://app:42/learning/112',
    ]) {
      expect(WidgetDeepLink.tryParse(source), isNull, reason: source);
    }
  });
}
