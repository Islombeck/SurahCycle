import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app/murajaah_app.dart';
import 'app/widget_interactivity_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
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
