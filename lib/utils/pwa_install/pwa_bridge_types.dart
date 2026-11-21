/// Platform hint used to display tailored manual PWA installation steps when
/// the browser does not expose a native `beforeinstallprompt` dialog.
enum PwaPlatformHint {
  /// Running on a non-web platform where PWA installation is not applicable.
  unsupported,

  /// Standard desktop/mobile browser (Chrome, Edge, Brave, Firefox, etc.).
  standard,

  /// iOS or iPadOS browser where installation uses Share -> Add to Home Screen.
  ios,

  /// macOS Safari where installation uses File/Share -> Add to Dock.
  macosSafari,
}

/// Outcome of invoking the browser's native PWA installation prompt.
enum PwaPromptResult {
  /// User accepted the native install prompt.
  accepted,

  /// User dismissed or cancelled the native install prompt.
  dismissed,

  /// Native install prompt was not available; caller should show manual guide.
  unavailable,
}

/// Platform abstraction over browser PWA installation capabilities.
abstract class PwaBridge {
  /// Whether the current runtime is a web browser supporting PWA installation.
  bool get isSupported;

  /// Whether the app is currently running in installed standalone mode.
  bool get isInstalled;

  /// Whether a deferred `beforeinstallprompt` event is ready to be triggered.
  bool get canPrompt;

  /// Platform hint for manual installation instructions.
  PwaPlatformHint get platformHint;

  /// Emits whenever [isInstalled] or [canPrompt] changes.
  Stream<void> get onStateChanged;

  /// Triggers the browser's native install prompt if available.
  Future<PwaPromptResult> promptInstall();

  /// Releases any underlying platform listeners.
  void dispose();
}

/// No-op [PwaBridge] used on non-web platforms and in default unit tests.
class StubPwaBridge implements PwaBridge {
  const StubPwaBridge();

  @override
  bool get isSupported => false;

  @override
  bool get isInstalled => false;

  @override
  bool get canPrompt => false;

  @override
  PwaPlatformHint get platformHint => PwaPlatformHint.unsupported;

  @override
  Stream<void> get onStateChanged => const Stream.empty();

  @override
  Future<PwaPromptResult> promptInstall() async => PwaPromptResult.unavailable;

  @override
  void dispose() {}
}
