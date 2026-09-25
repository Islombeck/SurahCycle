/// Whether a prayer stands, decided by when each side last decided it.
///
/// A recitation is append-only, so `SyncMergeDecision` does not compare it:
/// two devices produce different prayers, not two versions of one. What they
/// *can* both touch is whether a prayer stands — one withdraws it, the other
/// brings it back — and until schema v11 nothing recorded when that decision
/// was made. `deleted_at_utc` holds only one half: restoring clears it, so
/// after a restore the row remembered nothing, and a withdrawal made offline
/// on Monday could undo a restore made on Tuesday simply by arriving later.
/// ADR-0002 carried this as "a withdrawal made offline can beat a newer
/// restore".
///
/// The rule, in full, and it is the same rule on both sides of the boundary —
/// the repository writes `state_changed_at_utc` when the owner acts here, and
/// the applier compares against it when the account speaks:
///
/// - **Whole seconds.** That is the resolution the v10 touch triggers write at
///   and the resolution `SyncMergeDecision` already compares at; mixing
///   precisions is how a record dated in the same second reads as older.
/// - **Null loses.** Every row written before v11 has no state version, and it
///   is deliberately not invented — `created_at_utc` is when the prayer was
///   recited, not when its standing last changed. A known time beating an
///   unknown one is the direction `SyncMergeDecision` already takes.
/// - **On an exact tie the withdrawal wins.** ADR-0002's reasoning, unchanged:
///   withdrawn is the recoverable answer, because History can undo it, while a
///   resurrection cannot be told apart from the owner recording the prayer
///   again.
library;

abstract final class RecitationStateVersion {
  /// Whether the arriving decision replaces the one this device holds.
  ///
  /// [incomingWithdraws] is what breaks an exact tie, so a caller must say
  /// which kind of decision is arriving rather than let it be inferred.
  static bool incomingWins({
    required DateTime incomingAtUtc,
    required DateTime? localAtUtc,
    required bool incomingWithdraws,
  }) {
    if (localAtUtc == null) return true;
    // Both sides are normalised rather than asserted. The incoming one is UTC
    // by the envelope's own contract; the local one is whatever Drift hands
    // back for a `DateTime` column, which is the same instant in the device's
    // zone. Comparing instants is the whole point, and refusing a local-zone
    // value here would only mean every caller writing `.toUtc()` instead.
    final incoming = _seconds(incomingAtUtc.toUtc());
    final local = _seconds(localAtUtc.toUtc());
    if (incoming != local) return incoming > local;
    return incomingWithdraws;
  }

  static int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;
}
