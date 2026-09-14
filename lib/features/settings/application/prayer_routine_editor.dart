import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';

/// Result of one user-initiated prayer routine edit.
sealed class PrayerRoutineEditOutcome {
  const PrayerRoutineEditOutcome();
}

/// The edit was committed. [template] is the authoritative post-commit state.
final class PrayerRoutineEditApplied extends PrayerRoutineEditOutcome {
  const PrayerRoutineEditApplied(this.template);

  final PrayerRoutineTemplate template;
}

/// The requested state already held, so nothing was written.
///
/// A repeated submit of the same tap resolves here instead of duplicating a
/// part or failing, which is what "one tap never creates a duplicate" means
/// from the user's point of view.
final class PrayerRoutineEditUnchanged extends PrayerRoutineEditOutcome {
  const PrayerRoutineEditUnchanged(this.template);

  final PrayerRoutineTemplate template;
}

/// Another writer changed the routine. [template] is the refreshed state.
final class PrayerRoutineEditConflict extends PrayerRoutineEditOutcome {
  const PrayerRoutineEditConflict(this.template);

  final PrayerRoutineTemplate template;
}

/// The edit failed and the user may retry it.
final class PrayerRoutineEditFailed extends PrayerRoutineEditOutcome {
  const PrayerRoutineEditFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// Serializes routine edits and always writes against a freshly read revision.
///
/// The editor UI cannot supply `expectedRevision` safely on its own: it holds
/// whatever revision the watch stream last delivered, and that stream has not
/// caught up at the moment a write completes. Reading the revision here —
/// inside the queue, immediately before the write — removes that window, while
/// the repository's in-transaction revision check still guards against a
/// genuinely concurrent writer.
final class PrayerRoutineEditor {
  PrayerRoutineEditor({required this.repository});

  final PrayerRoutineRepository repository;

  Future<void> _pending = Future<void>.value();

  Future<PrayerRoutineEditOutcome> addPart({
    required PrayerType prayerType,
    required PrayerRoutinePartTemplate part,
  }) => _enqueue(prayerType, (current) async {
    if (current.parts.any((existing) => existing.id == part.id)) {
      return PrayerRoutineEditUnchanged(current);
    }
    return PrayerRoutineEditApplied(
      await repository.addPart(
        prayerType: prayerType,
        expectedRevision: current.revision,
        part: part,
      ),
    );
  });

  Future<PrayerRoutineEditOutcome> updatePart({
    required PrayerType prayerType,
    required PrayerRoutinePartTemplate replacement,
  }) => _enqueue(prayerType, (current) async {
    if (!current.parts.any((part) => part.id == replacement.id)) {
      return PrayerRoutineEditConflict(current);
    }
    return PrayerRoutineEditApplied(
      await repository.updatePart(
        prayerType: prayerType,
        expectedRevision: current.revision,
        replacement: replacement,
      ),
    );
  });

  Future<PrayerRoutineEditOutcome> deletePart({
    required PrayerType prayerType,
    required String partId,
  }) => _enqueue(prayerType, (current) async {
    if (!current.parts.any((part) => part.id == partId)) {
      return PrayerRoutineEditUnchanged(current);
    }
    return PrayerRoutineEditApplied(
      await repository.deletePart(
        prayerType: prayerType,
        expectedRevision: current.revision,
        partId: partId,
      ),
    );
  });

  Future<PrayerRoutineEditOutcome> reorderParts({
    required PrayerType prayerType,
    required List<String> orderedPartIds,
  }) => _enqueue(prayerType, (current) async {
    final currentIds = current.parts.map((part) => part.id).toList();
    if (currentIds.toSet().length != orderedPartIds.toSet().length ||
        !currentIds.toSet().containsAll(orderedPartIds)) {
      return PrayerRoutineEditConflict(current);
    }
    if (_sameOrder(currentIds, orderedPartIds)) {
      return PrayerRoutineEditUnchanged(current);
    }
    return PrayerRoutineEditApplied(
      await repository.reorderParts(
        prayerType: prayerType,
        expectedRevision: current.revision,
        orderedPartIds: orderedPartIds,
      ),
    );
  });

  Future<PrayerRoutineEditOutcome> setEnabled({
    required PrayerType prayerType,
    required bool enabled,
  }) => _enqueue(prayerType, (current) async {
    if (current.enabled == enabled) return PrayerRoutineEditUnchanged(current);
    return PrayerRoutineEditApplied(
      await repository.setTemplateEnabled(
        prayerType: prayerType,
        expectedRevision: current.revision,
        enabled: enabled,
      ),
    );
  });

  Future<PrayerRoutineEditOutcome> _enqueue(
    PrayerType prayerType,
    Future<PrayerRoutineEditOutcome> Function(PrayerRoutineTemplate current)
    edit,
  ) {
    final result = _pending.then((_) => _attempt(prayerType, edit));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// At most two attempts: one against the current revision and, only for a
  /// genuine concurrent-writer conflict, one against the refreshed revision.
  Future<PrayerRoutineEditOutcome> _attempt(
    PrayerType prayerType,
    Future<PrayerRoutineEditOutcome> Function(PrayerRoutineTemplate current)
    edit,
  ) async {
    try {
      return await edit(await repository.getTemplate(prayerType));
    } on PrayerRoutineRevisionConflict catch (error, stackTrace) {
      _log('Routine revision changed; retrying once.', error, stackTrace);
    } on Object catch (error, stackTrace) {
      _log('Routine edit failed.', error, stackTrace);
      return PrayerRoutineEditFailed(error, stackTrace);
    }
    try {
      return await edit(await repository.getTemplate(prayerType));
    } on PrayerRoutineRevisionConflict catch (error, stackTrace) {
      _log('Routine edit still conflicts; refreshing.', error, stackTrace);
      return PrayerRoutineEditConflict(
        await repository.getTemplate(prayerType),
      );
    } on Object catch (error, stackTrace) {
      _log('Routine edit failed after retry.', error, stackTrace);
      return PrayerRoutineEditFailed(error, stackTrace);
    }
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    developer.log(
      '$message (${error.runtimeType})',
      name: 'MurajaahRoutine',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
