/// Result of an undo attempt.
final class UndoOutcome<T> {
  const UndoOutcome._({
    required this.value,
    required this.didUndo,
    this.undoneEventId,
  });

  const UndoOutcome.restored(T value, {required String undoneEventId})
    : this._(value: value, didUndo: true, undoneEventId: undoneEventId);

  const UndoOutcome.nothingToUndo(T value)
    : this._(value: value, didUndo: false);

  final T value;
  final bool didUndo;
  final String? undoneEventId;
}
