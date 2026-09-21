import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/data/sync/drift_sync_store.dart';
import 'package:murajaah/core/sync/sync.dart';
import 'package:murajaah/features/account/application/account_providers.dart';
import 'package:murajaah/features/account/presentation/account_screen.dart';
import 'package:murajaah/l10n/app_localizations.dart';

/// The preview is the moment the whole activation design exists for: the last
/// point at which a user can see what a merge would do and still say no.
///
/// What these tests hold it to is that it never overstates itself, and that
/// both answers are really available — "keep this device local" is a decision
/// with its own consequences, not a way of putting the merge off.
void main() {
  final account = SyncAccount(
    userId: 'user-a',
    linkedProviders: const <SyncAuthProvider>{SyncAuthProvider.google},
  );

  Future<void> pump(
    WidgetTester tester, {
    required SyncActivationGateway? coordinator,
    _FakeCycle? cycle,
  }) async {
    // The card, the counts and both answers together are taller than the
    // default 800pt surface, and a list does not build what it cannot show —
    // which reads in a test exactly like a missing button.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          currentAccountProvider.overrideWith((ref) async => account),
          syncStatusProvider.overrideWith(
            (ref) => AsyncValue<SyncStatus>.data(
              SyncStatus.resolve(
                config: AppwriteConfig.resolve(
                  endpoint: 'https://fra.cloud.appwrite.io/v1',
                  projectId: 'test-project',
                ),
                isSignedIn: true,
                isActivated: false,
              ),
            ),
          ),
          syncActivationProvider.overrideWith((ref, userId) => coordinator),
          syncCycleProvider.overrideWith((ref, userId) => cycle),
          syncTransportProvider.overrideWith(
            (ref, userId) async => SyncTransportSnapshot.inactive,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder button() =>
      find.byKey(const ValueKey<String>('account-preview-merge'));
  Finder result() =>
      find.byKey(const ValueKey<String>('account-preview-result'));
  Finder merge() => find.byKey(const ValueKey<String>('account-choose-merge'));
  Finder keepLocal() =>
      find.byKey(const ValueKey<String>('account-choose-keep-local'));

  testWidgets('nothing is offered when there is no coordinator', (
    tester,
  ) async {
    await pump(tester, coordinator: null);

    expect(
      button(),
      findsNothing,
      reason: 'a button that would fail on being pressed is worse than none',
    );
  });

  testWidgets('the report is only shown once it has been asked for', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator();
    await pump(tester, coordinator: coordinator);

    expect(button(), findsOneWidget);
    expect(result(), findsNothing);
    expect(
      coordinator.prepared,
      0,
      reason:
          'preparing takes a backup, so it must not happen just by opening '
          'the screen',
    );

    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(coordinator.prepared, 1);
    expect(result(), findsOneWidget);
  });

  testWidgets('it reports both sides, and says nothing was sent', (
    tester,
  ) async {
    await pump(tester, coordinator: _FakeCoordinator());

    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(find.textContaining('On this device only: 697'), findsOneWidget);
    expect(find.textContaining('In the account only: 0'), findsOneWidget);
    expect(find.textContaining('On both sides: 3'), findsOneWidget);
    expect(find.textContaining('Disagree: 1'), findsOneWidget);
    expect(
      find.textContaining('Cannot be compared: 2'),
      findsOneWidget,
      reason:
          'a known disagreement and an honest "unknown" are different '
          'statements and must not share a line',
    );
    expect(find.textContaining('backup-1'), findsOneWidget);
    expect(
      find.textContaining('The decision is below'),
      findsOneWidget,
      reason: 'the counts are a report; the answer is a separate, later act',
    );
  });

  testWidgets('both answers are offered, and only after the report', (
    tester,
  ) async {
    await pump(tester, coordinator: _FakeCoordinator());

    expect(merge(), findsNothing, reason: 'there is nothing to agree to yet');
    expect(keepLocal(), findsNothing);

    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(merge(), findsOneWidget);
    expect(
      keepLocal(),
      findsOneWidget,
      reason:
          'the honest third option has to be on screen beside the merge, not '
          'hidden behind a back button',
    );
  });

  testWidgets('a merge is confirmed against the backup it was shown', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator();
    await pump(tester, coordinator: coordinator);
    await tester.tap(button());
    await tester.pumpAndSettle();

    await tester.tap(merge());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('backup-1'),
      findsWidgets,
      reason:
          'a merge is agreeable only because it can be undone, so the dialog '
          'names the copy rather than promising one',
    );
    expect(coordinator.answered, isEmpty, reason: 'nothing until it is agreed');

    await tester.tap(
      find.byKey(const ValueKey<String>('account-activation-apply')),
    );
    await tester.pumpAndSettle();

    expect(coordinator.answered, <SyncActivationChoice>[
      SyncActivationChoice.merge,
    ]);
    expect(
      coordinator.tokens,
      <String>['preview-abc'],
      reason: 'the answer quotes back the exact snapshot it was given for',
    );
    expect(find.textContaining('Merging is on'), findsOneWidget);
    expect(
      result(),
      findsNothing,
      reason:
          'the question has been answered; leaving it up invites a second '
          'answer the coordinator would refuse',
    );
  });

  testWidgets('agreeing to a merge actually starts one', (tester) async {
    final cycle = _FakeCycle();
    await pump(tester, coordinator: _FakeCoordinator(), cycle: cycle);
    await tester.tap(button());
    await tester.pumpAndSettle();

    await tester.tap(merge());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('account-activation-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      cycle.runs,
      1,
      reason:
          'the backfill has just queued the history; a device that said '
          '"merging is on" and had sent nothing is the failure this avoids',
    );
    expect(
      find.byKey(const ValueKey<String>('account-sync-now-result')),
      findsNothing,
      reason:
          'the outcome card already says what happened, and a snackbar on top '
          'would be two answers to one action',
    );
  });

  testWidgets('keeping the device local starts nothing', (tester) async {
    final cycle = _FakeCycle();
    await pump(tester, coordinator: _FakeCoordinator(), cycle: cycle);
    await tester.tap(button());
    await tester.pumpAndSettle();

    await tester.tap(keepLocal());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('account-activation-apply')),
    );
    await tester.pumpAndSettle();

    expect(cycle.runs, 0);
  });

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    final coordinator = _FakeCoordinator();
    await pump(tester, coordinator: coordinator);
    await tester.tap(button());
    await tester.pumpAndSettle();

    await tester.tap(keepLocal());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('account-activation-cancel')),
    );
    await tester.pumpAndSettle();

    expect(coordinator.answered, isEmpty);
    expect(
      result(),
      findsOneWidget,
      reason: 'the question is still open and still shows its counts',
    );
  });

  testWidgets('keeping the device local says so plainly', (tester) async {
    final coordinator = _FakeCoordinator();
    await pump(tester, coordinator: coordinator);
    await tester.tap(button());
    await tester.pumpAndSettle();

    await tester.tap(keepLocal());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('account-activation-apply')),
    );
    await tester.pumpAndSettle();

    expect(coordinator.answered, <SyncActivationChoice>[
      SyncActivationChoice.keepDeviceLocalOnly,
    ]);
    expect(find.textContaining('This device stays local'), findsOneWidget);
    expect(find.textContaining('Nothing is sent'), findsOneWidget);
  });

  testWidgets('a refused answer does not look like nothing happened', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator(refuseAnswer: true);
    await pump(tester, coordinator: coordinator);
    await tester.tap(button());
    await tester.pumpAndSettle();

    await tester.tap(merge());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('account-activation-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('was not applied'),
      findsOneWidget,
      reason:
          'a silent return would read as success, and sync would be off with '
          'nobody aware of it',
    );
    expect(
      find.textContaining('Run the report again'),
      findsOneWidget,
      reason: 'the token is spent either way, so this is the real next step',
    );
  });

  testWidgets('a failure says so and claims no counts', (tester) async {
    await pump(tester, coordinator: _FakeCoordinator(fail: true));

    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(result(), findsNothing);
    expect(find.textContaining('No report'), findsOneWidget);
    expect(
      find.textContaining('Nothing was changed'),
      findsOneWidget,
      reason: 'the one thing a user needs to know after a failed dry run',
    );
  });
}

final class _FakeCycle implements SyncCycle {
  int runs = 0;

  @override
  Future<SyncCycleOutcome> runOnce() async {
    runs++;
    return const SyncCycleOutcome(ran: true, pushedCount: 700);
  }
}

final class _FakeCoordinator implements SyncActivationGateway {
  _FakeCoordinator({this.fail = false, this.refuseAnswer = false});

  final bool fail;

  /// Makes `finishFirstSync` throw, which is how a spent token or an
  /// unreachable queue reaches the screen.
  final bool refuseAnswer;

  int prepared = 0;
  final List<SyncActivationChoice> answered = <SyncActivationChoice>[];
  final List<String> tokens = <String>[];

  @override
  Future<SyncMergePreview> prepareFirstSync(SyncAccount account) async {
    prepared++;
    if (fail) throw const SyncTransportException('sync-unreachable');
    return SyncMergePreview(
      token: 'preview-abc',
      backupId: 'backup-1',
      localOnlyCount: 697,
      remoteOnlyCount: 0,
      sharedCount: 3,
      conflictCount: 1,
      undeterminedCount: 2,
    );
  }

  @override
  Future<void> finishFirstSync({
    required String previewToken,
    required SyncActivationChoice choice,
  }) async {
    if (refuseAnswer) {
      throw const SyncActivationException('preview-superseded');
    }
    tokens.add(previewToken);
    answered.add(choice);
  }

  @override
  Future<bool> isSyncActiveFor(String userId) async => false;
}
