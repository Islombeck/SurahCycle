const Object _notProvided = Object();

bool _sameList<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// An inclusive, one-based range of ayahs.
final class AyahRange {
  factory AyahRange({required int startAyah, required int endAyah}) {
    if (startAyah <= 0) {
      throw ArgumentError.value(startAyah, 'startAyah', 'Must be positive.');
    }
    if (endAyah < startAyah) {
      throw ArgumentError.value(
        endAyah,
        'endAyah',
        'Must not precede startAyah.',
      );
    }
    return AyahRange._(startAyah: startAyah, endAyah: endAyah);
  }

  const AyahRange._({required this.startAyah, required this.endAyah});

  final int startAyah;
  final int endAyah;

  int get ayahCount => endAyah - startAyah + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AyahRange &&
          startAyah == other.startAyah &&
          endAyah == other.endAyah;

  @override
  int get hashCode => Object.hash(startAyah, endAyah);

  @override
  String toString() => '$startAyah–$endAyah';
}

/// Immutable definition and derived state of one part in a rotation scheme.
final class SurahRotationPart {
  factory SurahRotationPart({
    required String id,
    required String schemeId,
    required int partNumber,
    required AyahRange ayahRange,
    int rotationScore = 0,
    int recitationCount = 0,
    DateTime? lastUsedAtUtc,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (schemeId.isEmpty) {
      throw ArgumentError.value(schemeId, 'schemeId', 'Must not be empty.');
    }
    if (partNumber <= 0) {
      throw ArgumentError.value(partNumber, 'partNumber', 'Must be positive.');
    }
    if (rotationScore < 0) {
      throw ArgumentError.value(
        rotationScore,
        'rotationScore',
        'Must not be negative.',
      );
    }
    if (recitationCount < 0) {
      throw ArgumentError.value(
        recitationCount,
        'recitationCount',
        'Must not be negative.',
      );
    }
    if (lastUsedAtUtc != null && !lastUsedAtUtc.isUtc) {
      throw ArgumentError.value(lastUsedAtUtc, 'lastUsedAtUtc', 'Must be UTC.');
    }
    return SurahRotationPart._(
      id: id,
      schemeId: schemeId,
      partNumber: partNumber,
      ayahRange: ayahRange,
      rotationScore: rotationScore,
      recitationCount: recitationCount,
      lastUsedAtUtc: lastUsedAtUtc,
    );
  }

  const SurahRotationPart._({
    required this.id,
    required this.schemeId,
    required this.partNumber,
    required this.ayahRange,
    required this.rotationScore,
    required this.recitationCount,
    required this.lastUsedAtUtc,
  });

  final String id;
  final String schemeId;
  final int partNumber;
  final AyahRange ayahRange;
  final int rotationScore;
  final int recitationCount;
  final DateTime? lastUsedAtUtc;

  SurahRotationPart copyWith({
    int? rotationScore,
    int? recitationCount,
    Object? lastUsedAtUtc = _notProvided,
  }) => SurahRotationPart(
    id: id,
    schemeId: schemeId,
    partNumber: partNumber,
    ayahRange: ayahRange,
    rotationScore: rotationScore ?? this.rotationScore,
    recitationCount: recitationCount ?? this.recitationCount,
    lastUsedAtUtc: identical(lastUsedAtUtc, _notProvided)
        ? this.lastUsedAtUtc
        : lastUsedAtUtc as DateTime?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahRotationPart &&
          id == other.id &&
          schemeId == other.schemeId &&
          partNumber == other.partNumber &&
          ayahRange == other.ayahRange &&
          rotationScore == other.rotationScore &&
          recitationCount == other.recitationCount &&
          lastUsedAtUtc == other.lastUsedAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    schemeId,
    partNumber,
    ayahRange,
    rotationScore,
    recitationCount,
    lastUsedAtUtc,
  );
}

/// A versioned, immutable partition definition with rebuildable part state.
///
/// Every scheme contains one or more contiguous parts that exactly cover the
/// verified [ayahCount]. A part always contains at least one ayah, so the
/// verified ayah count is the natural maximum. An unsplit surah has one part.
final class SurahRotationScheme {
  factory SurahRotationScheme({
    required String id,
    required String surahId,
    required int version,
    required int ayahCount,
    required Iterable<SurahRotationPart> parts,
    int baselineRotationScore = 0,
    int baselineTotalRecitations = 0,
    DateTime? baselineLastUsedAtUtc,
    bool resetsRotationBaseline = false,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (surahId.isEmpty) {
      throw ArgumentError.value(surahId, 'surahId', 'Must not be empty.');
    }
    if (version <= 0) {
      throw ArgumentError.value(version, 'version', 'Must be positive.');
    }
    if (ayahCount <= 0) {
      throw ArgumentError.value(ayahCount, 'ayahCount', 'Must be positive.');
    }
    if (baselineRotationScore < 0) {
      throw ArgumentError.value(
        baselineRotationScore,
        'baselineRotationScore',
        'Must not be negative.',
      );
    }
    if (baselineTotalRecitations < 0) {
      throw ArgumentError.value(
        baselineTotalRecitations,
        'baselineTotalRecitations',
        'Must not be negative.',
      );
    }
    if (baselineLastUsedAtUtc != null && !baselineLastUsedAtUtc.isUtc) {
      throw ArgumentError.value(
        baselineLastUsedAtUtc,
        'baselineLastUsedAtUtc',
        'Must be UTC.',
      );
    }

    final immutableParts = List<SurahRotationPart>.unmodifiable(parts);
    _validateParts(schemeId: id, ayahCount: ayahCount, parts: immutableParts);
    return SurahRotationScheme._(
      id: id,
      surahId: surahId,
      version: version,
      ayahCount: ayahCount,
      baselineRotationScore: baselineRotationScore,
      baselineTotalRecitations: baselineTotalRecitations,
      baselineLastUsedAtUtc: baselineLastUsedAtUtc,
      resetsRotationBaseline: resetsRotationBaseline,
      parts: immutableParts,
    );
  }

  factory SurahRotationScheme.fromRanges({
    required String id,
    required String surahId,
    required int version,
    required int ayahCount,
    required Iterable<AyahRange> ranges,
    int baselineRotationScore = 0,
    int baselineTotalRecitations = 0,
    DateTime? baselineLastUsedAtUtc,
    bool resetsRotationBaseline = false,
  }) {
    final immutableRanges = List<AyahRange>.unmodifiable(ranges);
    return SurahRotationScheme(
      id: id,
      surahId: surahId,
      version: version,
      ayahCount: ayahCount,
      baselineRotationScore: baselineRotationScore,
      baselineTotalRecitations: baselineTotalRecitations,
      baselineLastUsedAtUtc: baselineLastUsedAtUtc,
      resetsRotationBaseline: resetsRotationBaseline,
      parts: <SurahRotationPart>[
        for (var index = 0; index < immutableRanges.length; index += 1)
          SurahRotationPart(
            id: '$id:part:${index + 1}',
            schemeId: id,
            partNumber: index + 1,
            ayahRange: immutableRanges[index],
            rotationScore: baselineRotationScore,
            recitationCount: baselineTotalRecitations,
            lastUsedAtUtc: baselineLastUsedAtUtc,
          ),
      ],
    );
  }

  factory SurahRotationScheme.unsplit({
    required String id,
    required String surahId,
    required int version,
    required int ayahCount,
    int baselineRotationScore = 0,
    int baselineTotalRecitations = 0,
    DateTime? baselineLastUsedAtUtc,
    bool resetsRotationBaseline = false,
  }) => SurahRotationScheme.fromRanges(
    id: id,
    surahId: surahId,
    version: version,
    ayahCount: ayahCount,
    ranges: <AyahRange>[AyahRange(startAyah: 1, endAyah: ayahCount)],
    baselineRotationScore: baselineRotationScore,
    baselineTotalRecitations: baselineTotalRecitations,
    baselineLastUsedAtUtc: baselineLastUsedAtUtc,
    resetsRotationBaseline: resetsRotationBaseline,
  );

  factory SurahRotationScheme.evenlySplit({
    required String id,
    required String surahId,
    required int version,
    required int ayahCount,
    required int partCount,
    int baselineRotationScore = 0,
    int baselineTotalRecitations = 0,
    DateTime? baselineLastUsedAtUtc,
    bool resetsRotationBaseline = false,
  }) => SurahRotationScheme.fromRanges(
    id: id,
    surahId: surahId,
    version: version,
    ayahCount: ayahCount,
    ranges: suggestEvenRanges(ayahCount: ayahCount, partCount: partCount),
    baselineRotationScore: baselineRotationScore,
    baselineTotalRecitations: baselineTotalRecitations,
    baselineLastUsedAtUtc: baselineLastUsedAtUtc,
    resetsRotationBaseline: resetsRotationBaseline,
  );

  const SurahRotationScheme._({
    required this.id,
    required this.surahId,
    required this.version,
    required this.ayahCount,
    required this.baselineRotationScore,
    required this.baselineTotalRecitations,
    required this.baselineLastUsedAtUtc,
    required this.resetsRotationBaseline,
    required this.parts,
  });

  final String id;
  final String surahId;
  final int version;
  final int ayahCount;
  final int baselineRotationScore;
  final int baselineTotalRecitations;
  final DateTime? baselineLastUsedAtUtc;

  /// True only when this scheme begins a new mastery lifecycle. Journal
  /// rebuilds preserve its score baseline instead of inheriting old debt.
  final bool resetsRotationBaseline;
  final List<SurahRotationPart> parts;

  bool get isSplit => parts.length > 1;

  int get effectiveRotationScore => parts
      .map((SurahRotationPart part) => part.rotationScore)
      .reduce((int left, int right) => left < right ? left : right);

  int get fullEquivalentRecitations => parts
      .map((SurahRotationPart part) => part.recitationCount)
      .reduce((int left, int right) => left < right ? left : right);

  DateTime? get lastUsedAtUtc {
    DateTime? latest;
    for (final part in parts) {
      final usedAt = part.lastUsedAtUtc;
      if (usedAt != null && (latest == null || usedAt.isAfter(latest))) {
        latest = usedAt;
      }
    }
    return latest;
  }

  SurahRotationPart partById(String id) {
    for (final part in parts) {
      if (part.id == id) return part;
    }
    throw StateError('No rotation part with id "$id" in scheme "${this.id}".');
  }

  int remainingForPart(String partId, int rotationTarget) =>
      rotationTarget - partById(partId).rotationScore;

  bool coversEveryPart(Iterable<String> partIds) {
    final supplied = partIds.toSet();
    return supplied.length == parts.length &&
        parts.every((SurahRotationPart part) => supplied.contains(part.id));
  }

  SurahRotationScheme copyWith({
    Iterable<SurahRotationPart>? parts,
    int? baselineRotationScore,
    int? baselineTotalRecitations,
    Object? baselineLastUsedAtUtc = _notProvided,
    bool? resetsRotationBaseline,
  }) => SurahRotationScheme(
    id: id,
    surahId: surahId,
    version: version,
    ayahCount: ayahCount,
    baselineRotationScore: baselineRotationScore ?? this.baselineRotationScore,
    baselineTotalRecitations:
        baselineTotalRecitations ?? this.baselineTotalRecitations,
    baselineLastUsedAtUtc: identical(baselineLastUsedAtUtc, _notProvided)
        ? this.baselineLastUsedAtUtc
        : baselineLastUsedAtUtc as DateTime?,
    resetsRotationBaseline:
        resetsRotationBaseline ?? this.resetsRotationBaseline,
    parts: parts ?? this.parts,
  );

  /// Rebases a new scheme version to the effective state of its predecessor.
  /// Part definitions and identifiers remain unchanged.
  SurahRotationScheme rebase({
    required int rotationScore,
    required int totalRecitations,
    required DateTime? lastUsedAtUtc,
  }) => SurahRotationScheme(
    id: id,
    surahId: surahId,
    version: version,
    ayahCount: ayahCount,
    baselineRotationScore: rotationScore,
    baselineTotalRecitations: totalRecitations,
    baselineLastUsedAtUtc: lastUsedAtUtc,
    resetsRotationBaseline: resetsRotationBaseline,
    parts: <SurahRotationPart>[
      for (final part in parts)
        SurahRotationPart(
          id: part.id,
          schemeId: id,
          partNumber: part.partNumber,
          ayahRange: part.ayahRange,
          rotationScore: rotationScore,
          recitationCount: totalRecitations,
          lastUsedAtUtc: lastUsedAtUtc,
        ),
    ],
  );

  SurahRotationScheme shiftScores(int delta) {
    if (delta == 0) return this;
    if (parts.any((SurahRotationPart part) => part.rotationScore + delta < 0)) {
      throw StateError('The adjustment would make a part score negative.');
    }
    return copyWith(
      parts: parts.map(
        (SurahRotationPart part) =>
            part.copyWith(rotationScore: part.rotationScore + delta),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahRotationScheme &&
          id == other.id &&
          surahId == other.surahId &&
          version == other.version &&
          ayahCount == other.ayahCount &&
          baselineRotationScore == other.baselineRotationScore &&
          baselineTotalRecitations == other.baselineTotalRecitations &&
          baselineLastUsedAtUtc == other.baselineLastUsedAtUtc &&
          resetsRotationBaseline == other.resetsRotationBaseline &&
          _sameList(parts, other.parts);

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    version,
    ayahCount,
    baselineRotationScore,
    baselineTotalRecitations,
    baselineLastUsedAtUtc,
    resetsRotationBaseline,
    Object.hashAll(parts),
  );
}

/// Produces a deterministic balanced proposal; users may replace the ranges.
List<AyahRange> suggestEvenRanges({
  required int ayahCount,
  required int partCount,
}) {
  if (ayahCount <= 0) {
    throw ArgumentError.value(ayahCount, 'ayahCount', 'Must be positive.');
  }
  if (partCount < 1) {
    throw ArgumentError.value(partCount, 'partCount', 'Must be at least one.');
  }
  if (partCount > ayahCount) {
    throw ArgumentError.value(
      partCount,
      'partCount',
      'Every part must contain at least one ayah.',
    );
  }

  final baseLength = ayahCount ~/ partCount;
  final longerPartCount = ayahCount % partCount;
  var start = 1;
  return List<AyahRange>.unmodifiable(<AyahRange>[
    for (var index = 0; index < partCount; index += 1)
      (() {
        final length = baseLength + (index < longerPartCount ? 1 : 0);
        final range = AyahRange(startAyah: start, endAyah: start + length - 1);
        start = range.endAyah + 1;
        return range;
      })(),
  ]);
}

void _validateParts({
  required String schemeId,
  required int ayahCount,
  required List<SurahRotationPart> parts,
}) {
  if (parts.isEmpty || parts.length > ayahCount) {
    throw ArgumentError.value(
      parts.length,
      'parts',
      'A scheme must contain between one and ayahCount parts.',
    );
  }
  final ids = <String>{};
  var expectedStart = 1;
  for (var index = 0; index < parts.length; index += 1) {
    final part = parts[index];
    if (part.schemeId != schemeId) {
      throw ArgumentError.value(
        part.schemeId,
        'parts',
        'Every part must belong to scheme "$schemeId".',
      );
    }
    if (!ids.add(part.id)) {
      throw ArgumentError.value(part.id, 'parts', 'Part IDs must be unique.');
    }
    final expectedNumber = index + 1;
    if (part.partNumber != expectedNumber) {
      throw ArgumentError.value(
        part.partNumber,
        'parts',
        'Part numbers must be unique and sequential from one.',
      );
    }
    if (part.ayahRange.startAyah != expectedStart) {
      throw ArgumentError.value(
        part.ayahRange,
        'parts',
        'Parts must be contiguous, without gaps or overlap.',
      );
    }
    if (part.ayahRange.endAyah > ayahCount) {
      throw ArgumentError.value(
        part.ayahRange,
        'parts',
        'A part must not exceed ayahCount.',
      );
    }
    expectedStart = part.ayahRange.endAyah + 1;
  }
  if (expectedStart != ayahCount + 1) {
    throw ArgumentError.value(
      parts.last.ayahRange,
      'parts',
      'The final part must end at ayahCount.',
    );
  }
}
