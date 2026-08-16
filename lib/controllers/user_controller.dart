import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';
import '../utils/auth_error_handler.dart';

typedef Translator = String Function(String);

// TODO: Remove translate arg in constructor and use context-based translation in tests instead. read easy_localization docs to find the best approach

@injectable
class UserController extends ChangeNotifier {
  final IAuthService _authService;
  final Logger _logger;
  final Translator _tr;
  late final StreamSubscription _authSubscription;
  bool _isInitialized = false;

  UserController(
    this._authService,
    this._logger, {
    @factoryParam Translator? translate,
  }) : _tr = translate ?? ((key) => tr(key)) {
    _user = _authService.currentUser;
    _authSubscription = _authService.authStateChanges.listen((user) {
      _user = user;
      if (!_isInitialized) {
        _isInitialized = true;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  User? _user;
  User? get user => _user;
  bool get isInitialized => _isInitialized;

  bool get isAnonymous => _user?.isAnonymous ?? true;

  String get displayName {
    if (isAnonymous) {
      return _tr('settings.guest_user');
    }
    return _user?.displayName ?? _user?.email?.split('@').first ?? '';
  }

  String? get email => isAnonymous ? null : _user?.email;
  String? get photoUrl => isAnonymous ? null : _user?.photoURL;

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
    _clearMessages();
  }

  set rememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  set agreedToTerms(bool value) {
    _agreedToTerms = value;
    notifyListeners();
  }

  void _clearMessages() {
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
      _errorMessage = _tr('auth.terms.required');
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

  Future<void> signInAsGuest() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      await _authService.signInAsGuest();
    } catch (e) {
      _logger.e('Guest sign-in error: $e');
      _errorMessage = AuthErrorHandler.getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> forgotPassword(String email) async {
    if (_isLoading) return;

    if (email.trim().isEmpty) {
      _errorMessage = _tr('auth.reset.email_prompt');
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email.trim());
      _successMessage = _tr('auth.reset.email_sent');
    } catch (e) {
      _logger.e('Forgot password error: $e');
      _errorMessage = AuthErrorHandler.getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) {
      _errorMessage = null;
      _successMessage = null;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      await _authService.signOut();
    } catch (e) {
      _logger.e('Sign out error: $e');
      _errorMessage = 'Failed to sign out. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  // Placeholder for deleteAccount.
  Future<void> deleteAccount() async {
    if (_isLoading) return;
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    try {
      // await _authService.deleteAccount();
    } catch (e) {
      _logger.e('Delete account error: $e');
      _errorMessage = 'Failed to delete account. Please try again.';
    } finally {
      _setLoading(false);
    }
  }
}
