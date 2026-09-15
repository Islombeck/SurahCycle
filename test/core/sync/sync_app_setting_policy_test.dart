import 'package:flutter_test/flutter_test.dart';
import 'package:murajaah/core/sync/sync.dart';

void main() {
  test('explicit user preferences are syncable', () {
    expect(SyncAppSettingPolicy.shouldSync('theme_preference'), isTrue);
    expect(SyncAppSettingPolicy.shouldSync('prayer_time_settings_v1'), isTrue);
    expect(
      SyncAppSettingPolicy.shouldSync('quran.translation.selection.v1'),
      isTrue,
    );
  });

  test('derived, device-permission, and migration state stays local', () {
    expect(SyncAppSettingPolicy.shouldSync('recommendationBatch'), isFalse);
    expect(
      SyncAppSettingPolicy.shouldSync('learningNotificationEnabled'),
      isFalse,
    );
    expect(
      SyncAppSettingPolicy.shouldSync('selected_learning_surah_id'),
      isFalse,
    );
    expect(SyncAppSettingPolicy.shouldSync('selected_prayer_type'), isFalse);
    expect(SyncAppSettingPolicy.shouldSync('selected_prayer_is_qada'), isFalse);
    expect(
      SyncAppSettingPolicy.shouldSync('rotation_exclusions_v1_normalized'),
      isFalse,
    );
  });

  test('unknown settings fail closed', () {
    expect(SyncAppSettingPolicy.shouldSync('future_unreviewed_key'), isFalse);
    expect(SyncAppSettingPolicy.shouldSync(''), isFalse);
  });
}
