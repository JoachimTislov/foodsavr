import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';
import '../utils/auth_error_handler.dart';

typedef Translator = String Function(String);

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
    _socialSignInAttempt++;
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
  bool _isSocialSignInLoading = false;
  int _socialSignInAttempt = 0;
  String? _errorMessage;
  String? _successMessage;
  bool _rememberMe = false;

  bool get isLogin => _isLogin;
  bool get isLoading => _isLoading;
  bool get isSocialSignInLoading => _isSocialSignInLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get rememberMe => _rememberMe;

  set isLogin(bool value) {
    _isLogin = value;
    _clearMessages();
  }

  set rememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Stops waiting on an in-flight social sign-in popup so the user is never
  /// stuck behind a spinner. Any late completion from the abandoned attempt is
  /// ignored.
  void cancelSocialSignIn() {
    if (!_isSocialSignInLoading) return;
    _socialSignInAttempt++;
    _isSocialSignInLoading = false;
    _setLoading(false);
  }

  Future<void> authenticate({
    required String email,
    required String password,
  }) async {
    if (_isLoading) return;

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

  Future<bool> signInWithGoogle() =>
      _signInWithProvider(SignInProvider.google, _authService.signInWithGoogle);

  Future<bool> signInWithFacebook() => _signInWithProvider(
    SignInProvider.facebook,
    _authService.signInWithFacebook,
  );

  Future<bool> signInAsGuest() =>
      _signInWithProvider(SignInProvider.guest, _authService.signInAsGuest);

  /// Returns whether sign-in succeeded. A failure sets [errorMessage], except
  /// when the user cancelled.
  Future<bool> _signInWithProvider(
    SignInProvider provider,
    Future<void> Function() signIn,
  ) async {
    if (_isLoading) return false;
    final attempt = ++_socialSignInAttempt;
    _isSocialSignInLoading = provider != SignInProvider.guest;
    _setLoading(true);
    try {
      await signIn();
      return attempt == _socialSignInAttempt;
    } catch (error) {
      if (attempt != _socialSignInAttempt) return false;
      final message = AuthErrorHandler.getProviderErrorMessage(
        provider,
        error,
        _tr,
      );
      if (message != null) {
        // SDK error messages can contain OAuth tokens, so only log the code.
        final code = error is FirebaseAuthException
            ? error.code
            : error.runtimeType.toString();
        _logger.e('${provider.name} sign-in error: $code');
        _errorMessage = message;
      }
      return false;
    } finally {
      if (attempt == _socialSignInAttempt) {
        _isSocialSignInLoading = false;
        _setLoading(false);
      }
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

  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    if (_isLoading) return;

    if (newEmail.trim().isEmpty) {
      _successMessage = null;
      _errorMessage = _tr('profile.new_email_prompt');
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      await _authService.changeEmail(
        currentPassword: currentPassword,
        newEmail: newEmail.trim(),
      );
      _successMessage = _tr('profile.change_email_sent');
    } catch (e) {
      _logger.e('Change email error: $e');
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
      _errorMessage = _tr('profile.error_sign_out');
    } finally {
      _setLoading(false);
    }
  }

  String? _deletionReauthenticationUid;

  bool get deletionRequiresReauthentication =>
      _deletionReauthenticationUid != null &&
      _deletionReauthenticationUid == _user?.uid;

  // Reads the current user first: linking a password replaces it without an
  // auth state event.
  bool get deletionRequiresPassword =>
      (_authService.currentUser ?? _user)?.providerData.any(
        (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  Future<bool> deleteAccount({
    bool reauthenticate = false,
    String? password,
  }) async {
    final uid = _user?.uid;
    if (_isLoading || uid == null || _authService.getUserId() != uid) {
      return false;
    }
    _setLoading(true);
    try {
      await _authService.deleteAccount(
        reauthenticate: reauthenticate,
        password: password,
      );
      _deletionReauthenticationUid = null;
      return true;
    } catch (error, stackTrace) {
      if (error is FirebaseAuthException &&
          error.code == 'requires-recent-login') {
        _deletionReauthenticationUid = uid;
        return false;
      }
      _logger.e('Delete account failed', error: error, stackTrace: stackTrace);
      _errorMessage = _tr('profile.error_delete_account');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
