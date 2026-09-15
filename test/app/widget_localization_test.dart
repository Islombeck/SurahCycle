import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/widget_localization.dart';
import 'package:murajaah/core/data/data.dart';
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
      'Choose a prayer in SalahCycle',
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

  test('followed-imam completion is never rendered as missing slots', () {
    final completedAt = DateTime.utc(2026, 9, 4, 9);
    final snapshot = PrayerRoutineSessionSnapshot(
      session: PrayerSession(
        id: 'jumuah-session',
        context: PrayerContext(prayerType: PrayerType.jumuah),
        startedAtUtc: DateTime.utc(2026, 9, 4, 8),
      ),
      localDate: LocalDate(2026, 9, 4),
      parts: <PrayerSessionPartProgress>[
        PrayerSessionPartProgress(
          part: PrayerSessionPart(
            id: 'jumuah-session:fard',
            prayerSessionId: 'jumuah-session',
            sourceTemplatePartId: 'jumuah-fard',
            templateRevision: 2,
            stableKey: 'fard',
            orderIndex: 0,
            label: 'fard',
            kind: PrayerRoutinePartKind.fard,
            rakaatCount: 2,
            requiredSurahSlots: 2,
            allowsFollowingImam: true,
            completionMode: PrayerPartCompletionMode.followedImam,
            completedAtUtc: completedAt,
          ),
          occupiedSlotIndexes: const <int>{},
        ),
      ],
    );

    final projection = WidgetLocalization.forLanguageCode('en')
        .prayerRoutineProjection(
          PrayerContext(prayerType: PrayerType.jumuah),
          snapshot,
        );

    expect(projection!.currentPartLabel, 'Prayer routine complete');
    expect(projection.slotProgressLabel, 'Completed by following the imam');
    expect(projection.nextSlotIndex, isNull);
  });
}
