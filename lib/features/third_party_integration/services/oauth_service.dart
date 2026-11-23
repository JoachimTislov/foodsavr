import 'dart:async';
import 'dart:convert';

import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/models/oauth_token_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_util.dart';
import 'package:http/http.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../services/secure_storage_service.dart';

@LazySingleton(as: IOAuthService)
class OAuthService implements IOAuthService {
  final Logger _logger;
  final SecureStorage _secureStorage;
  ({Provider provider, OAuthUtil util, Completer<void> result})? _attempt;
  bool _exchanging = false;

  @override
  late final WebViewController webViewController =
      WebViewController.fromPlatformCreationParams(
          const PlatformWebViewControllerCreationParams(),
        )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              final result = _attempt?.result;
              if (error.isForMainFrame == true &&
                  !_exchanging &&
                  result != null &&
                  !result.isCompleted) {
                result.completeError(const OAuthAuthorizationException());
              }
            },
            onNavigationRequest: (request) async {
              final attempt = _attempt;
              final uri = Uri.tryParse(request.url);
              if (attempt == null) return NavigationDecision.prevent;
              if (uri == null || !attempt.util.matchesRedirect(uri)) {
                return NavigationDecision.navigate;
              }
              if (!request.isMainFrame ||
                  _exchanging ||
                  attempt.result.isCompleted) {
                return NavigationDecision.prevent;
              }

              _exchanging = true;
              try {
                final code = attempt.util.authorizationCode(uri);
                await _fetchToken(attempt.provider, attempt.util, code);
                attempt.result.complete();
              } catch (_) {
                attempt.result.completeError(
                  const OAuthAuthorizationException(),
                );
              }
              return NavigationDecision.prevent;
            },
          ),
        );

  OAuthService(this._logger, this._secureStorage);

  Future<void> _fetchToken(
    Provider provider,
    OAuthUtil util,
    String code,
  ) async {
    final response = await post(
      Uri.parse(util.env('TOKEN_URL')),
      body: util.tokenBody(code),
    );

    if (response.statusCode != 200) {
      throw const OAuthAuthorizationException();
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const OAuthAuthorizationException();
    }

    await save(
      provider,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiration: _expiration(data['expires_in']),
    );
  }

  DateTime? _expiration(Object? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.toString());
    if (seconds == null || seconds < 0) {
      throw const OAuthAuthorizationException();
    }
    return DateTime.now().toUtc().add(Duration(seconds: seconds));
  }

  @override
  Future<void> authorize(Provider provider) async {
    if (_attempt != null) throw const OAuthAuthorizationException();

    final util = OAuthUtil(provider);
    final uri = util.authUri();
    final result = Completer<void>();
    _attempt = (provider: provider, util: util, result: result);

    try {
      unawaited(
        webViewController.loadRequest(uri).catchError((Object _) {
          if (!result.isCompleted && !_exchanging) {
            result.completeError(const OAuthAuthorizationException());
          }
        }),
      );
      await result.future;
    } finally {
      _attempt = null;
      _exchanging = false;
    }
  }

  @override
  void cancelAuthorization(Provider provider) {
    final attempt = _attempt;
    if (attempt != null &&
        attempt.provider == provider &&
        !_exchanging &&
        !attempt.result.isCompleted) {
      attempt.result.completeError(const OAuthAuthorizationCancelled());
    }
  }

  @override
  Future<List<Connection>> getConnections() async {
    if (WebViewPlatform.instance == null) return [];
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
      final [access, refresh, id, exp] = await Future.wait([
        _secureStorage.read(provider, Key.access_token),
        _secureStorage.read(provider, Key.refresh_token),
        _secureStorage.read(provider, Key.id_token),
        _secureStorage.read(provider, Key.expires_at),
      ]);
      if (access == null || refresh == null || id == null || exp == null) {
        return null;
      }
      return OAuthToken(access: access, refresh: refresh, id: id, exp: exp);
    } catch (_) {
      _logger.e('Failed to read OAuthToken for ${provider.name}');
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
    final util = OAuthUtil(provider);
    final connections = await getConnections();
    final connection = connections.firstWhere((c) => c.provider == provider);
    final refreshToken = connection.refreshToken;

    if (refreshToken == null) {
      _logger.w('No refresh token found for $provider. Cannot refresh.');
      return;
    }

    final body = {
      ...util.baseParams,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    };

    final response = await post(
      Uri.parse(util.env('TOKEN_URL')),
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
          accessTokenExpiration: _expiration(data['expires_in']),
        );
      } else {
        throw Exception('Refreshed access token is null');
      }
    } else {
      _logger.e('Failed to refresh token: ${response.statusCode}');
      throw Exception('Failed to refresh token: ${response.statusCode}');
    }
  }
}
