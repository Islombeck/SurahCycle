import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../domain/quran_audio_models.dart';
import 'learning_audio_controller.dart';

final class JustAudioQuranPlayback implements QuranAudioPlayback {
  JustAudioQuranPlayback({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions.add(
      _player.playerStateStream.listen((value) {
        _emit(
          isPlaying: value.playing,
          isLoading:
              value.processingState == ProcessingState.loading ||
              value.processingState == ProcessingState.buffering,
        );
      }),
    );
    _subscriptions.add(
      _player.positionStream.listen((value) => _emit(position: value)),
    );
    _subscriptions.add(
      _player.errorStream.listen(
        (_) => _emit(isPlaying: false, isLoading: false, errorCode: 'playback'),
      ),
    );
  }

  final AudioPlayer _player;
  final StreamController<QuranAudioPlaybackState> _states =
      StreamController.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  QuranAudioPlaybackState _state = const QuranAudioPlaybackState();
  bool _notificationPermissionRequested = false;

  @override
  Stream<QuranAudioPlaybackState> get states => _states.stream;

  @override
  Future<void> loadAndPlay({
    required QuranAudioTrack track,
    required QuranAudioRange range,
    required QuranAudioRepeat repeat,
  }) async {
    await _requestAndroidMediaNotificationPermission();
    _emit(isLoading: true, errorCode: null, position: Duration.zero);
    final count = repeat.count ?? 1;
    final sources = <AudioSource>[
      for (var index = 0; index < count; index += 1) _source(track, range),
    ];
    await _player.setAudioSources(sources);
    _emit(isLoading: false, hasAudio: true);
    await _player.setLoopMode(
      repeat == QuranAudioRepeat.infinite ? LoopMode.all : LoopMode.off,
    );
    unawaited(_player.play());
  }

  Future<void> _requestAndroidMediaNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _notificationPermissionRequested) {
      return;
    }
    _notificationPermissionRequested = true;
    try {
      await const MethodChannel(
        'dev.murajaah.murajaah/media_permissions',
      ).invokeMethod<bool>('requestMediaNotifications');
    } on MissingPluginException {
      // Playback remains available if an embedding cannot expose the prompt.
    }
  }

  AudioSource _source(QuranAudioTrack track, QuranAudioRange range) {
    final mediaItem = MediaItem(
      id: '${track.moshaf.id}:${track.surahNumber}:${range.startAyah}-${range.endAyah}',
      title:
          'Surah ${track.surahNumber} · ayahs ${range.startAyah}–${range.endAyah}',
      artist: track.reciterName,
      album: track.moshaf.riwayaName,
    );
    final base = AudioSource.uri(track.uri, tag: mediaItem);
    if (range.kind == QuranAudioRangeKind.fullSurahOnly) return base;
    return ClippingAudioSource(
      child: base,
      start: range.start,
      end: range.end,
      tag: mediaItem,
    );
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() async => unawaited(_player.play());
  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(
      isPlaying: false,
      isLoading: false,
      hasAudio: false,
      position: Duration.zero,
      errorCode: null,
    );
  }

  void _emit({
    bool? isPlaying,
    bool? isLoading,
    bool? hasAudio,
    Duration? position,
    String? errorCode,
    bool preserveError = false,
  }) {
    _state = QuranAudioPlaybackState(
      isPlaying: isPlaying ?? _state.isPlaying,
      isLoading: isLoading ?? _state.isLoading,
      hasAudio: hasAudio ?? _state.hasAudio,
      position: position ?? _state.position,
      errorCode: preserveError ? _state.errorCode : errorCode,
    );
    if (!_states.isClosed) _states.add(_state);
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _states.close();
  }
}
