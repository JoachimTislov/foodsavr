import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/models/token_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_util.dart';
import 'package:http/http.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../services/secure_storage_service.dart';

// TODO: Need to figure out a clean relationship between the OAuth model, controller and the methods exposed
// It operates based on one provider
@LazySingleton(as: IOAuthService)
class OAuthService implements IOAuthService {
  final Logger _logger;
  final SecureStorage _secureStorage;
  late Provider provider;
  late OAuthUtil _util;
  Completer<void>? _authCompleter;

  @override
  late WebViewController webViewController;

  OAuthService(this._logger, this._secureStorage) {
    webViewController =
        WebViewController.fromPlatformCreationParams(
            const PlatformWebViewControllerCreationParams(),
          )
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
                if (error.isForMainFrame != null && error.isForMainFrame!) {
                  _authCompleter?.completeError(
                    Exception('Failed to load auth page: ${error.description}'),
                  );
                }
              },
              onHttpError: (HttpResponseError error) {
                _logger.d(
                  'Error occurred on page: ${error.response?.statusCode}',
                );
              },
              onUrlChange: (UrlChange change) {
                _logger.d('url change to ${change.url}');
              },
              onHttpAuthRequest: (HttpAuthRequest request) {
                _logger.d('WebView HTTP auth request: ${request.host}');
                // openDialog(request);
              },
              onNavigationRequest: (request) async {
                _logger.d('WebView navigation request: ${request.url}');
                if (request.url.startsWith(_util.env('REDIRECT_URL'))) {
                  final code = Uri.parse(request.url).queryParameters['code'];
                  if (code != null && code.isNotEmpty) {
                    _logger.d(
                      'Detected authorization code in WebView URL: $code',
                    );
                    try {
                      await _fetchToken(code);
                      _authCompleter?.complete();
                    } catch (e, s) {
                      _logger.e(
                        'Error fetching token',
                        error: e,
                        stackTrace: s,
                      );
                      _authCompleter?.completeError(e);
                    }
                    return NavigationDecision.prevent;
                  }
                }
                return NavigationDecision.navigate;
              },
            ),
          );
  }

  /// fetchToken exchanges code for token
  /// throws HTTP [error]
  Future<void> _fetchToken(String code) async {
    final Response response = await post(
      Uri.parse(_util.env('TOKEN_URL')),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: _util.tokenBody(code),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // TODO: consider handling each null case...
      // TODO: store json / Map<String, String>
      // values will rarely be used separately
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (accessToken != null && refreshToken != null) {
        _logger.i('[SUCCESS]: fetched accessToken');
        await save(
          provider,
          accessToken: accessToken,
          refreshToken: refreshToken,
          accessTokenExpiration: data['expires_in'],
        );
      } else {
        throw Exception('accessToken or refreshToken is null');
      }
    } else {
      _logger.e(
        'Failed to fetch token: ${response.statusCode} ${response.body}',
      );
    }
  }

  @override
  Future<void> authorize(Provider provider) async {
    this.provider = provider;
    _util = OAuthUtil(provider);
    _authCompleter = Completer<void>();
    await webViewController.loadRequest(_util.authUri());
    return _authCompleter!.future;
  }

  @override
  Future<List<Connection>> getConnections() async {
    var connections = <Connection>[];
    for (final provider in Provider.values) {
      if (!provider.isSupported()) continue;
      connections.add(
        Connection(
          provider: provider,
          accessToken: await _secureStorage.read(provider, Key.access_token),
          refreshToken: await _secureStorage.read(provider, Key.refresh_token),
          idToken: await _secureStorage.read(provider, Key.id_token),
          accessTokenExpiration: await expiresAt(provider),
        ),
      );
    }
    return connections;
  }

  Future<OAuthToken?> readOAuthToken(Provider provider) async {
    try {
      List<String?> wait = await Future.wait([
        _secureStorage.read(provider, Key.access_token),
        _secureStorage.read(provider, Key.refresh_token),
        _secureStorage.read(provider, Key.id_token),
        _secureStorage.read(provider, Key.expires_at),
      ]);
      return OAuthToken(
        access: wait[0],
        refresh: wait[1],
        id: wait[2],
        exp: wait[3],
      );
    } catch (e) {
      _logger.e('Failed to read OAuthToken for ${provider.name}, $e');
      return null;
    }
  }

  Future<void> save(
    Provider provider, {
    required String accessToken,
    required String refreshToken,
    String? idToken,
    DateTime? accessTokenExpiration,
  }) async {
    await Future.wait([
      _secureStorage.write(provider, Key.access_token, accessToken),
      _secureStorage.write(provider, Key.refresh_token, refreshToken),
      _secureStorage.write(provider, Key.id_token, idToken),
      _secureStorage.write(
        provider,
        Key.expires_at,
        accessTokenExpiration?.toIso8601String(),
      ),
    ]);
  }

  Future<DateTime?> expiresAt(Provider provider) async {
    dynamic expiresAt = await _secureStorage.read(provider, Key.expires_at);
    if (expiresAt != null) return DateTime.tryParse(expiresAt);
    return expiresAt;
  }

  Future<void> saveUserProfile(
    Provider provider,
    Map<String, dynamic> profile,
  ) async {
    await _secureStorage.write(provider, Key.user_profile, jsonEncode(profile));
  }

  @override
  Future<Map<String, dynamic>?> fetchUserProfile(Provider provider) async {
    final rawProfile = await _secureStorage.read(provider, Key.user_profile);
    if (rawProfile == null || rawProfile.isEmpty) {
      return null;
    }
    return jsonDecode(rawProfile) as Map<String, dynamic>;
  }

  Future<void> refreshToken(Provider provider) async {
    _util = OAuthUtil(provider);
    final connections = await getConnections();
    final connection = connections.firstWhere((c) => c.provider == provider);
    final refreshToken = connection.refreshToken;

    if (refreshToken == null) {
      _logger.w('No refresh token found for $provider. Cannot refresh.');
      return;
    }

    final body = {
      ..._util.baseParams,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    };

    final response = await post(
      Uri.parse(_util.env('TOKEN_URL')),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccessToken = data['access_token'];
      if (newAccessToken != null) {
        _logger.i('[SUCCESS]: refreshed accessToken for $provider');
        await save(
          provider,
          accessToken: newAccessToken,
          refreshToken: data['refresh_token'] ?? refreshToken,
          idToken: data['id_token'],
          accessTokenExpiration: data['expires_in'],
        );
      } else {
        throw Exception('Refreshed access token is null');
      }
    } else {
      _logger.e(
        'Failed to refresh token: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to refresh token: ${response.statusCode}');
    }
  }
}
