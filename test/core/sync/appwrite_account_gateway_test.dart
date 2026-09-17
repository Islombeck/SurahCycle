import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

/// A scripted stand-in for Appwrite's Account service.
///
/// It records what was asked of it and lets a test say what the session looks
/// like before and after an OAuth round trip, which is the only way to express
/// the case that matters most here: a "link" that silently lands on somebody
/// else's account.
final class _FakeAccountApi implements AppwriteAccountApi {
  _FakeAccountApi({
    this.userId,
    this.providers = const <String>[],
    this.userIdAfterOAuth = _unchanged,
  });

  static const String _unchanged = '__unchanged__';

  String? userId;
  List<String> providers;

  /// The id reported after [createOAuth2Session]. `_unchanged` keeps the
  /// current one; null means the session vanished.
  final String? userIdAfterOAuth;

  final List<String> oauthCalls = <String>[];
  int signOutCalls = 0;

  @override
  Future<String?> currentUserId() async => userId;

  @override
  Future<List<String>> identityProviders() async => providers;

  @override
  Future<void> createOAuth2Session(String providerName) async {
    oauthCalls.add(providerName);
    if (userIdAfterOAuth != _unchanged) {
      // May be null on purpose: the flow returned without leaving a session.
      userId = userIdAfterOAuth;
    } else {
      userId ??= 'user-from-oauth';
    }
    if (!providers.contains(providerName)) {
      providers = <String>[...providers, providerName];
    }
  }

  @override
  Future<void> deleteCurrentSession() async {
    signOutCalls++;
    userId = null;
    providers = const <String>[];
  }
}

void main() {
  group('currentAccount', () {
    test('is null when no session exists', () async {
      final gateway = AppwriteAccountGateway(_FakeAccountApi());

      expect(await gateway.currentAccount(), isNull);
    });

    test('maps Appwrite provider names onto the modelled providers', () async {
      final gateway = AppwriteAccountGateway(
        _FakeAccountApi(
          userId: 'user-1',
          providers: const <String>['google', 'yandex'],
        ),
      );

      final account = await gateway.currentAccount();

      expect(account, isNotNull);
      expect(account!.userId, 'user-1');
      expect(account.linkedProviders, <SyncAuthProvider>{
        SyncAuthProvider.google,
        SyncAuthProvider.yandex,
      });
    });

    test(
      'drops a provider this build does not model instead of guessing',
      () async {
        // The Console may have providers enabled that this app never offers.
        // Showing one as Google because it happened to be first would be a lie
        // about which account the history is attached to.
        final gateway = AppwriteAccountGateway(
          _FakeAccountApi(
            userId: 'user-1',
            providers: const <String>['google', 'apple'],
          ),
        );

        final account = await gateway.currentAccount();

        expect(account!.linkedProviders, <SyncAuthProvider>{
          SyncAuthProvider.google,
        });
      },
    );
  });

  group('signIn', () {
    test('opens the provider flow and returns the resulting account', () async {
      final api = _FakeAccountApi();
      final gateway = AppwriteAccountGateway(api);

      final account = await gateway.signIn(SyncAuthProvider.yandex);

      expect(api.oauthCalls, <String>['yandex']);
      expect(account.linkedProviders, contains(SyncAuthProvider.yandex));
    });

    test('refuses to report success when no session was left behind', () async {
      // The browser flow can return without completing. Reporting a signed-in
      // account here would put the screen into a state every later call
      // contradicts.
      final api = _FakeAccountApi(userIdAfterOAuth: null);
      final gateway = AppwriteAccountGateway(api);

      await expectLater(
        gateway.signIn(SyncAuthProvider.google),
        throwsA(isA<SyncAccountException>()),
      );
    });
  });

  group('linkIdentity', () {
    test('is refused while signed out', () async {
      final api = _FakeAccountApi();
      final gateway = AppwriteAccountGateway(api);

      await expectLater(
        gateway.linkIdentity(SyncAuthProvider.google),
        throwsA(isA<SyncIdentityLinkException>()),
      );
      // The flow must not even be opened: an anonymous OAuth login is a
      // sign-in, and starting it would make it one.
      expect(api.oauthCalls, isEmpty);
    });

    test('attaches a second provider to the same account', () async {
      final api = _FakeAccountApi(
        userId: 'user-1',
        providers: const <String>['google'],
      );
      final gateway = AppwriteAccountGateway(api);

      final account = await gateway.linkIdentity(SyncAuthProvider.yandex);

      expect(account.userId, 'user-1');
      expect(account.linkedProviders, <SyncAuthProvider>{
        SyncAuthProvider.google,
        SyncAuthProvider.yandex,
      });
    });

    test('refuses when the provider belongs to a different user', () async {
      // Appwrite signs into the matching user instead of linking. The caller
      // asked to link; silently returning a stranger's account would attach
      // this device's history to it.
      final api = _FakeAccountApi(
        userId: 'user-1',
        providers: const <String>['google'],
        userIdAfterOAuth: 'user-2',
      );
      final gateway = AppwriteAccountGateway(api);

      await expectLater(
        gateway.linkIdentity(SyncAuthProvider.yandex),
        throwsA(isA<SyncIdentityLinkException>()),
      );
    });
  });

  test('signOut ends the session exactly once', () async {
    final api = _FakeAccountApi(userId: 'user-1');
    final gateway = AppwriteAccountGateway(api);

    await gateway.signOut();

    expect(api.signOutCalls, 1);
    expect(await gateway.currentAccount(), isNull);
  });

  group('what this gateway refuses to pretend', () {
    test(
      'exportCloudData fails rather than returning an empty export',
      () async {
        // Nothing of the user's has ever left the device: no table is
        // provisioned. An empty map shaped like a successful export would read
        // as "backed up, nothing to restore".
        final gateway = AppwriteAccountGateway(
          _FakeAccountApi(userId: 'user-1'),
        );

        await expectLater(
          gateway.exportCloudData(),
          throwsA(isA<SyncAccountException>()),
        );
      },
    );

    test('deleteCloudAccount fails because the client can only block', () async {
      // Appwrite's client call blocks the record; erasure needs the Users API
      // and an admin key this build must never carry. Offering blocking under
      // the name "delete" would misinform someone exercising a deletion right.
      final gateway = AppwriteAccountGateway(_FakeAccountApi(userId: 'user-1'));

      await expectLater(
        gateway.deleteCloudAccount(),
        throwsA(isA<SyncAccountException>()),
      );
    });
  });
}
