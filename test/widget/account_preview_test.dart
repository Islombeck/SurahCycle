import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';
import 'package:murajaah/features/account/application/account_providers.dart';
import 'package:murajaah/features/account/presentation/account_screen.dart';
import 'package:murajaah/l10n/app_localizations.dart';

/// The preview is the moment the whole activation design exists for: the last
/// point at which a user can see what a merge would do and still say no.
///
/// What these tests hold it to is that it never overstates itself. It reports
/// counts, it says a backup was taken, and it says plainly that nothing was
/// sent and no choice is on offer — because nothing in the app moves data yet,
/// and a button whose effect cannot be observed is not consent.
void main() {
  final account = SyncAccount(
    userId: 'user-a',
    linkedProviders: const <SyncAuthProvider>{SyncAuthProvider.google},
  );

  Future<void> pump(
    WidgetTester tester, {
    required SyncActivationGateway? coordinator,
  }) async {
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
      find.textContaining('no choice is offered yet'),
      findsOneWidget,
      reason: 'the screen must not imply a merge is available',
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

final class _FakeCoordinator implements SyncActivationGateway {
  _FakeCoordinator({this.fail = false});

  final bool fail;
  int prepared = 0;

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
  }) async => throw UnimplementedError('No choice is offered yet.');

  @override
  Future<bool> isSyncActiveFor(String userId) async => false;
}
