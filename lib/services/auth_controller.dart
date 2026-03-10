import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';
import '../utils/auth_error_handler.dart';
import '../services/collection_service.dart';
import '../models/collection_model.dart';
import '../utils/collection_types.dart';

typedef Translator = String Function(String);

@injectable
class AuthController extends ChangeNotifier {
  final IAuthService _authService;
  final CollectionService _collectionService;
  final Logger _logger;
  final Translator _tr;

  AuthController(
    this._authService,
    this._collectionService,
    this._logger, {
    @factoryParam Translator? translate,
  }) : _tr = translate ?? ((key) => key);

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

  Future<void> _initializeDefaultCollections(String userId) async {
    try {
      final existing = await _collectionService.getCollectionsForUser(userId);
      if (existing.isNotEmpty) {
        _logger.i(
          'Collections already exist for user $userId, skipping initialization.',
        );
        return;
      }

      await _collectionService.addCollection(
        Collection(
          id: '',
          name: _tr('dashboard.myInventory'),
          userId: userId,
          type: CollectionType.inventory,
          productIds: [],
        ),
      );
      await _collectionService.addCollection(
        Collection(
          id: '',
          name: _tr('dashboard.shoppingList'),
          userId: userId,
          type: CollectionType.shoppingList,
          productIds: [],
        ),
      );
    } catch (e) {
      _logger.e('Failed to initialize default collections: $e');
    }
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
      final UserCredential credential;
      if (_isLogin) {
        credential = await _authService.signIn(
          email: email.trim(),
          password: password.trim(),
          rememberMe: _rememberMe,
        );
      } else {
        credential = await _authService.signUp(
          email: email.trim(),
          password: password.trim(),
        );
      }
      if (credential.user != null) {
        await _initializeDefaultCollections(credential.user!.uid);
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
      final credential = await _authService.signInWithGoogle();
      if (credential.user != null) {
        await _initializeDefaultCollections(credential.user!.uid);
      }
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
      final credential = await _authService.signInWithFacebook();
      if (credential.user != null) {
        await _initializeDefaultCollections(credential.user!.uid);
      }
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
      final credential = await _authService.signInAsGuest();
      if (credential.user != null) {
        await _initializeDefaultCollections(credential.user!.uid);
      }
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
}
