import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization_extensions.dart';
import '../../../core/sync/sync.dart';
import '../../../l10n/app_localizations.dart';
import '../application/account_providers.dart';

/// Everything the app is willing to say about the user's account.
///
/// It renders [SyncStatus] and nothing else. The decision of what may be shown
/// lives in that type, in one ordered place, so this screen cannot accidentally
/// present a cheerful summary over a queue that never drained.
///
/// One state is deliberately **not** a [SyncStatus] at all: not knowing. When
/// the account cannot be reached, the provider carries an error, and that is
/// rendered as "could not reach" rather than as "signed out". Those two look
/// identical to an offline device and mean opposite things to its owner.
final class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

final class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(syncStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: SafeArea(
        child: switch (status) {
          AsyncLoading<SyncStatus>() => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          AsyncError<SyncStatus>() => _unreachable(l10n),
          _ => _forStatus(l10n, status.requireValue),
        },
      ),
    );
  }

  Widget _unreachable(AppLocalizations l10n) => _Body(
    children: <Widget>[
      _StatusCard(
        title: l10n.accountUnknownTitle,
        body: l10n.accountUnknownBody,
        icon: Icons.cloud_off_outlined,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const ValueKey<String>('account-retry'),
        onPressed: _busy ? null : () => ref.invalidate(currentAccountProvider),
        child: Text(l10n.accountRetry),
      ),
    ],
  );

  Widget _forStatus(AppLocalizations l10n, SyncStatus status) =>
      switch (status.health) {
        SyncHealth.unavailable => _Body(
          children: <Widget>[
            _StatusCard(
              title: l10n.accountUnavailableTitle,
              body: l10n.accountUnavailableBody,
              icon: Icons.cloud_off_outlined,
            ),
          ],
        ),
        SyncHealth.misconfigured => _Body(
          children: <Widget>[
            _StatusCard(
              title: l10n.accountMisconfiguredTitle,
              body: l10n.accountMisconfiguredBody,
              icon: Icons.error_outline,
              // The reason comes from AppwriteConfig and is developer-facing.
              // It is shown because a build fault the user can report is worth
              // more than a tidy screen that hides it.
              detail: status.problem,
            ),
          ],
        ),
        SyncHealth.signedOut => _Body(
          children: <Widget>[
            _StatusCard(
              title: l10n.accountSignedOutTitle,
              body: l10n.accountSignedOutBody,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('account-sign-in-google'),
              onPressed: _busy ? null : () => _signIn(SyncAuthProvider.google),
              icon: const Icon(Icons.login),
              label: Text(l10n.accountSignInWithGoogle),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey<String>('account-sign-in-yandex'),
              onPressed: _busy ? null : () => _signIn(SyncAuthProvider.yandex),
              icon: const Icon(Icons.login),
              label: Text(l10n.accountSignInWithYandex),
            ),
          ],
        ),
        SyncHealth.notActivated => _signedIn(
          l10n,
          title: l10n.accountSyncOffTitle,
          body: l10n.accountSyncOffBody,
          icon: Icons.sync_disabled_outlined,
        ),
        // Every remaining case needs `isActivated`, and no activation gateway
        // exists yet, so none of them can occur today. They are rendered from
        // the counts SyncStatus already carries rather than from invented copy,
        // so whenever activation does land this stays truthful instead of
        // needing to be remembered.
        _ => _signedIn(
          l10n,
          title: l10n.accountSyncOnTitle,
          body: l10n.accountSyncCounts(
            status.queuedCount,
            status.quarantinedCount,
          ),
          icon: Icons.sync_outlined,
        ),
      };

  Widget _signedIn(
    AppLocalizations l10n, {
    required String title,
    required String body,
    required IconData icon,
  }) {
    final account = ref.watch(currentAccountProvider).valueOrNull;
    final providers = account?.linkedProviders ?? const <SyncAuthProvider>{};
    return _Body(
      children: <Widget>[
        _StatusCard(
          title: l10n.accountSignedInTitle,
          body: providers.isEmpty
              ? l10n.accountSignedInTitle
              : l10n.accountLinkedProviders(
                  providers.map((p) => _providerLabel(l10n, p)).join(' · '),
                ),
          icon: Icons.person,
        ),
        const SizedBox(height: 12),
        _StatusCard(title: title, body: body, icon: icon),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey<String>('account-sign-out'),
          onPressed: _busy ? null : _signOut,
          child: Text(l10n.accountSignOut),
        ),
      ],
    );
  }

  static String _providerLabel(AppLocalizations l10n, SyncAuthProvider p) =>
      switch (p) {
        SyncAuthProvider.google => l10n.accountProviderGoogle,
        SyncAuthProvider.yandex => l10n.accountProviderYandex,
      };

  Future<void> _signIn(SyncAuthProvider provider) async {
    final gateway = ref.read(accountGatewayProvider);
    if (gateway == null) {
      return;
    }
    await _run(
      () => gateway.signIn(provider),
      context.l10n.accountSignInFailed,
    );
  }

  Future<void> _signOut() async {
    final gateway = ref.read(accountGatewayProvider);
    if (gateway == null) {
      return;
    }
    await _run(gateway.signOut, context.l10n.accountSignOutFailed);
  }

  /// Runs one account action, then re-reads who is signed in.
  ///
  /// The re-read is not optional and is not an optimisation: the gateway's
  /// answer is the only thing that decides what this screen shows, so acting on
  /// the local assumption that the call worked is how a screen starts
  /// contradicting the server.
  Future<void> _run(
    Future<void> Function() action,
    String failureMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object {
      // The reason is deliberately not shown. It can carry a provider message,
      // and those quote the user's own address back at them.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } finally {
      ref.invalidate(currentAccountProvider);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

final class _Body extends StatelessWidget {
  const _Body({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: children);
}

final class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.body,
    required this.icon,
    this.detail,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    key: const ValueKey<String>('account-status-title'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodyMedium),
                  if (detail != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      detail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
