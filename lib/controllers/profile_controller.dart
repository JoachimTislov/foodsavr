import 'package:flutter/material.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

@injectable
class ProfileController extends ChangeNotifier {
  final IAuthService _authService;
  final Logger _logger;

  ProfileController(this._authService, this._logger);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_isLoading) return; // Prevent multiple simultaneous calls
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signOut();
    } catch (e) {
      _logger.e('Sign out error: $e');
      _setError('Failed to sign out. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  // Placeholder for deleteAccount.
  Future<void> deleteAccount() async {
    if (_isLoading) return; // Prevent multiple simultaneous calls
    _setLoading(true);
    _setError(null);
    await Future.delayed(const Duration(seconds: 1));
    _setLoading(false);
    try {
      // await _authService.deleteAccount();
    } catch (e) {
      _logger.e('Delete account error: $e');
      _setError('Failed to delete account. Please try again.');
    } finally {
      _setLoading(false);
    }
  }
}
