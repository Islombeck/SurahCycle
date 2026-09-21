/// One complete exchange with the account, as the rest of the app sees it.
///
/// The port is here and the implementation is in the data layer, like every
/// other pair in this feature: a screen that wanted to trigger a sync would
/// otherwise have to import a Drift store to do it.
library;

/// What one cycle did.
final class SyncCycleOutcome {
  const SyncCycleOutcome({
    required this.ran,
    this.pushedCount = 0,
    this.rejectedCount = 0,
    this.remainingCount = 0,
    this.pulledPageCount = 0,
    this.failureReason,
  });

  /// A cycle that was refused before it started: no account, not activated, or
  /// no transport in this build.
  static const SyncCycleOutcome skipped = SyncCycleOutcome(ran: false);

  /// Whether anything was actually attempted.
  ///
  /// Separate from "nothing changed": a device kept local and a device with an
  /// empty queue both report zero, and only one of them is waiting for work.
  final bool ran;

  final int pushedCount;
  final int rejectedCount;
  final int remainingCount;
  final int pulledPageCount;

  /// A content-free category, never a payload or a server message.
  final String? failureReason;

  bool get hasFailure => failureReason != null;

  bool get didAnything => pushedCount > 0 || pulledPageCount > 0;
}

/// Sends what is queued and takes what the account has.
abstract interface class SyncCycle {
  /// Runs one exchange. Callers that arrive during one join it rather than
  /// starting a second.
  Future<SyncCycleOutcome> runOnce();
}
