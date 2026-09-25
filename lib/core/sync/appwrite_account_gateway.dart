/// The real [AccountGateway], backed by Appwrite.
///
/// This file establishes **identity only**. Signing in here does not move a
/// single recitation: activation is a separate, explicit decision
/// ([SyncActivationGateway]), and the data gateway does not exist yet because
/// no cloud tables have been provisioned. That separation is deliberate — an
/// account that silently started rewriting local history on first login is the
/// one failure this architecture is built to prevent.
library;

import 'package:flutter/foundation.dart';

import 'sync_ports.dart';

/// The slice of Appwrite's `Account` service this gateway needs.
///
/// It exists so the gateway's rules — what counts as signed out, when a link
/// is refused, what a changed user id means — are testable without a network,
/// a browser or a real project. The adapter that implements it against the SDK
/// holds no logic of its own.
abstract interface class AppwriteAccountApi {
  /// The signed-in user's id, or null when no session exists.
  ///
  /// Implementations must distinguish "no session" from "could not ask".
  /// Returning null on a network error would report a signed-in user as
  /// signed out and quietly strand their queued work.
  Future<String?> currentUserId();

  /// Provider names attached to the current account, as Appwrite spells them.
  Future<List<String>> identityProviders();

  /// Opens the provider's browser flow and completes the session.
  Future<void> createOAuth2Session(String providerName);

  /// Signs in with an email and a password. **Acceptance runs only.**
  ///
  /// See [DebugPasswordSignIn] for why this exists at all; the adapter merely
  /// performs it, and the refusal that keeps it out of a release build is one
  /// layer up, where it can be read next to the reason for it.
  Future<void> createEmailPasswordSession({
    required String email,
    required String password,
  });

  /// Ends the current session only. Other devices stay signed in.
  Future<void> deleteCurrentSession();
}

/// Signing in with a password, which the product deliberately does not offer.
///
/// The app authenticates with Google or Yandex and nothing else. That is the
/// right product decision and it is not changed here — but it means a test
/// account is a *Google account*, and the acceptance sequence needs two devices
/// on one account that is not the owner's. Registering an identity in his name
/// to satisfy a test is worse than this.
///
/// So: a password sign-in that exists for acceptance runs against a **separate
/// Appwrite project** with no real data in it, kept off the [AccountGateway]
/// port so nothing in the product can reach it by accident, and **refused
/// outside a debug build** rather than merely hidden from the screen.
///
/// It does not make the OAuth flow any less tested. It cannot: it is a
/// different path, and §6.6 item 2 is closed by the owner's own phones, not by
/// this.
abstract interface class DebugPasswordSignIn {
  /// Throws [SyncAccountException] `password-sign-in-is-debug-only` in a
  /// release build, before contacting anything.
  Future<SyncAccount> signInWithPassword({
    required String email,
    required String password,
  });
}

/// Raised when the account could not be reached or understood.
///
/// Deliberately distinct from [SyncIdentityLinkException]: one means "we do not
/// know", the other means "we know, and this is not allowed".
final class SyncAccountException implements Exception {
  const SyncAccountException(this.reason);

  /// A short category. Never a token, never a provider message that could
  /// carry the user's own address.
  final String reason;

  @override
  String toString() => 'SyncAccountException($reason)';
}

final class AppwriteAccountGateway
    implements AccountGateway, DebugPasswordSignIn {
  const AppwriteAccountGateway(this._api);

  final AppwriteAccountApi _api;

  /// Appwrite's own provider spelling, which is also what the redirect URIs
  /// registered with Google and Yandex are keyed by.
  static const Map<SyncAuthProvider, String> _providerNames =
      <SyncAuthProvider, String>{
        SyncAuthProvider.google: 'google',
        SyncAuthProvider.yandex: 'yandex',
      };

  static SyncAuthProvider? _providerFromName(String name) {
    for (final entry in _providerNames.entries) {
      if (entry.value == name) {
        return entry.key;
      }
    }
    // An unknown provider is not an error: the Console may have others enabled,
    // and a provider this build does not model is simply not shown. Dropping it
    // is safe; guessing which one it is would not be.
    return null;
  }

  @override
  Future<SyncAccount?> currentAccount() async {
    final userId = await _api.currentUserId();
    if (userId == null) {
      return null;
    }
    return _accountFor(userId);
  }

  @override
  Future<SyncAccount> signIn(SyncAuthProvider provider) async {
    await _api.createOAuth2Session(_nameOf(provider));
    final userId = await _api.currentUserId();
    if (userId == null) {
      // The browser flow returned without leaving a session behind. Treating
      // this as success would put the account screen into a signed-in state
      // that every later call contradicts.
      throw const SyncAccountException('no-session-after-sign-in');
    }
    return _accountFor(userId);
  }

  @override
  Future<SyncAccount> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!kDebugMode) {
      // Refused here rather than hidden in the widget tree. A screen that does
      // not draw a button is one edit away from drawing it; this is the layer
      // that has to say no.
      throw const SyncAccountException('password-sign-in-is-debug-only');
    }
    await _api.createEmailPasswordSession(email: email, password: password);
    final userId = await _api.currentUserId();
    if (userId == null) {
      throw const SyncAccountException('no-session-after-sign-in');
    }
    return _accountFor(userId);
  }

  @override
  Future<SyncAccount> linkIdentity(SyncAuthProvider provider) async {
    final before = await _api.currentUserId();
    if (before == null) {
      // The port's rule, enforced rather than documented: an unauthenticated
      // OAuth login is a sign-in. If it could also link, anyone who controls an
      // email address could attach themselves to someone else's history.
      throw const SyncIdentityLinkException('not-signed-in');
    }

    await _api.createOAuth2Session(_nameOf(provider));

    final after = await _api.currentUserId();
    if (after == null) {
      throw const SyncAccountException('no-session-after-link');
    }
    if (after != before) {
      // Appwrite attaches the new session to the logged-in account, but if the
      // provider's email already belongs to a different user it signs into that
      // one instead. That is a silent account switch, and the caller asked to
      // link, not to switch. Say so rather than returning a stranger's account
      // as though the link had worked.
      throw const SyncIdentityLinkException('provider-belongs-to-another-user');
    }
    return _accountFor(after);
  }

  @override
  Future<void> signOut() => _api.deleteCurrentSession();

  @override
  Future<Map<String, Object?>> exportCloudData() async {
    // There is no cloud data to export. No database or table has been
    // provisioned for this project yet, so the only thing an export could
    // honestly contain is the identity itself — and returning an empty map
    // shaped like a successful export would teach the user their history is
    // backed up when nothing of theirs has ever left the device.
    throw const SyncAccountException('cloud-data-not-provisioned');
  }

  @override
  Future<void> deleteCloudAccount() async {
    // Appwrite's client-side call is `account.updateStatus()`, and its own
    // documentation is explicit: "the user record is not deleted but
    // permanently blocked from any access. To completely delete a user, use
    // the Users API instead." The Users API needs an admin key, which this
    // repository forbids shipping in a client build.
    //
    // Blocking is not erasure. Offering it under this name would tell someone
    // exercising a data-deletion right that their record is gone while it is
    // retained, so this refuses until a server-side erasure path exists.
    throw const SyncAccountException('account-erasure-requires-server');
  }

  Future<SyncAccount> _accountFor(String userId) async {
    final names = await _api.identityProviders();
    final providers = <SyncAuthProvider>{};
    for (final name in names) {
      final provider = _providerFromName(name);
      if (provider != null) {
        providers.add(provider);
      }
    }
    return SyncAccount(userId: userId, linkedProviders: providers);
  }

  static String _nameOf(SyncAuthProvider provider) =>
      _providerNames[provider] ??
      (throw ArgumentError.value(provider, 'provider', 'Unsupported.'));
}
