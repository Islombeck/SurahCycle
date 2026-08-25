import 'rotation_scheme.dart';

const Object _notProvided = Object();

/// Verified metadata needed by the repetition and learning domains.
///
/// Values are supplied by a content repository. This type never fabricates or
/// normalizes Quran content.
final class SurahDescriptor {
  static const int alFatihaSurahNumber = 1;

  factory SurahDescriptor({
    required String id,
    required int surahNumber,
    required String officialName,
    required int ayahCount,
    String? alias,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (surahNumber <= 0) {
      throw ArgumentError.value(
        surahNumber,
        'surahNumber',
        'Must be positive.',
      );
    }
    if (officialName.isEmpty) {
      throw ArgumentError.value(
        officialName,
        'officialName',
        'Must not be empty.',
      );
    }
    if (ayahCount <= 0) {
      throw ArgumentError.value(ayahCount, 'ayahCount', 'Must be positive.');
    }
    return SurahDescriptor._(
      id: id,
      surahNumber: surahNumber,
      officialName: officialName,
      ayahCount: ayahCount,
      alias: alias,
    );
  }

  const SurahDescriptor._({
    required this.id,
    required this.surahNumber,
    required this.officialName,
    required this.ayahCount,
    required this.alias,
  });

  final String id;
  final int surahNumber;
  final String officialName;
  final int ayahCount;
  final String? alias;

  bool get isAlFatiha => surahNumber == alFatihaSurahNumber;

  /// Al-Fatiha remains available to catalog, content, history, and learning,
  /// but it is deliberately excluded from the ordinary rotation pool.
  bool get isRotationEligible => !isAlFatiha;

  String get displayName =>
      alias == null || alias!.isEmpty ? officialName : alias!;

  SurahDescriptor copyWith({Object? alias = _notProvided}) => SurahDescriptor(
    id: id,
    surahNumber: surahNumber,
    officialName: officialName,
    ayahCount: ayahCount,
    alias: identical(alias, _notProvided) ? this.alias : alias as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahDescriptor &&
          id == other.id &&
          surahNumber == other.surahNumber &&
          officialName == other.officialName &&
          ayahCount == other.ayahCount &&
          alias == other.alias;

  @override
  int get hashCode =>
      Object.hash(id, surahNumber, officialName, ayahCount, alias);
}

/// User-owned repetition state for one mastered surah.
final class MasteredSurah {
  factory MasteredSurah({
    required SurahDescriptor surah,
    bool isActive = false,
    bool hasEnteredRotation = false,
    int? totalRecitations,
    int? rotationScore,
    int displayOrder = 0,
    DateTime? lastUsedAtUtc,
    SurahRotationScheme? rotationScheme,
  }) {
    if (isActive && !hasEnteredRotation) {
      throw ArgumentError(
        'An active surah must already have entered the rotation.',
      );
    }
    if (totalRecitations != null && totalRecitations < 0) {
      throw ArgumentError.value(
        totalRecitations,
        'totalRecitations',
        'Must not be negative.',
      );
    }
    if (rotationScore != null && rotationScore < 0) {
      throw ArgumentError.value(
        rotationScore,
        'rotationScore',
        'Must not be negative.',
      );
    }
    if (lastUsedAtUtc != null && !lastUsedAtUtc.isUtc) {
      throw ArgumentError.value(lastUsedAtUtc, 'lastUsedAtUtc', 'Must be UTC.');
    }
    final resolvedScheme =
        rotationScheme ??
        SurahRotationScheme.unsplit(
          id: '${surah.id}:scheme:1',
          surahId: surah.id,
          version: 1,
          ayahCount: surah.ayahCount,
          baselineRotationScore: rotationScore ?? 0,
          baselineTotalRecitations: totalRecitations ?? 0,
          baselineLastUsedAtUtc: lastUsedAtUtc,
        );
    if (resolvedScheme.surahId != surah.id) {
      throw ArgumentError.value(
        resolvedScheme.surahId,
        'rotationScheme',
        'The scheme must belong to the mastered surah.',
      );
    }
    if (resolvedScheme.ayahCount != surah.ayahCount) {
      throw ArgumentError.value(
        resolvedScheme.ayahCount,
        'rotationScheme',
        'The scheme must use the verified surah ayahCount.',
      );
    }
    if (rotationScore != null &&
        rotationScore != resolvedScheme.effectiveRotationScore) {
      throw ArgumentError.value(
        rotationScore,
        'rotationScore',
        'Must equal the active scheme effective score.',
      );
    }
    if (totalRecitations != null &&
        totalRecitations != resolvedScheme.fullEquivalentRecitations) {
      throw ArgumentError.value(
        totalRecitations,
        'totalRecitations',
        'Must equal the active scheme full-equivalent count.',
      );
    }
    if (lastUsedAtUtc != null &&
        lastUsedAtUtc != resolvedScheme.lastUsedAtUtc) {
      throw ArgumentError.value(
        lastUsedAtUtc,
        'lastUsedAtUtc',
        'Must equal the active scheme last-used time.',
      );
    }
    return MasteredSurah._(
      surah: surah,
      isActive: isActive,
      hasEnteredRotation: hasEnteredRotation,
      displayOrder: displayOrder,
      rotationScheme: resolvedScheme,
    );
  }

  const MasteredSurah._({
    required this.surah,
    required this.isActive,
    required this.hasEnteredRotation,
    required this.displayOrder,
    required this.rotationScheme,
  });

  final SurahDescriptor surah;
  final bool isActive;
  final bool hasEnteredRotation;
  final int displayOrder;
  final SurahRotationScheme rotationScheme;

  String get id => surah.id;
  int get totalRecitations => rotationScheme.fullEquivalentRecitations;
  int get rotationScore => rotationScheme.effectiveRotationScore;
  DateTime? get lastUsedAtUtc => rotationScheme.lastUsedAtUtc;

  MasteredSurah copyWith({
    SurahDescriptor? surah,
    bool? isActive,
    bool? hasEnteredRotation,
    int? totalRecitations,
    int? rotationScore,
    int? displayOrder,
    Object? lastUsedAtUtc = _notProvided,
    SurahRotationScheme? rotationScheme,
  }) {
    var resolvedScheme = rotationScheme ?? this.rotationScheme;
    if (rotationScore != null &&
        rotationScore != resolvedScheme.effectiveRotationScore) {
      resolvedScheme = resolvedScheme.shiftScores(
        rotationScore - resolvedScheme.effectiveRotationScore,
      );
    }
    if (totalRecitations != null &&
        totalRecitations != resolvedScheme.fullEquivalentRecitations) {
      final delta = totalRecitations - resolvedScheme.fullEquivalentRecitations;
      if (resolvedScheme.parts.any(
        (SurahRotationPart part) => part.recitationCount + delta < 0,
      )) {
        throw StateError('The update would make a part count negative.');
      }
      resolvedScheme = resolvedScheme.copyWith(
        parts: resolvedScheme.parts.map(
          (SurahRotationPart part) =>
              part.copyWith(recitationCount: part.recitationCount + delta),
        ),
      );
    }
    if (!identical(lastUsedAtUtc, _notProvided)) {
      resolvedScheme = resolvedScheme.copyWith(
        parts: resolvedScheme.parts.map(
          (SurahRotationPart part) =>
              part.copyWith(lastUsedAtUtc: lastUsedAtUtc as DateTime?),
        ),
      );
    }
    return MasteredSurah(
      surah: surah ?? this.surah,
      isActive: isActive ?? this.isActive,
      hasEnteredRotation: hasEnteredRotation ?? this.hasEnteredRotation,
      displayOrder: displayOrder ?? this.displayOrder,
      rotationScheme: resolvedScheme,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasteredSurah &&
          surah == other.surah &&
          isActive == other.isActive &&
          hasEnteredRotation == other.hasEnteredRotation &&
          displayOrder == other.displayOrder &&
          rotationScheme == other.rotationScheme;

  @override
  int get hashCode => Object.hash(
    surah,
    isActive,
    hasEnteredRotation,
    displayOrder,
    rotationScheme,
  );
}
