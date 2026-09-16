import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';

/// Captured on the owner's 2026-09-16 recording: marking Al-Falaq swapped it
/// with An-Naas, so the next tap landed on a different surah. He reported it as
/// the reason he could not enter yesterday's prayers at all.
void main() {
  const service = StableOrderService();

  test('the first ordering is taken as given', () {
    expect(
      service.reorder(
        previous: const <String>[],
        current: const <String>['a', 'b'],
      ),
      <String>['a', 'b'],
    );
  });

  test('a mark reorders nothing, because membership did not change', () {
    // Marking a surah changes how overdue it is, so the operational order
    // hands back the same rows in a different sequence.
    final stabilized = service.reorder(
      previous: const <String>['falaq', 'naas', 'lail'],
      current: const <String>['naas', 'lail', 'falaq'],
    );

    expect(stabilized, <String>[
      'falaq',
      'naas',
      'lail',
    ], reason: 'no row may move under a finger that is already on it');
  });

  test('a surah that left the list is dropped', () {
    expect(
      service.reorder(
        previous: const <String>['a', 'b', 'c'],
        current: const <String>['c', 'a'],
      ),
      <String>['a', 'c'],
    );
  });

  test('a newcomer arrives at the end rather than in the middle', () {
    // Inserting it at its operational position would displace everything below
    // it — the very thing this exists to prevent.
    expect(
      service.reorder(
        previous: const <String>['a', 'b'],
        current: const <String>['new', 'a', 'b'],
      ),
      <String>['a', 'b', 'new'],
    );
  });

  test('order is idempotent when nothing changes', () {
    const rows = <String>['a', 'b', 'c'];
    final once = service.reorder(previous: rows, current: rows);

    expect(service.reorder(previous: once, current: rows), rows);
  });

  test('the result cannot be mutated by its caller', () {
    final result = service.reorder(
      previous: const <String>['a'],
      current: const <String>['a', 'b'],
    );

    expect(() => result.add('c'), throwsUnsupportedError);
  });
}
