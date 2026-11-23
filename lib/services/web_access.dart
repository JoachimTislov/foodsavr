import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebAccess extends ChangeNotifier {
  WebAccess(this._code, this._prefs) {
    _unlocked = _prefs.getString(preferenceKey) == _fingerprint;
  }

  static const preferenceKey = 'web_access_granted';
  final String _code;
  final SharedPreferencesWithCache _prefs;
  late final String _fingerprint = sha256
      .convert(utf8.encode(_code))
      .toString();
  late bool _unlocked;

  bool get isLocked => _code.isNotEmpty && !_unlocked;

  bool unlock(String code) {
    if (code.trim() != _code) return false;
    _unlocked = true;
    unawaited(_persist());
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    try {
      await _prefs.setString(preferenceKey, _fingerprint);
    } catch (_) {
      // Access stays granted for this visit if storage is unavailable.
    }
  }
}
