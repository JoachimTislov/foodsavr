import 'dart:js_interop';

extension type _CrashlyticsCollectorJs._(JSObject _) implements JSObject {
  external void recordError(
    String errorType,
    String message,
    String stack,
    bool fatal,
  );
}

extension type _WindowMonitoringJs._(JSObject _) implements JSObject {
  external _CrashlyticsCollectorJs? get foodsavrCrashlytics;
}

@JS('window')
external _WindowMonitoringJs get _window;

/// Forwards an error to `window.foodsavrCrashlytics` when `@firebase/crashlytics`
/// is mounted on Blaze web deployments.
bool reportToCrashlyticsJs({
  required String errorType,
  required String message,
  required String stack,
  required bool fatal,
}) {
  try {
    final collector = _window.foodsavrCrashlytics;
    if (collector == null) return false;
    collector.recordError(errorType, message, stack, fatal);
    return true;
  } catch (_) {
    return false;
  }
}
