import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../interfaces/is_grocery_store_oauth.dart';
import '../models/m_grocery_store.dart';
import '../models/m_grocery_store_auth_confid.dart';
import '../models/m_grocery_store_provider.dart';
import '../models/m_oauth_token_bundle.dart';
import 's_oauth_token_store.dart';

@LazySingleton(as: IGroceryStoreAuthService)
class GroceryStoreAuthService implements IGroceryStoreAuthService {
  GroceryStoreAuthService(this._httpClient, this._logger, this._tokenStore) {
    webViewController = WebViewController.fromPlatformCreationParams(
      const PlatformWebViewControllerCreationParams(),
    );

    webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            _logger.d('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            _logger.d('Page started loading: $url');
          },
          onPageFinished: (String url) {
            _logger.d('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            _logger.d('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          onHttpError: (HttpResponseError error) {
            _logger.d('Error occurred on page: ${error.response?.statusCode}');
          },
          onUrlChange: (UrlChange change) {
            _logger.d('url change to ${change.url}');
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            _logger.d('WebView HTTP auth request: ${request.host}');
            // openDialog(request);
          },
          onNavigationRequest: (request) {
            _logger.d('WebView navigation request: ${request.url}');
            final uri = Uri.parse(request.url);
            final code = uri.queryParameters['code'];
            if (code is String && code.isNotEmpty) {
              _logger.d('Detected authorization code in WebView URL: $code');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  final http.Client _httpClient;
  final Logger _logger;
  final OAuthTokenStore _tokenStore;

  @override
  late final WebViewController webViewController;

  @override
  Future<List<GroceryStoreConnection>> getConnections() async {
    final connections = <GroceryStoreConnection>[];
    for (final config in {}) {
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
    final config = configFor(provider);
    _assertSupported(config);

    final response = await _appAuth.authorize(
      AuthorizationRequest(
        config.clientId,
        config.redirectUri,
        serviceConfiguration: config.serviceConfiguration,
        scopes: config.scopes,
      ),
      // AuthorizationTokenRequest(
      //   config.clientId,
      //   config.redirectUri,
      //   // discoveryUrl: config.discoveryUrl,
      //   serviceConfiguration: config.serviceConfiguration,
      //   scopes: config.scopes,
      //   // additionalParameters: config.additionalParameters,
      // ),
    );

    _logger.d('OAuth response for $provider: $response');

    final accessToken = response.authorizationCode;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Provider did not return an access token.');
    }

    // await _tokenStore.save(
    //   provider,
    //   OAuthTokenBundle(
    //     accessToken: accessToken,
    //     refreshToken: response.refreshToken,
    //     idToken: response.idToken,
    //     accessTokenExpirationDateTime: response.accessTokenExpirationDateTime,
    //   ),
    // );

    _logger.i('Linked grocery provider: $provider');
  }

  @override
  Future<void> disconnect(GroceryStoreProvider provider) async {
    await _tokenStore.clear(provider);
    _logger.i('Disconnected grocery provider: $provider');
  }

  @override
  Future<String?> getValidAccessToken(GroceryStoreProvider provider) async {
    final config = configFor(provider);
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
    final config = configFor(provider);
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

  GroceryStoreAuthConfig configFor(GroceryStoreProvider provider) {
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
