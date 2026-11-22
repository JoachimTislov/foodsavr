/// Defaults and bounds for [UserPreferences].
class PreferencesConfig {
  const PreferencesConfig._();

  /// Products expiring within this many days (and not yet expired) count as
  /// "expiring soon". Matches the behavior before preferences existed.
  static const int defaultExpiringSoonDays = 6;
  static const int minExpiringSoonDays = 1;
  static const int maxExpiringSoonDays = 30;

  /// Local cache key; must be in the `SharedPreferencesWithCache` allow-list.
  static const String cacheKey = 'user_preferences';
}
