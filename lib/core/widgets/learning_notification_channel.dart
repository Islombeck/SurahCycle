import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the optional, silent "what's next in Learning" notification.
///
/// The native side never posts anything unless Dart explicitly calls [show],
/// and Dart only calls [show] after the user has opted in and
/// [requestPermission] succeeded.
abstract interface class LearningNotificationChannel {
  Future<bool> requestPermission();

  Future<void> show({required String title, required String text});

  Future<void> cancel();
}

/// Every call is a no-op outside Android (including in tests without a
/// native embedding, via [MissingPluginException]).
final class MethodChannelLearningNotifications
    implements LearningNotificationChannel {
  const MethodChannelLearningNotifications({
    this._channel = const MethodChannel(
      'dev.murajaah.murajaah/learning_notifications',
    ),
  });

  final MethodChannel _channel;

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> show({required String title, required String text}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('show', <String, String>{
        'title': title,
        'text': text,
      });
    } on MissingPluginException {
      // No native embedding (e.g. tests): nothing to show.
    }
  }

  @override
  Future<void> cancel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No native embedding (e.g. tests): nothing to cancel.
    }
  }
}
