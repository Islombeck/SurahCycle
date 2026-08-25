import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/features/quran/quran.dart';

void main() {
  test('Sprint 1 rule service never invents a religious restriction', () {
    const service = NoOpRecitationRuleService();
    final candidate = Surah(
      id: 'test-surah-a',
      number: 10,
      ayahCount: 3,
      localizedName: 'Test Surah A',
    );

    final decision = service.evaluate(
      RecitationRuleContext(candidate: candidate),
    );

    expect(decision.isAllowed, isTrue);
    expect(decision.reasonCode, isNull);
  });
}
