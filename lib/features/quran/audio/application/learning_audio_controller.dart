import '../../../../core/domain/learning.dart';
import '../domain/quran_audio_models.dart';

abstract interface class QuranAudioPlayback {
  Stream<QuranAudioPlaybackState> get states;
  Future<void> loadAndPlay({
    required QuranAudioTrack track,
    required QuranAudioRange range,
    required QuranAudioRepeat repeat,
  });
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

final class QuranAudioPlaybackState {
  const QuranAudioPlaybackState({
    this.isPlaying = false,
    this.isLoading = false,
    this.hasAudio = false,
    this.position = Duration.zero,
    this.errorCode,
  });
  final bool isPlaying;
  final bool isLoading;
  final bool hasAudio;
  final Duration position;
  final String? errorCode;
}

abstract final class LearningAudioRangeResolver {
  static QuranAudioRange resolve({
    required LearningStage stage,
    required List<AyahTiming>? timings,
  }) {
    if (timings == null || timings.isEmpty) {
      return QuranAudioRange(
        kind: QuranAudioRangeKind.fullSurahOnly,
        startAyah: stage.startAyah,
        endAyah: stage.endAyah,
      );
    }
    final byAyah = <int, AyahTiming>{
      for (final value in timings) value.ayahNumber: value,
    };
    final first = byAyah[stage.startAyah];
    final last = byAyah[stage.endAyah];
    for (var ayah = stage.startAyah; ayah <= stage.endAyah; ayah += 1) {
      if (!byAyah.containsKey(ayah)) {
        return QuranAudioRange(
          kind: QuranAudioRangeKind.fullSurahOnly,
          startAyah: stage.startAyah,
          endAyah: stage.endAyah,
        );
      }
    }
    if (first == null || last == null || last.end <= first.start) {
      return QuranAudioRange(
        kind: QuranAudioRangeKind.fullSurahOnly,
        startAyah: stage.startAyah,
        endAyah: stage.endAyah,
      );
    }
    return QuranAudioRange(
      kind: stage.startAyah == stage.endAyah
          ? QuranAudioRangeKind.exactAyahClip
          : QuranAudioRangeKind.exactRangeClip,
      startAyah: stage.startAyah,
      endAyah: stage.endAyah,
      start: first.start,
      end: last.end,
    );
  }
}

final class LearningAudioController {
  LearningAudioController(this._provider, this._playback);

  final QuranAudioProvider _provider;
  final QuranAudioPlayback _playback;
  int _generation = 0;

  Stream<QuranAudioPlaybackState> get states => _playback.states;

  Future<QuranAudioRange> play({
    required List<QuranReciter> catalog,
    required int reciterId,
    required int moshafId,
    required int surahNumber,
    required LearningStage stage,
    required QuranAudioRepeat repeat,
  }) async {
    final generation = ++_generation;
    await _playback.stop();
    final track = _provider.trackFor(
      catalog: catalog,
      reciterId: reciterId,
      moshafId: moshafId,
      surahNumber: surahNumber,
    );
    List<AyahTiming>? timings;
    final readId = track.moshaf.timingReadId;
    if (readId != null) {
      try {
        timings = await _provider.loadAyahTimings(
          readId: readId,
          surahNumber: surahNumber,
        );
      } on QuranAudioProviderException catch (error) {
        if (error.code != 'invalid_timing') rethrow;
      }
    }
    if (generation != _generation) {
      throw const QuranAudioOperationCancelled();
    }
    final range = LearningAudioRangeResolver.resolve(
      stage: stage,
      timings: timings,
    );
    await _playback.loadAndPlay(track: track, range: range, repeat: repeat);
    return range;
  }

  Future<void> pause() => _playback.pause();
  Future<void> resume() => _playback.resume();

  Future<void> stop() async {
    _generation += 1;
    await _playback.stop();
  }

  Future<void> dispose() async {
    _generation += 1;
    await _playback.dispose();
  }
}

final class QuranAudioOperationCancelled implements Exception {
  const QuranAudioOperationCancelled();
}
