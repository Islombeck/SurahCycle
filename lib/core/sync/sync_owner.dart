/// Whose queue, cursor and activation a durable sync row belongs to.
///
/// Every durable sync row is scoped by this key rather than living in one
/// global singleton, because the dangerous case is cheap to reach: sign out of
/// account A and into account B on the same device, and a shared queue would
/// push A's recitation history under B's account. Scoping makes that
/// impossible by construction rather than by remembering to clear state.
///
/// [local] is the pre-account state. A device that has never signed in still
/// queues nothing useful, but it has a well-defined owner, so adopting its
/// data into an account stays an explicit merge decision instead of two
/// lifetimes quietly sharing the same rows.
final class SyncOwnerKey {
  factory SyncOwnerKey.user(String userId) {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }
    return SyncOwnerKey._('user:$userId');
  }

  /// Rebuilds a key from the form it was stored in.
  ///
  /// For the storage layer reading its own rows back, and nothing else. A
  /// caller that has a user id should use [SyncOwnerKey.user], which is the
  /// one place that decides what the stored form looks like.
  factory SyncOwnerKey.stored(String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Must not be empty.');
    }
    return SyncOwnerKey._(value);
  }

  const SyncOwnerKey._(this.value);

  static const SyncOwnerKey local = SyncOwnerKey._('local');

  /// The stored form. Opaque to everything but the storage layer.
  final String value;

  bool get isLocal => value == local.value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SyncOwnerKey && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SyncOwnerKey($value)';
}
