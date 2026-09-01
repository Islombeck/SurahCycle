import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/domain/domain.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test('NEW_AYAH uses exact ayah timing', () {
    final range = LearningAudioRangeResolver.resolve(
      stage: LearningStage.newAyah(2),
      timings: _timings,
    );
    expect(range.kind, QuranAudioRangeKind.exactAyahClip);
    expect(range.start, const Duration(seconds: 2));
    expect(range.end, const Duration(seconds: 4));
  });

  test('review range uses first start through last end', () {
    final range = LearningAudioRangeResolver.resolve(
      stage: LearningStage.reviewRange(startAyah: 1, endAyah: 3, blockIndex: 1),
      timings: _timings,
    );
    expect(range.kind, QuranAudioRangeKind.exactRangeClip);
    expect(range.start, Duration.zero);
    expect(range.end, const Duration(seconds: 7));
  });

  test('missing timing never invents a clip', () {
    final range = LearningAudioRangeResolver.resolve(
      stage: LearningStage.reviewRange(startAyah: 1, endAyah: 3, blockIndex: 1),
      timings: _timings.take(2).toList(),
    );
    expect(range.kind, QuranAudioRangeKind.fullSurahOnly);
    expect(range.start, isNull);
    expect(range.end, isNull);
  });

  test('repeat count reaches playback unchanged', () async {
    final playback = _FakePlayback();
    final controller = LearningAudioController(_FakeProvider(), playback);
    await controller.play(
      catalog: _catalog,
      reciterId: 1,
      moshafId: 2,
      surahNumber: 1,
      stage: LearningStage.newAyah(1),
      repeat: QuranAudioRepeat.ten,
    );
    expect(playback.repeat, QuranAudioRepeat.ten);
    expect(playback.stopCalls, 1);
  });

  test('pause, stop and disposal reach playback', () async {
    final playback = _FakePlayback();
    final controller = LearningAudioController(_FakeProvider(), playback);
    await controller.pause();
    await controller.resume();
    await controller.stop();
    await controller.dispose();
    expect(
      (
        playback.pauseCalls,
        playback.resumeCalls,
        playback.stopCalls,
        playback.disposeCalls,
      ),
      (1, 1, 1, 1),
    );
  });

  test(
    'stage change cancels an in-flight timing load before playback',
    () async {
      final playback = _FakePlayback();
      final provider = _DelayedProvider();
      final controller = LearningAudioController(provider, playback);
      final pending = controller.play(
        catalog: _catalog,
        reciterId: 1,
        moshafId: 2,
        surahNumber: 1,
        stage: LearningStage.newAyah(1),
        repeat: QuranAudioRepeat.once,
      );
      await Future<void>.delayed(Duration.zero);
      await controller.stop();
      provider.timings.complete(_timings);
      await expectLater(pending, throwsA(isA<QuranAudioOperationCancelled>()));
      expect(playback.loadCalls, 0);
    },
  );
}

final _timings = [
  AyahTiming(
    ayahNumber: 1,
    start: Duration.zero,
    end: const Duration(seconds: 2),
  ),
  AyahTiming(
    ayahNumber: 2,
    start: const Duration(seconds: 2),
    end: const Duration(seconds: 4),
  ),
  AyahTiming(
    ayahNumber: 3,
    start: const Duration(seconds: 4),
    end: const Duration(seconds: 7),
  ),
];

final _moshaf = QuranMoshaf(
  id: 2,
  name: 'Hafs',
  riwayaId: 1,
  riwayaName: 'Hafs',
  server: Uri.parse('https://audio.example/'),
  availableSurahs: [1],
  timingReadId: 9,
);
final _catalog = [
  QuranReciter(id: 1, displayName: 'Reader', moshafs: [_moshaf]),
];

class _FakeProvider implements QuranAudioProvider {
  @override
  Future<List<QuranReciter>> listHafsReciters({
    String languageCode = 'eng',
  }) async => _catalog;
  @override
  Future<List<AyahTiming>> loadAyahTimings({
    required int readId,
    required int surahNumber,
  }) async => _timings;
  @override
  QuranAudioTrack trackFor({
    required List<QuranReciter> catalog,
    required int reciterId,
    required int moshafId,
    required int surahNumber,
  }) => QuranAudioTrack(
    reciterId: 1,
    reciterName: 'Reader',
    moshaf: _moshaf,
    surahNumber: 1,
    uri: Uri.parse('https://audio.example/001.mp3'),
  );
}

final class _FakePlayback implements QuranAudioPlayback {
  final controller = StreamController<QuranAudioPlaybackState>.broadcast();
  QuranAudioRepeat? repeat;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  int loadCalls = 0;
  @override
  Stream<QuranAudioPlaybackState> get states => controller.stream;
  @override
  Future<void> loadAndPlay({
    required QuranAudioTrack track,
    required QuranAudioRange range,
    required QuranAudioRepeat repeat,
  }) async {
    loadCalls++;
    this.repeat = repeat;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await controller.close();
  }
}

final class _DelayedProvider extends _FakeProvider {
  final timings = Completer<List<AyahTiming>>();

  @override
  Future<List<AyahTiming>> loadAyahTimings({
    required int readId,
    required int surahNumber,
  }) => timings.future;
}
