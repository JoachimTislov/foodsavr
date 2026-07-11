import 'package:flutter/foundation.dart';
import 'package:foodsavr/features/third_party_integration/models/m_connection.dart';
import 'package:foodsavr/features/third_party_integration/models/m_provider.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'interfaces/i_oauth_service.dart';

@injectable
class OAuthController extends ChangeNotifier {
  OAuthController(this._oauthService, this._logger);

  final IOAuthService _oauthService;
  final Logger _logger;

  List<Connection> _connections = [];
  Provider? _activeProvider;
  String? _errorMessage;

  List<Connection> get connections => _connections;
  Provider? get activeProvider => _activeProvider;
  String? get errorMessage => _errorMessage;
  WebViewController get webview => _oauthService.webViewController;

  Future<void> loadConnections() async {
    _errorMessage = null;
    _connections = await _oauthService.getConnections();
    notifyListeners();
  }

  Future<void> connect(Provider provider) async {
    if (_activeProvider != null) return;

    _activeProvider = provider;
    _errorMessage = null;
    notifyListeners();

    try {
      await _oauthService.authorize(provider);
      await _oauthService.fetchUserProfile(provider);
      await loadConnections();
    } catch (error, stackTrace) {
      _errorMessage = 'Failed to connect grocery provider';
      _logger.e(_errorMessage, error: error, stackTrace: stackTrace);
    } finally {
      _activeProvider = null;
      notifyListeners();
    }
  }
}
