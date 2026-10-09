/// Account and progress sync.
///
/// [AccountGateway] now has a production implementation
/// ([AppwriteAccountGateway]); [SyncGateway] still does not, because no cloud
/// table has been provisioned. Signing in is therefore possible and moving data
/// is not — which is exactly the split the architecture asks for, not a gap.
/// See `docs/ACCOUNT_SYNC_ARCHITECTURE.md` and
/// `docs/adr/ADR-0001-account-sync-backend.md`.
///
/// `appwrite_account_api.dart` and `appwrite_sync_api.dart` are deliberately
/// **not** exported here: they are the two files that import
/// `package:appwrite`, and re-exporting either drags the SDK into every unit
/// test that only wanted an envelope.
///
/// `appwrite_sync_api.dart` *was* exported for a while, and by the time it was
/// noticed `lib/core/data/data.dart` — which every widget test imports — had
/// the SDK in its graph. Nothing failed, because a platform channel only breaks
/// when it is called, which is exactly why the rule needs to be kept rather
/// than rediscovered. Import it directly where the SDK is already owned.
library;

export 'acceptance_credentials.dart';
export 'appwrite_account_gateway.dart';
export 'appwrite_config.dart';
export 'appwrite_sync_gateway.dart';
export 'fake_sync_backend.dart';
export 'in_memory_sync_outbox.dart';
export 'sync_activation_coordinator.dart';
export 'sync_app_setting_policy.dart';
export 'sync_backfill.dart';
export 'sync_cycle.dart';
export 'sync_engine.dart';
export 'sync_envelope.dart';
export 'sync_merge_decision.dart';
export 'sync_owner.dart';
export 'sync_ports.dart';
export 'sync_status.dart';
