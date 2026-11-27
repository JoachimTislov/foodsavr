import 'dart:js_interop';

@JS('window.lettmatDismissStartupLoader')
external JSFunction? get _dismissStartupLoader;

/// Fades out and removes the pre-boot HTML startup loader once Flutter renders
/// its first frame.
void dismissStartupLoader() {
  try {
    _dismissStartupLoader?.callAsFunction();
  } catch (_) {}
}
