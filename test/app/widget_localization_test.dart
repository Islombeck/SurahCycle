import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/widget_localization.dart';
import 'package:murajaah/core/domain/domain.dart';

void main() {
  test('manual and automatic widget prayer headers are explicit', () {
    final en = WidgetLocalization.forLanguageCode('en');

    expect(
      en.prayerContextLabel(
        PrayerContext(prayerType: PrayerType.witr),
        isAutomatic: false,
      ),
      'Manual: Witr · Rotation',
    );
    expect(
      en.prayerContextLabel(
        PrayerContext(prayerType: PrayerType.asr),
        isAutomatic: true,
        startsAt: '17:10',
        endsAt: '19:12',
      ),
      'Asr · 17:10–19:12 · Rotation',
    );
    expect(
      en.prayerContextLabel(null, isAutomatic: true),
      'Choose a prayer in Murajaah',
    );
  });

  test('widget prayer headers are available for every supported locale', () {
    for (final language in <String>['ru', 'en', 'uz']) {
      final localization = WidgetLocalization.forLanguageCode(language);
      final label = localization.prayerContextLabel(
        PrayerContext(prayerType: PrayerType.fajr),
        isAutomatic: true,
        startsAt: '04:17',
      );

      expect(localization.languageCode, language);
      expect(label, contains('04:17'));
      expect(label, isNot(contains('null')));
    }
  });
}
