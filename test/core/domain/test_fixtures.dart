import 'package:murajaah/core/domain/domain.dart';

SurahDescriptor testSurah({
  required String id,
  required int number,
  String? name,
  int ayahCount = 3,
}) => SurahDescriptor(
  id: id,
  surahNumber: number,
  officialName: name ?? 'Test Surah $id',
  ayahCount: ayahCount,
);

MasteredSurah mastered({
  required String id,
  required int score,
  int total = 0,
  bool active = true,
  bool entered = true,
  int order = 0,
  DateTime? lastUsedAtUtc,
}) => MasteredSurah(
  surah: testSurah(id: id, number: order + 1),
  isActive: active,
  hasEnteredRotation: entered,
  totalRecitations: total,
  rotationScore: score,
  displayOrder: order,
  lastUsedAtUtc: lastUsedAtUtc,
);

SurahRecitationEvent recitation(
  String id,
  String surahId, {
  DateTime? at,
  PrayerContext? prayerContext,
}) {
  final createdAt = at ?? DateTime.utc(2026, 1, 1, 12);
  return SurahRecitationEvent(
    id: id,
    surahId: surahId,
    prayerContext: prayerContext ?? PrayerContext(prayerType: PrayerType.asr),
    createdAtUtc: createdAt,
    localDate: LocalDate(2026, 1, 1),
  );
}

final class FakeTimeProvider implements TimeProvider {
  FakeTimeProvider(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}
