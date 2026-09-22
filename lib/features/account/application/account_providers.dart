/// Providers for the account surface.
///
/// Kept out of `lib/app/app_providers.dart` on purpose: this is the one place
/// that reaches `appwrite_account_api.dart`, and that file imports
/// `package:appwrite`. Declaring these in the shared provider file would pull
/// the SDK into every widget test that only wanted a database.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/app_providers.dart';
import '../../../core/data/data.dart';
import '../../../core/data/sync/sync_recorder.dart';
import '../../../core/sync/appwrite_account_api.dart';
import '../../../core/sync/appwrite_sync_api.dart';
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

/// Where recovery copies live: a `backups` folder beside the database.
///
/// The application *support* directory, not documents: these are the app's own
/// recovery copies, not files the owner filed there himself, and on iOS the
/// documents directory is user-visible.
final backupDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}backups');
  },
);

/// On-demand local backup and recovery. Needs no account and no network.
final localBackupGatewayProvider = Provider<LocalBackupGateway>(
  (ref) => DriftLocalBackupGateway(
    database: ref.watch(appDatabaseProvider),
    backupDirectory: ref.watch(backupDirectoryProvider),
    nowUtc: ref.watch(timeProviderProvider).nowUtc,
  ),
);

/// The transport, bound to one account, or null when there is nowhere to talk
/// to or nobody signed in.
///
/// A family on the user id rather than a lookup inside: a gateway that
/// re-read the session per call could straddle two accounts mid-batch, which
/// is the one thing owner scoping exists to prevent.
final syncGatewayProvider = Provider.family<SyncGateway?, String>((
  ref,
  userId,
) {
  final config = ref.watch(appwriteConfigProvider);
  if (!config.isReady || userId.isEmpty) return null;
  return AppwriteSyncGateway(
    api: LiveAppwriteSyncApi(createAppwriteClient(config)),
    userId: userId,
  );
});

/// What this device holds and what the account holds, in comparable form.
final syncInventoryProvider = Provider.family<SyncInventory?, String>((
  ref,
  userId,
) {
  final gateway = ref.watch(syncGatewayProvider(userId));
  if (gateway == null) return null;
  return DriftSyncInventory(
    database: ref.watch(appDatabaseProvider),
    gateway: gateway,
    userId: userId,
  );
});

/// This device's durable sync state for one account: the queue, the cursor and
/// the activation row, all scoped by owner.
///
/// A family on the user id for the same reason the gateway is: two accounts on
/// one phone share a database and must share nothing else.
final syncStoreProvider = Provider.family<DriftSyncStore, String>(
  (ref, userId) => DriftSyncStore(
    ref.watch(appDatabaseProvider),
    owner: SyncOwnerKey.user(userId),
  ),
);

/// The id this device is known by inside an account.
///
/// Created on first read and stored; random, never derived from the hardware.
/// Returned as a function rather than a value because it is read from settings,
/// which a synchronous provider cannot await.
final syncDeviceIdProvider = Provider<Future<String> Function()>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  final timeProvider = ref.watch(timeProviderProvider);
  return () => SyncDeviceId.ensure(
    settings,
    newId: _randomToken,
    nowUtc: timeProvider.nowUtc(),
  );
});

/// Turns the history already on this device into queued envelopes.
///
/// Only activation uses it, and only after the owner has agreed to a merge.
final syncBackfillProvider = Provider.family<SyncBackfill, String>(
  (ref, userId) => DriftSyncBackfill(
    database: ref.watch(appDatabaseProvider),
    outbox: ref.watch(syncStoreProvider(userId)).outbox,
    deviceId: ref.watch(syncDeviceIdProvider),
    newId: _randomToken,
  ),
);

/// The gate between signing in and letting an account touch local data.
///
/// Null when there is no usable configuration or nobody signed in — the screen
/// then has nothing to offer, which is the correct empty state rather than a
/// button that would fail on being pressed.
final syncActivationProvider = Provider.family<SyncActivationGateway?, String>((
  ref,
  userId,
) {
  final inventory = ref.watch(syncInventoryProvider(userId));
  if (inventory == null) return null;
  return SyncActivationCoordinator(
    store: ref.watch(syncStoreProvider(userId)),
    backups: ref.watch(localBackupGatewayProvider),
    inventory: inventory,
    backfill: ref.watch(syncBackfillProvider(userId)),
    nowUtc: ref.watch(timeProviderProvider).nowUtc,
    // Random rather than sequential: the token's job is to bind one
    // confirmation to one snapshot, and a guessable one would let a stale
    // dialog match a preview it was never shown.
    createToken: () => 'preview-${_randomToken()}',
  );
});

/// A random identifier, from the secure generator.
///
/// The same source for envelope ids, idempotency keys, device ids and preview
/// tokens: all four are only ever required to be unique and unguessable, and a
/// sequential counter would make a preview token predictable.
String _randomToken() =>
    '${Random.secure().nextInt(1 << 32).toRadixString(16)}'
    '${Random.secure().nextInt(1 << 32).toRadixString(16)}';

/// The single summary the account screen is allowed to render.
final syncStatusProvider = Provider<AsyncValue<SyncStatus>>((ref) {
  final config = ref.watch(appwriteConfigProvider);
  if (!config.isReady) {
    // Do not ask the network who is signed in when there is nowhere to ask.
    return AsyncValue<SyncStatus>.data(
      SyncStatus.resolve(config: config, isSignedIn: false, isActivated: false),
    );
  }
  final account = ref.watch(currentAccountProvider);
  final user = account.valueOrNull;
  if (user == null) {
    return account.whenData(
      (_) => SyncStatus.resolve(
        config: config,
        isSignedIn: false,
        isActivated: false,
      ),
    );
  }
  // Nobody-signed-in is answered above without touching the database, so the
  // only case that waits on a read is the one where the numbers matter.
  return ref
      .watch(syncTransportProvider(user.userId))
      .whenData(
        (transport) => SyncStatus.resolve(
          config: config,
          isSignedIn: true,
          isActivated: transport.isActivated,
          queuedCount: transport.queuedCount,
          quarantinedCount: transport.quarantinedCount,
          lastSuccessAtUtc: transport.lastSuccessAtUtc,
          lastFailureReason: transport.lastFailureReason,
          consecutiveFailureCount: transport.consecutiveFailureCount,
          backfill: transport.backfill,
        ),
      );
});

/// One complete exchange with the account, when something asks for it.
///
/// Null when there is no transport in this build or nobody signed in — the same
/// empty state as everything else here, rather than a runner that would fail on
/// being called.
///
/// Kept alive for the life of the provider rather than made per call: the
/// runner holds the "one cycle at a time" guard, and a fresh instance per tap
/// would have nothing to guard.
final syncCycleProvider = Provider.family<SyncCycle?, String>((ref, userId) {
  final gateway = ref.watch(syncGatewayProvider(userId));
  if (gateway == null) return null;
  return SyncCycleRunner(
    database: ref.watch(appDatabaseProvider),
    store: ref.watch(syncStoreProvider(userId)),
    gateway: gateway,
    nowUtc: ref.watch(timeProviderProvider).nowUtc,
    // The same walk that filled the queue at activation, asked a narrower
    // question. Without it a change made after activation would sit in the
    // database with nothing to carry it.
    scan: ref.watch(syncBackfillProvider(userId)),
  );
});

/// The durable queue and activation state, read as one consistent moment.
///
/// A future rather than a stream on purpose: this screen is not a live monitor,
/// and a summary that re-rendered on every enqueue during a backfill would
/// flicker through thousands of numbers that mean nothing individually. It is
/// invalidated at the points where it can actually have changed.
final syncTransportProvider =
    FutureProvider.family<SyncTransportSnapshot, String>(
      (ref, userId) => ref.watch(syncStoreProvider(userId)).transportSnapshot(),
    );
