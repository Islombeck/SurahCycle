import 'appwrite_config.dart';

/// What the account screen is allowed to say, decided in one place.
///
/// The ordering of these cases is the ordering of the decision: the first one
/// that applies wins, so a misconfiguration can never be hidden behind a
/// cheerful "up to date", and a quarantined change can never be hidden behind
/// an empty queue.
enum SyncHealth {
  /// No Appwrite configuration in this build. The app is local-first, so this
  /// is an ordinary state and not a fault: it means "no account features".
  unavailable,

  /// A configuration exists and is wrong. This one has to be visible, because
  /// it is indistinguishable from being offline until someone reads the reason.
  misconfigured,

  /// Nothing is signed in.
  signedOut,

  /// Signed in, sync deliberately not switched on — what "keep this device
  /// local" chooses. Queued work is not shown as progress, because none is
  /// being made.
  notActivated,

  /// On, and nothing has ever synced. **Not** a success: an empty queue on a
  /// device that has never reached the server means nothing has been protected
  /// yet, and saying otherwise is the fake green this type exists to prevent.
  neverSynced,

  /// On, the queue is empty, and at least one real success is on record.
  upToDate,

  /// On, with work queued and no failure yet.
  syncing,

  /// On, the last attempt failed, and it will be retried.
  retrying,

  /// The server refused something permanently. It sits in quarantine, where it
  /// blocks nothing and waits to be looked at — so it must be surfaced rather
  /// than left to rot silently.
  needsAttention,
}

/// A single, honest summary of where sync stands.
final class SyncStatus {
  const SyncStatus._({
    required this.health,
    required this.queuedCount,
    required this.quarantinedCount,
    required this.lastSuccessAtUtc,
    required this.lastFailureReason,
    required this.consecutiveFailureCount,
    required this.problem,
  });

  /// [lastFailureReason] must be the engine's content-free category, never a
  /// payload or a server message that could carry the user's own data.
  factory SyncStatus.resolve({
    required AppwriteConfig config,
    required bool isSignedIn,
    required bool isActivated,
    int queuedCount = 0,
    int quarantinedCount = 0,
    DateTime? lastSuccessAtUtc,
    String? lastFailureReason,
    int consecutiveFailureCount = 0,
  }) {
    if (queuedCount < 0 || quarantinedCount < 0) {
      throw ArgumentError.value(
        queuedCount < 0 ? queuedCount : quarantinedCount,
        'count',
        'Must not be negative.',
      );
    }
    if (lastSuccessAtUtc != null && !lastSuccessAtUtc.isUtc) {
      throw ArgumentError.value(
        lastSuccessAtUtc,
        'lastSuccessAtUtc',
        'Must be UTC.',
      );
    }

    SyncHealth health;
    if (config.isAbsent) {
      health = SyncHealth.unavailable;
    } else if (!config.isReady) {
      health = SyncHealth.misconfigured;
    } else if (!isSignedIn) {
      health = SyncHealth.signedOut;
    } else if (!isActivated) {
      health = SyncHealth.notActivated;
    } else if (quarantinedCount > 0) {
      health = SyncHealth.needsAttention;
    } else if (lastFailureReason != null) {
      health = SyncHealth.retrying;
    } else if (queuedCount > 0) {
      health = SyncHealth.syncing;
    } else if (lastSuccessAtUtc == null) {
      health = SyncHealth.neverSynced;
    } else {
      health = SyncHealth.upToDate;
    }

    return SyncStatus._(
      health: health,
      queuedCount: queuedCount,
      quarantinedCount: quarantinedCount,
      lastSuccessAtUtc: lastSuccessAtUtc,
      // A failure is only worth reporting while sync is actually running; a
      // signed-out device showing yesterday's transport error is noise.
      lastFailureReason: health == SyncHealth.retrying
          ? lastFailureReason
          : null,
      consecutiveFailureCount: health == SyncHealth.retrying
          ? consecutiveFailureCount
          : 0,
      problem: health == SyncHealth.misconfigured ? config.problem : null,
    );
  }

  final SyncHealth health;
  final int queuedCount;
  final int quarantinedCount;
  final DateTime? lastSuccessAtUtc;
  final String? lastFailureReason;
  final int consecutiveFailureCount;

  /// Why the configuration is unusable, present only when it is.
  final String? problem;

  /// The one state a screen may render as success.
  ///
  /// Deliberately not "no error": a device that has never synced has no error
  /// either, and showing it as safe would be a lie about where the user's data
  /// is.
  bool get isSuccess => health == SyncHealth.upToDate;

  /// Whether the user can do anything about it here and now.
  bool get isActionable =>
      health == SyncHealth.misconfigured ||
      health == SyncHealth.signedOut ||
      health == SyncHealth.notActivated ||
      health == SyncHealth.needsAttention;

  /// Whether a manual retry makes sense. Retrying a queue that has never
  /// failed, or one nobody is signed in for, only teaches the user that the
  /// button does nothing.
  bool get canRetryNow =>
      health == SyncHealth.retrying || health == SyncHealth.needsAttention;

  /// True when local work exists that the server has not accepted.
  bool get hasUnsentWork => queuedCount > 0 || quarantinedCount > 0;

  @override
  String toString() =>
      'SyncStatus(${health.name}, queued: $queuedCount, '
      'quarantined: $quarantinedCount)';
}
