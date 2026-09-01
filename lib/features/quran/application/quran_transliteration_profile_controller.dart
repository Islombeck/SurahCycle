import '../../../core/domain/domain.dart';
import '../data/quran_transliteration_profile_selection_repository.dart';
import '../domain/quran_transliteration_profile.dart';

final class QuranTransliterationProfileController {
  const QuranTransliterationProfileController({
    required this.repository,
    required this.timeProvider,
  });

  final QuranTransliterationProfileSelectionRepository repository;
  final TimeProvider timeProvider;

  Future<void> select(QuranTransliterationProfile profile) =>
      repository.save(profile, updatedAtUtc: timeProvider.nowUtc());
}
