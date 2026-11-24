import 'dart:async';
import 'dart:convert';

import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_util.dart';
import 'package:foodsavr/features/third_party_integration/services/store_credentials.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:http/http.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  OAuthService(
    this._logger,
    this._secureStorage, {
    StoreCredentials? credentials,
  }) : _injectedCredentials = credentials;

  final StoreCredentials? _injectedCredentials;
  late final StoreCredentials _credentials =
      _injectedCredentials ??
      StoreCredentials(_secureStorage, Client(), _logger);

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
    final idToken = data['id_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const OAuthAuthorizationException();
    }

    final DateTime? expiration;
    try {
      expiration = StoreCredentials.expiration(data['expires_in']);
    } on FormatException {
      throw const OAuthAuthorizationException();
    }
    await _credentials.save(
      provider,
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken is String ? idToken : null,
      accessTokenExpiration: expiration,
    );
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
    final connections = <Connection>[];
    for (final provider in Provider.values) {
      if (!provider.isSupported()) continue;
      final issue = await _issue(provider);
      connections.add(
        Connection(
          provider: provider,
          accessToken: await _secureStorage.read(provider, Key.access_token),
          refreshToken: await _secureStorage.read(provider, Key.refresh_token),
          idToken: await _secureStorage.read(provider, Key.id_token),
          accessTokenExpiration: await expiresAt(provider),
          issue: issue,
        ),
      );
    }
    return connections;
  }

  /// Renews an expiring token so the list reflects whether the connection
  /// still works.
  Future<ConnectionIssue?> _issue(Provider provider) async {
    try {
      await _credentials.accessToken(provider);
    } on StoreReconnectRequired {
      return ConnectionIssue.reconnectRequired;
    } on StoreTemporarilyUnavailable {
      return ConnectionIssue.temporarilyUnavailable;
    } catch (error, stack) {
      _logger.w(
        'Could not renew store access: ${provider.name}',
        error: error,
        stackTrace: stack,
      );
      return ConnectionIssue.temporarilyUnavailable;
    }
    return await _credentials.reconnectRequired(provider)
        ? ConnectionIssue.reconnectRequired
        : null;
  }

  @override
  Future<void> disconnect(Provider provider) => _credentials.revoke(provider);

  Future<DateTime?> expiresAt(Provider provider) async {
    final expiresAt = await _secureStorage.read(provider, Key.expires_at);
    return expiresAt == null ? null : DateTime.tryParse(expiresAt);
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
}
