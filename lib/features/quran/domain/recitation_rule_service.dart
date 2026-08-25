import 'quran_models.dart';

/// Extension point for future, verified recitation rules.
abstract interface class RecitationRuleService {
  RecitationRuleDecision evaluate(RecitationRuleContext context);
}

final class RecitationRuleContext {
  const RecitationRuleContext({
    required this.candidate,
    this.previouslyRecited,
  });

  final Surah candidate;
  final Surah? previouslyRecited;
}

final class RecitationRuleDecision {
  const RecitationRuleDecision.allowed() : isAllowed = true, reasonCode = null;

  const RecitationRuleDecision.blocked(this.reasonCode) : isAllowed = false;

  final bool isAllowed;
  final String? reasonCode;
}

/// Sprint 1 intentionally applies no inferred religious restrictions.
final class NoOpRecitationRuleService implements RecitationRuleService {
  const NoOpRecitationRuleService();

  @override
  RecitationRuleDecision evaluate(RecitationRuleContext context) =>
      const RecitationRuleDecision.allowed();
}
