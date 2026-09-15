/// Decides which rows from the generic `app_settings` table are user-owned
/// preferences and which are local implementation state.
///
/// The allowlist is intentionally closed. A newly introduced setting stays
/// local until its cross-device meaning and privacy impact are reviewed.
abstract final class SyncAppSettingPolicy {
  static const Set<String> syncableKeys = <String>{
    'theme_preference',
    'prayer_time_settings_v1',
    'quran.transliteration.profile.v1',
    'quran.translation.selection.v1',
    'quran.translation.language.v1',
    'quran_display_preferences_v1',
  };

  static bool shouldSync(String key) => syncableKeys.contains(key);
}
