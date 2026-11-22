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

  PreferencesRepository(this._firestore, this._prefs, this._logger);

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _firestore.doc('users/$userId/settings/preferences');

  @override
  UserPreferences? getCached(String userId) {
    final raw = _prefs.getString(PreferencesConfig.cacheKey);
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      if (entry['userId'] != userId) return null;
      return UserPreferences.fromJson(
        Map<String, dynamic>.from(entry['preferences'] as Map),
      );
    } catch (e) {
      _logger.w('Ignoring unreadable preferences cache: $e');
      return null;
    }
  }

  @override
  Future<UserPreferences> load(String userId) async {
    try {
      final snapshot = await _doc(userId).get();
      final data = snapshot.data();
      if (snapshot.exists && data != null) {
        final preferences = UserPreferences.fromJson(data);
        await _cache(userId, preferences);
        return preferences;
      }
    } catch (e) {
      _logger.w('Could not load preferences, using the local cache: $e');
    }
    return getCached(userId) ?? const UserPreferences();
  }

  @override
  Future<void> save(String userId, UserPreferences preferences) async {
    await _cache(userId, preferences);
    await _doc(userId).set(preferences.toJson(), SetOptions(merge: true));
  }

  Future<void> _cache(String userId, UserPreferences preferences) {
    return _prefs.setString(
      PreferencesConfig.cacheKey,
      jsonEncode({'userId': userId, 'preferences': preferences.toJson()}),
    );
  }
}
