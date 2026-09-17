import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization_extensions.dart';

/// The entry point to the account screen.
///
/// The subtitle says what it says on purpose. "Account" next to a sign-in
/// button reads as "turn on backup" to most people, and this app does not back
/// anything up: signing in establishes identity and moves nothing.
final class AccountSettingsCard extends StatelessWidget {
  const AccountSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        key: const ValueKey<String>('account-settings-entry'),
        leading: const Icon(Icons.person_outline),
        title: Text(l10n.accountTitle),
        subtitle: Text(l10n.accountCardSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/settings/account'),
      ),
    );
  }
}
