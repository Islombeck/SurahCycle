import 'prayer.dart';

enum PrayerRoutinePartKind { fard, sunnah, witr, nafl, custom }

enum PrayerPartCompletionMode { recitations, followedImam }

final class PrayerRoutinePartTemplate {
  factory PrayerRoutinePartTemplate({
    required String id,
    required String stableKey,
    required int orderIndex,
    required PrayerRoutinePartKind kind,
    String? customLabel,
    required int rakaatCount,
    required int requiredSurahSlots,
    bool allowsFollowingImam = false,
    PrayerPartCompletionMode defaultCompletionMode =
        PrayerPartCompletionMode.recitations,
  }) {
    if (id.isEmpty || stableKey.isEmpty || orderIndex < 0) {
      throw ArgumentError('Routine part identity/order is invalid.');
    }
    if (kind == PrayerRoutinePartKind.custom &&
        (customLabel == null || customLabel.isEmpty)) {
      throw ArgumentError('A custom part requires a label.');
    }
    if (rakaatCount <= 0 || requiredSurahSlots < 0) {
      throw ArgumentError('Rakaat and slot counts are invalid.');
    }
    if (defaultCompletionMode == PrayerPartCompletionMode.followedImam &&
        !allowsFollowingImam) {
      throw ArgumentError('Following imam must be explicitly allowed.');
    }
    return PrayerRoutinePartTemplate._(
      id: id,
      stableKey: stableKey,
      orderIndex: orderIndex,
      kind: kind,
      customLabel: customLabel,
      rakaatCount: rakaatCount,
      requiredSurahSlots: requiredSurahSlots,
      allowsFollowingImam: allowsFollowingImam,
      defaultCompletionMode: defaultCompletionMode,
    );
  }

  const PrayerRoutinePartTemplate._({
    required this.id,
    required this.stableKey,
    required this.orderIndex,
    required this.kind,
    required this.customLabel,
    required this.rakaatCount,
    required this.requiredSurahSlots,
    required this.allowsFollowingImam,
    required this.defaultCompletionMode,
  });

  final String id;
  final String stableKey;
  final int orderIndex;
  final PrayerRoutinePartKind kind;
  final String? customLabel;
  final int rakaatCount;
  final int requiredSurahSlots;
  final bool allowsFollowingImam;
  final PrayerPartCompletionMode defaultCompletionMode;

  String get displayLabel => customLabel ?? kind.name;
}

final class PrayerRoutineTemplate {
  factory PrayerRoutineTemplate({
    required String id,
    required PrayerType prayerType,
    required String displayName,
    bool enabled = true,
    required int revision,
    Iterable<PrayerRoutinePartTemplate> parts =
        const <PrayerRoutinePartTemplate>[],
  }) {
    if (id.isEmpty || displayName.isEmpty || revision <= 0) {
      throw ArgumentError('Routine template identity/revision is invalid.');
    }
    final ordered = List<PrayerRoutinePartTemplate>.unmodifiable(parts);
    for (var index = 0; index < ordered.length; index += 1) {
      if (ordered[index].orderIndex != index) {
        throw ArgumentError('Routine part order must be contiguous.');
      }
    }
    if (ordered.map((part) => part.stableKey).toSet().length !=
        ordered.length) {
      throw ArgumentError('Routine stable keys must be unique.');
    }
    return PrayerRoutineTemplate._(
      id: id,
      prayerType: prayerType,
      displayName: displayName,
      enabled: enabled,
      revision: revision,
      parts: ordered,
    );
  }

  const PrayerRoutineTemplate._({
    required this.id,
    required this.prayerType,
    required this.displayName,
    required this.enabled,
    required this.revision,
    required this.parts,
  });

  final String id;
  final PrayerType prayerType;
  final String displayName;
  final bool enabled;
  final int revision;
  final List<PrayerRoutinePartTemplate> parts;
}

final class PrayerSessionPart {
  const PrayerSessionPart({
    required this.id,
    required this.prayerSessionId,
    required this.sourceTemplatePartId,
    required this.templateRevision,
    required this.stableKey,
    required this.orderIndex,
    required this.label,
    required this.kind,
    required this.rakaatCount,
    required this.requiredSurahSlots,
    required this.allowsFollowingImam,
    required this.completionMode,
    required this.completedAtUtc,
  });

  final String id;
  final String prayerSessionId;
  final String? sourceTemplatePartId;
  final int? templateRevision;
  final String stableKey;
  final int orderIndex;
  final String label;
  final PrayerRoutinePartKind kind;
  final int rakaatCount;
  final int requiredSurahSlots;
  final bool allowsFollowingImam;
  final PrayerPartCompletionMode completionMode;
  final DateTime? completedAtUtc;

  bool get isCompleted => completedAtUtc != null;
  bool get wasFollowedImam =>
      isCompleted && completionMode == PrayerPartCompletionMode.followedImam;
}
