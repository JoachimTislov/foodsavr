import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

enum Key {
  access_token,
  refresh_token,
  id_token,
  expires_at,
  user_profile,
  reconnect_reason,
}

/// Store credentials in [FlutterSecureStorage], scoped to the signed-in
/// FoodSavr account.
///
/// Keys are `store.<uid>.<provider>.<key>`. On every auth state change the
/// device keeps only the signed-in account's credentials, so signing out or
/// switching accounts removes the previous account's tokens. Unscoped keys
/// from earlier versions are adopted once, on the first auth state, only when
/// they provably postdate the restored session's sign-in; otherwise they are
/// deleted and the store must be reconnected.
@lazySingleton
class SecureStorage {
  SecureStorage(this._storage, {FirebaseAuth? auth, Logger? logger})
    : _auth = auth,
      _logger = logger {
    _subscription = auth?.authStateChanges().listen(
      (user) => _pending = _pending.then((_) => _onAccountChanged(user)),
    );
  }

  static const _prefix = 'store.';

  final FlutterSecureStorage _storage;
  final FirebaseAuth? _auth;
  final Logger? _logger;
  StreamSubscription<User?>? _subscription;
  Future<void> _pending = Future.value();
  bool _sawFirstAccount = false;

  /// The FoodSavr account whose credentials are visible, or null.
  String? get accountId => _auth?.currentUser?.uid;

  /// Completes when pending account cleanup and migration are done.
  @visibleForTesting
  Future<void> get idle => _pending;

  static String _scoped(String uid, Provider provider, Key key) =>
      '$_prefix$uid.${provider.name}.${key.name}';

  static String _legacy(Provider provider, Key key) => '${provider.name}.$key';

  static final Set<String> _legacyKeys = {
    for (final provider in Provider.values)
      for (final key in Key.values) _legacy(provider, key),
  };

  Future<String?> read(Provider provider, Key key) async {
    await _pending;
    final uid = accountId;
    if (uid == null) return null;
    return _storage.read(key: _scoped(uid, provider, key));
  }

  /// Writes [value] for the signed-in account; a null [value] deletes it.
  ///
  /// Throws [StateError] when no account is signed in.
  Future<void> write(Provider provider, Key key, String? value) async {
    await _pending;
    final uid = accountId;
    if (uid == null) throw StateError('No signed-in account');
    await _storage.write(key: _scoped(uid, provider, key), value: value);
  }

  /// Clears the signed-in account's credentials for every store, or every
  /// stored store credential when no account is signed in.
  Future<void> clearStoreTokens() async {
    await _pending;
    final uid = accountId;
    if (uid == null) return _removeAllExcept(null);
    for (final provider in Provider.values) {
      await _clear(uid, provider);
    }
  }

  /// Clears the signed-in account's credentials for [provider].
  Future<void> clear(Provider provider) async {
    await _pending;
    final uid = accountId;
    if (uid != null) await _clear(uid, provider);
  }

  Future<void> _clear(String uid, Provider provider) async {
    for (final key in Key.values) {
      await _storage.delete(key: _scoped(uid, provider, key));
    }
  }

  Future<void> _onAccountChanged(User? user) async {
    try {
      final first = !_sawFirstAccount;
      _sawFirstAccount = true;
      if (first && user != null) await _adoptLegacy(user);
      await _removeAllExcept(user?.uid);
    } catch (error, stack) {
      _logger?.w(
        'Could not scope store credentials',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Moves unscoped credentials to [user] when they were issued during the
  /// restored session: their expiry is not earlier than the last sign-in.
  Future<void> _adoptLegacy(User user) async {
    final signedInAt = user.metadata.lastSignInTime;
    if (signedInAt == null) return;
    for (final provider in Provider.values) {
      final values = {
        for (final key in Key.values)
          key: await _storage.read(key: _legacy(provider, key)),
      };
      final expiresAt = DateTime.tryParse(values[Key.expires_at] ?? '');
      if (values[Key.access_token] == null ||
          values[Key.refresh_token] == null ||
          expiresAt == null ||
          expiresAt.isBefore(signedInAt)) {
        continue;
      }
      for (final MapEntry(:key, :value) in values.entries) {
        if (value == null) continue;
        await _storage.write(
          key: _scoped(user.uid, provider, key),
          value: value,
        );
      }
    }
  }

  /// Deletes unscoped keys and every scoped key not owned by [uid].
  Future<void> _removeAllExcept(String? uid) async {
    final keep = uid == null ? null : '$_prefix$uid.';
    final keys = (await _storage.readAll()).keys.toList();
    for (final key in keys) {
      final scoped = key.startsWith(_prefix);
      final owned = keep != null && key.startsWith(keep);
      if (_legacyKeys.contains(key) || (scoped && !owned)) {
        await _storage.delete(key: key);
      }
    }
  }

  @disposeMethod
  Future<void> dispose() async => _subscription?.cancel();
}
