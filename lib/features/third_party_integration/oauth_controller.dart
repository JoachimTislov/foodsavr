import 'package:flutter/foundation.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'interfaces/i_oauth_service.dart';
import 'oauth_util.dart';

@injectable
class OAuthController extends ChangeNotifier {
  OAuthController(this._oauthService, this._logger);

  final IOAuthService _oauthService;
  final Logger _logger;

  List<Connection> connections = [];
  Provider? activeProvider;
  bool connectionFailed = false;

  WebViewController get webview => _oauthService.webViewController;

  Future<void> loadConnections() async {
    connectionFailed = false;
    connections = await _oauthService.getConnections();
    notifyListeners();
  }

  void cancelConnection() {
    final provider = activeProvider;
    if (provider != null) _oauthService.cancelAuthorization(provider);
  }

  /// Revokes and clears [provider]'s tokens, then reloads the list.
  Future<void> disconnect(Provider provider) async {
    if (activeProvider != null) return;

    activeProvider = provider;
    notifyListeners();
    try {
      await _oauthService.disconnect(provider);
    } catch (error, stack) {
      _logger.e(
        'Failed to disconnect grocery provider',
        error: error,
        stackTrace: stack,
      );
    } finally {
      activeProvider = null;
      await loadConnections();
    }
  }

  Future<void> connect(Provider provider) async {
    if (activeProvider != null) return;

    activeProvider = provider;
    connectionFailed = false;
    notifyListeners();

    try {
      await _oauthService.authorize(provider);
      await _oauthService.fetchUserProfile(provider);
      await loadConnections();
    } on OAuthAuthorizationCancelled {
      return;
    } catch (_) {
      connectionFailed = true;
      _logger.e('Failed to connect grocery provider');
    } finally {
      activeProvider = null;
      notifyListeners();
    }
  }
}
