import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../interfaces/is_grocery_store_oauth.dart';
import '../models/m_grocery_store.dart';

@injectable
class GroceryStoreAuthController extends ChangeNotifier {
  GroceryStoreAuthController(this._authService, this._logger);

  final IGroceryStoreAuthService _authService;
  final Logger _logger;

  WebViewController get webViewController => _authService.webViewController;

  List<GroceryStoreConnection> _connections = const [];
  GroceryStoreProvider? _activeProvider;
  String? _errorMessage;

  List<GroceryStoreConnection> get connections => _connections;
  GroceryStoreProvider? get activeProvider => _activeProvider;
  String? get errorMessage => _errorMessage;

  Future<void> loadConnections() async {
    _errorMessage = null;
    _connections = await _authService.getConnections();
    notifyListeners();
  }

  Future<void> connect(GroceryStoreProvider provider) async {
    if (_activeProvider != null) {
      return;
    }

    _activeProvider = provider;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.authorize(provider);
      await _authService.fetchUserProfile(provider);
      _connections = await _authService.getConnections();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to connect grocery provider',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = _formatError(error);
    } finally {
      _activeProvider = null;
      notifyListeners();
    }
  }

  Future<void> disconnect(GroceryStoreProvider provider) async {
    if (_activeProvider != null) {
      return;
    }

    _activeProvider = provider;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.disconnect(provider);
      _connections = await _authService.getConnections();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to disconnect grocery provider',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = _formatError(error);
    } finally {
      _activeProvider = null;
      notifyListeners();
    }
  }

  String _formatError(Object error) {
    final message = error.toString();
    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Unsupported operation: ', '');
  }
}
