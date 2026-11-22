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
/// cached in [SharedPreferencesWithCache] under one key.
@LazySingleton(as: IPreferencesRepository)
class PreferencesRepository implements IPreferencesRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferencesWithCache _prefs;
  final Logger _logger;

  /// Incremented by every [save]; a [load] that started before a save does
  /// not write its (older) backend value to the cache.
  int _writeSequence = 0;

  PreferencesRepository(this._firestore, this._prefs, this._logger);

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _firestore.doc('users/$userId/settings/preferences');

  @override
  UserPreferences? getCached(String userId) => _readCache(userId)?.$1;

  /// The cached preferences of [userId] and whether they are still waiting
  /// for the backend to confirm them (a local change not yet synced).
  (UserPreferences, bool)? _readCache(String userId) {
    final raw = _prefs.getString(PreferencesConfig.cacheKey);
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      if (entry['userId'] != userId) return null;
      final preferences = UserPreferences.fromJson(
        Map<String, dynamic>.from(entry['preferences'] as Map),
      );
      return (preferences, entry['pending'] == true);
    } catch (e) {
      _logger.w('Ignoring unreadable preferences cache: $e');
      return null;
    }
  }

  @override
  Future<UserPreferences> load(String userId) async {
    // A local change the backend has not confirmed wins over the backend copy;
    // retry its sync instead of overwriting it.
    final cached = _readCache(userId);
    if (cached != null && cached.$2) {
      unawaited(_resync(userId, cached.$1));
      return cached.$1;
    }
    final sequence = _writeSequence;
    try {
      final snapshot = await _doc(userId).get();
      final data = snapshot.data();
      if (snapshot.exists && data != null) {
        final preferences = UserPreferences.fromJson(data);
        if (sequence == _writeSequence) await _cache(userId, preferences);
        return preferences;
      }
    } catch (e) {
      _logger.w('Could not load preferences, using the local cache: $e');
    }
    return getCached(userId) ?? const UserPreferences();
  }

  @override
  Future<void> save(String userId, UserPreferences preferences) async {
    final sequence = ++_writeSequence;
    await _cache(userId, preferences, pending: true);
    await _doc(userId).set(preferences.toJson(), SetOptions(merge: true));
    // Confirmed; a newer save keeps its own pending entry.
    if (sequence == _writeSequence) await _cache(userId, preferences);
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
    return _prefs.setString(
      PreferencesConfig.cacheKey,
      jsonEncode({
        'userId': userId,
        'preferences': preferences.toJson(),
        'pending': pending,
      }),
    );
  }
}
