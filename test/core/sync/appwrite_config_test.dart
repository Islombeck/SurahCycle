import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

/// Stage J §6.3: the endpoint and project id are public typed configuration
/// with a clear failure state, and a missing configuration is never dressed up
/// as a working sync.
///
/// Nothing here contacts Appwrite. The point is to decide, before any request
/// is attempted, whether there is a usable configuration at all.
void main() {
  group('a usable configuration', () {
    test('the owner\'s real published values resolve', () {
      final config = AppwriteConfig.fromEnvironment();

      expect(config.isReady, isTrue);
      expect(config.endpoint, 'https://fra.cloud.appwrite.io/v1');
      expect(config.projectId, '6aa91956000d1d490a3e');
      expect(config.problem, isNull);
    });

    test('surrounding whitespace is forgiven', () {
      final config = AppwriteConfig.resolve(
        endpoint: '  https://fra.cloud.appwrite.io/v1  ',
        projectId: '  6aa91956000d1d490a3e ',
      );

      expect(config.isReady, isTrue);
      expect(config.endpoint, 'https://fra.cloud.appwrite.io/v1');
    });
  });

  group('no configuration is an ordinary state, not a fault', () {
    test('both values empty means absent', () {
      final config = AppwriteConfig.resolve(endpoint: '', projectId: '');

      expect(config.status, AppwriteConfigStatus.absent);
      expect(config.isAbsent, isTrue);
      expect(config.isReady, isFalse);
      expect(
        config.problem,
        isNull,
        reason: 'the app is local-first: no cloud is not an error to report',
      );
    });
  });

  group('a broken configuration is a fault, and says why', () {
    test('half a configuration is a mistake, not an opt-out', () {
      final missingId = AppwriteConfig.resolve(
        endpoint: 'https://fra.cloud.appwrite.io/v1',
        projectId: '',
      );
      final missingEndpoint = AppwriteConfig.resolve(
        endpoint: '',
        projectId: '6aa91956000d1d490a3e',
      );

      expect(missingId.status, AppwriteConfigStatus.malformed);
      expect(missingId.problem, contains('project id'));
      expect(missingEndpoint.status, AppwriteConfigStatus.malformed);
      expect(missingEndpoint.problem, contains('endpoint'));
    });

    test('plain http is refused, with no development exception', () {
      // A debug build runs against the same real account, so there is no
      // build in which sending a session token in the clear is acceptable.
      final config = AppwriteConfig.resolve(
        endpoint: 'http://fra.cloud.appwrite.io/v1',
        projectId: '6aa91956000d1d490a3e',
      );

      expect(config.status, AppwriteConfigStatus.malformed);
      expect(config.problem, contains('https'));
    });

    test('a relative or unparseable endpoint is refused', () {
      final config = AppwriteConfig.resolve(
        endpoint: 'fra.cloud.appwrite.io/v1',
        projectId: '6aa91956000d1d490a3e',
      );

      expect(config.status, AppwriteConfigStatus.malformed);
      expect(config.problem, contains('absolute'));
    });

    test('an endpoint without the API version is refused', () {
      // Appwrite's REST base is versioned; dropping /v1 yields 404s that look
      // exactly like being offline.
      final config = AppwriteConfig.resolve(
        endpoint: 'https://fra.cloud.appwrite.io',
        projectId: '6aa91956000d1d490a3e',
      );

      expect(config.status, AppwriteConfigStatus.malformed);
      expect(config.problem, contains('/v1'));
    });

    test('a malformed configuration is never ready', () {
      for (final endpoint in <String>[
        '',
        'nonsense',
        'http://fra.cloud.appwrite.io/v1',
        'https://fra.cloud.appwrite.io',
      ]) {
        expect(
          AppwriteConfig.resolve(endpoint: endpoint, projectId: 'x').isReady,
          isFalse,
          reason: '"$endpoint" must not be treated as usable',
        );
      }
    });
  });

  test('two configurations with the same values are equal', () {
    expect(
      AppwriteConfig.resolve(
        endpoint: 'https://fra.cloud.appwrite.io/v1',
        projectId: '6aa91956000d1d490a3e',
      ),
      AppwriteConfig.fromEnvironment(),
    );
  });

  test('toString carries nothing that is not already public', () {
    // Guards the rule rather than the text: if someone later adds a secret to
    // this class, this is where it would start leaking into logs.
    final text = AppwriteConfig.fromEnvironment().toString();

    expect(text, contains('6aa91956000d1d490a3e'));
    expect(text, contains('fra.cloud.appwrite.io'));
    expect(text.toLowerCase(), isNot(contains('key')));
    expect(text.toLowerCase(), isNot(contains('secret')));
    expect(text.toLowerCase(), isNot(contains('token')));
  });
}
