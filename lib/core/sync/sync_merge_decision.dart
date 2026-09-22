/// Whether a pulled record may replace the copy this device already holds.
///
/// ADR-0002 settles a disagreement by `updatedAtUtc`, then by whether it is a
/// deletion, then by `deviceId`, and says the rules are "verified against a
/// local double". That double — `FakeSyncBackend` — decides them **on the
/// server**, and the server this app actually uses is Appwrite's TablesDB: a
/// row store that upserts what it is given and compares nothing. Nothing in
/// the shipped path enforced any of it, which made the effective rule "the
/// last push wins" — the one thing the ADR explicitly rejected, because it is
/// not a rule but a race.
///
/// So the decision lives here, on the device, where it can actually run, and
/// every applier asks it before writing.
///
/// **Two of the ADR's three steps are decidable here and the third is not.** A
/// local row records when it last changed; it does not record which device
/// wrote it, so `deviceId` cannot break a tie. What remains is:
///
/// ```
/// the incoming record is applied
///   unless this device holds a strictly newer one
/// ```
///
/// which keeps the ADR's first step exactly and folds the other two into "the
/// account wins a tie". That is the same answer the tombstone rule would give
/// — a withdrawal at the same instant wins, and it is recoverable through
/// History — and on a complete tie it matches `FakeSyncBackend`, which also
/// takes the incoming one. One second of resolution means a tie is almost
/// always one device's own two edits inside a second, where arrival order is
/// that device's order.
///
/// **An undated local row loses**, which is ADR-0002 §7 and the reason schema
/// v10 backfilled nothing: null is "not knowing", and the only way the account
/// holds a dated copy of a row this device cannot date is that some device
/// edited it after v10 while this one has not touched it since before.
library;

abstract final class SyncMergeDecision {
  /// True when the account's copy should be written over this device's.
  ///
  /// [localUpdatedAtUtc] is null for a row that has never been dated, and for
  /// a record this device does not have at all — both mean "nothing here can
  /// outrank it".
  static bool incomingWins({
    required DateTime incomingUpdatedAtUtc,
    required DateTime? localUpdatedAtUtc,
  }) {
    if (localUpdatedAtUtc == null) return true;
    // Whole seconds on both sides: the touch triggers write
    // `strftime('%s','now')`, so a local row can never carry sub-second
    // precision, and an envelope that does would beat an equal local row for a
    // reason that is an artefact of formatting rather than a fact about the
    // record.
    final incoming = _seconds(incomingUpdatedAtUtc);
    final local = _seconds(localUpdatedAtUtc);
    return incoming >= local;
  }

  static int _seconds(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch ~/ 1000;
}
