import 'package:flutter/foundation.dart';

/// Seam for reporting uncaught runtime and Flutter framework errors.
///
/// Implementations adapt per deployment level (Spark Firestore, Blaze
/// Crashlytics web JS interop, or external collectors) and stay disabled in
/// emulator/development builds.
abstract class IErrorReporter {
  String get name;
  bool get isEnabled;

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const {},
  });

  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });
}
