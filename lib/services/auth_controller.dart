import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';
import '../utils/auth_error_handler.dart';

class AuthController extends ChangeNotifier {
  final IAuthService _authService;
  final Logger _logger;
<<<<<<< Updated upstream
  final String Function(String) _translate;
=======
  final String Function(String) _tr;
>>>>>>> Stashed changes

  AuthController(
    this._authService,
    this._logger, {
    String Function(String)? translate,
<<<<<<< Updated upstream
  }) : _translate = translate ?? ((key) => key.tr());
=======
  }) : _tr = translate ?? ((key) => key.tr());
>>>>>>> Stashed changes

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _rememberMe = false;
  bool _agreedToTerms = false;

  bool get isLogin => _isLogin;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get rememberMe => _rememberMe;
  bool get agreedToTerms => _agreedToTerms;

  set isLogin(bool value) {
    _isLogin = value;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  set rememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  set agreedToTerms(bool value) {
    _agreedToTerms = value;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> authenticate({
    required String email,
    required String password,
  }) async {
    if (_isLoading) return;

    if (!_isLogin && !_agreedToTerms) {
<<<<<<< Updated upstream
      _errorMessage = _translate('auth.terms.required');
=======
      _errorMessage = _tr('auth.terms.required');
>>>>>>> Stashed changes
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      if (_isLogin) {
        await _authService.signIn(
          email: email.trim(),
          password: password.trim(),
          rememberMe: _rememberMe,
        );
      } else {
        await _authService.signUp(
          email: email.trim(),
          password: password.trim(),
        );
      }
    } catch (e) {
      _logger.e('Auth error: $e');
      _errorMessage = AuthErrorHandler.getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _logger.e('Google Sign-in error: $e');
      _errorMessage = AuthErrorHandler.getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithFacebook() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      await _authService.signInWithFacebook();
    } catch (e) {
      _logger.e('Facebook Sign-in error: $e');
      _errorMessage = AuthErrorHandler.getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> forgotPassword(String email) async {
    if (_isLoading) return;

    if (email.trim().isEmpty) {
<<<<<<< Updated upstream
      _errorMessage = _translate('auth.reset.email_prompt');
=======
      _errorMessage = _tr('auth.reset.email_prompt');
>>>>>>> Stashed changes
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email.trim());
<<<<<<< Updated upstream
      _successMessage = _translate('auth.reset.email_sent');
=======
      _successMessage = _tr('auth.reset.email_sent');
>>>>>>> Stashed changes
    } catch (e) {
      _logger.e('Forgot password error: $e');
      _errorMessage = AuthErrorHandler.getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
