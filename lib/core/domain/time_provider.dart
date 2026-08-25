/// Supplies time to domain services.
///
/// Business logic must depend on this abstraction rather than calling
/// [DateTime.now] directly.
abstract interface class TimeProvider {
  DateTime nowUtc();
}

/// Production clock. Tests should use a deterministic [TimeProvider].
final class SystemTimeProvider implements TimeProvider {
  const SystemTimeProvider();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
