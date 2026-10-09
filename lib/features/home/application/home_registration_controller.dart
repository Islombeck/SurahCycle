import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';
import '../../prayer_times/prayer_times.dart';

/// Reads a provider. `WidgetRef.read` and `ProviderContainer.read` both have
/// this shape, which is what lets the controller run inside the screen and
/// inside a plain test.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Invalidates a provider, the shape `WidgetRef` and `ProviderContainer`
/// share.
typedef ProviderInvalidator = void Function(ProviderOrFamily provider);

/// The prayer a mark belongs to, and whether the schedule chose it.
final class ActionPrayerContext {
  const ActionPrayerContext({required this.context, required this.isAutomatic});

  final PrayerContext context;
  final bool isAutomatic;
}

/// What a mark was started under. Compared again before every write, so a
/// sheet that stayed open across a change of prayer or day cannot write into
/// the context the user has since left.
@immutable
final class RegistrationContextToken {
  const RegistrationContextToken({
    required this.generation,
    required this.localDate,
  });

  final int generation;
  final LocalDate localDate;
}

/// Thrown when the context a mark was started under is no longer in force.
final class RegistrationContextChanged implements Exception {
  const RegistrationContextChanged();
}

/// How a request to record a recitation ended.
sealed class RecitationRegistrationOutcome {
  const RecitationRegistrationOutcome();
}

/// Recorded. [contextStillCurrent] is false when the user moved on while the
/// write was in flight: the record stands, but saying "marked" under a
/// different prayer would describe the wrong one.
final class RecitationRecorded extends RecitationRegistrationOutcome {
  const RecitationRecorded(
    this.registration, {
    required this.contextStillCurrent,
  });

  final RecitationRegistration registration;
  final bool contextStillCurrent;
}

/// The prayer's routine has no free slot: finished, or its current part is
/// full. Nothing was written.
final class RecitationSlotUnavailable extends RecitationRegistrationOutcome {
  const RecitationSlotUnavailable({required this.routineCompleted});

  final bool routineCompleted;
}

/// The same surah is already being recorded. Nothing was written.
final class RecitationAlreadyInFlight extends RecitationRegistrationOutcome {
  const RecitationAlreadyInFlight();
}

/// The context changed before the write. Nothing was written.
final class RecitationContextChanged extends RecitationRegistrationOutcome {
  const RecitationContextChanged();
}

/// The mark pipeline of Home, without the screen.
///
/// It lived for two years inside `_HomeScreenState`, a 76-method class in a
/// 2,567-line file, and every defect of the autumn — the tick that went out
/// when a part finished, Witr unmarkable after Isha, the mark after midnight
/// filed a day forward, the empty Isha opened on a day that had not begun —
/// was in it. It could only be tested by pumping the whole screen.
///
/// What is here is the logic: which day and prayer a mark belongs to, the
/// token that guards a write against a context that changed meanwhile, the
/// Isha→Witr hand-over, the write into the routine's slot, Undo, and the busy
/// sets. What stays in the screen is everything that needs a `BuildContext`:
/// the sheets, the dialogs, the snackbars.
final class HomeRegistrationController {
  HomeRegistrationController({
    required this._read,
    required this._invalidate,
    required this._isActive,
    VoidCallback? onBusyChanged,
  }) : _onBusyChanged = onBusyChanged ?? _noop;

  static void _noop() {}

  final ProviderReader _read;
  final ProviderInvalidator _invalidate;
  final bool Function() _isActive;
  final VoidCallback _onBusyChanged;

  final Set<String> _busySurahIds = <String>{};
  final Set<String> _busyRoutinePartIds = <String>{};
  int _generation = 0;

  /// Surahs being recorded right now. A view; the controller owns the set.
  Set<String> get busySurahIds => UnmodifiableSetView<String>(_busySurahIds);

  /// Routine parts being completed by following the imam right now.
  Set<String> get busyRoutinePartIds =>
      UnmodifiableSetView<String>(_busyRoutinePartIds);

  /// Something a mark depends on changed: the chosen day, the chosen prayer,
  /// the override, the selection mode.
  ///
  /// A generation rather than a comparison of values: A → B → A still
  /// invalidates a sheet opened for the original A.
  void contextChanged() => _generation++;

  /// The prayer day in force right now, which between midnight and Fajr is
  /// the day that is ending rather than the one on the clock.
  LocalDate currentPrayerLocalDate() =>
      settledAsyncValue(
        _read(homePrayerContextResolutionProvider),
      )?.contextLocalDate ??
      _read(localDateProvider).today();

  /// The past day chosen in the calendar, if one is in force right now.
  ///
  /// The current prayer day is never returned as "pending": a record for it
  /// is the ordinary case and must not take the historical path. Compared
  /// against the *prayer* day rather than the calendar one, so that after
  /// midnight choosing the night that is ending still counts as ordinary —
  /// and choosing the new day is still an explicit instruction and is
  /// honoured.
  LocalDate? pendingRegistrationDate() {
    final pending = _read(pendingRegistrationDateProvider);
    if (pending == null) return null;
    return pending == currentPrayerLocalDate() ? null : pending;
  }

  /// The day a mark made right now belongs to: the past day he chose, or the
  /// current prayer day.
  ///
  /// Captured into the token **and** compared against it, from this one
  /// method. They were two expressions for a while and they disagreed after
  /// midnight — the capture took the prayer day, the comparison took the
  /// wall clock — so between midnight and Fajr every mark was abandoned as
  /// "the context changed" without recording anything. Found by marking on a
  /// device with the clock at 00:32, not by reading the code.
  LocalDate registrationLocalDate() =>
      pendingRegistrationDate() ?? currentPrayerLocalDate();

  /// What the prayer picker should open on: whatever is actually in effect.
  ///
  /// A sticky override never writes the persisted selection, so reading the
  /// stored value first showed a prayer the user had left behind — Магриб
  /// ticked while the card read Иша, on video.
  PrayerContext? pickerInitialContext() =>
      settledAsyncValue(_read(homePrayerContextResolutionProvider))?.context ??
      _read(selectedPrayerProvider);

  RegistrationContextToken captureToken() => RegistrationContextToken(
    generation: _generation,
    localDate: registrationLocalDate(),
  );

  bool isCurrent(RegistrationContextToken token) =>
      _isActive() &&
      token.generation == _generation &&
      token.localDate == registrationLocalDate();

  void requireCurrent(RegistrationContextToken token) {
    if (!isCurrent(token)) throw const RegistrationContextChanged();
  }

  /// Automatic attribution is resolved at the action boundary. A timer keeps
  /// Home current for presentation, but a delayed rebuild can never
  /// authorize a write with an old prayer or an expired schedule.
  ///
  /// Null means "ask": the screen opens the picker.
  Future<ActionPrayerContext?> resolvePrayerForAction() async {
    final settings = await loadPrayerTimeSettings();
    // While a past day is chosen, today's schedule says nothing about which
    // prayer a mark belongs to. Returning null here opens the picker, so a
    // historical record always names its prayer explicitly instead of
    // inheriting whichever one happens to be current.
    if (pendingRegistrationDate() != null &&
        settings.contextSelectionMode != PrayerContextSelectionMode.manual &&
        _read(activePrayerContextOverrideProvider) == null) {
      return null;
    }
    if (settings.contextSelectionMode == PrayerContextSelectionMode.manual) {
      final selected =
          _read(selectedPrayerProvider) ??
          await _read(prayerRepositoryProvider).getSelectedContext();
      return selected == null
          ? null
          : ActionPrayerContext(context: selected, isAutomatic: false);
    }

    final override = _read(activePrayerContextOverrideProvider);
    if (override != null) {
      return ActionPrayerContext(context: override, isAutomatic: false);
    }
    if (!settings.locationConfirmed) return null;
    final today = matchingPrayerSchedule(
      _read(prayerTodayScheduleProvider),
      settings,
    );
    if (today == null) return null;
    final resolution = today.resolveAutomaticContext(
      _read(timeProviderProvider),
    );
    final context = resolution.context;
    if (context == null) return null;
    return ActionPrayerContext(
      context: await withIshaToWitrTransition(context),
      isAutomatic: true,
    );
  }

  /// The prayer a mark is recorded against must be the prayer on screen.
  ///
  /// The card and the routine card read [homePrayerContextResolutionProvider],
  /// which applies [applyIshaToWitrTransition]; the tap resolved its prayer
  /// straight from the schedule and so never learned about the transition.
  /// After a finished Иша the screen therefore said Витр while the mark went
  /// to Иша, whose slots were all taken, and the owner was told «Порядок
  /// намаза завершён» with no way forward but picking Витр by hand.
  ///
  /// The routine is read from the repository rather than from the provider
  /// on purpose: a tap must not depend on whether a stream has settled yet.
  /// The session it ensures is the same one the provider ensures for the same
  /// prayer and day, so this adds no state of its own.
  Future<PrayerContext> withIshaToWitrTransition(PrayerContext context) async {
    if (context.prayerType != PrayerType.isha || context.isQada) return context;
    final repository = _read(prayerRoutineRepositoryProvider);
    final ishaRoutine = await repository.ensureCurrentSession(
      context: context,
      // The prayer day, not the calendar one. This call **creates** the
      // session it reads, so after midnight the wall clock opened an Иша on
      // the day that had not started — which is what he saw as "it marks it
      // for yesterday and for today" — and then found it empty, so the move
      // to Витр never happened and the mark went to an Иша of the wrong day.
      localDate: registrationLocalDate(),
      startedAtUtc: _read(timeProviderProvider).nowUtc(),
    );
    return applyIshaToWitrTransition(
          PrayerContextResolution(
            status: PrayerContextResolutionStatus.automatic,
            context: context,
          ),
          ishaRoutine: ishaRoutine,
          witrTemplate: await repository.getTemplate(PrayerType.witr),
        ).context ??
        context;
  }

  Future<PrayerTimeSettings> loadPrayerTimeSettings() async {
    final settled = settledAsyncValue(_read(prayerTimeSettingsProvider));
    if (settled != null) return settled;
    final prayerRepository = _read(prayerRepositoryProvider);
    return _read(prayerTimeSettingsRepositoryProvider).load(
      legacyManualContextExists: () async =>
          await prayerRepository.getSelectedContext() != null,
    );
  }

  /// Records one recitation into the prayer's routine.
  ///
  /// The write goes into the current part's next free slot. A routine with
  /// no free slot records nothing and says why. Failures other than a
  /// changed context propagate; the busy mark is cleared either way.
  Future<RecitationRegistrationOutcome> registerRecitation({
    required String surahId,
    required PrayerContext prayer,
    required RegistrationContextToken token,
    Iterable<String>? coveredPartIds,
    int rakaatSpanCount = 1,
    LocalDate? occurrenceLocalDate,
    bool qadaOriginIsUnknown = false,
    LocalDate? qadaFulfilledLocalDate,
  }) async {
    if (!_busySurahIds.add(surahId)) return const RecitationAlreadyInFlight();
    _onBusyChanged();
    try {
      // Before ensuring the session, not only after: ensuring creates it, and
      // a mark from a context the user has left must not open an empty
      // prayer on a day he did not pray.
      requireCurrent(token);
      final localDate = occurrenceLocalDate ?? token.localDate;
      final routine = await _read(prayerRoutineRepositoryProvider)
          .ensureCurrentSession(
            context: prayer,
            localDate: localDate,
            startedAtUtc: _read(timeProviderProvider).nowUtc(),
          );
      requireCurrent(token);
      final routinePart = routine?.currentPart;
      final slotIndex = routinePart?.nextSlotIndex;
      if (routine != null && slotIndex == null) {
        return RecitationSlotUnavailable(routineCompleted: routine.isCompleted);
      }
      final registration = await _read(appActionsProvider).registerRecitation(
        surahId: surahId,
        prayerContext: prayer,
        prayerSessionId: slotIndex == null ? null : routine!.session.id,
        prayerSessionPartId: slotIndex == null ? null : routinePart!.part.id,
        slotIndex: slotIndex,
        coveredPartIds: coveredPartIds,
        rakaatSpanCount: rakaatSpanCount,
        occurrenceLocalDate: localDate,
        qadaOriginIsUnknown: qadaOriginIsUnknown,
        qadaFulfilledLocalDate: qadaFulfilledLocalDate,
      );
      // A manual context deliberately survives this mark: it is cleared only
      // by the explicit "back to automatic" action or once its local date
      // has passed. Re-picking Witr or Nafl for every surah was the reported
      // bug.
      return RecitationRecorded(
        registration,
        contextStillCurrent: isCurrent(token),
      );
    } on RegistrationContextChanged {
      return const RecitationContextChanged();
    } finally {
      _busySurahIds.remove(surahId);
      _onBusyChanged();
    }
  }

  /// Undoes a recorded recitation, the action behind the snackbar's Undo.
  Future<RecitationUndoResult> undoRecitation(
    RecitationRegistration registration,
  ) => _read(recitationRepositoryProvider).undo(registration.undoToken);

  /// Puts a prayer the user picked into force, the way the current mode
  /// keeps it: the persisted selection in manual mode, a same-day override
  /// in automatic mode.
  ///
  /// False when the context changed while the picker was open, in which
  /// case nothing was applied.
  Future<bool> applyPickedPrayer(
    PrayerContext selected,
    RegistrationContextToken token,
  ) async {
    if (!isCurrent(token)) return false;
    final settings = await loadPrayerTimeSettings();
    if (!isCurrent(token)) return false;
    if (settings.contextSelectionMode == PrayerContextSelectionMode.manual) {
      await _read(selectedPrayerProvider.notifier).select(selected);
    } else {
      setPrayerContextOverride(selected);
    }
    return true;
  }

  /// Scopes the override to the local date it was chosen for, so it can stay
  /// selected across a series of marks without ever leaking into the next
  /// day.
  void setPrayerContextOverride(PrayerContext context) {
    _read(prayerContextOverrideProvider.notifier).state = PrayerContextOverride(
      context: context,
      localDate: _read(localDateProvider).today(),
    );
  }

  /// Completes a routine part by following the imam — which creates no
  /// recitation, by the rule this app keeps.
  ///
  /// Null when that part is already being completed. Failures propagate;
  /// the busy mark is cleared either way.
  Future<FollowedImamCompletion?> completeByFollowingImam(
    String prayerSessionPartId,
  ) async {
    if (!_busyRoutinePartIds.add(prayerSessionPartId)) return null;
    _onBusyChanged();
    try {
      final completion = await _read(prayerRoutineRepositoryProvider)
          .completeByFollowingImam(
            prayerSessionPartId: prayerSessionPartId,
            completedAtUtc: _read(timeProviderProvider).nowUtc(),
          );
      // Same rule as an ordinary mark: following the imam does not end a
      // manually chosen context.
      _invalidate(currentPrayerRoutineProvider);
      return completion;
    } finally {
      _busyRoutinePartIds.remove(prayerSessionPartId);
      _onBusyChanged();
    }
  }

  /// Undoes following the imam. True when something was undone.
  Future<bool> undoFollowedImam(FollowedImamUndoToken token) async {
    final undone = await _read(
      prayerRoutineRepositoryProvider,
    ).undoFollowedImam(token);
    if (undone && _isActive()) _invalidate(currentPrayerRoutineProvider);
    return undone;
  }
}

/// Today's schedule only while it describes the settings in force, or null
/// when there is genuinely nothing to draw.
///
/// A reloading schedule still holds the one it last produced, and
/// [PrayerTodaySchedule.matchesSettings] already decides whether that value
/// is about the settings in force — a far better test than "is this provider
/// busy this frame". Hiding Home's strip on every loading tick is visible
/// jank, and the value is presentational there: it keys nothing.
PrayerTodaySchedule? matchingPrayerSchedule(
  AsyncValue<PrayerTodaySchedule> state,
  PrayerTimeSettings? settings,
) {
  final value = state.valueOrNull;
  if (settings == null ||
      !settings.locationConfirmed ||
      value == null ||
      !value.matchesSettings(settings)) {
    return null;
  }
  return value;
}

/// A value only while the provider is idle.
///
/// Used for the resolved context, and deliberately so. That context is a
/// **family key** on Home — the routine, the batch and the occurrence are
/// all watched as `family((context: ..., localDate: ...))`. Feeding a stale
/// context back in makes the screen alternate between two family instances,
/// each disposing the other's element and invalidating the provider that
/// produced it: a rebuild loop that hangs the app.
T? settledAsyncValue<T>(AsyncValue<T> state) =>
    state.isLoading || state.hasError ? null : state.valueOrNull;
