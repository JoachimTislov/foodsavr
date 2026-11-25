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
/// Keys are `store.<uid>.<provider>.<key>`, and every read and write uses the
/// current Firebase user's uid. That scoping is the isolation guarantee: one
/// account never reads another's credentials. The auth listener below only
/// tidies the device (removing a previous account's tokens on sign-out or an
/// account switch), and it runs only once this lazy singleton is first
/// resolved.
///
/// Unscoped keys from earlier versions have no verifiable owner; they are
/// deleted on the first auth event, and those stores must be reconnected.
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
  bool _sawFirstEvent = false;
  String? _previousUid;

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

  /// Purges only on a real transition. A null before any user was seen is
  /// ignored: it can precede restoring the persisted session at launch.
  Future<void> _onAccountChanged(User? user) async {
    try {
      final uid = user?.uid;
      final previous = _previousUid;
      _previousUid = uid;
      if (!_sawFirstEvent) {
        _sawFirstEvent = true;
        await _removeLegacy();
      }
      if (uid == null) {
        if (previous != null) await _removeAllExcept(null);
      } else if (uid != previous) {
        await _removeAllExcept(uid);
      }
    } catch (error, stack) {
      _logger?.w(
        'Could not scope store credentials',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _removeLegacy() async {
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
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
