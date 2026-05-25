import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_grocery_store_auth_service.dart';
import '../models/grocery_store_auth_config.dart';
import '../models/grocery_store_connection.dart';
import '../models/grocery_store_provider.dart';
import '../models/oauth_token_bundle.dart';
import '../utils/config.dart';
import 'oauth_token_store.dart';

@LazySingleton(as: IGroceryStoreAuthService)
class GroceryStoreAuthService implements IGroceryStoreAuthService {
  GroceryStoreAuthService(
    this._appAuth,
    this._httpClient,
    this._logger,
    this._tokenStore,
  );

  final FlutterAppAuth _appAuth;
  final http.Client _httpClient;
  final Logger _logger;
  final OAuthTokenStore _tokenStore;

  static final List<GroceryStoreAuthConfig> _configs = [
    GroceryStoreAuthConfig(
      provider: GroceryStoreProvider.coop,
      clientId: Config.coopClientId,
      redirectUri: Config.coopRedirectUri,
      discoveryUrl: Config.coopDiscoveryUrl,
      scopes: Config.coopScopes.split(' '),
      additionalParameters: Config.coopAudience.isEmpty
          ? const {}
          : {'audience': Config.coopAudience},
      userInfoEndpoint: Config.coopUserInfoEndpoint,
    ),
    GroceryStoreAuthConfig(
      provider: GroceryStoreProvider.rema1000,
      clientId: Config.remaClientId,
      redirectUri: Config.remaRedirectUri,
      authorizationEndpoint: Config.remaAuthorizationEndpoint,
      tokenEndpoint: Config.remaTokenEndpoint,
      scopes: Config.remaScopes.split(' '),
    ),
    GroceryStoreAuthConfig(
      provider: GroceryStoreProvider.trumf,
      clientId: Config.trumfClientId,
      redirectUri: Config.trumfRedirectUri,
      discoveryUrl: Config.trumfDiscoveryUrl,
      scopes: Config.trumfScopes.split(' '),
    ),
  ];

  @override
  Future<List<GroceryStoreConnection>> getConnections() async {
    final connections = <GroceryStoreConnection>[];
    for (final config in _configs) {
      final storedToken = await _tokenStore.read(config.provider);
      connections.add(
        GroceryStoreConnection(
          provider: config.provider,
          isAvailable: !kIsWeb && config.isConfigured,
          isConnected: storedToken != null,
          statusKey: kIsWeb
              ? 'settings.integrations.status.mobile_only'
              : config.isConfigured
              ? null
              : 'settings.integrations.status.not_configured',
        ),
      );
    }
    return connections;
  }

  @override
  Future<void> authorize(GroceryStoreProvider provider) async {
    final config = _configFor(provider);
    _assertSupported(config);

    final response = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        config.clientId,
        config.redirectUri,
        discoveryUrl: config.discoveryUrl,
        serviceConfiguration: config.serviceConfiguration,
        scopes: config.scopes,
        additionalParameters: config.additionalParameters,
      ),
    );

    final accessToken = response.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Provider did not return an access token.');
    }

    await _tokenStore.save(
      provider,
      OAuthTokenBundle(
        accessToken: accessToken,
        refreshToken: response.refreshToken,
        idToken: response.idToken,
        accessTokenExpirationDateTime: response.accessTokenExpirationDateTime,
      ),
    );

    _logger.i('Linked grocery provider: ${provider.storageKey}');
  }

  @override
  Future<void> disconnect(GroceryStoreProvider provider) async {
    await _tokenStore.clear(provider);
    _logger.i('Disconnected grocery provider: ${provider.storageKey}');
  }

  @override
  Future<String?> getValidAccessToken(GroceryStoreProvider provider) async {
    final config = _configFor(provider);
    final storedToken = await _tokenStore.read(provider);
    if (storedToken == null) {
      return null;
    }

    final expiresAt = storedToken.accessTokenExpirationDateTime;
    final hasValidAccessToken =
        expiresAt == null ||
        expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 1)));
    if (hasValidAccessToken) {
      return storedToken.accessToken;
    }

    final refreshToken = storedToken.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStore.clear(provider);
      return null;
    }

    final response = await _appAuth.token(
      TokenRequest(
        config.clientId,
        config.redirectUri,
        refreshToken: refreshToken,
        discoveryUrl: config.discoveryUrl,
        serviceConfiguration: config.serviceConfiguration,
        scopes: config.scopes,
        additionalParameters: config.additionalParameters,
      ),
    );

    final refreshedAccessToken = response.accessToken;
    if (refreshedAccessToken == null || refreshedAccessToken.isEmpty) {
      await _tokenStore.clear(provider);
      throw StateError(
        'Provider refresh did not return a usable access token.',
      );
    }

    final refreshedBundle = OAuthTokenBundle(
      accessToken: refreshedAccessToken,
      refreshToken: response.refreshToken ?? refreshToken,
      idToken: response.idToken ?? storedToken.idToken,
      accessTokenExpirationDateTime: response.accessTokenExpirationDateTime,
    );
    await _tokenStore.save(provider, refreshedBundle);

    return refreshedBundle.accessToken;
  }

  @override
  Future<Map<String, dynamic>?> fetchUserProfile(
    GroceryStoreProvider provider,
  ) async {
    final config = _configFor(provider);
    final userInfoEndpoint = config.userInfoEndpoint;
    if (userInfoEndpoint == null || userInfoEndpoint.isEmpty) {
      return null;
    }

    final accessToken = await getValidAccessToken(provider);
    if (accessToken == null) {
      return null;
    }

    final response = await _httpClient.get(
      Uri.parse(userInfoEndpoint),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Failed to fetch provider profile (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    await _tokenStore.saveUserProfile(provider, decoded);
    return decoded;
  }

  GroceryStoreAuthConfig _configFor(GroceryStoreProvider provider) {
    return _configs.firstWhere((config) => config.provider == provider);
  }

  void _assertSupported(GroceryStoreAuthConfig config) {
    if (kIsWeb) {
      throw UnsupportedError(
        'Grocery-store linking is only available on mobile.',
      );
    }
    if (!config.isConfigured) {
      throw StateError('Provider configuration is missing.');
    }
  }
}
