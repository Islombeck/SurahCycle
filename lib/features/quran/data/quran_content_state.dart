enum QuranContentUnavailableReason {
  notConfigured,
  notDownloaded,
  networkFailure,
  invalidProviderResponse,
  providerRejectedRequest,
  credentialsRequireBackend,
  cacheFailure,
}

/// Safe, localizable error information. It deliberately carries no provider
/// response body or Quran text.
final class QuranContentIssue {
  const QuranContentIssue({required this.reason, required this.code});

  final QuranContentUnavailableReason reason;
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranContentIssue &&
          reason == other.reason &&
          code == other.code;

  @override
  int get hashCode => Object.hash(reason, code);
}

sealed class QuranContentState<T> {
  const QuranContentState();

  bool get isAvailable => this is AvailableQuranContent<T>;
}

final class UnavailableQuranContent<T> extends QuranContentState<T> {
  const UnavailableQuranContent({required this.issue});

  final QuranContentIssue issue;
}

final class AvailableQuranContent<T> extends QuranContentState<T> {
  const AvailableQuranContent({
    required this.value,
    required this.fromCache,
    this.issue,
  });

  final T value;
  final bool fromCache;

  /// A non-fatal issue, for example a failed refresh when cached content was
  /// returned successfully.
  final QuranContentIssue? issue;
}
