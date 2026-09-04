import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/widgets/widgets.dart';

void main() {
  group('PrayerWidgetProjection validation', () {
    test('unavailable requires a non-empty message', () {
      expect(
        () => PrayerWidgetProjection.unavailable(messageLabel: ''),
        throwsArgumentError,
      );
      final projection = PrayerWidgetProjection.unavailable(
        messageLabel: 'Open the app',
      );
      expect(projection.isAvailable, isFalse);
      expect(projection.messageLabel, 'Open the app');
      expect(projection.entries, isEmpty);
      expect(projection.allowsRotationAutoMark, isFalse);
    });

    test('available requires exactly six boundary entries', () {
      expect(
        () => PrayerWidgetProjection.available(
          dateLabel: '2026-09-04',
          regionLabel: 'Tashkent',
          providerLabel: 'Namoz-vaqti.uz',
          entries: <PrayerWidgetTimeEntry>[
            PrayerWidgetTimeEntry(label: 'Fajr', timeLabel: '05:00'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('at most one entry can be current, at most one next', () {
      expect(
        () => PrayerWidgetProjection.available(
          dateLabel: '2026-09-04',
          regionLabel: 'Tashkent',
          providerLabel: 'Namoz-vaqti.uz',
          entries:
              _sixEntries(currentIndex: 0, nextIndex: 2).map((entry) {
                  return entry.isCurrent
                      ? PrayerWidgetTimeEntry(
                          label: entry.label,
                          timeLabel: entry.timeLabel,
                          isCurrent: true,
                        )
                      : entry;
                }).toList()
                ..[1] = PrayerWidgetTimeEntry(
                  label: _sixEntries()[1].label,
                  timeLabel: _sixEntries()[1].timeLabel,
                  isCurrent: true,
                ),
        ),
        throwsArgumentError,
      );
    });

    test('a boundary-only entry cannot be current or next', () {
      expect(
        () => PrayerWidgetTimeEntry(
          label: 'Sunrise',
          timeLabel: '06:12',
          isBoundaryOnly: true,
          isCurrent: true,
        ),
        throwsArgumentError,
      );
    });

    test('an entry cannot be both current and next', () {
      expect(
        () => PrayerWidgetTimeEntry(
          label: 'Dhuhr',
          timeLabel: '12:30',
          isCurrent: true,
          isNext: true,
        ),
        throwsArgumentError,
      );
    });

    test('isStale requires a staleLabel and vice versa', () {
      expect(
        () => PrayerWidgetProjection.available(
          dateLabel: '2026-09-04',
          regionLabel: 'Tashkent',
          providerLabel: 'Namoz-vaqti.uz',
          entries: _sixEntries(),
          isStale: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => PrayerWidgetProjection.available(
          dateLabel: '2026-09-04',
          regionLabel: 'Tashkent',
          providerLabel: 'Namoz-vaqti.uz',
          entries: _sixEntries(),
          staleLabel: 'Needs refresh',
        ),
        throwsArgumentError,
      );
    });

    test('a stale schedule never allows Rotation Widget auto-mark', () {
      final stale = PrayerWidgetProjection.available(
        dateLabel: '2026-09-04',
        regionLabel: 'Tashkent',
        providerLabel: 'Namoz-vaqti.uz',
        entries: _sixEntries(),
        isStale: true,
        staleLabel: 'Needs refresh',
      );
      final fresh = PrayerWidgetProjection.available(
        dateLabel: '2026-09-04',
        regionLabel: 'Tashkent',
        providerLabel: 'Namoz-vaqti.uz',
        entries: _sixEntries(),
      );

      expect(stale.allowsRotationAutoMark, isFalse);
      expect(fresh.allowsRotationAutoMark, isTrue);
    });
  });

  group('PrayerWidgetProjectionFactory', () {
    const factory = PrayerWidgetProjectionFactory();

    test('formats times and flags exactly the current/next boundary', () {
      final boundaries = <PrayerWidgetBoundary>[
        const PrayerWidgetBoundary(
          label: 'Fajr',
          hour: 5,
          minute: 3,
          prayerType: PrayerType.fajr,
        ),
        const PrayerWidgetBoundary(label: 'Sunrise', hour: 6, minute: 45),
        const PrayerWidgetBoundary(
          label: 'Dhuhr',
          hour: 12,
          minute: 30,
          prayerType: PrayerType.dhuhr,
        ),
        const PrayerWidgetBoundary(
          label: 'Asr',
          hour: 15,
          minute: 42,
          prayerType: PrayerType.asr,
        ),
        const PrayerWidgetBoundary(
          label: 'Maghrib',
          hour: 18,
          minute: 9,
          prayerType: PrayerType.maghrib,
        ),
        const PrayerWidgetBoundary(
          label: 'Isha',
          hour: 19,
          minute: 40,
          prayerType: PrayerType.isha,
        ),
      ];

      final projection = factory.available(
        dateLabel: '2026-09-04',
        regionLabel: 'Tashkent',
        providerLabel: 'Namoz-vaqti.uz',
        boundaries: boundaries,
        currentPrayerType: PrayerType.dhuhr,
        nextPrayerType: PrayerType.asr,
        currentLabel: 'Dhuhr',
        nextLabel: 'Asr',
      );

      expect(projection.isAvailable, isTrue);
      expect(projection.entries, hasLength(prayerWidgetEntryCount));
      expect(projection.entries.map((entry) => entry.timeLabel), <String>[
        '05:03',
        '06:45',
        '12:30',
        '15:42',
        '18:09',
        '19:40',
      ]);
      expect(
        projection.entries.where((entry) => entry.isCurrent).single.label,
        'Dhuhr',
      );
      expect(
        projection.entries.where((entry) => entry.isNext).single.label,
        'Asr',
      );
      expect(
        projection.entries
            .firstWhere((entry) => entry.label == 'Sunrise')
            .isBoundaryOnly,
        isTrue,
      );
      expect(projection.currentLabel, 'Dhuhr');
      expect(projection.nextLabel, 'Asr');
    });

    test('no current/next prayer type leaves every entry unhighlighted', () {
      final projection = factory.available(
        dateLabel: '2026-09-04',
        regionLabel: 'Tashkent',
        providerLabel: 'Namoz-vaqti.uz',
        boundaries: _boundaries(),
      );

      expect(projection.entries.any((entry) => entry.isCurrent), isFalse);
      expect(projection.entries.any((entry) => entry.isNext), isFalse);
    });
  });

  test('a prayer projection round-trips through the widget snapshot codec', () {
    const codec = WidgetSnapshotCodec();
    final snapshot = WidgetSnapshot(
      generatedAtUtc: DateTime.utc(2026, 9, 4, 10),
      locale: 'ru',
      rotation: RotationWidgetProjection(items: const <RotationWidgetItem>[]),
      learning: const LearningWidgetProjection.empty(),
      prayer: PrayerWidgetProjection.available(
        dateLabel: '2026-09-04',
        regionLabel: 'Tashkent',
        providerLabel: 'Namoz-vaqti.uz',
        entries: _sixEntries(currentIndex: 2, nextIndex: 3),
        currentLabel: 'Dhuhr',
        nextLabel: 'Asr',
      ),
    );

    final decoded = codec.decode(codec.encode(snapshot));

    expect(decoded, isA<WidgetSnapshotDecoded>());
    final result = (decoded as WidgetSnapshotDecoded).snapshot;
    expect(result.prayer, snapshot.prayer);
  });
}

List<PrayerWidgetTimeEntry> _sixEntries({int? currentIndex, int? nextIndex}) {
  const labels = <String>['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  const times = <String>['05:03', '06:45', '12:30', '15:42', '18:09', '19:40'];
  return <PrayerWidgetTimeEntry>[
    for (var index = 0; index < labels.length; index += 1)
      PrayerWidgetTimeEntry(
        label: labels[index],
        timeLabel: times[index],
        isBoundaryOnly: index == 1,
        isCurrent: index == currentIndex,
        isNext: index == nextIndex,
      ),
  ];
}

List<PrayerWidgetBoundary> _boundaries() => const <PrayerWidgetBoundary>[
  PrayerWidgetBoundary(
    label: 'Fajr',
    hour: 5,
    minute: 3,
    prayerType: PrayerType.fajr,
  ),
  PrayerWidgetBoundary(label: 'Sunrise', hour: 6, minute: 45),
  PrayerWidgetBoundary(
    label: 'Dhuhr',
    hour: 12,
    minute: 30,
    prayerType: PrayerType.dhuhr,
  ),
  PrayerWidgetBoundary(
    label: 'Asr',
    hour: 15,
    minute: 42,
    prayerType: PrayerType.asr,
  ),
  PrayerWidgetBoundary(
    label: 'Maghrib',
    hour: 18,
    minute: 9,
    prayerType: PrayerType.maghrib,
  ),
  PrayerWidgetBoundary(
    label: 'Isha',
    hour: 19,
    minute: 40,
    prayerType: PrayerType.isha,
  ),
];
