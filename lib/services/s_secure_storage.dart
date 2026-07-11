import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';
import 'package:injectable/injectable.dart';

enum Key { access_token, refresh_token, id_token, expires_at, user_profile }

/// SecureStorage is a wrapper for FlutterSecureStorage
@singleton
class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage(this._storage);

  String _key(Provider provider, Key suffix) {
    return '${provider.name}.$suffix';
  }

  Future<String?> read(Provider provider, Key key) async {
    final val = await _storage.read(key: _key(provider, key));
    return val;
  }

  Future<void> write(Provider provider, Key key, String? v) async =>
      await _storage.write(key: _key(provider, key), value: v);

  Future<void> clear(Provider provider) async {
    for (var key in Key.values) {
      await _storage.delete(key: _key(provider, key));
    }
  }
}
