import 'package:murajaah/core/sync/sync.dart';

import 'sync_outbox_contract.dart';

/// The in-memory outbox is the reference implementation, so it runs the shared
/// contract unchanged. The durable one will run the very same suite.
void main() {
  runSyncOutboxContract('InMemorySyncOutbox', InMemorySyncOutbox.new);
}
