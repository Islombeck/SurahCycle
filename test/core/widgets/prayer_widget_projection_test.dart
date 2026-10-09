import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/core/widgets/widgets.dart';

/// Tashkent, UTC+5, on 2026-09-04. Midnight there is 19:00 UTC the day before.
final DateTime _localMidnightUtc = DateTime.utc(2026, 9, 3, 19);

DateTime _localTime(int hour, int minute) =>
    _localMidnightUtc.add(Duration(hours: hour, minutes: minute));

int _atLocal(int hour, int minute) =>
    _localTime(hour, minute).millisecondsSinceEpoch;

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
      expect(projection.windows, isEmpty);
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
          windows: _windows(),
        ),
        throwsArgumentError,
      );
    });

    test('a window may never point at Sunrise', () {
      // Sunrise is a boundary, not a prayer. Before, the entry itself refused
      // to be marked current; now the refusal has to live where the choice is
      // made, or the platform would faithfully highlight it.
      expect(
        () => PrayerWidgetProjection.available(
          dateLabel: '2026-09-04',
          regionLabel: 'Tashkent',
          providerLabel: 'Namoz-vaqti.uz',
          entries: _sixEntries(),
          windows: <PrayerWidgetWindow>[
            PrayerWidgetWindow(
              startUtcMs: _atLocal(0, 0),
              endUtcMs: _atLocal(24, 0),
              entryIndex: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('windows must be contiguous and in order', () {
      // A gap or an overlap makes "which prayer is this" ambiguous on the far
      // side, where there is nobody to ask.
      for (final second in <PrayerWidgetWindow>[
        // Gap.
        PrayerWidgetWindow(
          startUtcMs: _atLocal(13, 0),
          endUtcMs: _atLocal(24, 0),
          entryIndex: 2,
        ),
        // Overlap.
        PrayerWidgetWindow(
          startUtcMs: _atLocal(11, 0),
          endUtcMs: _atLocal(24, 0),
          entryIndex: 2,
        ),
      ]) {
        expect(
          () => PrayerWidgetProjection.available(
            dateLabel: '2026-09-04',
            regionLabel: 'Tashkent',
            providerLabel: 'Namoz-vaqti.uz',
            entries: _sixEntries(),
            windows: <PrayerWidgetWindow>[
              PrayerWidgetWindow(
                startUtcMs: _atLocal(0, 0),
                endUtcMs: _atLocal(12, 0),
                entryIndex: 0,
              ),
              second,
            ],
          ),
          throwsArgumentError,
        );
      }
    });

    test('a window must end after it starts, and name a real row', () {
      expect(
        () => PrayerWidgetWindow(
          startUtcMs: _atLocal(12, 0),
          endUtcMs: _atLocal(12, 0),
          entryIndex: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => PrayerWidgetWindow(
          startUtcMs: _atLocal(0, 0),
          endUtcMs: _atLocal(1, 0),
          entryIndex: prayerWidgetEntryCount,
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
          windows: _windows(),
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
          windows: _windows(),
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
        windows: _windows(),
        isStale: true,
        staleLabel: 'Needs refresh',
      );
      final fresh = PrayerWidgetProjection.available(
        dateLabel: '2026-09-04',
        regionLabel: 'Tashkent',
        providerLabel: 'Namoz-vaqti.uz',
        entries: _sixEntries(),
        windows: _windows(),
      );

      expect(stale.allowsRotationAutoMark, isFalse);
      expect(fresh.allowsRotationAutoMark, isTrue);
    });
  });

  group('PrayerWidgetProjectionFactory', () {
    test('formats the six times and divides the day into seven stretches', () {
      final projection = _projection();

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
        projection.entries
            .firstWhere((entry) => entry.label == 'Sunrise')
            .isBoundaryOnly,
        isTrue,
      );
      expect(
        projection.windows.map((window) => window.entryIndex),
        <int>[5, 0, -1, 2, 3, 4, 5],
        reason:
            'the night before Fajr belongs to the Isha row, Sunrise to no '
            'prayer at all, and the evening after Isha back to Isha',
      );
      expect(projection.windows.first.startUtcMs, _atLocal(0, 0));
      expect(projection.windows.last.endUtcMs, _atLocal(24, 0));
    });
  });

  group('which prayer is it, now', () {
    test('the row is chosen by the clock, not by when this was written', () {
      final projection = _projection();

      expect(projection.currentEntryIndexAt(_atLocal(16, 0)), 3);
      expect(projection.currentEntryIndexAt(_atLocal(5, 4)), 0);
      expect(projection.currentEntryIndexAt(_atLocal(19, 41)), 5);
    });

    test('the hours before Fajr belong to the night that is ending', () {
      // 02:00 is Isha, and that has been the resolver's answer all along. The
      // widget could not say it before, because the answer it carried was
      // frozen at whatever the app last saw.
      expect(_projection().currentEntryIndexAt(_atLocal(2, 0)), 5);
    });

    test('between Sunrise and Dhuhr there is no current prayer', () {
      expect(_projection().currentEntryIndexAt(_atLocal(7, 0)), isNull);
      expect(
        _projection().nextEntryIndexAt(_atLocal(7, 0)),
        2,
        reason: 'Dhuhr is still what comes next',
      );
    });

    test('a snapshot from another day says it does not know', () {
      // **The defect, in one assertion.** The widget used to keep the row it
      // was given: his phone showed Asr highlighted because Asr was current
      // when the launcher last built it, hours or days earlier. Outside its
      // own day the honest answer is null, and the widget renders the
      // fallback instead of a confident wrong one.
      final projection = _projection();

      expect(projection.currentEntryIndexAt(_atLocal(-5, 0)), isNull);
      expect(projection.currentEntryIndexAt(_atLocal(30, 0)), isNull);
      expect(projection.nextEntryIndexAt(_atLocal(30, 0)), isNull);
    });

    test('it says when its own answer expires', () {
      // What a scheduled redraw is set against.
      expect(_projection().windowEndsAt(_atLocal(16, 0)), _atLocal(18, 9));
      expect(_projection().windowEndsAt(_atLocal(30, 0)), isNull);
    });
  });

  test('a prayer projection round-trips through the widget snapshot codec', () {
    const codec = WidgetSnapshotCodec();
    final snapshot = WidgetSnapshot(
      generatedAtUtc: DateTime.utc(2026, 9, 4, 10),
      locale: 'ru',
      rotation: RotationWidgetProjection(items: const <RotationWidgetItem>[]),
      learning: const LearningWidgetProjection.empty(),
      prayer: _projection(),
    );

    final decoded = codec.decode(codec.encode(snapshot));

    expect(decoded, isA<WidgetSnapshotDecoded>());
    final result = (decoded as WidgetSnapshotDecoded).snapshot;
    expect(result.prayer, snapshot.prayer);
    expect(result.prayer.windows, hasLength(7));
  });
}

PrayerWidgetProjection _projection() =>
    const PrayerWidgetProjectionFactory().available(
      dateLabel: '2026-09-04',
      regionLabel: 'Tashkent',
      providerLabel: 'Namoz-vaqti.uz',
      boundaries: _boundaries(),
      localMidnightUtc: _localMidnightUtc,
    );

List<PrayerWidgetTimeEntry> _sixEntries() {
  const labels = <String>['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  const times = <String>['05:03', '06:45', '12:30', '15:42', '18:09', '19:40'];
  return <PrayerWidgetTimeEntry>[
    for (var index = 0; index < labels.length; index += 1)
      PrayerWidgetTimeEntry(
        label: labels[index],
        timeLabel: times[index],
        isBoundaryOnly: index == 1,
      ),
  ];
}

List<PrayerWidgetWindow> _windows() => _projection().windows;

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
