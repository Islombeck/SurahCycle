import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Stage J §6.3: the account screen shows status, last success, queue, error
/// and retry — and **never a fake green success**. That last rule is what most
/// of this file is about, because it is the one a cheerful default would break
/// without anybody noticing until a device was lost.
void main() {
  final ready = AppwriteConfig.fromEnvironment();
  final absent = AppwriteConfig.resolve(endpoint: '', projectId: '');
  final broken = AppwriteConfig.resolve(
    endpoint: 'http://fra.cloud.appwrite.io/v1',
    projectId: '6aa91956000d1d490a3e',
  );
  final syncedAt = DateTime.utc(2026, 9, 17, 8);

  SyncStatus statusOf({
    AppwriteConfig? config,
    bool isSignedIn = true,
    bool isActivated = true,
    int queued = 0,
    int quarantined = 0,
    DateTime? lastSuccessAtUtc,
    String? failure,
    int failures = 0,
  }) => SyncStatus.resolve(
    config: config ?? ready,
    isSignedIn: isSignedIn,
    isActivated: isActivated,
    queuedCount: queued,
    quarantinedCount: quarantined,
    lastSuccessAtUtc: lastSuccessAtUtc,
    lastFailureReason: failure,
    consecutiveFailureCount: failures,
  );

  group('never a fake green success', () {
    test('a device that has never synced is not up to date', () {
      final status = statusOf();

      expect(status.health, SyncHealth.neverSynced);
      expect(
        status.isSuccess,
        isFalse,
        reason:
            'an empty queue on a device that never reached the server '
            'means nothing has been protected yet',
      );
    });

    test('success requires a recorded success, not merely no error', () {
      expect(statusOf(lastSuccessAtUtc: syncedAt).isSuccess, isTrue);
      expect(statusOf().isSuccess, isFalse);
    });

    test('no state except upToDate counts as success', () {
      for (final status in <SyncStatus>[
        statusOf(config: absent),
        statusOf(config: broken),
        statusOf(isSignedIn: false),
        statusOf(isActivated: false),
        statusOf(queued: 3),
        statusOf(failure: 'transport'),
        statusOf(quarantined: 1),
        statusOf(),
      ]) {
        expect(
          status.isSuccess,
          isFalse,
          reason: '${status.health.name} must not render as success',
        );
      }
    });
  });

  group('the first applicable case wins', () {
    test('no configuration is unavailable, not an error', () {
      final status = statusOf(config: absent, queued: 5, failure: 'transport');

      expect(status.health, SyncHealth.unavailable);
      expect(
        status.problem,
        isNull,
        reason: 'local-first: having no cloud is not a fault to report',
      );
    });

    test('a broken configuration outranks everything after it', () {
      final status = statusOf(
        config: broken,
        lastSuccessAtUtc: syncedAt,
        queued: 0,
      );

      expect(status.health, SyncHealth.misconfigured);
      expect(status.problem, contains('https'));
      expect(status.isActionable, isTrue);
    });

    test('signed out outranks a queue', () {
      expect(
        statusOf(isSignedIn: false, queued: 4).health,
        SyncHealth.signedOut,
      );
    });

    test('"keep this device local" is its own state, not progress', () {
      final status = statusOf(isActivated: false, queued: 4);

      expect(status.health, SyncHealth.notActivated);
      expect(
        status.hasUnsentWork,
        isTrue,
        reason: 'the work is still counted; it is simply not being sent',
      );
    });

    test('quarantine outranks an otherwise clean queue', () {
      final status = statusOf(quarantined: 2, lastSuccessAtUtc: syncedAt);

      expect(status.health, SyncHealth.needsAttention);
      expect(status.canRetryNow, isTrue);
    });

    test('a failure outranks pending work', () {
      final status = statusOf(queued: 3, failure: 'transport', failures: 2);

      expect(status.health, SyncHealth.retrying);
      expect(status.lastFailureReason, 'transport');
      expect(status.consecutiveFailureCount, 2);
    });

    test('pending work with no failure is syncing', () {
      expect(statusOf(queued: 1).health, SyncHealth.syncing);
    });
  });

  group('stale detail is dropped rather than shown', () {
    test('a signed-out device does not display yesterday\'s error', () {
      final status = statusOf(
        isSignedIn: false,
        failure: 'transport',
        failures: 3,
      );

      expect(status.lastFailureReason, isNull);
      expect(status.consecutiveFailureCount, 0);
    });

    test('a working configuration reports no problem text', () {
      expect(statusOf(lastSuccessAtUtc: syncedAt).problem, isNull);
    });
  });

  group('retry is offered only where it does something', () {
    test('retry is offered for a failure and for quarantine', () {
      expect(statusOf(failure: 'transport').canRetryNow, isTrue);
      expect(statusOf(quarantined: 1).canRetryNow, isTrue);
    });

    test('retry is not offered when nothing would happen', () {
      for (final status in <SyncStatus>[
        statusOf(config: absent),
        statusOf(isSignedIn: false),
        statusOf(isActivated: false),
        statusOf(queued: 2),
        statusOf(lastSuccessAtUtc: syncedAt),
      ]) {
        expect(
          status.canRetryNow,
          isFalse,
          reason:
              'a retry button that does nothing teaches the user to '
              'distrust every button (${status.health.name})',
        );
      }
    });
  });

  group('inputs are checked', () {
    test('a negative count is refused', () {
      expect(() => statusOf(queued: -1), throwsArgumentError);
      expect(() => statusOf(quarantined: -1), throwsArgumentError);
    });

    test('a local timestamp is refused', () {
      expect(
        () => statusOf(lastSuccessAtUtc: DateTime(2026, 9, 17)),
        throwsArgumentError,
        reason: 'a last-success time compared across devices must be UTC',
      );
    });
  });
}
