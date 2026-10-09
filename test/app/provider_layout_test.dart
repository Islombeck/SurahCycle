import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where providers are declared — the architecture review's §2.2, held by a
/// test so the composition root does not grow back.
///
/// `app_providers.dart` had become 2,017 lines and ~95 providers belonging to
/// every feature. The prayer-time group is the first to go home; the barrel
/// keeps re-exporting it, so no import anywhere had to change.
void main() {
  const appProviders = 'lib/app/app_providers.dart';
  const coreProviders = 'lib/app/core_providers.dart';
  const prayerProviders =
      'lib/features/prayer_times/application/prayer_time_providers.dart';

  const prayerTimeProviders = <String>[
    'prayerTimeSettingsRepositoryProvider',
    'prayerTimeSettingsProvider',
    'devicePrayerLocationServiceProvider',
    'prayerScheduleCacheStoreProvider',
    'namozVaqtiUzPrayerTimeProvider',
    'adhanPrayerTimeCalculatorProvider',
    'cachingPrayerScheduleRepositoryProvider',
    'prayerScheduleCoordinatorProvider',
    'prayerScheduleUseCasesProvider',
    'prayerTodayScheduleProvider',
    'prayerTimeSettingsControllerProvider',
    'localDateProvider',
  ];

  const coreGlobals = <String>[
    'appDatabaseProvider',
    'httpClientProvider',
    'timeProviderProvider',
    'uuidProvider',
    'settingsRepositoryProvider',
    'prayerRepositoryProvider',
  ];

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'missing $path');
    return file.readAsStringSync();
  }

  bool declares(String source, String name) =>
      RegExp('^final $name\\s*=', multiLine: true).hasMatch(source);

  test('the prayer-time providers are declared in their feature', () {
    final app = read(appProviders);
    final prayer = read(prayerProviders);
    for (final name in prayerTimeProviders) {
      expect(declares(prayer, name), isTrue, reason: '$name not in feature');
      expect(declares(app, name), isFalse, reason: '$name still in app');
    }
  });

  test('the genuinely global ones are declared in core_providers', () {
    final app = read(appProviders);
    final core = read(coreProviders);
    for (final name in coreGlobals) {
      expect(declares(core, name), isTrue, reason: '$name not in core');
      expect(declares(app, name), isFalse, reason: '$name still in app');
    }
  });

  test('the barrel still re-exports both, so no import had to change', () {
    final app = read(appProviders);
    expect(app, contains("export 'core_providers.dart';"));
    expect(
      app,
      contains(
        "export '../features/prayer_times/application/"
        "prayer_time_providers.dart';",
      ),
    );
  });

  test('the dependency points one way', () {
    Iterable<String> imports(String source) => RegExp(
      r"^import '([^']+)'",
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)!);

    expect(
      imports(read(coreProviders)).where((uri) => uri.contains('/features/')),
      isEmpty,
      reason: 'the core knows no feature',
    );
    expect(
      imports(
        read(prayerProviders),
      ).where((uri) => uri.endsWith('app_providers.dart')),
      isEmpty,
      reason: 'a feature reaches the core, never the whole registry',
    );
  });
}
