/// Sends each pulled envelope to the applier that understands it.
///
/// **Order inside a page is the interesting part.** Every applier refuses,
/// retryably, when a prerequisite is missing — a recitation before its roster
/// entry, a scheme before its surah, a learning event before its plan. A page
/// is applied in one transaction, so a page that happened to carry a recitation
/// ahead of its roster entry would fail, roll back, and be fetched again in the
/// same order: a permanent stall over a page that contains everything it needs.
///
/// So the router sorts a page into dependency order first. The ranking is not a
/// preference, it is the foreign keys written down:
///
///   roster → schemes → prayer sessions → routines → learning plans
///          → everything that points at them
///
/// Settings depend on nothing and go last, where they cannot be in the way.
///
/// This does not remove the refusals. A prerequisite that is genuinely on
/// another page still stalls the pull, which is what it should do — the sort
/// only stops a page stalling on itself.
library;

import '../../sync/app_setting_sync_payload.dart';
import '../../sync/sync.dart';
import '../database/app_database.dart';
import 'app_setting_sync_applier.dart';
import 'journal_sync_appliers.dart';
import 'learning_sync_appliers.dart';
import 'mastered_surah_sync_applier.dart';
import 'prayer_routine_sync_applier.dart';
import 'prayer_session_sync_applier.dart';
import 'recitation_sync_applier.dart';
import 'rotation_scheme_sync_applier.dart';

final class SyncEnvelopeRouter {
  SyncEnvelopeRouter(AppDatabase database)
    : _roster = MasteredSurahSyncApplier(database),
      _schemes = RotationSchemeSyncApplier(database),
      _sessions = PrayerSessionSyncApplier(database),
      _routines = PrayerRoutineSyncApplier(database),
      _plans = LearningStateSyncApplier(database),
      _recitations = RecitationSyncApplier(database),
      _adjustments = RotationAdjustmentSyncApplier(database),
      _recalls = RecallAttemptSyncApplier(database),
      _learningEvents = LearningEventSyncApplier(database),
      _settings = AppSettingSyncApplier(database);

  final MasteredSurahSyncApplier _roster;
  final RotationSchemeSyncApplier _schemes;
  final PrayerSessionSyncApplier _sessions;
  final PrayerRoutineSyncApplier _routines;
  final LearningStateSyncApplier _plans;
  final RecitationSyncApplier _recitations;
  final RotationAdjustmentSyncApplier _adjustments;
  final RecallAttemptSyncApplier _recalls;
  final LearningEventSyncApplier _learningEvents;
  final AppSettingSyncApplier _settings;

  /// What each entity type has to wait for. Lower goes first.
  ///
  /// `rotationState` is absent on purpose and refused below: it is the rotation
  /// projection, which `sync_envelope.dart` says is rebuilt rather than synced.
  /// Its presence in [SyncEntityType] is the enum's mistake, and accepting it
  /// here would give the projection a second source of truth.
  static const Map<SyncEntityType, int> _rank = <SyncEntityType, int>{
    // Nothing points at these, and everything else points at some of them.
    SyncEntityType.masteredSurah: 0,
    SyncEntityType.rotationScheme: 1,
    SyncEntityType.prayerSession: 2,
    SyncEntityType.prayerRoutineTemplate: 2,
    SyncEntityType.learningState: 2,
    // The dependants.
    SyncEntityType.recitationEvent: 3,
    SyncEntityType.rotationAdjustment: 3,
    SyncEntityType.recallAttempt: 3,
    SyncEntityType.learningEvent: 3,
    // Independent; last so it is never in the way.
    SyncEntityType.appSetting: 4,
  };

  /// The same envelopes, ordered so a self-contained page applies in one go.
  ///
  /// Stable within a rank: two recitations keep the order the server sent them
  /// in, which is `updatedAtUtc` ascending, so a later version still lands
  /// after the earlier one it replaces.
  List<SyncEnvelope> inDependencyOrder(Iterable<SyncEnvelope> envelopes) {
    final ordered = envelopes.toList();
    // A stable sort: `List.sort` is not guaranteed stable, so rank ties are
    // broken by the original position rather than left to the algorithm.
    final positions = <SyncEnvelope, int>{
      for (var index = 0; index < ordered.length; index += 1)
        ordered[index]: index,
    };
    ordered.sort((a, b) {
      final byRank = _rankOf(a).compareTo(_rankOf(b));
      if (byRank != 0) return byRank;
      return positions[a]!.compareTo(positions[b]!);
    });
    return ordered;
  }

  /// A page with its envelopes in dependency order, ready for
  /// `DriftSyncStore.applyPulledPage`.
  SyncPullPage ordered(SyncPullPage page) => SyncPullPage(
    envelopes: inDependencyOrder(page.envelopes),
    cursor: page.cursor,
    hasMore: page.hasMore,
  );

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) {
    if (_roster.handles(envelope)) return _roster.apply(envelope);
    if (_schemes.handles(envelope)) return _schemes.apply(envelope);
    if (_sessions.handles(envelope)) return _sessions.apply(envelope);
    if (_routines.handles(envelope)) return _routines.apply(envelope);
    if (_plans.handles(envelope)) return _plans.apply(envelope);
    if (_recitations.handles(envelope)) return _recitations.apply(envelope);
    if (_adjustments.handles(envelope)) return _adjustments.apply(envelope);
    if (_recalls.handles(envelope)) return _recalls.apply(envelope);
    if (_learningEvents.handles(envelope)) {
      return _learningEvents.apply(envelope);
    }
    if (_settings.handles(envelope)) return _settings.apply(envelope);
    // Only `rotationState` reaches here today. Stalling is the honest outcome
    // for anything this build cannot place: skipping would advance the cursor
    // past data that is then never fetched again.
    throw SyncTransportException(
      'remote-entity-type-unhandled-${envelope.entityType.name.toLowerCase()}',
    );
  }

  static int _rankOf(SyncEnvelope envelope) =>
      _rank[envelope.entityType] ?? _rank.length;

  /// Whether this build can place [type] at all. Exposed so a test fails when a
  /// new entity type is added without a route.
  static bool handlesType(SyncEntityType type) => _rank.containsKey(type);

  /// The one type deliberately left unrouted. See [_rank].
  static const Set<SyncEntityType> deliberatelyUnrouted = <SyncEntityType>{
    SyncEntityType.rotationState,
  };

  /// Whether a setting may be applied at all, for callers that want to ask
  /// before enqueuing rather than after.
  static bool acceptsSetting(String key) =>
      AppSettingSyncPayload.isSyncable(key);
}
