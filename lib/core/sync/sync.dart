/// Account and progress sync.
///
/// Design and local contracts only: nothing here is wired into the running app,
/// and there is no production [SyncGateway] or [AccountGateway] while no
/// backend project exists. See `docs/ACCOUNT_SYNC_ARCHITECTURE.md` and
/// `docs/adr/ADR-0001-account-sync-backend.md`.
library;

export 'fake_sync_backend.dart';
export 'in_memory_sync_outbox.dart';
export 'sync_engine.dart';
export 'sync_envelope.dart';
export 'sync_app_setting_policy.dart';
export 'sync_owner.dart';
export 'sync_ports.dart';
