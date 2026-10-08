import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart';
// Imported directly, not through `sync.dart`: the barrel deliberately keeps
// `package:appwrite` out of everything that only wanted an account.
import 'package:murajaah/core/sync/appwrite_account_api.dart';

/// The adapter has one decision in it, and this is the half that cannot be
/// reached through a fake: which server answers mean "no session" and which
/// mean the question was never answered.
///
/// Kept as a pure predicate for the same reason the sync classifier is one.
/// Constructing Appwrite's `Account` needs a `Client`, a platform channel and a
/// Flutter binding, and a decision this consequential should not need any of
/// them to be examined.
void main() {
  group('a project paused for inactivity', () {
    test('is told apart from everything else by its own type', () {
      // His phone, 2026-10-08. The account screen said «Не удалось связаться с
      // аккаунтом. Возможно, нет сети» while the phone could ping the endpoint
      // in 110 ms: Appwrite Cloud had paused the project for inactivity and was
      // answering every request with 403 `project_paused`. The code alone
      // cannot say that — 403 is also an ordinary refusal — so the type is what
      // this reads.
      expect(
        LiveAppwriteAccountApi.isProjectPaused(
          AppwriteException('paused', 403, 'project_paused'),
        ),
        isTrue,
      );
    });

    test('is not confused with an ordinary refusal or a missing session', () {
      for (final error in <Object>[
        AppwriteException('forbidden', 403, 'general_access_forbidden'),
        AppwriteException('no session', 401, 'general_unauthorized_scope'),
        AppwriteException('boom', 500),
        Exception('offline'),
      ]) {
        expect(
          LiveAppwriteAccountApi.isProjectPaused(error),
          isFalse,
          reason: '$error is not a paused project',
        );
      }
    });
  });
}
