import 'package:flutter/foundation.dart';

/// Raw capability signals returned by the platform implementation.
typedef RawPlatformSignals = ({
  bool? userAgentMobile,
  bool hasCoarsePointer,
  bool hasFinePointer,
  int maxTouchPoints,
  bool isWeb,
});

/// Native fallback when not running on web.
RawPlatformSignals readRawPlatformSignals() {
  final isMobilePlatform =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  return (
    userAgentMobile: null,
    hasCoarsePointer: isMobilePlatform,
    hasFinePointer: !isMobilePlatform,
    maxTouchPoints: isMobilePlatform ? 5 : 0,
    isWeb: false,
  );
}

/// No-op on non-web platforms where the browser does not hijack Ctrl+wheel zoom.
VoidCallback? attachWebCtrlWheelGuard() => null;
