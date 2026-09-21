import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app_providers.dart';
import 'app/murajaah_app.dart';
import 'app/widget_interactivity_bootstrap.dart';
import 'features/account/application/account_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Persist the headless callback handle before optional media startup work.
    await HomeWidget.registerInteractivityCallback(
      murajaahWidgetInteractivityCallback,
    ).catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to register widget interactivity: $error');
      }
      return false;
    });
    await JustAudioBackground.init(
      androidNotificationChannelId: 'dev.murajaah.murajaah.quran_audio',
      androidNotificationChannelName: 'Quran audio',
      androidNotificationChannelDescription: 'Quran learning playback controls',
      androidNotificationOngoing: true,
    );
  }
  runApp(
    ProviderScope(
      overrides: <Override>[
        // The composition root is where the account feature is allowed to be
        // named. `app_providers.dart` declares the hook and nothing more, so
        // `package:appwrite` stays out of the graph of every widget test — a
        // regression this project has made once already.
        syncOnResumeProvider.overrideWith(
          (ref) =>
              () => _syncNow(ref),
        ),
      ],
      child: const MurajaahApp(),
    ),
  );
}

/// One exchange with the account, if there is an account to exchange with.
///
/// Who is signed in is asked through `.future` rather than read from cache: on
/// a cold start nothing has asked yet, and reading the cache would mean a
/// device that only ever syncs after someone opens the account screen. The
/// answer is then cached by Riverpod, so later resumes cost nothing.
///
/// Every failure is swallowed by design. The runner does nothing at all for a
/// device that was not activated, and being offline is a phone's ordinary
/// state, not a fault to report on top of the user's data.
Future<void> _syncNow(Ref ref) async {
  try {
    final account = await ref.read(currentAccountProvider.future);
    if (account == null) return;
    await ref.read(syncCycleProvider(account.userId))?.runOnce();
  } on Object {
    // Nothing to say and nothing to do differently: the queue is durable and
    // the next resume will try again.
  }
}
