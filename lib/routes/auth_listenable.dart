import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';

/// A [Listenable] that notifies when the auth state changes.
class AuthStreamListenable extends ChangeNotifier {
  final IAuthService _authService;
  late final StreamSubscription<User?> _subscription;
  Timer? _fallbackTimer;
  bool _isDisposed = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  AuthStreamListenable(this._authService) {
    _subscription = _authService.authStateChanges.listen((_) {
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      _isInitialized = true;
      if (!_isDisposed) {
        notifyListeners();
      }
    });

    // Safety fallback for initialization
    _fallbackTimer = Timer(const Duration(seconds: 1), () {
      if (!_isInitialized && !_isDisposed) {
        _isInitialized = true;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fallbackTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
