import 'dart:async';

import 'widget_snapshot.dart';

abstract interface class WidgetBridge {
  /// Atomically rejects an older projection. Returns true when persisted.
  Future<bool> saveSnapshotIfCurrent(WidgetSnapshot snapshot, String json);

  Future<void> updateRotationWidget();

  Future<void> updateLearningWidget();
}

typedef WidgetSyncErrorHandler =
    void Function(Object error, StackTrace stackTrace);

/// Serializes, coalesces, and deduplicates widget writes from application
/// streams. Domain actions remain independent from launcher update failures.
final class WidgetSyncCoordinator {
  factory WidgetSyncCoordinator({
    required WidgetBridge bridge,
    Duration debounce = const Duration(milliseconds: 150),
    WidgetSnapshotCodec codec = const WidgetSnapshotCodec(),
    WidgetSyncErrorHandler? onError,
  }) {
    if (debounce.isNegative) {
      throw ArgumentError.value(debounce, 'debounce', 'Must not be negative.');
    }
    return WidgetSyncCoordinator._(bridge, codec, onError, debounce);
  }

  WidgetSyncCoordinator._(
    this._bridge,
    this._codec,
    this._onError,
    this.debounce,
  );

  final WidgetBridge _bridge;
  final WidgetSnapshotCodec _codec;
  final WidgetSyncErrorHandler? _onError;
  final Duration debounce;

  Timer? _timer;
  WidgetSnapshot? _pending;
  WidgetSnapshot? _lastWritten;
  Future<void>? _drainFuture;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Coalesces rapid stream emissions and writes only the newest projection.
  void schedule(WidgetSnapshot snapshot) {
    if (_disposed) return;
    _pending = snapshot;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_submitPending().catchError((Object _) {}));
    });
  }

  /// Writes without waiting for the debounce window. Concurrent calls are
  /// serialized and collapse to the newest not-yet-started snapshot.
  Future<void> syncNow(WidgetSnapshot snapshot) {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    _pending = snapshot;
    return _submitPending();
  }

  /// Flushes a scheduled projection, or waits for an in-flight native update.
  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    if (_pending != null) return _submitPending();
    return _drainFuture ?? Future<void>.value();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  Future<void> _submitPending() {
    final running = _drainFuture;
    if (running != null) return running;

    late final Future<void> result;
    result = _drain().whenComplete(() {
      if (identical(_drainFuture, result)) _drainFuture = null;
    });
    _drainFuture = result;
    return result;
  }

  Future<void> _drain() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    while (!_disposed && _pending != null) {
      final snapshot = _pending!;
      _pending = null;
      if ((_lastWritten?.sameProjectionAs(snapshot) ?? false) &&
          _lastWritten!.snapshotRevision == snapshot.snapshotRevision) {
        continue;
      }
      try {
        final saved = await _bridge.saveSnapshotIfCurrent(
          snapshot,
          _codec.encode(snapshot),
        );
        if (!saved) continue;
        await Future.wait<void>(<Future<void>>[
          _bridge.updateRotationWidget(),
          _bridge.updateLearningWidget(),
        ]);
        _lastWritten = snapshot;
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
        _onError?.call(error, stackTrace);
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
