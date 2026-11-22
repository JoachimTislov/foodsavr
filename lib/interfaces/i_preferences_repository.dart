import '../models/user_preferences_model.dart';

/// Access to a user's synced [UserPreferences] with a local cache for instant
/// start-up and offline use.
abstract class IPreferencesRepository {
  /// Preferences last cached on this device for [userId], or null when none
  /// were cached (or they belong to another account).
  UserPreferences? getCached(String userId);

  /// Loads the preferences from the backend and refreshes the cache. Falls
  /// back to the cache, then to defaults, when the backend is unreachable or
  /// has no document yet.
  Future<UserPreferences> load(String userId);

  /// Caches [preferences] locally first, then writes them to the backend with
  /// merge semantics (last write wins per key).
  Future<void> save(String userId, UserPreferences preferences);
}
