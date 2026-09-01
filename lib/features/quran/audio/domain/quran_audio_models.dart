enum AudioCapability { fullSurahStreaming, ayahTiming }

final class QuranAudioProviderException implements Exception {
  const QuranAudioProviderException(
    this.code,
    this.message, {
    this.statusCode,
    this.cause,
  });
  final String code;
  final String message;
  final int? statusCode;
  final Object? cause;
  @override
  String toString() => 'QuranAudioProviderException($code): $message';
}

final class QuranMoshaf {
  QuranMoshaf({
    required this.id,
    required this.name,
    required this.riwayaId,
    required this.riwayaName,
    required this.server,
    required Iterable<int> availableSurahs,
    this.timingReadId,
  }) : availableSurahs = Set<int>.unmodifiable(availableSurahs) {
    if (id <= 0 || name.trim().isEmpty || server.scheme != 'https') {
      throw ArgumentError('Invalid moshaf metadata.');
    }
    if (this.availableSurahs.any((value) => value < 1 || value > 114)) {
      throw ArgumentError('Surah number must be between 1 and 114.');
    }
  }

  final int id;
  final String name;
  final int riwayaId;
  final String riwayaName;
  final Uri server;
  final Set<int> availableSurahs;
  final int? timingReadId;

  Set<AudioCapability> get capabilities => Set<AudioCapability>.unmodifiable({
    AudioCapability.fullSurahStreaming,
    if (timingReadId != null) AudioCapability.ayahTiming,
  });

  bool hasSurah(int number) => availableSurahs.contains(number);
}

final class QuranReciter {
  QuranReciter({
    required this.id,
    required this.displayName,
    required this.moshafs,
  }) {
    if (id <= 0 || displayName.trim().isEmpty || moshafs.isEmpty) {
      throw ArgumentError('Invalid reciter metadata.');
    }
  }

  final int id;
  final String displayName;
  final List<QuranMoshaf> moshafs;
}

final class QuranAudioTrack {
  const QuranAudioTrack({
    required this.reciterId,
    required this.reciterName,
    required this.moshaf,
    required this.surahNumber,
    required this.uri,
  });

  final int reciterId;
  final String reciterName;
  final QuranMoshaf moshaf;
  final int surahNumber;
  final Uri uri;
}

final class AyahTiming {
  AyahTiming({
    required this.ayahNumber,
    required this.start,
    required this.end,
  }) {
    if (ayahNumber < 0 || start.isNegative || end <= start) {
      throw ArgumentError('Invalid ayah timing.');
    }
  }

  final int ayahNumber;
  final Duration start;
  final Duration end;
}

abstract interface class QuranAudioProvider {
  Future<List<QuranReciter>> listHafsReciters({String languageCode = 'eng'});

  Future<List<AyahTiming>> loadAyahTimings({
    required int readId,
    required int surahNumber,
  });

  QuranAudioTrack trackFor({
    required List<QuranReciter> catalog,
    required int reciterId,
    required int moshafId,
    required int surahNumber,
  });
}

enum QuranAudioRangeKind { exactAyahClip, exactRangeClip, fullSurahOnly }

final class QuranAudioRange {
  const QuranAudioRange({
    required this.kind,
    required this.startAyah,
    required this.endAyah,
    this.start,
    this.end,
  });

  final QuranAudioRangeKind kind;
  final int startAyah;
  final int endAyah;
  final Duration? start;
  final Duration? end;
}

enum QuranAudioRepeat {
  once(1),
  three(3),
  five(5),
  ten(10),
  infinite(null);

  const QuranAudioRepeat(this.count);
  final int? count;
}
