import 'package:flutter/foundation.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'interfaces/i_oauth_service.dart';

@injectable
class OAuthController extends ChangeNotifier {
  OAuthController(this._oauthService, this._logger);

  final IOAuthService _oauthService;
  final Logger _logger;

  List<Connection> connections = [];
  Provider? activeProvider;
  String? errorMessage;

  WebViewController get webview => _oauthService.webViewController;

  Future<void> loadConnections() async {
    errorMessage = null;
    connections = await _oauthService.getConnections();
    notifyListeners();
  }

  Future<void> connect(Provider provider) async {
    if (activeProvider != null) return;

    activeProvider = provider;
    errorMessage = null;
    notifyListeners();

    try {
      await _oauthService.authorize(provider);
      await _oauthService.fetchUserProfile(provider);
    } catch (error, stackTrace) {
      errorMessage = 'Failed to connect grocery provider';
      _logger.e(errorMessage, error: error, stackTrace: stackTrace);
    } finally {
      activeProvider = null;
      await loadConnections();
      notifyListeners();
    }
  }
}
