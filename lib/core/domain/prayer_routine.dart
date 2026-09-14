import 'prayer.dart';

enum PrayerRoutinePartKind { fard, sunnah, witr, nafl, custom }

enum PrayerPartCompletionMode { recitations, followedImam }

/// Which routine parts a Qada context may contain.
///
/// Qada applies to the missed obligation itself, never to the voluntary parts
/// a user performs around it, so eligibility depends on both the prayer and
/// the kind of its part. [PrayerType.supportsQada] alone cannot express that:
/// it only answers whether the prayer has a make-up obligation at all.
///
/// This is the single source of truth. The routine snapshot filters by it, and
/// the recitation repository re-checks it at the write boundary, so a deep
/// link, a widget action, or a direct method call cannot bypass the rule.
abstract final class PrayerQadaPolicy {
  /// The one part kind that carries the obligation of [prayerType], or null
  /// when the prayer has no make-up obligation at all.
  static PrayerRoutinePartKind? obligatoryPartKind(PrayerType prayerType) =>
      switch (prayerType) {
        PrayerType.fajr ||
        PrayerType.dhuhr ||
        PrayerType.asr ||
        PrayerType.maghrib ||
        PrayerType.isha => PrayerRoutinePartKind.fard,
        PrayerType.witr => PrayerRoutinePartKind.witr,
        PrayerType.jumuah || PrayerType.nafl => null,
      };

  /// Ordinary prayers keep every configured part; a Qada context keeps only
  /// the obligatory one. Sunnah, Nafl and custom parts never become Qada.
  ///
  /// Takes the two coordinates separately so a stored row can be checked
  /// without rebuilding a [PrayerContext], whose own constructor rejects
  /// combinations that legacy history may still legitimately contain.
  static bool allowsPart({
    required PrayerType prayerType,
    required bool isQada,
    required PrayerRoutinePartKind kind,
  }) {
    if (!isQada) return true;
    return obligatoryPartKind(prayerType) == kind;
  }

  static bool allowsPartKind({
    required PrayerContext context,
    required PrayerRoutinePartKind kind,
  }) => allowsPart(
    prayerType: context.prayerType,
    isQada: context.isQada,
    kind: kind,
  );
}

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
