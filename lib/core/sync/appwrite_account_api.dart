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

  @override
  Future<String?> currentUserId() async {
    try {
      final user = await _account.get();
      return user.$id;
    } on AppwriteException catch (error) {
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
  Future<void> deleteCurrentSession() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } on AppwriteException catch (error) {
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
