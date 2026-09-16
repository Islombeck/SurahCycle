/// The public half of the Appwrite client configuration.
///
/// Endpoint and project id are public by design: they ship inside every copy
/// of the app and identify a project, they do not authorise anything. They are
/// also the **only** Appwrite values this repository is allowed to contain. An
/// API key or an OAuth client secret in a client build is not a secret at all
/// — it is a secret handed to every user who installs it — so those live in
/// the Appwrite Console and in the owner's local environment, never here.
///
/// Nothing in this file talks to Appwrite. It decides, before any request is
/// attempted, whether there is a usable configuration at all, so that a
/// missing one can be reported as missing rather than surfacing later as a
/// sync that quietly never happens.
library;

/// Why a configuration cannot be used, or that it can.
enum AppwriteConfigStatus {
  /// Usable: both values are present and well-formed.
  ready,

  /// Nothing was supplied. The app is local-first, so this is an ordinary
  /// state, not a fault — it means "no account features", not "sync failed".
  absent,

  /// Something was supplied and is wrong. This *is* a fault, and has to be
  /// visible: a typo in an endpoint would otherwise look identical to being
  /// offline, and the user would be told to check their connection forever.
  malformed,
}

final class AppwriteConfig {
  const AppwriteConfig._({
    required this.status,
    required this.endpoint,
    required this.projectId,
    required this.problem,
  });

  /// Validates a candidate configuration without contacting anything.
  factory AppwriteConfig.resolve({
    required String endpoint,
    required String projectId,
  }) {
    final trimmedEndpoint = endpoint.trim();
    final trimmedProjectId = projectId.trim();
    if (trimmedEndpoint.isEmpty && trimmedProjectId.isEmpty) {
      return const AppwriteConfig._(
        status: AppwriteConfigStatus.absent,
        endpoint: '',
        projectId: '',
        problem: null,
      );
    }
    // Half a configuration is a mistake, not an opt-out: someone meant to set
    // both and set one.
    if (trimmedEndpoint.isEmpty || trimmedProjectId.isEmpty) {
      return AppwriteConfig._(
        status: AppwriteConfigStatus.malformed,
        endpoint: trimmedEndpoint,
        projectId: trimmedProjectId,
        problem: trimmedEndpoint.isEmpty
            ? 'The Appwrite endpoint is missing.'
            : 'The Appwrite project id is missing.',
      );
    }
    final uri = Uri.tryParse(trimmedEndpoint);
    if (uri == null || !uri.isAbsolute) {
      return AppwriteConfig._(
        status: AppwriteConfigStatus.malformed,
        endpoint: trimmedEndpoint,
        projectId: trimmedProjectId,
        problem: 'The Appwrite endpoint is not an absolute URL.',
      );
    }
    // Plain http would put every request, and every session token in it, on
    // the wire in the clear. There is no development exception here: a debug
    // build runs against the same real account.
    if (uri.scheme != 'https') {
      return AppwriteConfig._(
        status: AppwriteConfigStatus.malformed,
        endpoint: trimmedEndpoint,
        projectId: trimmedProjectId,
        problem: 'The Appwrite endpoint must use https.',
      );
    }
    if (!uri.path.endsWith('/v1')) {
      return AppwriteConfig._(
        status: AppwriteConfigStatus.malformed,
        endpoint: trimmedEndpoint,
        projectId: trimmedProjectId,
        problem: 'The Appwrite endpoint must end with the API version, /v1.',
      );
    }
    return AppwriteConfig._(
      status: AppwriteConfigStatus.ready,
      endpoint: trimmedEndpoint,
      projectId: trimmedProjectId,
      problem: null,
    );
  }

  /// What a build was compiled with.
  ///
  /// Both values are read from the compile environment so a fork, a test
  /// project or a second region needs no code change. The defaults are the
  /// owner's real, public SurahCycle values.
  factory AppwriteConfig.fromEnvironment() => AppwriteConfig.resolve(
    endpoint: const String.fromEnvironment(
      'APPWRITE_ENDPOINT',
      defaultValue: 'https://fra.cloud.appwrite.io/v1',
    ),
    projectId: const String.fromEnvironment(
      'APPWRITE_PROJECT_ID',
      defaultValue: '6aa91956000d1d490a3e',
    ),
  );

  final AppwriteConfigStatus status;
  final String endpoint;
  final String projectId;

  /// Human-readable reason, present exactly when [status] is
  /// [AppwriteConfigStatus.malformed].
  final String? problem;

  bool get isReady => status == AppwriteConfigStatus.ready;

  /// True when the user simply has no cloud configured. The app is local-first,
  /// so everything except account features keeps working.
  bool get isAbsent => status == AppwriteConfigStatus.absent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppwriteConfig &&
          status == other.status &&
          endpoint == other.endpoint &&
          projectId == other.projectId &&
          problem == other.problem;

  @override
  int get hashCode => Object.hash(status, endpoint, projectId, problem);

  /// Deliberately omits nothing sensitive, because nothing here is sensitive —
  /// and says so, so that no one later adds a secret to this class and leaks
  /// it through a log line.
  @override
  String toString() =>
      'AppwriteConfig(${status.name}, endpoint: $endpoint, '
      'projectId: $projectId${problem == null ? '' : ', problem: $problem'})';
}
