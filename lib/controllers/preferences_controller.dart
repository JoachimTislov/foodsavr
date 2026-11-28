import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../constants/preferences_config.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_preferences_repository.dart';
import '../models/user_preferences_model.dart';
import '../services/collection_service.dart';
import '../utils/collection_types.dart';

/// Holds the signed-in user's [UserPreferences] and keeps them in sync with
/// the backend. Starts from the local cache for an instant first frame, then
/// refreshes from the backend; widgets rebuild reactively via watch_it.
@lazySingleton
class PreferencesController extends ChangeNotifier {
  final IAuthService _authService;
  final IPreferencesRepository _repository;
  final CollectionService _collectionService;
  final Logger _logger;
  late final StreamSubscription<Object?> _authSubscription;

  String? _userId;
  UserPreferences _preferences = const UserPreferences();
  int _generation = 0;

  PreferencesController(
    this._authService,
    this._repository,
    this._collectionService,
    this._logger,
  ) {
    _switchUser(_authService.getUserId());
    _authSubscription = _authService.authStateChanges.listen(
      (user) => _switchUser(user?.uid),
    );
  }

  UserPreferences get preferences => _preferences;

  /// Days ahead in which a product counts as expiring soon.
  int get expiringSoonDays => _preferences.effectiveExpiringSoonDays;

  /// The explicitly chosen default inventory, or null for "first inventory".
  String? get defaultInventoryId => _preferences.defaultInventoryId;

  /// The inventory that should receive new products when no collection is
  /// given: the chosen default when it still exists, otherwise the user's
  /// first inventory, or null when there is none. [userId] defaults to the
  /// signed-in user; another user's inventories ignore the local choice.
  Future<String?> resolveDefaultInventoryId({String? userId}) async {
    final id = userId ?? _userId;
    if (id == null) return null;
    try {
      final inventories = await _collectionService.getCollectionsForUser(
        id,
        type: CollectionType.inventory,
      );
      final preferences = id == _userId
          ? _preferences
          : const UserPreferences();
      return preferences.resolveDefaultInventoryId(inventories);
    } catch (e) {
      // No target is a valid outcome: the product is created standalone.
      _logger.w('Could not resolve the default inventory: $e');
      return null;
    }
  }

  /// Refreshes the preferences from the backend for the signed-in user.
  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    final generation = _generation;
    try {
      final loaded = await _repository.load(userId);
      if (generation == _generation) _apply(loaded);
    } catch (e) {
      _logger.w('Failed to load preferences: $e');
    }
  }

  Future<void> setExpiringSoonDays(int days) {
    return _update(
      _preferences.copyWith(
        expiringSoonDays: days.clamp(
          PreferencesConfig.minExpiringSoonDays,
          PreferencesConfig.maxExpiringSoonDays,
        ),
      ),
    );
  }

  /// Sets the default inventory; null restores the "first inventory" fallback.
  Future<void> setDefaultInventoryId(String? inventoryId) {
    return _update(_preferences.copyWith(defaultInventoryId: inventoryId));
  }

  /// Drops the stored default once [inventoryId] was deleted, restoring the
  /// "first inventory" fallback. A failed sync keeps the change on this device;
  /// [resolveDefaultInventoryId] ignores a stale ID either way.
  Future<void> forgetDefaultInventory(String inventoryId) async {
    if (defaultInventoryId != inventoryId) return;
    try {
      await setDefaultInventoryId(null);
    } catch (_) {
      // Already logged by the failed save.
    }
  }

  /// Applies [next] locally (and to the device cache), then syncs it. A failed
  /// sync is rethrown so the caller can tell the user the change is kept on
  /// this device only.
  Future<void> _update(UserPreferences next) async {
    final userId = _userId;
    if (userId == null || next == _preferences) return;
    // A load still in flight read the backend before this change; drop it.
    _generation++;
    _apply(next);
    try {
      await _repository.save(userId, next);
    } catch (e) {
      _logger.e('Failed to save preferences: $e');
      rethrow;
    }
  }

  void _switchUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    _apply(
      userId == null
          ? const UserPreferences()
          : _repository.getCached(userId) ?? const UserPreferences(),
    );
    if (userId != null) unawaited(load());
  }

  void _apply(UserPreferences next) {
    if (next == _preferences) return;
    _preferences = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
