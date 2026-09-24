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
import '../repositories/rotation_projection_store.dart';
import 'app_setting_sync_applier.dart';
import 'journal_sync_appliers.dart';
import 'learning_sync_appliers.dart';
import 'mastered_surah_sync_applier.dart';
import 'prayer_routine_sync_applier.dart';
import 'prayer_session_sync_applier.dart';
import 'recitation_sync_applier.dart';
import 'rotation_scheme_sync_applier.dart';
import 'sync_versioned_rows.dart';

final class SyncEnvelopeRouter {
  SyncEnvelopeRouter(AppDatabase database)
    : _projection = RotationProjectionStore(database),
      _roster = MasteredSurahSyncApplier(database),
      // The three that touch the rotation projection hand the rebuild to this
      // router, which does it once for a whole page. Each rebuild reads the
      // entire journal, so one per envelope is quadratic: a real history of
      // nine hundred records took seventeen seconds that way, all of it inside
      // transactions, where an app does not draw and a user sees a freeze.
      _schemes = RotationSchemeSyncApplier(database, rebuildsProjection: false),
      _sessions = PrayerSessionSyncApplier(database),
      _routines = PrayerRoutineSyncApplier(database),
      _plans = LearningStateSyncApplier(database),
      _recitations = RecitationSyncApplier(database, rebuildsProjection: false),
      _adjustments = RotationAdjustmentSyncApplier(
        database,
        rebuildsProjection: false,
      ),
      _recalls = RecallAttemptSyncApplier(database),
      _learningEvents = LearningEventSyncApplier(database),
      _settings = AppSettingSyncApplier(database),
      _versioned = SyncVersionedRows(database);

  /// The table each mutable entity's local copy lives in.
  ///
  /// Only these can lose to a local row: the rest are append-only facts, where
  /// "two versions of the same one" is a symptom rather than a conflict and the
  /// appliers refuse it by name.
  static const Map<SyncEntityType, String> _versionedTables =
      <SyncEntityType, String>{
        SyncEntityType.masteredSurah: 'mastered_surahs',
        SyncEntityType.rotationScheme: 'rotation_schemes',
        SyncEntityType.prayerSession: 'prayer_sessions',
        SyncEntityType.prayerRoutineTemplate: 'prayer_routine_templates',
        SyncEntityType.learningState: 'learning_surahs',
        SyncEntityType.appSetting: 'app_settings',
      };

  final RotationProjectionStore _projection;
  final SyncVersionedRows _versioned;

  /// Whether anything applied since the last settle touched the rotation.
  bool _rotationIsStale = false;

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

  /// Rebuilds the rotation projection if anything applied since the last call
  /// changed it, and does nothing otherwise.
  ///
  /// Call once after a page, inside the same transaction that applied it. A
  /// page whose records left the rotation alone costs nothing here; one that
  /// changed it pays for a single rebuild rather than one per record.
  ///
  /// It is the caller's job to call this. That is the price of batching, and
  /// it is why the appliers still rebuild for themselves when used directly —
  /// an applier on its own has to leave the device consistent.
  Future<void> settleProjection() async {
    if (!_rotationIsStale) return;
    _rotationIsStale = false;
    final state = await _projection.loadSnapshot();
    await _projection.rebuildFromJournal(targetFloor: state.rotationTarget);
  }

  /// Whether applying [envelope] can change the rotation projection.
  static bool _touchesRotation(SyncEnvelope envelope) =>
      switch (envelope.entityType) {
        SyncEntityType.recitationEvent ||
        SyncEntityType.rotationAdjustment ||
        SyncEntityType.rotationScheme ||
        // A roster entry can create a scheme, which is a rotation change.
        SyncEntityType.masteredSurah => true,
        _ => false,
      };

  /// Applies one envelope. Call inside a transaction.
  Future<void> apply(SyncEnvelope envelope) async {
    // ADR-0002's rule, decided once, here. It cannot be decided on the server:
    // TablesDB upserts what it is handed and the project deploys no function,
    // so an account holds whatever was pushed last rather than what is newest.
    // Without this the appliers wrote whatever arrived, and an edit made
    // offline on one phone silently replaced a newer one made on another.
    final table = _versionedTables[envelope.entityType];
    if (table != null) {
      final localAtUtc = await _versioned.updatedAtUtc(
        table: table,
        key: envelope.entityId,
      );
      if (!SyncMergeDecision.incomingWins(
        incomingUpdatedAtUtc: envelope.updatedAtUtc,
        localUpdatedAtUtc: localAtUtc,
      )) {
        // Dropped, and nothing is remembered about it. The account keeps the
        // older row — it is a log, and a row is never rewritten — and every
        // device that reads it makes this same comparison, so the stale one
        // loses there too. See `SyncCycleRunner` for what used to be here.
        return;
      }
    }
    if (_touchesRotation(envelope)) _rotationIsStale = true;
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
