import 'widget_deep_link.dart';
import 'widget_snapshot.dart';

/// Localized labels supplied by the Flutter localization layer.
final class WidgetProjectionLabels {
  const WidgetProjectionLabels({
    required this.part,
    required this.ayah,
    required this.ayahs,
    required this.openAppToLoadText,
  });

  final String part;
  final String ayah;
  final String ayahs;
  final String openAppToLoadText;
}

final class RotationWidgetCandidate {
  factory RotationWidgetCandidate.whole({
    required String id,
    required String surahId,
    required int surahNumber,
    required String displayName,
    required int ayahCount,
    required int remaining,
    required bool isRecommended,
    required int displayOrder,
    DateTime? lastUsedAtUtc,
  }) => RotationWidgetCandidate._validated(
    id: id,
    surahId: surahId,
    surahNumber: surahNumber,
    displayName: displayName,
    ayahCount: ayahCount,
    partId: null,
    partIndex: null,
    partCount: null,
    startAyah: null,
    endAyah: null,
    remaining: remaining,
    isRecommended: isRecommended,
    displayOrder: displayOrder,
    lastUsedAtUtc: lastUsedAtUtc,
  );

  factory RotationWidgetCandidate.part({
    required String id,
    required String surahId,
    required int surahNumber,
    required String displayName,
    required String partId,
    required int partIndex,
    required int partCount,
    required int startAyah,
    required int endAyah,
    required int remaining,
    required bool isRecommended,
    required int displayOrder,
    DateTime? lastUsedAtUtc,
  }) => RotationWidgetCandidate._validated(
    id: id,
    surahId: surahId,
    surahNumber: surahNumber,
    displayName: displayName,
    ayahCount: null,
    partId: partId,
    partIndex: partIndex,
    partCount: partCount,
    startAyah: startAyah,
    endAyah: endAyah,
    remaining: remaining,
    isRecommended: isRecommended,
    displayOrder: displayOrder,
    lastUsedAtUtc: lastUsedAtUtc,
  );

  factory RotationWidgetCandidate._validated({
    required String id,
    required String surahId,
    required int surahNumber,
    required String displayName,
    required int? ayahCount,
    required String? partId,
    required int? partIndex,
    required int? partCount,
    required int? startAyah,
    required int? endAyah,
    required int remaining,
    required bool isRecommended,
    required int displayOrder,
    required DateTime? lastUsedAtUtc,
  }) {
    if (id.isEmpty || surahId.isEmpty || displayName.isEmpty) {
      throw ArgumentError(
        'Widget candidate identifiers/text must not be empty.',
      );
    }
    if (surahNumber <= 0) {
      throw ArgumentError('Surah number must be positive.');
    }
    if (lastUsedAtUtc != null && !lastUsedAtUtc.isUtc) {
      throw ArgumentError.value(lastUsedAtUtc, 'lastUsedAtUtc', 'Must be UTC.');
    }
    if (partId == null) {
      if (ayahCount == null || ayahCount <= 0) {
        throw ArgumentError.value(ayahCount, 'ayahCount', 'Must be positive.');
      }
    } else if (partId.isEmpty ||
        partIndex == null ||
        partCount == null ||
        startAyah == null ||
        endAyah == null ||
        partIndex <= 0 ||
        partIndex > partCount ||
        startAyah <= 0 ||
        endAyah < startAyah) {
      throw ArgumentError('Invalid part metadata.');
    }
    return RotationWidgetCandidate._(
      id: id,
      surahId: surahId,
      surahNumber: surahNumber,
      displayName: displayName,
      ayahCount: ayahCount,
      partId: partId,
      partIndex: partIndex,
      partCount: partCount,
      startAyah: startAyah,
      endAyah: endAyah,
      remaining: remaining,
      isRecommended: isRecommended,
      displayOrder: displayOrder,
      lastUsedAtUtc: lastUsedAtUtc,
    );
  }

  const RotationWidgetCandidate._({
    required this.id,
    required this.surahId,
    required this.surahNumber,
    required this.displayName,
    required this.ayahCount,
    required this.partId,
    required this.partIndex,
    required this.partCount,
    required this.startAyah,
    required this.endAyah,
    required this.remaining,
    required this.isRecommended,
    required this.displayOrder,
    required this.lastUsedAtUtc,
  });

  final String id;
  final String surahId;
  final int surahNumber;
  final String displayName;
  final int? ayahCount;
  final String? partId;
  final int? partIndex;
  final int? partCount;
  final int? startAyah;
  final int? endAyah;
  final int remaining;
  final bool isRecommended;
  final int displayOrder;
  final DateTime? lastUsedAtUtc;
}

final class LearningWidgetCandidate {
  factory LearningWidgetCandidate({
    required String surahId,
    required int surahNumber,
    required String displayName,
    required String stageLabel,
    required int startAyah,
    required int endAyah,
    Iterable<String> verifiedTextLines = const <String>[],
  }) {
    if (surahId.isEmpty || displayName.isEmpty || stageLabel.isEmpty) {
      throw ArgumentError('Learning widget fields must not be empty.');
    }
    if (surahNumber <= 0 || startAyah <= 0 || endAyah < startAyah) {
      throw ArgumentError('Invalid learning ayah range.');
    }
    return LearningWidgetCandidate._(
      surahId: surahId,
      surahNumber: surahNumber,
      displayName: displayName,
      stageLabel: stageLabel,
      startAyah: startAyah,
      endAyah: endAyah,
      verifiedTextLines: List<String>.unmodifiable(verifiedTextLines),
    );
  }

  const LearningWidgetCandidate._({
    required this.surahId,
    required this.surahNumber,
    required this.displayName,
    required this.stageLabel,
    required this.startAyah,
    required this.endAyah,
    required this.verifiedTextLines,
  });

  final String surahId;
  final int surahNumber;
  final String displayName;
  final String stageLabel;
  final int startAyah;
  final int endAyah;

  /// Must originate from the verified Quran cache boundary. It is forwarded
  /// byte-for-byte as Dart strings; the builder never generates Quran text.
  final List<String> verifiedTextLines;
}

final class WidgetProjectionBuilder {
  const WidgetProjectionBuilder(this.labels);

  final WidgetProjectionLabels labels;

  WidgetSnapshot build({
    required DateTime generatedAtUtc,
    required String locale,
    required Iterable<RotationWidgetCandidate> rotationCandidates,
    LearningWidgetCandidate? learningCandidate,
  }) => WidgetSnapshot(
    generatedAtUtc: generatedAtUtc,
    locale: locale,
    rotation: buildRotation(rotationCandidates),
    learning: buildLearning(learningCandidate),
  );

  RotationWidgetProjection buildRotation(
    Iterable<RotationWidgetCandidate> candidates,
  ) {
    final due =
        candidates
            .where((candidate) => candidate.remaining > 0)
            .toList(growable: false)
          ..sort(_compareRotation);
    return RotationWidgetProjection(items: due.map(_rotationItem));
  }

  LearningWidgetProjection buildLearning(LearningWidgetCandidate? candidate) {
    if (candidate == null) return const LearningWidgetProjection.empty();
    final rangeLabel = candidate.startAyah == candidate.endAyah
        ? '${labels.ayah} ${candidate.startAyah}'
        : '${labels.ayahs} ${candidate.startAyah}–${candidate.endAyah}';
    return LearningWidgetProjection.selected(
      LearningWidgetItem(
        surahId: candidate.surahId,
        title: '${candidate.surahNumber}. ${candidate.displayName}',
        stageLabel: candidate.stageLabel,
        rangeLabel: rangeLabel,
        unavailableTextLabel: labels.openAppToLoadText,
        verifiedTextLines: candidate.verifiedTextLines,
        deepLink: WidgetLearningDeepLink(candidate.surahId).uri,
      ),
    );
  }

  RotationWidgetItem _rotationItem(RotationWidgetCandidate candidate) {
    final isPart = candidate.partId != null;
    return RotationWidgetItem(
      id: candidate.id,
      surahId: candidate.surahId,
      partId: candidate.partId,
      title: isPart
          ? '${candidate.surahNumber}. ${candidate.displayName}'
          : '${candidate.surahNumber}. ${candidate.displayName} · '
                '${candidate.ayahCount}',
      subtitle: isPart
          ? '${labels.part} ${candidate.partIndex}/${candidate.partCount} · '
                '${labels.ayahs} ${candidate.startAyah}–${candidate.endAyah}'
          : null,
      remaining: candidate.remaining,
      isRecommended: candidate.isRecommended,
      deepLink: WidgetSurahDeepLink(
        surahId: candidate.surahId,
        partId: candidate.partId,
      ).uri,
    );
  }

  int _compareRotation(
    RotationWidgetCandidate left,
    RotationWidgetCandidate right,
  ) {
    final recommendation = _descendingBool(
      left.isRecommended,
      right.isRecommended,
    );
    if (recommendation != 0) return recommendation;

    final remaining = right.remaining.compareTo(left.remaining);
    if (remaining != 0) return remaining;

    final leftUsed = left.lastUsedAtUtc;
    final rightUsed = right.lastUsedAtUtc;
    if (leftUsed == null && rightUsed != null) return -1;
    if (leftUsed != null && rightUsed == null) return 1;
    if (leftUsed != null && rightUsed != null) {
      final lastUsed = leftUsed.compareTo(rightUsed);
      if (lastUsed != 0) return lastUsed;
    }

    final displayOrder = left.displayOrder.compareTo(right.displayOrder);
    if (displayOrder != 0) return displayOrder;
    final surahNumber = left.surahNumber.compareTo(right.surahNumber);
    if (surahNumber != 0) return surahNumber;
    final partIndex = (left.partIndex ?? 0).compareTo(right.partIndex ?? 0);
    if (partIndex != 0) return partIndex;
    return left.id.compareTo(right.id);
  }
}

int _descendingBool(bool left, bool right) {
  if (left == right) return 0;
  return left ? -1 : 1;
}
