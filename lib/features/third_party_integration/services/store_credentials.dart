import 'dart:async';
import 'dart:convert';

import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_util.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

/// The store rejected the grant (consent revoked or refresh token expired);
/// the user has to reconnect.
class StoreReconnectRequired implements Exception {
  const StoreReconnectRequired();
}

/// The store could not be reached or answered unexpectedly; the connection
/// is kept and the request can be retried later.
class StoreTemporarilyUnavailable implements Exception {
  const StoreTemporarilyUnavailable();
}

/// Owns the store token lifecycle for the signed-in account: saving,
/// single-flight refresh, and revocation.
@lazySingleton
class StoreCredentials {
  StoreCredentials(this._storage, this._client, this._logger);

  /// Access tokens expiring within this margin are refreshed before use.
  static const refreshMargin = Duration(minutes: 1);
  static const _timeout = Duration(seconds: 30);
  static const revokedReason = 'revoked';

  final SecureStorage _storage;
  final http.Client _client;
  final Logger _logger;
  final Map<String, Future<String>> _refreshing = {};

  /// A usable access token for [provider], refreshed first when it expires
  /// within [refreshMargin]; null when the store is not connected.
  ///
  /// Throws [StoreReconnectRequired] or [StoreTemporarilyUnavailable] when a
  /// needed refresh fails.
  Future<String?> accessToken(Provider provider) async {
    final access = await _storage.read(provider, Key.access_token);
    if (access == null) return null;
    if (!await _expiresSoon(provider)) return access;
    return refresh(provider, rejected: access);
  }

  /// Refreshes the access token after [rejected] failed (expired or HTTP 401).
  ///
  /// Concurrent callers for the same account and store share one request.
  /// When another caller already replaced [rejected], the stored token is
  /// returned without a new request.
  Future<String> refresh(Provider provider, {required String rejected}) {
    final flight = '${_storage.accountId}.${provider.name}';
    return _refreshing[flight] ??= _refresh(provider, rejected).whenComplete(
      // A block body: returning the removed future would await itself.
      () {
        _refreshing.remove(flight);
      },
    );
  }

  Future<bool> _expiresSoon(Provider provider) async {
    final raw = await _storage.read(provider, Key.expires_at);
    final expiresAt = DateTime.tryParse(raw ?? '');
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(refreshMargin));
  }

  Future<String> _refresh(Provider provider, String rejected) async {
    final account = _storage.accountId;
    final current = await _storage.read(provider, Key.access_token);
    if (current != null &&
        current != rejected &&
        !await _expiresSoon(provider)) {
      return current;
    }
    final refreshToken = await _storage.read(provider, Key.refresh_token);
    if (refreshToken == null) {
      await _requireReconnect(provider);
      throw const StoreReconnectRequired();
    }

    final util = OAuthUtil(provider);
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(util.env('TOKEN_URL')),
            body: {
              ...util.baseParams,
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
            },
          )
          .timeout(_timeout);
    } on Exception catch (error) {
      _logger.w(
        'Store token refresh unreachable: ${provider.name}',
        error: error,
      );
      throw const StoreTemporarilyUnavailable();
    }

    // Discard the result if the account switched or the store was
    // disconnected while the request was in flight.
    if (_storage.accountId != account ||
        await _storage.read(provider, Key.refresh_token) != refreshToken) {
      throw const StoreReconnectRequired();
    }

    if (response.statusCode == 400 || response.statusCode == 401) {
      _logger.w('Store refresh token rejected: ${provider.name}');
      await _requireReconnect(provider);
      throw const StoreReconnectRequired();
    }
    final data = response.statusCode == 200 ? _decode(response.body) : null;
    final access = data?['access_token'];
    if (data == null || access is! String || access.isEmpty) {
      _logger.w(
        'Store token refresh failed: ${provider.name} ${response.statusCode}',
      );
      throw const StoreTemporarilyUnavailable();
    }
    final rotated = data['refresh_token'];
    final idToken = data['id_token'];
    await save(
      provider,
      accessToken: access,
      refreshToken: rotated is String && rotated.isNotEmpty
          ? rotated
          : refreshToken,
      idToken: idToken is String
          ? idToken
          : await _storage.read(provider, Key.id_token),
      accessTokenExpiration: expiration(data['expires_in']),
    );
    return access;
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final data = jsonDecode(body);
      return data is Map<String, dynamic> ? data : null;
    } on FormatException {
      return null;
    }
  }

  /// The expiry for an `expires_in` value in seconds, or null when absent.
  ///
  /// Throws [FormatException] for a negative or non-numeric value.
  static DateTime? expiration(Object? expiresIn) {
    if (expiresIn == null) return null;
    final seconds = int.tryParse(expiresIn.toString());
    if (seconds == null || seconds < 0) {
      throw const FormatException('Invalid expires_in');
    }
    return DateTime.now().toUtc().add(Duration(seconds: seconds));
  }

  Future<void> save(
    Provider provider, {
    required String accessToken,
    required String refreshToken,
    String? idToken,
    DateTime? accessTokenExpiration,
  }) async {
    await _storage.write(provider, Key.access_token, accessToken);
    await _storage.write(provider, Key.refresh_token, refreshToken);
    await _storage.write(provider, Key.id_token, idToken);
    await _storage.write(
      provider,
      Key.expires_at,
      accessTokenExpiration?.toIso8601String(),
    );
    await _storage.write(provider, Key.reconnect_reason, null);
  }

  Future<bool> reconnectRequired(Provider provider) async =>
      await _storage.read(provider, Key.reconnect_reason) != null;

  Future<void> _requireReconnect(Provider provider) async {
    await _storage.clear(provider);
    await _storage.write(provider, Key.reconnect_reason, revokedReason);
  }

  /// Revokes the grant at the store when it publishes a revocation endpoint
  /// (`<PROVIDER>_REVOCATION_URL`, RFC 7009), then clears the stored
  /// credentials. Revocation is best effort; local credentials are always
  /// cleared.
  Future<void> revoke(Provider provider) async {
    try {
      final refreshToken = await _storage.read(provider, Key.refresh_token);
      final (token, hint) = refreshToken != null
          ? (refreshToken, 'refresh_token')
          : (await _storage.read(provider, Key.access_token), 'access_token');
      final util = OAuthUtil(provider);
      final endpoint = util.maybeEnv('REVOCATION_URL');
      if (token != null && endpoint != null && endpoint.isNotEmpty) {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              body: {
                'client_id': util.env('CLIENT_ID'),
                'token': token,
                'token_type_hint': hint,
              },
            )
            .timeout(_timeout);
        if (response.statusCode != 200) {
          _logger.w(
            'Store revocation failed: ${provider.name} ${response.statusCode}',
          );
        }
      }
    } catch (error) {
      _logger.w('Store revocation failed: ${provider.name}', error: error);
    } finally {
      await _storage.clear(provider);
    }
  }
}
