/// Account and progress sync.
///
/// [AccountGateway] now has a production implementation
/// ([AppwriteAccountGateway]); [SyncGateway] still does not, because no cloud
/// table has been provisioned. Signing in is therefore possible and moving data
/// is not — which is exactly the split the architecture asks for, not a gap.
/// See `docs/ACCOUNT_SYNC_ARCHITECTURE.md` and
/// `docs/adr/ADR-0001-account-sync-backend.md`.
///
/// `appwrite_account_api.dart` is deliberately **not** exported here: it is the
/// one file that imports `package:appwrite`, and re-exporting it would drag the
/// SDK into every unit test that only wanted an envelope.
library;

export 'appwrite_account_gateway.dart';
export 'appwrite_config.dart';
export 'appwrite_sync_api.dart';
export 'appwrite_sync_gateway.dart';
export 'fake_sync_backend.dart';
export 'in_memory_sync_outbox.dart';
export 'sync_activation_coordinator.dart';
export 'sync_engine.dart';
export 'sync_envelope.dart';
export 'sync_app_setting_policy.dart';
export 'sync_owner.dart';
export 'sync_ports.dart';
export 'sync_status.dart';
