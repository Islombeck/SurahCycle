/// Providers for the account surface.
///
/// Kept out of `lib/app/app_providers.dart` on purpose: this is the one place
/// that reaches `appwrite_account_api.dart`, and that file imports
/// `package:appwrite`. Declaring these in the shared provider file would pull
/// the SDK into every widget test that only wanted a database.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/appwrite_account_api.dart';
import '../../../core/sync/sync.dart';

final appwriteConfigProvider = Provider<AppwriteConfig>(
  (ref) => AppwriteConfig.fromEnvironment(),
);

/// The live gateway, or null when this build has no usable configuration.
///
/// Null covers both "no cloud in this build" and "the cloud settings are
/// wrong". The screen tells those two apart from [AppwriteConfig] itself, not
/// from this being null, because they need different words: one is an ordinary
/// local-first state and the other is a fault someone has to fix.
final accountGatewayProvider = Provider<AccountGateway?>((ref) {
  final config = ref.watch(appwriteConfigProvider);
  if (!config.isReady) {
    return null;
  }
  return AppwriteAccountGateway(
    LiveAppwriteAccountApi(createAppwriteClient(config)),
  );
});

/// Who is signed in, or null for nobody.
///
/// An error here means **unknown**, not signed out. The gateway throws rather
/// than returning null when it could not ask, and that distinction has to
/// survive all the way to the screen: a device that is merely offline must not
/// be told it has no account.
final currentAccountProvider = FutureProvider<SyncAccount?>((ref) async {
  final gateway = ref.watch(accountGatewayProvider);
  if (gateway == null) {
    return null;
  }
  return gateway.currentAccount();
});

/// The single summary the account screen is allowed to render.
final syncStatusProvider = Provider<AsyncValue<SyncStatus>>((ref) {
  final config = ref.watch(appwriteConfigProvider);
  if (!config.isReady) {
    // Do not ask the network who is signed in when there is nowhere to ask.
    return AsyncValue<SyncStatus>.data(
      SyncStatus.resolve(config: config, isSignedIn: false, isActivated: false),
    );
  }
  return ref
      .watch(currentAccountProvider)
      .whenData(
        (account) => SyncStatus.resolve(
          config: config,
          isSignedIn: account != null,
          isActivated: false,
          // Queue counts are deliberately not read yet, and passing zero is
          // provably honest rather than convenient: nothing in the app enqueues
          // anything, because no repository is sync-aware. It is also
          // unreachable — SyncStatus.resolve decides `notActivated` before it
          // ever looks at a count.
          //
          // WHEN ACTIVATION LANDS, THIS MUST START READING THE REAL OUTBOX.
          // Leaving the zeros here would turn a queue full of unsent work into
          // a screen that says everything is fine.
        ),
      );
});
