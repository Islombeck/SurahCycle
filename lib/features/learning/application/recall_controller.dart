import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/application/application.dart';
import '../../../core/data/data.dart';
import '../../../core/domain/domain.dart';

/// What a running check looks like to the screen.
final class RecallRunState {
  const RecallRunState({
    required this.session,
    this.tally = RecallTally.empty,
    this.isSaving = false,
    this.saveFailed = false,
  });

  final RecallSession session;
  final RecallTally tally;
  final bool isSaving;

  /// The last grade could not be stored. The step stays where it is so the
  /// user can try again rather than quietly losing the result.
  final bool saveFailed;

  RecallRunState copyWith({
    RecallSession? session,
    RecallTally? tally,
    bool? isSaving,
    bool? saveFailed,
  }) => RecallRunState(
    session: session ?? this.session,
    tally: tally ?? this.tally,
    isSaving: isSaving ?? this.isSaving,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallRunState &&
          session == other.session &&
          tally == other.tally &&
          isSaving == other.isSaving &&
          saveFailed == other.saveFailed;

  @override
  int get hashCode => Object.hash(session, tally, isSaving, saveFailed);
}

/// Drives one memory check.
///
/// The controller never advances past an ayah whose grade failed to store: a
/// check the user completed but whose record was lost would overstate their
/// progress the next time the app ranks what to review.
final class RecallController extends StateNotifier<RecallRunState> {
  RecallController({
    required RecallSession session,
    required this.repository,
    required this.timeProvider,
    required this.localDateProvider,
    required this.uuid,
    required this.learningCycle,
    required this.source,
  }) : super(RecallRunState(session: session));

  final RecallRepository repository;
  final TimeProvider timeProvider;
  final RecitationLocalDateProvider localDateProvider;
  final Uuid uuid;
  final int learningCycle;
  final RecallSource source;

  void reveal() {
    if (state.session.isRevealed || state.session.isComplete) return;
    state = state.copyWith(session: state.session.reveal(), saveFailed: false);
  }

  /// Moves on without a grade. Skipping is not a result and is never stored.
  void skip() {
    if (state.session.isComplete || state.isSaving) return;
    state = state.copyWith(session: state.session.advance(), saveFailed: false);
  }

  Future<void> grade(RecallResult result) async {
    if (!state.session.canGrade || state.isSaving) return;
    final attempt = state.session.grade(
      result: result,
      id: uuid.v4(),
      learningCycle: learningCycle,
      createdAtUtc: timeProvider.nowUtc(),
      localDate: localDateProvider.today(),
      source: source,
    );
    state = state.copyWith(isSaving: true, saveFailed: false);
    try {
      await repository.append(attempt);
    } on Object {
      if (mounted) state = state.copyWith(isSaving: false, saveFailed: true);
      return;
    }
    if (!mounted) return;
    state = state.copyWith(
      session: state.session.advance(),
      tally: state.tally.add(result),
      isSaving: false,
    );
  }
}

/// Everything one check needs to start, resolved before the screen opens.
final class RecallRequest {
  const RecallRequest({
    required this.surahId,
    required this.surahNumber,
    required this.surahAyahCount,
    required this.ayahStart,
    required this.ayahEnd,
    required this.learningCycle,
    required this.source,
  });

  final String surahId;
  final int surahNumber;

  /// The surah's verified length, not the length of the checked range: the
  /// Quran text is always loaded whole so ayah numbers stay absolute.
  final int surahAyahCount;
  final int ayahStart;
  final int ayahEnd;
  final int learningCycle;
  final RecallSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallRequest &&
          surahId == other.surahId &&
          surahNumber == other.surahNumber &&
          surahAyahCount == other.surahAyahCount &&
          ayahStart == other.ayahStart &&
          ayahEnd == other.ayahEnd &&
          learningCycle == other.learningCycle &&
          source == other.source;

  @override
  int get hashCode => Object.hash(
    surahId,
    surahNumber,
    surahAyahCount,
    ayahStart,
    ayahEnd,
    learningCycle,
    source,
  );
}
