import 'package:flutter/foundation.dart';
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

  /// The last preview, and the question it poses.
  ///
  /// Held rather than persisted: it is bound to counts read at one moment, and
  /// a preview that survived a restart would invite an answer to a question
  /// about data that has since moved. Cleared as soon as it is answered.
  SyncMergePreview? _preview;
  bool _previewFailed = false;

  /// What the last answer did, or null while none has been given.
  _ActivationOutcome? _outcome;

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
          AsyncError<SyncStatus>(:final error) => _unreachable(l10n, error),
          _ => _forStatus(l10n, status.requireValue),
        },
      ),
    );
  }

  /// Not knowing, with whatever the failure was willing to say.
  ///
  /// A paused project gets its own words rather than the offline ones. It is
  /// the case where every sentence on the old card was false — the server was
  /// answering, the user had not been signed out, and the retry it offered was
  /// the only control on screen — and the one where the owner can actually act,
  /// because restoring the project is a thing he does.
  ///
  /// Everything else keeps "could not reach" and gains the category underneath
  /// it, the way a misconfigured build already shows its reason. The same guard
  /// as everywhere else on this screen decides whether it may be shown: the
  /// adapters promise a category and never a provider message, and a reason
  /// that does not look like one is withheld rather than trusted, because the
  /// messages that break that promise are the ones quoting the user's own
  /// address.
  Widget _unreachable(AppLocalizations l10n, Object? error) {
    final reason = error is SyncAccountException ? error.reason : null;
    if (reason == _pausedProjectReason) {
      return _Body(
        children: <Widget>[
          _StatusCard(
            key: const ValueKey<String>('account-project-paused'),
            title: l10n.accountPausedTitle,
            body: l10n.accountPausedBody,
            icon: Icons.pause_circle_outline,
          ),
          const SizedBox(height: 12),
          _retryButton(l10n),
        ],
      );
    }
    return _Body(
      children: <Widget>[
        _StatusCard(
          title: l10n.accountUnknownTitle,
          body: l10n.accountUnknownBody,
          icon: Icons.cloud_off_outlined,
          detail: reason != null && _isCategory.hasMatch(reason)
              ? reason
              : null,
        ),
        const SizedBox(height: 12),
        _retryButton(l10n),
      ],
    );
  }

  Widget _retryButton(AppLocalizations l10n) => OutlinedButton(
    key: const ValueKey<String>('account-retry'),
    onPressed: _busy ? null : () => ref.invalidate(currentAccountProvider),
    child: Text(l10n.accountRetry),
  );

  static const String _pausedProjectReason = 'account-project-paused';

  /// What the adapters promise every reason looks like.
  static final RegExp _isCategory = RegExp(r'^[a-z0-9-]+$');

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
            // Absent from every build the owner will ever run: a release build
            // drops it on kDebugMode, and a debug build without the two defines
            // drops it on `configured`. Deliberately unlocalised — it is a
            // harness control, not product copy.
            if (kDebugMode && AcceptanceCredentials.configured) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>('account-sign-in-acceptance'),
                onPressed: _busy ? null : _signInForAcceptance,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Sign in as the acceptance test account'),
              ),
            ],
          ],
        ),
        SyncHealth.notActivated => _signedIn(
          l10n,
          title: l10n.accountSyncOffTitle,
          body: l10n.accountSyncOffBody,
          icon: Icons.sync_disabled_outlined,
          extra: _previewSection(l10n),
        ),
        // Every remaining case is an activated device, told apart by the counts
        // SyncStatus already carries rather than by invented copy.
        _ => _signedIn(
          l10n,
          title: l10n.accountSyncOnTitle,
          body: l10n.accountSyncCounts(
            status.queuedCount,
            status.quarantinedCount,
          ),
          icon: Icons.sync_outlined,
          extra: <Widget>[
            // A card of its own, and for the same reason the one below it is:
            // "Синхронизация включена · Ждут отправки: 0" is true of a device
            // whose pull has been dead since its first page, and it is what
            // his second phone showed for an hour on 2026-09-23 while it
            // received nothing. Every number on that screen was correct.
            //
            // The category behind it stays unshown, as everywhere else here:
            // it can name a transport, and what the owner does about any of
            // them is the same. What he could not tell before is *that* there
            // is anything to wait for.
            if (status.health == SyncHealth.retrying) ...<Widget>[
              const SizedBox(height: 12),
              _StatusCard(
                key: const ValueKey<String>('account-sync-failing'),
                title: l10n.accountSyncFailingTitle,
                body: l10n.accountSyncFailingBody,
                icon: Icons.sync_problem_outlined,
              ),
            ],
            // Records the backfill could not express are not in the queue and
            // never will be, so no count on this screen mentions them. Said
            // out loud or not at all: silence here reads as "everything went".
            if (status.backfillSkipped case final skipped?) ...<Widget>[
              const SizedBox(height: 12),
              _StatusCard(
                key: const ValueKey<String>('account-backfill-incomplete'),
                // Its own heading rather than the card above it: "sync is on"
                // over a warning is the sentence that made the warning easy to
                // read past in the first place.
                title: l10n.accountBackfillIncompleteTitle,
                body: l10n.accountBackfillIncomplete(
                  skipped.skippedCount,
                  skipped.skippedFields.join(', '),
                ),
                icon: Icons.report_problem_outlined,
              ),
            ],
            const SizedBox(height: 12),
            // A cycle runs on its own after activation and whenever the app
            // asks; this is here because a queue that is waiting on a network
            // is the one case where the user knows something the app does not —
            // that they are back online.
            OutlinedButton.icon(
              key: const ValueKey<String>('account-sync-now'),
              onPressed: _busy ? null : _syncNow,
              icon: const Icon(Icons.sync),
              label: Text(l10n.accountSyncNow),
            ),
            // The recovery a permanent refusal has always promised and nothing
            // offered. Deliberately a separate button and never automatic: a
            // queue that retried what the server called permanent, on its own,
            // would hammer it forever over something nobody had fixed. It
            // appears only when there is something to recover, and the count
            // says how much.
            if (status.quarantinedCount > 0) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>('account-retry-refused'),
                onPressed: _busy ? null : _retryRefused,
                icon: const Icon(Icons.replay),
                label: Text(l10n.accountRetryRefused(status.quarantinedCount)),
              ),
            ],
          ],
        ),
      };

  Widget _signedIn(
    AppLocalizations l10n, {
    required String title,
    required String body,
    required IconData icon,
    List<Widget> extra = const <Widget>[],
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
        ...extra,
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey<String>('account-sign-out'),
          onPressed: _busy ? null : _signOut,
          child: Text(l10n.accountSignOut),
        ),
      ],
    );
  }

  /// The dry run of a merge: a real backup, and real counts from both sides.
  ///
  /// Offered without a decision attached. The counts are the honest part and
  /// are worth having on their own — they are also what makes the eventual
  /// choice an informed one instead of a leap.
  List<Widget> _previewSection(AppLocalizations l10n) {
    final account = ref.watch(currentAccountProvider).valueOrNull;
    if (account == null) return const <Widget>[];
    if (ref.watch(syncActivationProvider(account.userId)) == null) {
      return const <Widget>[];
    }
    final preview = _preview;
    return <Widget>[
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const ValueKey<String>('account-preview-merge'),
        onPressed: _busy ? null : _preparePreview,
        icon: const Icon(Icons.fact_check_outlined),
        label: Text(l10n.accountPreviewButton),
      ),
      if (_previewFailed) ...<Widget>[
        const SizedBox(height: 12),
        _StatusCard(
          title: l10n.accountPreviewFailedTitle,
          body: l10n.accountPreviewFailedBody,
          icon: Icons.error_outline,
        ),
      ],
      if (preview != null) ...<Widget>[
        const SizedBox(height: 12),
        _StatusCard(
          key: const ValueKey<String>('account-preview-result'),
          title: l10n.accountPreviewTitle,
          body: l10n.accountPreviewCounts(
            preview.localOnlyCount,
            preview.remoteOnlyCount,
            preview.sharedCount,
          ),
          icon: Icons.fact_check_outlined,
          // Conflicts and undetermined entities are separate lines because
          // they are separate statements: one is known disagreement, the other
          // is an honest "cannot tell". Folding them together would present a
          // guess as a finding.
          detail: <String>[
            l10n.accountPreviewConflicts(preview.conflictCount),
            l10n.accountPreviewUndetermined(preview.undeterminedCount),
            l10n.accountPreviewBackup(preview.backupId),
            l10n.accountPreviewNoChoiceYet,
          ].join('\n'),
        ),
        const SizedBox(height: 12),
        // Both answers are offered as buttons of the same weight. Keeping the
        // device local is a real decision, not a way of postponing the merge,
        // and rendering it as a quiet link would say otherwise.
        FilledButton.icon(
          key: const ValueKey<String>('account-choose-merge'),
          onPressed: _busy
              ? null
              : () => _answer(preview, SyncActivationChoice.merge),
          icon: const Icon(Icons.merge_outlined),
          label: Text(l10n.accountChooseMerge),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey<String>('account-choose-keep-local'),
          onPressed: _busy
              ? null
              : () =>
                    _answer(preview, SyncActivationChoice.keepDeviceLocalOnly),
          icon: const Icon(Icons.phone_android_outlined),
          label: Text(l10n.accountChooseKeepLocal),
        ),
      ],
      if (_outcome case final outcome?) ...<Widget>[
        const SizedBox(height: 12),
        _StatusCard(
          key: const ValueKey<String>('account-activation-outcome'),
          title: switch (outcome) {
            _ActivationOutcome.merged => l10n.accountMergedTitle,
            _ActivationOutcome.keptLocal => l10n.accountKeptLocalTitle,
            _ActivationOutcome.failed => l10n.accountChoiceFailedTitle,
          },
          body: switch (outcome) {
            _ActivationOutcome.merged => l10n.accountMergedBody,
            _ActivationOutcome.keptLocal => l10n.accountKeptLocalBody,
            _ActivationOutcome.failed => l10n.accountChoiceFailedBody,
          },
          icon: switch (outcome) {
            _ActivationOutcome.merged => Icons.cloud_done_outlined,
            _ActivationOutcome.keptLocal => Icons.phone_android_outlined,
            _ActivationOutcome.failed => Icons.error_outline,
          },
        ),
      ],
    ];
  }

  /// Confirms the choice, then applies it.
  ///
  /// The confirmation names the backup rather than only promising one: the
  /// whole reason this gate exists is that a user cannot meaningfully agree to
  /// something they cannot undo, and the backup is what makes it undoable.
  Future<void> _answer(
    SyncMergePreview preview,
    SyncActivationChoice choice,
  ) async {
    final l10n = context.l10n;
    final isMerge = choice == SyncActivationChoice.merge;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey<String>('account-activation-confirm'),
        title: Text(
          isMerge
              ? l10n.accountMergeConfirmTitle
              : l10n.accountKeepLocalConfirmTitle,
        ),
        content: Text(
          isMerge
              ? l10n.accountMergeConfirmBody(preview.backupId)
              : l10n.accountKeepLocalConfirmBody,
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('account-activation-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.accountChoiceCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('account-activation-apply'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isMerge
                  ? l10n.accountMergeConfirmAction
                  : l10n.accountKeepLocalConfirmAction,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final account = ref.read(currentAccountProvider).valueOrNull;
    if (account == null) return;
    final coordinator = ref.read(syncActivationProvider(account.userId));
    if (coordinator == null) return;

    setState(() => _busy = true);
    try {
      await coordinator.finishFirstSync(
        previewToken: preview.token,
        choice: choice,
      );
      if (!mounted) return;
      setState(() {
        // The question has been answered; leaving it on screen would invite a
        // second answer that the coordinator would refuse anyway.
        _preview = null;
        _outcome = isMerge
            ? _ActivationOutcome.merged
            : _ActivationOutcome.keptLocal;
      });
      // The summary above is derived from durable state this has just changed.
      ref.invalidate(syncTransportProvider(account.userId));
      if (isMerge) {
        // The backfill has just queued the history. Sending it now is the
        // follow-through the user agreed to; leaving it for the next time
        // something happened to ask would mean a device that said "merging is
        // on" and had sent nothing.
        await _syncNow(silent: true);
      }
    } on Object {
      // The reason is deliberately unshown: it can name a transport or a store,
      // and the user's next step is the same for all of them. The token is
      // spent either way, so the message says to run the report again.
      if (mounted) {
        setState(() {
          _preview = null;
          _outcome = _ActivationOutcome.failed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preparePreview() async {
    final account = ref.read(currentAccountProvider).valueOrNull;
    if (account == null) return;
    final coordinator = ref.read(syncActivationProvider(account.userId));
    if (coordinator == null) return;
    setState(() {
      _busy = true;
      _previewFailed = false;
      // A fresh question supersedes the last answer's notice: leaving it up
      // beside new counts would read as if it described them.
      _outcome = null;
    });
    try {
      final preview = await coordinator.prepareFirstSync(account);
      if (mounted) setState(() => _preview = preview);
    } on Object {
      // Reason deliberately unshown: it can carry a transport detail, and the
      // user's answer to any of them is the same — try again later.
      if (mounted) {
        setState(() {
          _preview = null;
          _previewFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs one exchange with the account and reports what it did.
  ///
  /// [silent] suppresses the notice only — the cycle itself is identical. It is
  /// used right after activation, where the outcome card already says what
  /// happened and a snackbar on top of it would be two answers to one action.
  Future<void> _syncNow({bool silent = false}) async {
    final account = ref.read(currentAccountProvider).valueOrNull;
    if (account == null) return;
    final runner = ref.read(syncCycleProvider(account.userId));
    if (runner == null) return;

    setState(() => _busy = true);
    try {
      final outcome = await runner.runOnce();
      if (!mounted) return;
      // Whatever happened, the queue and the success record may have moved.
      ref.invalidate(syncTransportProvider(account.userId));
      if (silent) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey<String>('account-sync-now-result'),
          content: Text(
            outcome.hasFailure
                // The category is never shown: it can name a transport, and the
                // user's answer to any of them is the same.
                ? context.l10n.accountSyncNowFailed
                : context.l10n.accountSyncNowResult(
                    outcome.pushedCount,
                    outcome.remainingCount,
                  ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Offers the refused entries again, then sends them.
  ///
  /// Two steps rather than one button that only re-queues: putting records
  /// back in a queue and leaving them there would look identical to doing
  /// nothing, and the owner would have no way to tell which it was.
  Future<void> _retryRefused() async {
    final account = ref.read(currentAccountProvider).valueOrNull;
    if (account == null) return;
    final store = ref.read(syncStoreProvider(account.userId));

    setState(() => _busy = true);
    int requeued;
    try {
      requeued = await store.outbox.requeueQuarantined();
      if (!mounted) return;
      ref.invalidate(syncTransportProvider(account.userId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar(reason: SnackBarClosedReason.hide);
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey<String>('account-retry-refused-result'),
        content: Text(context.l10n.accountRetryRefusedResult(requeued)),
      ),
    );
    await _syncNow(silent: true);
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

  /// One tap, because the acceptance run drives this over ADB.
  ///
  /// The capability is asked for rather than cast to: a gateway that cannot do
  /// this simply does not offer it, and the button is already behind the same
  /// two conditions.
  Future<void> _signInForAcceptance() async {
    final gateway = ref.read(accountGatewayProvider);
    if (gateway is! DebugPasswordSignIn) {
      return;
    }
    await _run(
      () => (gateway as DebugPasswordSignIn).signInWithPassword(
        email: AcceptanceCredentials.email,
        password: AcceptanceCredentials.password,
      ),
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

/// What the last answer to the activation question did.
///
/// A failure is one of the three rather than an absence: "nothing happened"
/// and "your answer did not take effect" look identical on screen otherwise,
/// and only one of them means the user has to answer again.
enum _ActivationOutcome { merged, keptLocal, failed }

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
    super.key,
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
