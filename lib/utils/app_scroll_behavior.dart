import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets mouse, trackpad, and stylus drag scrollables (and pull to refresh) the
/// way touch does; the wheel and visible scrollbars come from the platform.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
