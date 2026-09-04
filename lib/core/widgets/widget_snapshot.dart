import 'dart:convert';

import '../application/widget_recitation_action.dart';
import '../domain/suggestion.dart';
import 'widget_deep_link.dart';

/// Shared storage key used by Flutter and the native widget implementations.
const String widgetSnapshotStorageKey = 'murajaah_widget_snapshot';

/// Shared protocol ceilings mirrored by the native Android decoder.
const int maxRotationWidgetItems = 64;
const int maxLearningWidgetAyahLines = 3;

/// A fully denormalized, display-ready projection for home-screen widgets.
///
/// Native widgets must not derive domain state from this object. Dart owns
/// ordering, debt calculation, labels, ranges, aliases, and deep links.
final class WidgetSnapshot {
  factory WidgetSnapshot({
    required DateTime generatedAtUtc,
    int snapshotRevision = 0,
    required String locale,
    required RotationWidgetProjection rotation,
    required LearningWidgetProjection learning,
    required PrayerWidgetProjection prayer,
  }) {
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError.value(
        generatedAtUtc,
        'generatedAtUtc',
        'Must be UTC.',
      );
    }
    _requireText(locale, 'locale', maxLength: 32);
    if (snapshotRevision < 0) {
      throw ArgumentError.value(
        snapshotRevision,
        'snapshotRevision',
        'Must not be negative.',
      );
    }
    return WidgetSnapshot._(
      generatedAtUtc: generatedAtUtc,
      snapshotRevision: snapshotRevision,
      locale: locale,
      rotation: rotation,
      learning: learning,
      prayer: prayer,
    );
  }

  const WidgetSnapshot._({
    required this.generatedAtUtc,
    required this.snapshotRevision,
    required this.locale,
    required this.rotation,
    required this.learning,
    required this.prayer,
  });

  static const int schemaVersion = 6;

  final DateTime generatedAtUtc;
  final int snapshotRevision;
  final String locale;
  final RotationWidgetProjection rotation;
  final LearningWidgetProjection learning;
  final PrayerWidgetProjection prayer;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'generatedAtUtc': generatedAtUtc.toIso8601String(),
    'snapshotRevision': snapshotRevision,
    'locale': locale,
    'rotation': rotation.toJson(),
    'learning': learning.toJson(),
    'prayer': prayer.toJson(),
  };

  /// Ignores generation time so stream recomputation does not wake launchers
  /// when the actual projection has not changed.
  bool sameProjectionAs(WidgetSnapshot other) =>
      locale == other.locale &&
      rotation == other.rotation &&
      learning == other.learning &&
      prayer == other.prayer;

  static WidgetSnapshot _fromJson(Map<String, Object?> json) {
    final generatedAtUtc = DateTime.parse(_string(json, 'generatedAtUtc'));
    if (!generatedAtUtc.isUtc) {
      throw const FormatException('generatedAtUtc must include a UTC offset.');
    }
    return WidgetSnapshot(
      generatedAtUtc: generatedAtUtc,
      snapshotRevision: _integer(json, 'snapshotRevision'),
      locale: _string(json, 'locale'),
      rotation: RotationWidgetProjection._fromJson(_map(json, 'rotation')),
      learning: LearningWidgetProjection._fromJson(_map(json, 'learning')),
      prayer: PrayerWidgetProjection._fromJson(_map(json, 'prayer')),
    );
  }
}

final class RotationWidgetProjection {
  factory RotationWidgetProjection({
    required Iterable<RotationWidgetItem> items,
    int omittedCount = 0,
    String contextLabel = 'Rotation',
    String? currentPartLabel,
    String? slotProgressLabel,
    String? statusMessage,
  }) {
    if (omittedCount < 0) {
      throw ArgumentError.value(
        omittedCount,
        'omittedCount',
        'Must not be negative.',
      );
    }
    final result = List<RotationWidgetItem>.unmodifiable(items);
    if (result.length > maxRotationWidgetItems) {
      throw ArgumentError.value(
        result.length,
        'items',
        'Must contain at most $maxRotationWidgetItems rows.',
      );
    }
    _requireText(contextLabel, 'contextLabel', maxLength: 256);
    if (currentPartLabel != null) {
      _requireText(currentPartLabel, 'currentPartLabel', maxLength: 256);
    }
    if (slotProgressLabel != null) {
      _requireText(slotProgressLabel, 'slotProgressLabel', maxLength: 256);
    }
    if (statusMessage != null) {
      _requireText(statusMessage, 'statusMessage', maxLength: 512);
    }
    final ids = <String>{};
    final stableIds = <int>{};
    final recommendationRanks = <int>{};
    final actionTokens = <String>{};
    for (final item in result) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'items', 'IDs must be unique.');
      }
      if (!stableIds.add(stableWidgetItemId(item.id))) {
        throw ArgumentError.value(
          item.id,
          'items',
          'IDs must not collide after native stable hashing.',
        );
      }
      final rank = item.recommendationRank;
      if (rank != null && !recommendationRanks.add(rank)) {
        throw ArgumentError.value(
          rank,
          'items',
          'Recommendation ranks must be unique.',
        );
      }
      final action = item.action;
      if (action != null && !actionTokens.add(action.actionToken)) {
        throw ArgumentError.value(
          action.actionToken,
          'items',
          'Widget action tokens must be unique.',
        );
      }
    }
    return RotationWidgetProjection._(
      result,
      omittedCount,
      contextLabel,
      currentPartLabel,
      slotProgressLabel,
      statusMessage,
    );
  }

  const RotationWidgetProjection._(
    this.items,
    this.omittedCount,
    this.contextLabel,
    this.currentPartLabel,
    this.slotProgressLabel,
    this.statusMessage,
  );

  final List<RotationWidgetItem> items;
  final int omittedCount;
  final String contextLabel;
  final String? currentPartLabel;
  final String? slotProgressLabel;
  final String? statusMessage;

  Map<String, Object?> toJson() => <String, Object?>{
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'omittedCount': omittedCount,
    'contextLabel': contextLabel,
    if (currentPartLabel != null) 'currentPartLabel': currentPartLabel,
    if (slotProgressLabel != null) 'slotProgressLabel': slotProgressLabel,
    if (statusMessage != null) 'statusMessage': statusMessage,
  };

  static RotationWidgetProjection _fromJson(Map<String, Object?> json) =>
      RotationWidgetProjection(
        items: _list(
          json,
          'items',
        ).map((item) => RotationWidgetItem._fromJson(_asMap(item, 'item'))),
        omittedCount: _integer(json, 'omittedCount'),
        contextLabel: _string(json, 'contextLabel'),
        currentPartLabel: _nullableString(json, 'currentPartLabel'),
        slotProgressLabel: _nullableString(json, 'slotProgressLabel'),
        statusMessage: _nullableString(json, 'statusMessage'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationWidgetProjection &&
          _listEquals(items, other.items) &&
          omittedCount == other.omittedCount &&
          contextLabel == other.contextLabel &&
          currentPartLabel == other.currentPartLabel &&
          slotProgressLabel == other.slotProgressLabel &&
          statusMessage == other.statusMessage;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    omittedCount,
    contextLabel,
    currentPartLabel,
    slotProgressLabel,
    statusMessage,
  );
}

final class RotationWidgetItem {
  factory RotationWidgetItem({
    required String id,
    required String surahId,
    String? partId,
    required String title,
    String? subtitle,
    required int remaining,
    int? recommendationRank,
    required Uri deepLink,
    WidgetRecitationAction? action,
    bool isMarkedInCurrentPart = false,
    bool isActionInProgress = false,
    bool? canMark,
    String? disabledReason,
  }) {
    _requireText(id, 'id', maxLength: 256);
    _requireText(surahId, 'surahId', maxLength: 128);
    if (partId != null) _requireText(partId, 'partId', maxLength: 128);
    _requireText(title, 'title', maxLength: 512);
    if (subtitle != null) _requireText(subtitle, 'subtitle', maxLength: 512);
    if (remaining < 0) {
      throw ArgumentError.value(
        remaining,
        'remaining',
        'Must not be negative.',
      );
    }
    if (recommendationRank != null &&
        (recommendationRank < 0 ||
            recommendationRank >= maxRecommendationCount)) {
      throw ArgumentError.value(
        recommendationRank,
        'recommendationRank',
        'Must be in the product range '
            '0–${maxRecommendationCount - 1}.',
      );
    }
    final parsedLink = WidgetDeepLink.parse(deepLink);
    if (parsedLink is! WidgetSurahDeepLink ||
        parsedLink.surahId != surahId ||
        parsedLink.partId != partId) {
      throw ArgumentError.value(
        deepLink,
        'deepLink',
        'Must target the projected surah and part.',
      );
    }
    if (action != null &&
        (action.surahId != surahId || action.partId != partId)) {
      throw ArgumentError.value(
        action,
        'action',
        'Must target the projected surah and part.',
      );
    }
    final effectiveCanMark = canMark ?? action != null;
    if ((effectiveCanMark && action == null) ||
        (isMarkedInCurrentPart && effectiveCanMark)) {
      throw ArgumentError('Markability must match the committed item state.');
    }
    if (disabledReason != null) {
      _requireText(disabledReason, 'disabledReason', maxLength: 256);
    }
    return RotationWidgetItem._(
      id: id,
      surahId: surahId,
      partId: partId,
      title: title,
      subtitle: subtitle,
      remaining: remaining,
      recommendationRank: recommendationRank,
      deepLink: deepLink,
      action: action,
      isMarkedInCurrentPart: isMarkedInCurrentPart,
      isActionInProgress: isActionInProgress,
      canMark: effectiveCanMark,
      disabledReason: disabledReason,
    );
  }

  const RotationWidgetItem._({
    required this.id,
    required this.surahId,
    required this.partId,
    required this.title,
    required this.subtitle,
    required this.remaining,
    required this.recommendationRank,
    required this.deepLink,
    required this.action,
    required this.isMarkedInCurrentPart,
    required this.isActionInProgress,
    required this.canMark,
    required this.disabledReason,
  });

  final String id;
  final String surahId;
  final String? partId;
  final String title;
  final String? subtitle;
  final int remaining;
  final int? recommendationRank;
  final Uri deepLink;
  final WidgetRecitationAction? action;
  final bool isMarkedInCurrentPart;
  final bool isActionInProgress;
  final bool canMark;
  final String? disabledReason;

  bool get isRecommended => recommendationRank != null;

  /// Debt text is deliberately derived in Dart, never in Kotlin.
  String get debtLabel => remaining > 1 ? '$remaining×' : '';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'surahId': surahId,
    if (partId != null) 'partId': partId,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'remaining': remaining,
    'debtLabel': debtLabel,
    if (recommendationRank != null) 'recommendationRank': recommendationRank,
    'deepLink': deepLink.toString(),
    if (action != null) 'action': action!.toJson(),
    'isMarkedInCurrentPart': isMarkedInCurrentPart,
    'isActionInProgress': isActionInProgress,
    'canMark': canMark,
    if (disabledReason != null) 'disabledReason': disabledReason,
  };

  static RotationWidgetItem _fromJson(Map<String, Object?> json) {
    final item = RotationWidgetItem(
      id: _string(json, 'id'),
      surahId: _string(json, 'surahId'),
      partId: _nullableString(json, 'partId'),
      title: _string(json, 'title'),
      subtitle: _nullableString(json, 'subtitle'),
      remaining: _integer(json, 'remaining'),
      recommendationRank: json.containsKey('recommendationRank')
          ? _integer(json, 'recommendationRank')
          : null,
      deepLink: Uri.parse(_string(json, 'deepLink')),
      action: json.containsKey('action')
          ? WidgetRecitationAction.fromJson(_map(json, 'action'))
          : null,
      isMarkedInCurrentPart: _boolean(json, 'isMarkedInCurrentPart'),
      isActionInProgress: _boolean(json, 'isActionInProgress'),
      canMark: _boolean(json, 'canMark'),
      disabledReason: _nullableString(json, 'disabledReason'),
    );
    if (_string(json, 'debtLabel') != item.debtLabel) {
      throw const FormatException('debtLabel does not match remaining.');
    }
    return item;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationWidgetItem &&
          id == other.id &&
          surahId == other.surahId &&
          partId == other.partId &&
          title == other.title &&
          subtitle == other.subtitle &&
          remaining == other.remaining &&
          recommendationRank == other.recommendationRank &&
          deepLink == other.deepLink &&
          action == other.action &&
          isMarkedInCurrentPart == other.isMarkedInCurrentPart &&
          isActionInProgress == other.isActionInProgress &&
          canMark == other.canMark &&
          disabledReason == other.disabledReason;

  @override
  int get hashCode => Object.hash(
    id,
    surahId,
    partId,
    title,
    subtitle,
    remaining,
    recommendationRank,
    deepLink,
    action,
    isMarkedInCurrentPart,
    isActionInProgress,
    canMark,
    disabledReason,
  );
}

final class LearningWidgetProjection {
  const LearningWidgetProjection.empty() : item = null;

  const LearningWidgetProjection.selected(LearningWidgetItem selected)
    : item = selected;

  final LearningWidgetItem? item;

  Map<String, Object?> toJson() => <String, Object?>{
    if (item != null) 'item': item!.toJson(),
  };

  static LearningWidgetProjection _fromJson(Map<String, Object?> json) {
    if (!json.containsKey('item')) {
      return const LearningWidgetProjection.empty();
    }
    return LearningWidgetProjection.selected(
      LearningWidgetItem._fromJson(_map(json, 'item')),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningWidgetProjection && item == other.item;

  @override
  int get hashCode => item.hashCode;
}

/// One coordinate-bound ayah block for the Learning widget.
///
/// The three content layers deliberately live in the same object so an
/// Arabic ayah can never be paired with another ayah's transliteration or
/// translation. Strings are validated without trimming or normalization.
final class LearningWidgetAyahLine {
  factory LearningWidgetAyahLine({
    required int surahNumber,
    required int ayahNumber,
    required String arabic,
    String? transliteration,
    String? translation,
  }) {
    if (surahNumber <= 0) {
      throw ArgumentError.value(
        surahNumber,
        'surahNumber',
        'Must be positive.',
      );
    }
    if (ayahNumber <= 0) {
      throw ArgumentError.value(ayahNumber, 'ayahNumber', 'Must be positive.');
    }
    _requireText(arabic, 'arabic', maxLength: 8192);
    if (transliteration != null) {
      _requireText(transliteration, 'transliteration', maxLength: 8192);
    }
    if (translation != null) {
      _requireText(translation, 'translation', maxLength: 8192);
    }
    return LearningWidgetAyahLine._(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      arabic: arabic,
      transliteration: transliteration,
      translation: translation,
    );
  }

  const LearningWidgetAyahLine._({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabic,
    required this.transliteration,
    required this.translation,
  });

  final int surahNumber;
  final int ayahNumber;
  final String arabic;
  final String? transliteration;
  final String? translation;

  Map<String, Object?> toJson() => <String, Object?>{
    'surah': surahNumber,
    'ayah': ayahNumber,
    'arabic': arabic,
    if (transliteration != null) 'transliteration': transliteration,
    if (translation != null) 'translation': translation,
  };

  static LearningWidgetAyahLine _fromJson(Map<String, Object?> json) =>
      LearningWidgetAyahLine(
        surahNumber: _integer(json, 'surah'),
        ayahNumber: _integer(json, 'ayah'),
        arabic: _string(json, 'arabic'),
        transliteration: _nullableString(json, 'transliteration'),
        translation: _nullableString(json, 'translation'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningWidgetAyahLine &&
          surahNumber == other.surahNumber &&
          ayahNumber == other.ayahNumber &&
          arabic == other.arabic &&
          transliteration == other.transliteration &&
          translation == other.translation;

  @override
  int get hashCode => Object.hash(
    surahNumber,
    ayahNumber,
    arabic,
    transliteration,
    translation,
  );
}

final class LearningWidgetItem {
  factory LearningWidgetItem({
    required String surahId,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    required String title,
    required String stageLabel,
    required String rangeLabel,
    required String unavailableTextLabel,
    Iterable<LearningWidgetAyahLine> ayahLines =
        const <LearningWidgetAyahLine>[],
    bool showArabic = true,
    bool showTransliteration = true,
    bool showTranslation = true,
    required Uri deepLink,
  }) {
    _requireText(surahId, 'surahId', maxLength: 128);
    if (surahNumber <= 0 || startAyah <= 0 || endAyah < startAyah) {
      throw ArgumentError('Invalid Learning widget coordinates.');
    }
    _requireText(title, 'title', maxLength: 512);
    _requireText(stageLabel, 'stageLabel', maxLength: 256);
    _requireText(rangeLabel, 'rangeLabel', maxLength: 256);
    _requireText(unavailableTextLabel, 'unavailableTextLabel', maxLength: 512);
    final lines = List<LearningWidgetAyahLine>.unmodifiable(ayahLines);
    if (lines.length > maxLearningWidgetAyahLines) {
      throw ArgumentError.value(
        lines.length,
        'ayahLines',
        'Must contain at most $maxLearningWidgetAyahLines lines.',
      );
    }
    var previousAyah = 0;
    for (final line in lines) {
      if (line.surahNumber != surahNumber ||
          line.ayahNumber < startAyah ||
          line.ayahNumber > endAyah ||
          line.ayahNumber <= previousAyah) {
        throw ArgumentError.value(
          line,
          'ayahLines',
          'Coordinates must match the surah/range and be strictly ordered.',
        );
      }
      previousAyah = line.ayahNumber;
    }
    final parsedLink = WidgetDeepLink.parse(deepLink);
    if (parsedLink is! WidgetLearningDeepLink ||
        parsedLink.surahId != surahId) {
      throw ArgumentError.value(
        deepLink,
        'deepLink',
        'Must target the projected learning surah.',
      );
    }
    return LearningWidgetItem._(
      surahId: surahId,
      surahNumber: surahNumber,
      startAyah: startAyah,
      endAyah: endAyah,
      title: title,
      stageLabel: stageLabel,
      rangeLabel: rangeLabel,
      unavailableTextLabel: unavailableTextLabel,
      ayahLines: lines,
      showArabic: showArabic,
      showTransliteration: showTransliteration,
      showTranslation: showTranslation,
      deepLink: deepLink,
    );
  }

  const LearningWidgetItem._({
    required this.surahId,
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.title,
    required this.stageLabel,
    required this.rangeLabel,
    required this.unavailableTextLabel,
    required this.ayahLines,
    required this.showArabic,
    required this.showTransliteration,
    required this.showTranslation,
    required this.deepLink,
  });

  final String surahId;
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final String title;
  final String stageLabel;
  final String rangeLabel;
  final String unavailableTextLabel;

  /// Exact verified cached content supplied by Quran repository boundaries.
  /// This model never fabricates, transliterates, trims, or normalizes it.
  final List<LearningWidgetAyahLine> ayahLines;
  final bool showArabic;
  final bool showTransliteration;
  final bool showTranslation;
  final Uri deepLink;

  Map<String, Object?> toJson() => <String, Object?>{
    'surahId': surahId,
    'surahNumber': surahNumber,
    'startAyah': startAyah,
    'endAyah': endAyah,
    'title': title,
    'stageLabel': stageLabel,
    'rangeLabel': rangeLabel,
    'unavailableTextLabel': unavailableTextLabel,
    'showArabic': showArabic,
    'showTransliteration': showTransliteration,
    'showTranslation': showTranslation,
    'ayahLines': ayahLines.map((line) => line.toJson()).toList(growable: false),
    'deepLink': deepLink.toString(),
  };

  static LearningWidgetItem _fromJson(Map<String, Object?> json) =>
      LearningWidgetItem(
        surahId: _string(json, 'surahId'),
        surahNumber: _integer(json, 'surahNumber'),
        startAyah: _integer(json, 'startAyah'),
        endAyah: _integer(json, 'endAyah'),
        title: _string(json, 'title'),
        stageLabel: _string(json, 'stageLabel'),
        rangeLabel: _string(json, 'rangeLabel'),
        unavailableTextLabel: _string(json, 'unavailableTextLabel'),
        ayahLines: _list(json, 'ayahLines').map(
          (line) => LearningWidgetAyahLine._fromJson(_asMap(line, 'ayahLine')),
        ),
        showArabic: _boolean(json, 'showArabic'),
        showTransliteration: _boolean(json, 'showTransliteration'),
        showTranslation: _boolean(json, 'showTranslation'),
        deepLink: Uri.parse(_string(json, 'deepLink')),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningWidgetItem &&
          surahId == other.surahId &&
          surahNumber == other.surahNumber &&
          startAyah == other.startAyah &&
          endAyah == other.endAyah &&
          title == other.title &&
          stageLabel == other.stageLabel &&
          rangeLabel == other.rangeLabel &&
          unavailableTextLabel == other.unavailableTextLabel &&
          _listEquals(ayahLines, other.ayahLines) &&
          showArabic == other.showArabic &&
          showTransliteration == other.showTransliteration &&
          showTranslation == other.showTranslation &&
          deepLink == other.deepLink;

  @override
  int get hashCode => Object.hash(
    surahId,
    surahNumber,
    startAyah,
    endAyah,
    title,
    stageLabel,
    rangeLabel,
    unavailableTextLabel,
    Object.hashAll(ayahLines),
    showArabic,
    showTransliteration,
    showTranslation,
    deepLink,
  );
}

/// Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha — always this exact count and
/// order when [PrayerWidgetProjection.isAvailable].
const int prayerWidgetEntryCount = 6;

/// One row of the six daily boundaries the Prayer Times widget shows.
///
/// [isBoundaryOnly] is true only for Sunrise: it is never [isCurrent] or
/// [isNext] because it is a boundary, not a [PrayerType].
final class PrayerWidgetTimeEntry {
  factory PrayerWidgetTimeEntry({
    required String label,
    required String timeLabel,
    bool isBoundaryOnly = false,
    bool isCurrent = false,
    bool isNext = false,
  }) {
    _requireText(label, 'label', maxLength: 64);
    _requireText(timeLabel, 'timeLabel', maxLength: 16);
    if (isBoundaryOnly && (isCurrent || isNext)) {
      throw ArgumentError('A boundary-only entry cannot be current or next.');
    }
    if (isCurrent && isNext) {
      throw ArgumentError('An entry cannot be both current and next.');
    }
    return PrayerWidgetTimeEntry._(
      label: label,
      timeLabel: timeLabel,
      isBoundaryOnly: isBoundaryOnly,
      isCurrent: isCurrent,
      isNext: isNext,
    );
  }

  const PrayerWidgetTimeEntry._({
    required this.label,
    required this.timeLabel,
    required this.isBoundaryOnly,
    required this.isCurrent,
    required this.isNext,
  });

  final String label;
  final String timeLabel;
  final bool isBoundaryOnly;
  final bool isCurrent;
  final bool isNext;

  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'timeLabel': timeLabel,
    'isBoundaryOnly': isBoundaryOnly,
    'isCurrent': isCurrent,
    'isNext': isNext,
  };

  static PrayerWidgetTimeEntry _fromJson(Map<String, Object?> json) =>
      PrayerWidgetTimeEntry(
        label: _string(json, 'label'),
        timeLabel: _string(json, 'timeLabel'),
        isBoundaryOnly: _boolean(json, 'isBoundaryOnly'),
        isCurrent: _boolean(json, 'isCurrent'),
        isNext: _boolean(json, 'isNext'),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerWidgetTimeEntry &&
          label == other.label &&
          timeLabel == other.timeLabel &&
          isBoundaryOnly == other.isBoundaryOnly &&
          isCurrent == other.isCurrent &&
          isNext == other.isNext;

  @override
  int get hashCode =>
      Object.hash(label, timeLabel, isBoundaryOnly, isCurrent, isNext);
}

/// Display-ready projection for the Android Prayer Times widget.
///
/// Dart resolves current/next and freshness exactly once; Kotlin only picks
/// which fields a given widget size shows. There is no second resolver on
/// the native side.
final class PrayerWidgetProjection {
  factory PrayerWidgetProjection.unavailable({required String messageLabel}) {
    _requireText(messageLabel, 'messageLabel', maxLength: 256);
    return PrayerWidgetProjection._(
      isAvailable: false,
      messageLabel: messageLabel,
      dateLabel: null,
      regionLabel: null,
      providerLabel: null,
      entries: const <PrayerWidgetTimeEntry>[],
      currentLabel: null,
      nextLabel: null,
      isStale: false,
      staleLabel: null,
    );
  }

  factory PrayerWidgetProjection.available({
    required String dateLabel,
    required String regionLabel,
    required String providerLabel,
    required Iterable<PrayerWidgetTimeEntry> entries,
    String? currentLabel,
    String? nextLabel,
    bool isStale = false,
    String? staleLabel,
  }) {
    _requireText(dateLabel, 'dateLabel', maxLength: 128);
    _requireText(regionLabel, 'regionLabel', maxLength: 256);
    _requireText(providerLabel, 'providerLabel', maxLength: 256);
    final result = List<PrayerWidgetTimeEntry>.unmodifiable(entries);
    if (result.length != prayerWidgetEntryCount) {
      throw ArgumentError.value(
        result.length,
        'entries',
        'Must contain exactly $prayerWidgetEntryCount boundaries.',
      );
    }
    if (currentLabel != null) {
      _requireText(currentLabel, 'currentLabel', maxLength: 128);
    }
    if (nextLabel != null) {
      _requireText(nextLabel, 'nextLabel', maxLength: 128);
    }
    if (isStale) {
      if (staleLabel == null) {
        throw ArgumentError('staleLabel is required when isStale is true.');
      }
      _requireText(staleLabel, 'staleLabel', maxLength: 256);
    } else if (staleLabel != null) {
      throw ArgumentError('staleLabel must be null when not stale.');
    }
    if (result.where((entry) => entry.isCurrent).length > 1 ||
        result.where((entry) => entry.isNext).length > 1) {
      throw ArgumentError('At most one entry can be current, one next.');
    }
    return PrayerWidgetProjection._(
      isAvailable: true,
      messageLabel: null,
      dateLabel: dateLabel,
      regionLabel: regionLabel,
      providerLabel: providerLabel,
      entries: result,
      currentLabel: currentLabel,
      nextLabel: nextLabel,
      isStale: isStale,
      staleLabel: staleLabel,
    );
  }

  const PrayerWidgetProjection._({
    required this.isAvailable,
    required this.messageLabel,
    required this.dateLabel,
    required this.regionLabel,
    required this.providerLabel,
    required this.entries,
    required this.currentLabel,
    required this.nextLabel,
    required this.isStale,
    required this.staleLabel,
  });

  final bool isAvailable;
  final String? messageLabel;
  final String? dateLabel;
  final String? regionLabel;
  final String? providerLabel;
  final List<PrayerWidgetTimeEntry> entries;
  final String? currentLabel;
  final String? nextLabel;
  final bool isStale;
  final String? staleLabel;

  /// A stale/unsafe schedule must never let the Rotation Widget auto-mark
  /// against a boundary that might already be wrong.
  bool get allowsRotationAutoMark => isAvailable && !isStale;

  Map<String, Object?> toJson() => <String, Object?>{
    'isAvailable': isAvailable,
    if (messageLabel != null) 'messageLabel': messageLabel,
    if (dateLabel != null) 'dateLabel': dateLabel,
    if (regionLabel != null) 'regionLabel': regionLabel,
    if (providerLabel != null) 'providerLabel': providerLabel,
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    if (currentLabel != null) 'currentLabel': currentLabel,
    if (nextLabel != null) 'nextLabel': nextLabel,
    'isStale': isStale,
    if (staleLabel != null) 'staleLabel': staleLabel,
  };

  static PrayerWidgetProjection _fromJson(Map<String, Object?> json) {
    final isAvailable = _boolean(json, 'isAvailable');
    if (!isAvailable) {
      return PrayerWidgetProjection.unavailable(
        messageLabel: _string(json, 'messageLabel'),
      );
    }
    return PrayerWidgetProjection.available(
      dateLabel: _string(json, 'dateLabel'),
      regionLabel: _string(json, 'regionLabel'),
      providerLabel: _string(json, 'providerLabel'),
      entries: _list(
        json,
        'entries',
      ).map((entry) => PrayerWidgetTimeEntry._fromJson(_asMap(entry, 'entry'))),
      currentLabel: _nullableString(json, 'currentLabel'),
      nextLabel: _nullableString(json, 'nextLabel'),
      isStale: _boolean(json, 'isStale'),
      staleLabel: _nullableString(json, 'staleLabel'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerWidgetProjection &&
          isAvailable == other.isAvailable &&
          messageLabel == other.messageLabel &&
          dateLabel == other.dateLabel &&
          regionLabel == other.regionLabel &&
          providerLabel == other.providerLabel &&
          _listEquals(entries, other.entries) &&
          currentLabel == other.currentLabel &&
          nextLabel == other.nextLabel &&
          isStale == other.isStale &&
          staleLabel == other.staleLabel;

  @override
  int get hashCode => Object.hash(
    isAvailable,
    messageLabel,
    dateLabel,
    regionLabel,
    providerLabel,
    Object.hashAll(entries),
    currentLabel,
    nextLabel,
    isStale,
    staleLabel,
  );
}

enum WidgetSnapshotDecodeError { missing, malformed, unsupportedVersion }

sealed class WidgetSnapshotDecodeResult {
  const WidgetSnapshotDecodeResult();
}

final class WidgetSnapshotDecoded extends WidgetSnapshotDecodeResult {
  const WidgetSnapshotDecoded(this.snapshot);

  final WidgetSnapshot snapshot;
}

final class WidgetSnapshotRejected extends WidgetSnapshotDecodeResult {
  const WidgetSnapshotRejected(this.error, {this.actualVersion});

  final WidgetSnapshotDecodeError error;
  final int? actualVersion;
}

final class WidgetSnapshotCodec {
  const WidgetSnapshotCodec();

  String encode(WidgetSnapshot snapshot) => jsonEncode(snapshot.toJson());

  /// Converts all absent, corrupt, or incompatible data into an explicit safe
  /// result. Callers can render a fallback without allowing parsing failures to
  /// escape a widget receiver.
  WidgetSnapshotDecodeResult decode(String? source) {
    if (source == null || source.isEmpty) {
      return const WidgetSnapshotRejected(WidgetSnapshotDecodeError.missing);
    }
    try {
      final decoded = jsonDecode(source);
      final json = _asMap(decoded, 'snapshot');
      final version = json['schemaVersion'];
      if (version is! int) {
        return const WidgetSnapshotRejected(
          WidgetSnapshotDecodeError.malformed,
        );
      }
      if (version != WidgetSnapshot.schemaVersion) {
        return WidgetSnapshotRejected(
          WidgetSnapshotDecodeError.unsupportedVersion,
          actualVersion: version,
        );
      }
      return WidgetSnapshotDecoded(WidgetSnapshot._fromJson(json));
    } on Object {
      return const WidgetSnapshotRejected(WidgetSnapshotDecodeError.malformed);
    }
  }
}

void _requireText(String value, String name, {required int maxLength}) {
  if (value.isEmpty || value.length > maxLength) {
    throw ArgumentError.value(
      value,
      name,
      'Must contain 1–$maxLength characters.',
    );
  }
}

Map<String, Object?> _asMap(Object? value, String name) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$name is not an object.');
  }
  return value;
}

Map<String, Object?> _map(Map<String, Object?> json, String key) =>
    _asMap(json[key], key);

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key is not a list.');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key is not a string.');
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key is not a string.');
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key is not an integer.');
  return value;
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is not a boolean.');
  return value;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// Mirrors Kotlin's overflowing 64-bit polynomial hash followed by
/// `and Long.MAX_VALUE`. Dart integers do not overflow, so retaining the low
/// 63 bits after every step produces the same final non-negative identifier.
int stableWidgetItemId(String value) {
  const mask = 0x7FFFFFFFFFFFFFFF;
  var hash = 1125899906842597;
  for (final codeUnit in value.codeUnits) {
    hash = (31 * hash + codeUnit) & mask;
  }
  return hash;
}
