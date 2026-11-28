import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pwa_install/pwa_bridge.dart';

export '../utils/pwa_install/pwa_bridge_types.dart';

/// Coordinates Progressive Web App installation state, native browser install
/// prompts (`beforeinstallprompt`), platform-specific manual install guidance,
/// and persistent banner dismissal.
class PwaInstallController extends ChangeNotifier {
  static const kDismissedKey = 'pwa_install_banner_dismissed';

  PwaInstallController({
    PwaBridge? bridge,
    SharedPreferencesWithCache? prefs,
    TargetPlatform? os,
  }) : _bridge = bridge ?? createPlatformPwaBridge(),
       _os = os,
       _prefs = prefs,
       _isBannerDismissed = _readDismissed(prefs) {
    _subscription = _bridge.onStateChanged.listen((_) {
      notifyListeners();
    });
  }

  /// Creates an inert controller for non-web environments or isolated widget tests.
  factory PwaInstallController.disabled() =>
      PwaInstallController(bridge: const StubPwaBridge());

  final PwaBridge _bridge;

  /// The operating system; null reads `defaultTargetPlatform`, which Flutter
  /// derives from the browser on web.
  final TargetPlatform? _os;
  final SharedPreferencesWithCache? _prefs;
  StreamSubscription<void>? _subscription;
  bool _isBannerDismissed;
  bool _isPrompting = false;

  static bool _readDismissed(SharedPreferencesWithCache? prefs) {
    if (prefs == null) return false;
    try {
      return prefs.getBool(kDismissedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether the app is running in a web browser that supports PWA installation.
  bool get isSupported => _bridge.isSupported;

  /// Whether the app is currently running as an installed standalone PWA.
  bool get isInstalled => _bridge.isInstalled;

  /// Whether the browser has a native install prompt ready to trigger in one tap.
  bool get canPromptNatively => _bridge.canPrompt;

  /// Platform hint for manual installation steps when [canPromptNatively] is false.
  PwaPlatformHint get platformHint => resolvePwaPlatformHint(
    os: _os ?? defaultTargetPlatform,
    browserHint: _bridge.platformHint,
  );

  /// Whether the user has dismissed the in-app install banner.
  bool get isBannerDismissed => _isBannerDismissed;

  /// Whether a native install prompt is currently active.
  bool get isPrompting => _isPrompting;

  /// Whether the app can be installed (supported web runtime and not yet installed).
  bool get canInstall => isSupported && !isInstalled;

  /// Whether the inline install banner should be shown.
  ///
  /// Always hides once the app is installed (fulfilled intent) or dismissed.
  bool get shouldShowBanner => canInstall && !_isBannerDismissed;

  /// Triggers the browser's native install prompt if available.
  ///
  /// Returns [PwaPromptResult.unavailable] when the browser requires manual
  /// installation steps (such as iOS Safari or Firefox), allowing the UI to
  /// present the tailored sheet.
  Future<PwaPromptResult> requestInstall() async {
    if (!canInstall || _isPrompting || !canPromptNatively) {
      return PwaPromptResult.unavailable;
    }
    _isPrompting = true;
    notifyListeners();
    try {
      return await _bridge.promptInstall();
    } finally {
      _isPrompting = false;
      notifyListeners();
    }
  }

  /// Dismisses the inline install banner and persists the choice.
  Future<void> dismissBanner() async {
    if (_isBannerDismissed) return;
    _isBannerDismissed = true;
    notifyListeners();
    try {
      await _prefs?.setBool(kDismissedKey, true);
    } catch (_) {}
  }

  /// Resets the banner dismissal state.
  Future<void> resetBannerDismissal() async {
    if (!_isBannerDismissed) return;
    _isBannerDismissed = false;
    notifyListeners();
    try {
      await _prefs?.setBool(kDismissedKey, false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bridge.dispose();
    super.dispose();
  }
}
