import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/preferences_config.dart';
import '../interfaces/i_preferences_repository.dart';
import '../models/user_preferences_model.dart';

/// Firestore implementation of [IPreferencesRepository]. Preferences live at
/// `users/{uid}/settings/preferences`; the last signed-in account's copy is
/// cached in [SharedPreferencesWithCache] under one key, indexed by account.
@LazySingleton(as: IPreferencesRepository)
class PreferencesRepository implements IPreferencesRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferencesWithCache _prefs;
  final Logger _logger;

  /// Incremented by every [save]; a [load] that started before a save does
  /// not write its (older) backend value to that account's cache.
  final Map<String, int> _writeSequences = {};
  final Map<String, UserPreferences> _pendingWrites = {};

  Future<void> _cacheWrites = Future<void>.value();

  PreferencesRepository(this._firestore, this._prefs, this._logger);

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _firestore.doc('users/$userId/settings/preferences');

  @override
  UserPreferences? getCached(String userId) => _readCache(userId)?.$1;

  /// The cached preferences of [userId] and whether they are still waiting
  /// for the backend to confirm them (a local change not yet synced).
  (UserPreferences, bool)? _readCache(String userId) {
    final entry = _readCacheEntries()[userId];
    if (entry == null) return null;
    try {
      final preferences = UserPreferences.fromJson(
        Map<String, dynamic>.from(entry['preferences'] as Map),
      );
      return (preferences, entry['pending'] == true);
    } catch (e) {
      _logger.w('Ignoring unreadable preferences cache: $e');
      return null;
    }
  }

  Map<String, Map<String, dynamic>> _readCacheEntries() {
    final raw = _prefs.getString(PreferencesConfig.cacheKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final value = Map<String, dynamic>.from(decoded);
      final users = value['users'];
      if (users is Map) {
        return {
          for (final entry in users.entries)
            if (entry.key is String && entry.value is Map)
              entry.key as String: Map<String, dynamic>.from(
                entry.value as Map,
              ),
        };
      }

      // Read the previous single-account cache shape and migrate it on write.
      final userId = value['userId'];
      final preferences = value['preferences'];
      if (userId is String && preferences is Map) {
        return {
          userId: {
            'preferences': preferences,
            'pending': value['pending'] == true,
          },
        };
      }
    } catch (e) {
      _logger.w('Ignoring unreadable preferences cache: $e');
    }
    return {};
  }

  @override
  Future<UserPreferences> load(String userId) async {
    // A local change the backend has not confirmed wins over the backend copy;
    // retry its sync instead of overwriting it.
    final pendingWrite = _pendingWrites[userId];
    if (pendingWrite != null) {
      unawaited(_resync(userId, pendingWrite));
      return pendingWrite;
    }
    final cached = _readCache(userId);
    if (cached != null && cached.$2) {
      unawaited(_resync(userId, cached.$1));
      return cached.$1;
    }
    final sequence = _writeSequences[userId] ?? 0;
    try {
      final snapshot = await _doc(userId).get();
      final data = snapshot.data();
      if (snapshot.exists && data != null) {
        final preferences = UserPreferences.fromJson(data);
        if (sequence == (_writeSequences[userId] ?? 0)) {
          await _cache(userId, preferences);
        }
        return preferences;
      }
    } catch (e) {
      _logger.w('Could not load preferences, using the local cache: $e');
    }
    return getCached(userId) ?? const UserPreferences();
  }

  @override
  Future<void> save(String userId, UserPreferences preferences) async {
    final sequence = (_writeSequences[userId] ?? 0) + 1;
    _writeSequences[userId] = sequence;
    _pendingWrites[userId] = preferences;
    await _cache(userId, preferences, pending: true);
    await _doc(userId).set(preferences.toJson(), SetOptions(merge: true));
    // Confirmed; a newer save keeps its own pending entry.
    if (sequence == _writeSequences[userId]) {
      _pendingWrites.remove(userId);
      await _cache(userId, preferences);
    }
  }

  Future<void> _resync(String userId, UserPreferences preferences) async {
    try {
      await save(userId, preferences);
    } catch (e) {
      _logger.w('Preferences still not synced; kept on this device: $e');
    }
  }

  Future<void> _cache(
    String userId,
    UserPreferences preferences, {
    bool pending = false,
  }) {
    final write = _cacheWrites.then<void>((_) async {
      final users = _readCacheEntries();
      users[userId] = {'preferences': preferences.toJson(), 'pending': pending};
      await _prefs.setString(
        PreferencesConfig.cacheKey,
        jsonEncode({'users': users}),
      );
    });
    _cacheWrites = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }
}
