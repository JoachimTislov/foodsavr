import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodsavr/models/m_grocery_store.dart';
import 'package:injectable/injectable.dart';
import '../models/m_oauth_token_bundle.dart';

@lazySingleton
class OAuthTokenStore {
  OAuthTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  String _key(GroceryStoreProvider provider, String suffix) =>
      'grocery_oauth.${provider.name}.$suffix';

  Future<void> save(
    GroceryStoreProvider provider,
    OAuthTokenBundle tokenBundle,
  ) async {
    await _storage.write(
      key: _key(provider, 'access_token'),
      value: tokenBundle.accessToken,
    );
    await _storage.write(
      key: _key(provider, 'refresh_token'),
      value: tokenBundle.refreshToken,
    );
    await _storage.write(
      key: _key(provider, 'id_token'),
      value: tokenBundle.idToken,
    );
    await _storage.write(
      key: _key(provider, 'expires_at'),
      value: tokenBundle.accessTokenExpirationDateTime?.toIso8601String(),
    );
  }

  Future<OAuthTokenBundle?> read(GroceryStoreProvider provider) async {
    final accessToken = await _storage.read(
      key: _key(provider, 'access_token'),
    );
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final expiresAt = await _storage.read(key: _key(provider, 'expires_at'));

    return OAuthTokenBundle(
      accessToken: accessToken,
      refreshToken: await _storage.read(key: _key(provider, 'refresh_token')),
      idToken: await _storage.read(key: _key(provider, 'id_token')),
      accessTokenExpirationDateTime: expiresAt == null || expiresAt.isEmpty
          ? null
          : DateTime.tryParse(expiresAt),
    );
  }

  Future<void> saveUserProfile(
    GroceryStoreProvider provider,
    Map<String, dynamic> profile,
  ) async {
    await _storage.write(
      key: _key(provider, 'user_profile'),
      value: jsonEncode(profile),
    );
  }

  Future<Map<String, dynamic>?> readUserProfile(
    GroceryStoreProvider provider,
  ) async {
    final rawProfile = await _storage.read(key: _key(provider, 'user_profile'));
    if (rawProfile == null || rawProfile.isEmpty) {
      return null;
    }
    return jsonDecode(rawProfile) as Map<String, dynamic>;
  }

  final _storageKeys = [
    'access_token',
    'refreshToken',
    'id_token',
    'expires_at',
    'user_profile',
  ];

  Future<void> clear(GroceryStoreProvider provider) async {
    for (var key in _storageKeys) {
      await _storage.delete(key: _key(provider, key));
    }
  }
}
