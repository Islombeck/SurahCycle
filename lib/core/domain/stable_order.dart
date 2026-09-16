/// Keeps rows where the user last saw them.
///
/// The active-surah list is ordered operationally — by how overdue each surah
/// is — and marking one changes exactly that. So every mark re-sorted the list
/// while the user's finger was still on it: on the 2026-09-16 recording,
/// marking Al-Falaq swapped it with An-Naas and the next tap landed on a
/// different surah. The owner reported it as the reason he could not enter
/// yesterday's prayers at all.
///
/// The operational order still decides where a surah **first** appears. After
/// that it stays put until the ordering is reset — which callers do when the
/// prayer context or the day changes, not when a surah is marked.
///
/// A mark never adds or removes a row (a completed surah stays visible and
/// turns green), so in the case that matters the result is the previous order
/// unchanged. Membership changes are rare and user-initiated: a surah that
/// disappeared is dropped, and one that appeared is added at the end rather
/// than pushed into the middle, because arriving at the bottom is predictable
/// and displacing everything below it is not.
final class StableOrderService {
  const StableOrderService();

  List<String> reorder({
    required List<String> previous,
    required List<String> current,
  }) {
    if (previous.isEmpty) return List<String>.unmodifiable(current);
    final present = current.toSet();
    final kept = <String>[
      for (final id in previous)
        if (present.contains(id)) id,
    ];
    final keptIds = kept.toSet();
    return List<String>.unmodifiable(<String>[
      ...kept,
      for (final id in current)
        if (!keptIds.contains(id)) id,
    ]);
  }
}
