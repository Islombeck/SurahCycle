import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/app/app_providers.dart';
import 'package:murajaah/core/data/data.dart';
import 'package:murajaah/core/sync/sync.dart';
import 'package:murajaah/features/account/application/account_providers.dart';
import 'package:murajaah/features/account/presentation/account_screen.dart';
import 'package:murajaah/l10n/app_localizations.dart';

final class _FakeCycle implements SyncCycle {
  int runs = 0;

  @override
  Future<SyncCycleOutcome> runOnce() async {
    runs++;
    return const SyncCycleOutcome(ran: true, pushedCount: 4);
  }
}

final _user = SyncAccount(
  userId: 'user-1',
  linkedProviders: const <SyncAuthProvider>{SyncAuthProvider.google},
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('a build with no cloud says so and offers no sign-in', (
    tester,
  ) async {
    await _pump(tester, config: _absent);

    expect(find.text(l10n.accountUnavailableTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('account-sign-in-google')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('account-sign-in-yandex')),
      findsNothing,
    );
  });

  testWidgets('a broken configuration is shown as a build fault, with reason', (
    tester,
  ) async {
    await _pump(tester, config: _malformed);

    expect(find.text(l10n.accountMisconfiguredTitle), findsOneWidget);
    // The reason is developer-facing but shown anyway: a fault the owner can
    // report beats a tidy screen that hides it behind "check your connection".
    expect(find.textContaining('https'), findsOneWidget);
  });

  testWidgets('signed out offers both providers', (tester) async {
    await _pump(tester, account: null);

    expect(find.text(l10n.accountSignedOutTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('account-sign-in-google')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('account-sign-in-yandex')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('account-sign-out')),
      findsNothing,
    );
  });

  testWidgets('signed in says sync is off, and never implies otherwise', (
    tester,
  ) async {
    await _pump(
      tester,
      account: SyncAccount(
        userId: 'user-1',
        linkedProviders: const <SyncAuthProvider>{SyncAuthProvider.google},
      ),
    );

    expect(find.text(l10n.accountSignedInTitle), findsOneWidget);
    expect(find.text(l10n.accountSyncOffTitle), findsOneWidget);
    expect(find.text(l10n.accountSyncOnTitle), findsNothing);
    expect(
      find.text(l10n.accountLinkedProviders(l10n.accountProviderGoogle)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('account-sign-out')),
      findsOneWidget,
    );
  });

  testWidgets('an activated device reports the real queue', (tester) async {
    // Until the summary read the durable state, this screen said "sync is off"
    // whatever the queue held. A backfill that had put a lifetime of history in
    // the outbox would have been invisible on the one screen meant to report it.
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 697,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
      ),
    );

    expect(find.text(l10n.accountSyncOnTitle), findsOneWidget);
    expect(find.text(l10n.accountSyncOffTitle), findsNothing);
    expect(
      find.textContaining('697'),
      findsOneWidget,
      reason: 'the number of unsent changes is the point of the screen',
    );
  });

  testWidgets('a device that has never synced is not shown as safe', (
    tester,
  ) async {
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 0,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
      ),
    );

    // An empty queue and no success on record is not "up to date": nothing has
    // reached the account, and saying otherwise is a lie about where the data
    // is. The screen may say sync is on; it may not say it worked.
    expect(find.text(l10n.accountSyncOnTitle), findsOneWidget);
    expect(find.textContaining('0'), findsWidgets);
  });

  testWidgets('an activated device can ask for a cycle by hand', (
    tester,
  ) async {
    final runner = _FakeCycle();
    await _pump(
      tester,
      account: _user,
      cycle: runner,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 4,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: 'network-unreachable',
        consecutiveFailureCount: 2,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('account-sync-now')));
    await tester.pumpAndSettle();

    expect(
      runner.runs,
      1,
      reason:
          'a queue waiting on a network is the one case where the user knows '
          'something the app does not: that they are back online',
    );
    expect(
      find.byKey(const ValueKey<String>('account-sync-now-result')),
      findsOneWidget,
      reason: 'a button with no visible effect teaches that it does nothing',
    );
  });

  testWidgets('a refused change is surfaced, not left to rot', (tester) async {
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 0,
        quarantinedCount: 2,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
      ),
    );

    expect(
      find.textContaining('2'),
      findsWidgets,
      reason:
          'quarantine blocks nothing, which is exactly why it has to be said '
          'out loud rather than waited on',
    );
  });

  testWidgets('records the merge could not send are said out loud', (
    tester,
  ) async {
    // Nothing else on this screen would mention them: they are not queued, so
    // "0 waiting" is true and reads as "everything went".
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 0,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
        backfill: SyncBackfillOutcome(
          enqueuedCount: 940,
          skippedCount: 12,
          skippedFields: <String>{'startedAtUtc'},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('account-backfill-incomplete')),
      findsOneWidget,
    );
    expect(find.textContaining('12'), findsWidgets);
    expect(
      find.textContaining('startedAtUtc'),
      findsOneWidget,
      reason: 'a count alone says a row was left behind and nothing about why',
    );
  });

  testWidgets('an exchange that keeps failing is said out loud', (
    tester,
  ) async {
    // What his second phone showed for an hour on 2026-09-23 while it received
    // nothing: sync on, nothing queued, nothing refused. Every number true.
    // The pull had been dead since its first page and no line said so.
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 0,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: 'remote-recitation-scheme-missing',
        consecutiveFailureCount: 0,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('account-sync-failing')),
      findsOneWidget,
    );
    expect(
      find.textContaining('remote-recitation-scheme-missing'),
      findsNothing,
      reason:
          'the category stays unshown here as everywhere else on this screen: '
          'it can name a transport, and what he does about any of them is the '
          'same',
    );
  });

  testWidgets('a healthy exchange is not warned about', (tester) async {
    await _pump(
      tester,
      account: _user,
      transport: SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 0,
        quarantinedCount: 0,
        lastSuccessAtUtc: DateTime.utc(2026, 9, 23, 10, 50),
        lastFailureReason: null,
        consecutiveFailureCount: 0,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('account-sync-failing')),
      findsNothing,
      reason: 'a warning that fires on a working device is one nobody reads',
    );
  });

  testWidgets('a merge that left nothing behind shows no warning', (
    tester,
  ) async {
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 0,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
        backfill: SyncBackfillOutcome(
          enqueuedCount: 940,
          skippedCount: 0,
          skippedFields: <String>{},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('account-backfill-incomplete')),
      findsNothing,
      reason: 'a warning that fires on a clean merge is one nobody reads twice',
    );
  });

  testWidgets('a device kept local is told nothing about a backfill', (
    tester,
  ) async {
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: false,
        queuedCount: 0,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
        backfill: SyncBackfillOutcome(
          enqueuedCount: 0,
          skippedCount: 12,
          skippedFields: <String>{'startedAtUtc'},
        ),
      ),
    );

    expect(find.text(l10n.accountSyncOffTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('account-backfill-incomplete')),
      findsNothing,
      reason:
          'a device that chose to stay local has nothing outstanding to report '
          'about an account it is not part of',
    );
  });

  testWidgets('refused records can be offered again, by hand', (tester) async {
    // It happened: a defect in this client made the server refuse every record
    // whose id contains a colon, and 112 of the owner's prayer sessions,
    // routines and schemes sat in quarantine with nothing able to release
    // them. A permanent refusal has always promised an explicit recovery; this
    // is the first thing that offers one.
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 0,
        quarantinedCount: 112,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
      ),
    );

    final button = find.byKey(const ValueKey<String>('account-retry-refused'));
    expect(button, findsOneWidget);
    expect(find.textContaining('112'), findsWidgets);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('account-retry-refused-result')),
      findsOneWidget,
      reason:
          'putting records back in a queue and saying nothing looks exactly '
          'like doing nothing',
    );
  });

  testWidgets('nothing refused means no button to press', (tester) async {
    await _pump(
      tester,
      account: _user,
      transport: const SyncTransportSnapshot(
        isActivated: true,
        queuedCount: 4,
        quarantinedCount: 0,
        lastSuccessAtUtc: null,
        lastFailureReason: null,
        consecutiveFailureCount: 0,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('account-retry-refused')),
      findsNothing,
    );
  });

  testWidgets('an unreachable account is not reported as signed out', (
    tester,
  ) async {
    // The whole point of the gateway throwing instead of returning null. An
    // offline device shown as "not signed in" invites the user to sign in
    // again, and a second OAuth round trip is not what a dropped connection
    // needs.
    await _pump(tester, accountError: const SyncAccountException('offline'));

    expect(find.text(l10n.accountUnknownTitle), findsOneWidget);
    expect(find.text(l10n.accountSignedOutTitle), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('account-sign-in-google')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('account-retry')), findsOneWidget);
  });

  testWidgets('tapping Google asks the gateway for exactly that provider', (
    tester,
  ) async {
    final gateway = _FakeAccountGateway();
    await _pump(tester, account: null, gateway: gateway);

    await tester.tap(
      find.byKey(const ValueKey<String>('account-sign-in-google')),
    );
    await tester.pumpAndSettle();

    expect(gateway.signInCalls, <SyncAuthProvider>[SyncAuthProvider.google]);
  });

  testWidgets('a failed sign-in reports failure without leaking the reason', (
    tester,
  ) async {
    final gateway = _FakeAccountGateway(
      failure: const SyncAccountException(
        'oauth-failed-401-secret@example.com',
      ),
    );
    await _pump(tester, account: null, gateway: gateway);

    await tester.tap(
      find.byKey(const ValueKey<String>('account-sign-in-google')),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.accountSignInFailed), findsOneWidget);
    // Provider errors quote the user's own address back at them; the screen
    // must not put that on a snackbar.
    expect(find.textContaining('example.com'), findsNothing);
  });
}

final AppwriteConfig _absent = AppwriteConfig.resolve(
  endpoint: '',
  projectId: '',
);

final AppwriteConfig _malformed = AppwriteConfig.resolve(
  endpoint: 'http://fra.cloud.appwrite.io/v1',
  projectId: 'project-1',
);

final AppwriteConfig _ready = AppwriteConfig.resolve(
  endpoint: 'https://fra.cloud.appwrite.io/v1',
  projectId: 'project-1',
);

final class _FakeAccountGateway implements AccountGateway {
  _FakeAccountGateway({this.failure});

  final Object? failure;
  final List<SyncAuthProvider> signInCalls = <SyncAuthProvider>[];
  int signOutCalls = 0;

  @override
  Future<SyncAccount?> currentAccount() async => null;

  @override
  Future<SyncAccount> signIn(SyncAuthProvider provider) async {
    signInCalls.add(provider);
    if (failure != null) {
      throw failure!;
    }
    return SyncAccount(
      userId: 'user-1',
      linkedProviders: <SyncAuthProvider>{provider},
    );
  }

  @override
  Future<SyncAccount> linkIdentity(SyncAuthProvider provider) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<Map<String, Object?>> exportCloudData() async =>
      throw UnimplementedError();

  @override
  Future<void> deleteCloudAccount() async => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  AppwriteConfig? config,
  SyncAccount? account,
  Object? accountError,
  AccountGateway? gateway,
  SyncTransportSnapshot? transport,
  _FakeCycle? cycle,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The screen watches the activation gateway, which reaches the store and so
  // constructs the app's real database object. Nothing here queries it, but a
  // widget test that opens the owner's database file is one edit away from
  // writing to it — and the "database created twice" warning it prints would
  // hide the next real one.
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        appwriteConfigProvider.overrideWithValue(config ?? _ready),
        accountGatewayProvider.overrideWithValue(
          gateway ?? _FakeAccountGateway(),
        ),
        currentAccountProvider.overrideWith((ref) async {
          if (accountError != null) {
            throw accountError;
          }
          return account;
        }),
        // Without this the summary would open the real database, which a
        // widget test has no business doing and which never settles here.
        syncTransportProvider.overrideWith(
          (ref, userId) async => transport ?? SyncTransportSnapshot.inactive,
        ),
        syncCycleProvider.overrideWith((ref, userId) => cycle),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
