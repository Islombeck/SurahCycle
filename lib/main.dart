import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/murajaah_app.dart';
import 'app/widget_interactivity_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'dev.murajaah.murajaah.quran_audio',
      androidNotificationChannelName: 'Quran audio',
      androidNotificationChannelDescription: 'Quran learning playback controls',
      androidNotificationOngoing: true,
    );
    unawaited(
      HomeWidget.registerInteractivityCallback(
        murajaahWidgetInteractivityCallback,
      ).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to register widget interactivity: $error');
        return false;
      }),
    );
  }
  runApp(const ProviderScope(child: MurajaahApp()));
}
