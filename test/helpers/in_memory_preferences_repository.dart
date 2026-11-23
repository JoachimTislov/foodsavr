import 'dart:async';

import 'package:foodsavr/interfaces/i_preferences_repository.dart';
import 'package:foodsavr/models/user_preferences_model.dart';

/// In-memory [IPreferencesRepository] for tests; `cache` and `remote` can be
/// seeded independently to model a device-local copy and the backend.
class InMemoryPreferencesRepository implements IPreferencesRepository {
  final Map<String, UserPreferences> cache = {};
  final Map<String, UserPreferences> remote = {};
  final List<(String, UserPreferences)> saved = [];
  Completer<void>? loadGate;

  @override
  UserPreferences? getCached(String userId) => cache[userId];

  @override
  Future<UserPreferences> load(String userId) async {
    await loadGate?.future;
    return remote[userId] ?? cache[userId] ?? const UserPreferences();
  }

  @override
  Future<void> deleteForUser(String userId) async {
    cache.remove(userId);
    remote.remove(userId);
  }

  @override
  Future<void> save(String userId, UserPreferences preferences) async {
    cache[userId] = preferences;
    remote[userId] = preferences;
    saved.add((userId, preferences));
  }
}
