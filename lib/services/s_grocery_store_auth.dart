import 'package:flutter/foundation.dart';
import 'package:foodsavr/interfaces/is_grocery_store_oauth.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/m_grocery_store.dart';
import 's_oauth_token_store.dart';

@LazySingleton(as: IGroceryStoreAuthService)
class GroceryStoreAuthService implements IGroceryStoreAuthService {
  GroceryStoreAuthService(this._logger, this._tokenStore) {
    _webViewController = WebViewController.fromPlatformCreationParams(
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

  final Logger _logger;
  final OAuthTokenStore _tokenStore;
  late WebViewController _webViewController;

  @override
  WebViewController get webViewController => _webViewController;

  @override
  Future<void> authorize(GroceryStoreProvider provider) async {}

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
  Future<Map<String, dynamic>?> fetchUserProfile(
    GroceryStoreProvider provider,
  ) async {
    return {};
  }
}
