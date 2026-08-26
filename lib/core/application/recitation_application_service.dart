import '../data/repositories/prayer_repository.dart';
import '../data/repositories/recitation_repository.dart';
import '../data/repositories/surah_repository.dart';
import '../domain/domain.dart';
import 'widget_recitation_action.dart';

typedef RecitationEventIdFactory = String Function();

/// Resolves the prayer context at action execution time.
///
/// A future automatic resolver can implement this interface using a trusted
/// local schedule. The current implementation deliberately requires the
/// user's persisted manual selection and never invents a default prayer.
abstract interface class RecitationPrayerContextResolver {
  Future<PrayerContext?> resolve();
}

/// Optional richer boundary used by widget presentation after the same
/// execution-time safety decision. Clock strings are already display-ready;
/// this core layer remains independent from any prayer schedule provider.
final class RecitationPrayerContextDetails {
  const RecitationPrayerContextDetails({
    required this.context,
    required this.isAutomatic,
    this.startsAt,
    this.endsAt,
  });

  final PrayerContext? context;
  final bool isAutomatic;
  final String? startsAt;
  final String? endsAt;
}

abstract interface class DetailedRecitationPrayerContextResolver
    implements RecitationPrayerContextResolver {
  Future<RecitationPrayerContextDetails> resolveDetails();
}

final class StoredManualRecitationPrayerContextResolver
    implements RecitationPrayerContextResolver {
  const StoredManualRecitationPrayerContextResolver(this.repository);

  final PrayerRepository repository;

  @override
  Future<PrayerContext?> resolve() => repository.getSelectedContext();
}

abstract interface class RecitationLocalDateProvider {
  LocalDate today();
}

final class SystemRecitationLocalDateProvider
    implements RecitationLocalDateProvider {
  const SystemRecitationLocalDateProvider();

  @override
  LocalDate today() => LocalDate.fromLocalDateTime(DateTime.now());
}

enum WidgetRecitationRejection {
  unknownPrayerContext,
  unknownSurah,
  inactiveSurah,
  fatihaExcluded,
  staleScheme,
  invalidPart,
}

sealed class WidgetRecitationResult {
  const WidgetRecitationResult();
}

final class WidgetRecitationRegistered extends WidgetRecitationResult {
  const WidgetRecitationRegistered(this.registration);

  final RecitationRegistration registration;
}

final class WidgetRecitationDuplicate extends WidgetRecitationResult {
  const WidgetRecitationDuplicate();
}

final class WidgetRecitationRejected extends WidgetRecitationResult {
  const WidgetRecitationRejected(this.reason);

  final WidgetRecitationRejection reason;
}

/// Shared application use case for recitations from Home, widgets and future
/// shortcuts. Persistence and rotation projection changes remain one atomic
/// repository transaction.
final class RecitationApplicationService {
  const RecitationApplicationService({
    required this.surahs,
    required this.recitations,
    required this.prayerContextResolver,
    required this.timeProvider,
    required this.localDates,
    required this.createEventId,
  });

  final SurahRepository surahs;
  final RecitationRepository recitations;
  final RecitationPrayerContextResolver prayerContextResolver;
  final TimeProvider timeProvider;
  final RecitationLocalDateProvider localDates;
  final RecitationEventIdFactory createEventId;

  Future<RecitationRegistration> registerFromApp({
    required String surahId,
    required PrayerContext prayerContext,
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
  }) async {
    final snapshot = await surahs.getRotationSnapshot();
    final mastered = snapshot.surahById(surahId);
    final explicitPartIds = coveredPartIds?.toList(growable: false);
    return recitations.register(
      SurahRecitationEvent(
        id: createEventId(),
        surahId: surahId,
        prayerContext: prayerContext,
        createdAtUtc: timeProvider.nowUtc(),
        localDate: localDates.today(),
        rotationSchemeId: explicitPartIds == null
            ? null
            : mastered.rotationScheme.id,
        coveredPartIds: explicitPartIds,
        rakaatSpanCount: rakaatSpanCount,
      ),
    );
  }

  Future<WidgetRecitationResult> registerFromWidget(
    WidgetRecitationAction action,
  ) async {
    // A redelivered action remains a success even if the first transaction
    // moved the row or the user subsequently changed its scheme. The event ID
    // is the action token, so it must never be applied a second time.
    if (await recitations.containsJournalEventId(action.actionToken)) {
      return const WidgetRecitationDuplicate();
    }

    final snapshot = await surahs.getRotationSnapshot();
    MasteredSurah? mastered;
    for (final candidate in snapshot.surahs) {
      if (candidate.id == action.surahId) {
        mastered = candidate;
        break;
      }
    }
    if (mastered == null) {
      return const WidgetRecitationRejected(
        WidgetRecitationRejection.unknownSurah,
      );
    }
    if (!mastered.surah.isRotationEligible) {
      return const WidgetRecitationRejected(
        WidgetRecitationRejection.fatihaExcluded,
      );
    }
    if (!mastered.isActive) {
      return const WidgetRecitationRejected(
        WidgetRecitationRejection.inactiveSurah,
      );
    }
    final scheme = mastered.rotationScheme;
    if (scheme.id != action.rotationSchemeId) {
      return const WidgetRecitationRejected(
        WidgetRecitationRejection.staleScheme,
      );
    }

    late final List<String> coveredPartIds;
    if (scheme.isSplit) {
      final partId = action.partId;
      if (partId == null || !scheme.parts.any((part) => part.id == partId)) {
        return const WidgetRecitationRejected(
          WidgetRecitationRejection.invalidPart,
        );
      }
      coveredPartIds = <String>[partId];
    } else {
      if (action.partId != null || scheme.parts.length != 1) {
        return const WidgetRecitationRejected(
          WidgetRecitationRejection.invalidPart,
        );
      }
      coveredPartIds = <String>[scheme.parts.single.id];
    }

    final prayerContext = await prayerContextResolver.resolve();
    if (prayerContext == null) {
      return const WidgetRecitationRejected(
        WidgetRecitationRejection.unknownPrayerContext,
      );
    }
    final registration = await recitations.registerOnce(
      SurahRecitationEvent(
        id: action.actionToken,
        surahId: action.surahId,
        prayerContext: prayerContext,
        createdAtUtc: timeProvider.nowUtc(),
        localDate: localDates.today(),
        rotationSchemeId: scheme.id,
        coveredPartIds: coveredPartIds,
        rakaatSpanCount: 1,
      ),
    );
    return registration == null
        ? const WidgetRecitationDuplicate()
        : WidgetRecitationRegistered(registration);
  }
}
