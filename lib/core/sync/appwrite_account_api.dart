/// The only file in the repository that talks to `package:appwrite`.
///
/// It holds no rules. Every decision — what counts as signed out, when a link
/// is refused — lives in [AppwriteAccountGateway], which is why that class can
/// be tested without a network. This adapter's single job is to turn the SDK's
/// exceptions into the two honest outcomes the port promises: a null user id
/// when there is genuinely no session, and a thrown error when the answer is
/// unknown.
library;

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as enums;

import 'appwrite_account_gateway.dart';
import 'appwrite_config.dart';

/// Builds a configured Appwrite client, or refuses to.
///
/// [config] must be [AppwriteConfigStatus.ready]; an absent or malformed
/// configuration is a decision the caller has to make before this point, so
/// that "no cloud in this build" and "cloud is broken" stay distinguishable.
Client createAppwriteClient(AppwriteConfig config) {
  if (!config.isReady) {
    throw ArgumentError.value(
      config,
      'config',
      'Refusing to build a client from a configuration that is not ready.',
    );
  }
  return Client().setEndpoint(config.endpoint).setProject(config.projectId);
}

final class LiveAppwriteAccountApi implements AppwriteAccountApi {
  LiveAppwriteAccountApi(Client client) : _account = Account(client);

  /// Visible for tests that supply their own [Account].
  LiveAppwriteAccountApi.withAccount(this._account);

  final Account _account;

  /// Appwrite answers an unauthenticated request with 401. That is the only
  /// code that means "no session"; every other failure means the question was
  /// not answered, and must not be flattened into "signed out".
  static const int _unauthorized = 401;

  /// Appwrite Cloud pauses a project that has gone unused and then answers
  /// **every** request to it with 403 and this type.
  static const String _projectPausedType = 'project_paused';

  /// A paused project, told apart from an ordinary refusal.
  ///
  /// Pure, and public for the test, for the same reason the sync adapter's
  /// classifier is: constructing an `Account` needs a client, a platform
  /// channel and a binding, and this decision should not need any of them to
  /// be examined.
  ///
  /// The **type**, not the code: 403 is also how a project refuses a request it
  /// understands perfectly well. Read off his phone on 2026-10-08, where the
  /// screen said "you may be offline" while the device could ping the endpoint
  /// in 110 ms — and where signing in again, the one thing the app suggested,
  /// could not have worked, because signing in is a request to the same paused
  /// project.
  static bool isProjectPaused(Object error) =>
      error is AppwriteException && error.type == _projectPausedType;

  @override
  Future<String?> currentUserId() async {
    try {
      final user = await _account.get();
      return user.$id;
    } on AppwriteException catch (error) {
      if (isProjectPaused(error)) {
        throw const SyncAccountException('account-project-paused');
      }
      if (error.code == _unauthorized) {
        return null;
      }
      throw SyncAccountException('account-read-failed-${error.code ?? 0}');
    } on Object {
      // Offline, DNS, TLS — unknown, not signed out.
      throw const SyncAccountException('account-unreachable');
    }
  }

  @override
  Future<List<String>> identityProviders() async {
    try {
      final identities = await _account.listIdentities();
      return <String>[
        for (final identity in identities.identities) identity.provider,
      ];
    } on AppwriteException catch (error) {
      if (isProjectPaused(error)) {
        throw const SyncAccountException('account-project-paused');
      }
      if (error.code == _unauthorized) {
        return const <String>[];
      }
      throw SyncAccountException('identities-read-failed-${error.code ?? 0}');
    } on Object {
      throw const SyncAccountException('account-unreachable');
    }
  }

  @override
  Future<void> createOAuth2Session(String providerName) async {
    final provider = _providerByName(providerName);
    try {
      await _account.createOAuth2Session(provider: provider);
    } on AppwriteException catch (error) {
      if (isProjectPaused(error)) {
        // Worth saying plainly here most of all: this is the call the screen
        // offers as the way out of every other failure, and against a paused
        // project it cannot work either.
        throw const SyncAccountException('account-project-paused');
      }
      // A provider that is registered with Google/Yandex but still switched
      // off in the Appwrite Console fails here, and it is worth its own
      // category: it is a configuration gap, not the user's mistake.
      throw SyncAccountException('oauth-failed-${error.code ?? 0}');
    } on Object {
      // Includes the user closing the browser tab before finishing.
      throw const SyncAccountException('oauth-cancelled-or-unreachable');
    }
  }

  @override
  Future<void> createEmailPasswordSession({
    required String email,
    required String password,
  }) async {
    try {
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
    } on AppwriteException catch (error) {
      if (isProjectPaused(error)) {
        throw const SyncAccountException('account-project-paused');
      }
      // The code and nothing else. A provider message here would carry the
      // address that was typed, and this file's whole contract is that a
      // reason is a category, never the user's own data.
      throw SyncAccountException('password-sign-in-failed-${error.code ?? 0}');
    } on Object {
      throw const SyncAccountException('account-unreachable');
    }
  }

  @override
  Future<void> deleteCurrentSession() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } on AppwriteException catch (error) {
      if (isProjectPaused(error)) {
        throw const SyncAccountException('account-project-paused');
      }
      if (error.code == _unauthorized) {
        // Already signed out. Signing out twice is not a failure.
        return;
      }
      throw SyncAccountException('sign-out-failed-${error.code ?? 0}');
    } on Object {
      throw const SyncAccountException('account-unreachable');
    }
  }

  static enums.OAuthProvider _providerByName(String name) => switch (name) {
    'google' => enums.OAuthProvider.google,
    'yandex' => enums.OAuthProvider.yandex,
    _ => throw ArgumentError.value(name, 'name', 'Unsupported provider.'),
  };
}
