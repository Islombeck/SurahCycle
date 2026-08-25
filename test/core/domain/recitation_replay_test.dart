import 'package:flutter_test/flutter_test.dart';

import 'package:murajaah/core/domain/domain.dart';
import 'test_fixtures.dart';

void main() {
  const service = RecitationReplayService();

  RotationSnapshot baseline() => RotationSnapshot(
    surahs: <MasteredSurah>[
      mastered(id: 'a', score: 0),
      mastered(id: 'b', score: 0),
    ],
  );

  test('deleting latest event rebuilds score but keeps target monotonic', () {
    final initial = service.create(baseline: baseline());
    final afterA = service.record(initial, recitation('e-a', 'a'));
    final afterB = service.record(afterA, recitation('e-b', 'b'));
    expect(afterB.snapshot.rotationTarget, 2);

    final deletion = service.deleteEvent(afterB, 'e-b');

    expect(deletion.didDelete, isTrue);
    expect(deletion.deletedEvent?.id, 'e-b');
    expect(deletion.timeline.snapshot.rotationTarget, 2);
    expect(deletion.timeline.snapshot.surahById('a').rotationScore, 1);
    expect(deletion.timeline.snapshot.surahById('b').rotationScore, 0);
    expect(deletion.timeline.snapshot.surahById('b').totalRecitations, 0);
    expect(deletion.timeline.events.map((event) => event.id), <String>['e-a']);
  });

  test('deleting an earlier event derives counters and target from replay', () {
    var timeline = service.create(baseline: baseline());
    timeline = service.record(timeline, recitation('e-a', 'a'));
    timeline = service.record(timeline, recitation('e-b', 'b'));

    final deletion = service.deleteEvent(timeline, 'e-a');
    final snapshot = deletion.timeline.snapshot;

    expect(snapshot.rotationTarget, 2);
    expect(snapshot.surahById('a').totalRecitations, 0);
    expect(snapshot.surahById('a').rotationScore, 0);
    expect(snapshot.surahById('b').totalRecitations, 1);
    expect(snapshot.surahById('b').rotationScore, 1);
  });

  test(
    'undo removes the last fact and restores the exact previous snapshot',
    () {
      final initial = service.create(baseline: baseline());
      final previous = service.record(initial, recitation('e-a', 'a'));
      final current = service.record(previous, recitation('e-b', 'b'));

      final undo = service.undoLast(current);

      expect(undo.didUndo, isTrue);
      expect(undo.undoneEventId, 'e-b');
      expect(undo.value.snapshot, previous.snapshot);
      expect(undo.value.events, previous.events);
    },
  );

  test('undo can lower target because it restores the pre-action snapshot', () {
    final initial = service.create(baseline: baseline());
    final afterA = service.record(initial, recitation('e-a', 'a'));
    final afterB = service.record(afterA, recitation('e-b', 'b'));
    expect(afterB.snapshot.rotationTarget, 2);

    final undo = service.undoLast(afterB);

    expect(undo.value.snapshot.rotationTarget, 1);
    expect(undo.value.snapshot, afterA.snapshot);
  });

  test('undo on empty history is a no-op', () {
    final initial = service.create(baseline: baseline());

    final undo = service.undoLast(initial);

    expect(undo.didUndo, isFalse);
    expect(identical(undo.value, initial), isTrue);
  });

  test('unknown deletion is a no-op', () {
    final timeline = service.create(baseline: baseline());

    final deletion = service.deleteEvent(timeline, 'missing');

    expect(deletion.didDelete, isFalse);
    expect(identical(deletion.timeline, timeline), isTrue);
  });

  test('duplicate event ids are rejected', () {
    final event = recitation('same-id', 'a');

    expect(
      () => service.create(
        baseline: baseline(),
        events: <SurahRecitationEvent>[event, event],
      ),
      throwsArgumentError,
    );
  });

  test('adjustment replay changes score only and never advances target', () {
    final adjustedBaseline = RotationSnapshot(
      rotationTarget: 10,
      surahs: <MasteredSurah>[mastered(id: 'a', score: 8, total: 6)],
    );
    final adjustment = RotationAdjustmentEvent(
      id: 'adjust-1',
      surahId: 'a',
      delta: 2,
      reason: 'Confirmed migration balance',
      createdAtUtc: DateTime.utc(2026, 1, 2),
    );

    final timeline = service.recordAdjustment(
      service.create(baseline: adjustedBaseline),
      adjustment,
    );
    final replayed = service.create(
      baseline: adjustedBaseline,
      events: timeline.events,
    );

    expect(timeline.snapshot.surahById('a').rotationScore, 10);
    expect(timeline.snapshot.surahById('a').totalRecitations, 6);
    expect(timeline.snapshot.rotationTarget, 10);
    expect(replayed.snapshot, timeline.snapshot);
  });

  test('negative adjustment cannot make a score negative', () {
    final adjustment = RotationAdjustmentEvent(
      id: 'adjust-1',
      surahId: 'a',
      delta: -1,
      reason: 'Confirmed correction',
      createdAtUtc: DateTime.utc(2026, 1, 2),
    );

    expect(
      () => service.recordAdjustment(
        service.create(baseline: baseline()),
        adjustment,
      ),
      throwsStateError,
    );
  });

  test('one multi-part action has one atomic exact Undo', () {
    final splitScheme = SurahRotationScheme.evenlySplit(
      id: 'split-v1',
      surahId: 'split',
      version: 1,
      ayahCount: 4,
      partCount: 2,
    );
    final baseline = RotationSnapshot(
      surahs: <MasteredSurah>[
        MasteredSurah(
          surah: testSurah(id: 'split', number: 2, ayahCount: 4),
          isActive: true,
          hasEnteredRotation: true,
          rotationScheme: splitScheme,
        ),
      ],
    );
    final initial = service.create(baseline: baseline);
    final recorded = service.record(
      initial,
      _eventForParts(
        id: 'whole',
        scheme: splitScheme,
        partNumbers: const <int>[1, 2],
        rakaats: 2,
      ),
    );

    expect(recorded.events, hasLength(1));
    expect(
      recorded.snapshot
          .surahById('split')
          .rotationScheme
          .parts
          .map((part) => part.rotationScore),
      <int>[1, 1],
    );
    expect(recorded.snapshot.rotationTarget, 2);

    final undo = service.undoLast(recorded);

    expect(undo.didUndo, isTrue);
    expect(undo.value.snapshot, baseline);
    expect(undo.value.events, isEmpty);
  });

  test('versioned coverage stays historical and old deletion propagates', () {
    final baseline = RotationSnapshot(
      surahs: <MasteredSurah>[mastered(id: 'a', score: 0)],
    );
    var timeline = service.create(baseline: baseline);
    timeline = service.record(timeline, recitation('old-whole', 'a'));
    final oldEvent = timeline.events.single as SurahRecitationEvent;
    final oldScheme = timeline.snapshot.surahById('a').rotationScheme;
    final proposed = SurahRotationScheme.evenlySplit(
      id: 'a-v2',
      surahId: 'a',
      version: 2,
      ayahCount: 3,
      partCount: 2,
    );
    timeline = service.recordSchemeChange(
      timeline,
      RotationSchemeChangedEvent(
        id: 'change-v2',
        surahId: 'a',
        scheme: proposed,
        createdAtUtc: DateTime.utc(2026, 1, 1, 13),
      ),
    );
    final activeScheme = timeline.snapshot.surahById('a').rotationScheme;
    timeline = service.record(
      timeline,
      _eventForParts(
        id: 'new-p1',
        scheme: activeScheme,
        partNumbers: const <int>[1],
        surahId: 'a',
      ),
    );
    timeline = service.record(
      timeline,
      _eventForParts(
        id: 'new-p2',
        scheme: activeScheme,
        partNumbers: const <int>[2],
        surahId: 'a',
      ),
    );
    expect(timeline.snapshot.surahById('a').rotationScore, 2);
    expect(timeline.snapshot.surahById('a').totalRecitations, 2);
    expect(timeline.snapshot.rotationTarget, 3);

    final newEvents = timeline.events
        .whereType<SurahRecitationEvent>()
        .toList();
    expect(oldEvent.rotationSchemeId, oldScheme.id);
    expect(oldEvent.coveredPartIds, <String>[oldScheme.parts.single.id]);
    expect(newEvents.last.rotationSchemeId, 'a-v2');

    final deletion = service.deleteEvent(timeline, 'old-whole');

    expect(deletion.didDelete, isTrue);
    expect(deletion.timeline.snapshot.rotationTarget, 3);
    expect(deletion.timeline.snapshot.surahById('a').rotationScore, 1);
    expect(deletion.timeline.snapshot.surahById('a').totalRecitations, 1);
    expect(
      deletion.timeline.snapshot
          .surahById('a')
          .rotationScheme
          .parts
          .map((part) => part.rotationScore),
      <int>[1, 1],
    );
  });
}

SurahRecitationEvent _eventForParts({
  required String id,
  required SurahRotationScheme scheme,
  required List<int> partNumbers,
  String surahId = 'split',
  int rakaats = 1,
}) => SurahRecitationEvent(
  id: id,
  surahId: surahId,
  prayerContext: PrayerContext(prayerType: PrayerType.asr),
  createdAtUtc: DateTime.utc(2026, 1, 1, 14),
  localDate: LocalDate(2026, 1, 1),
  rotationSchemeId: scheme.id,
  coveredPartIds: partNumbers
      .map((number) => scheme.parts[number - 1].id)
      .toList(),
  rakaatSpanCount: rakaats,
);
