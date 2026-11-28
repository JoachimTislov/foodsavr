import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Raw capability signals returned by the platform implementation.
typedef RawPlatformSignals = ({
  bool? userAgentMobile,
  bool hasCoarsePointer,
  bool hasFinePointer,
  int maxTouchPoints,
  bool isWeb,
});

extension type _NavigatorUAData._(JSObject _) implements JSObject {
  external JSBoolean? get mobile;
}

extension _NavigatorUADataExt on web.Navigator {
  @JS('userAgentData')
  external _NavigatorUAData? get userAgentData;
}

/// Reads browser capability signals via `navigator.userAgentData`,
/// `window.matchMedia`, and `navigator.maxTouchPoints`.
RawPlatformSignals readRawPlatformSignals() {
  bool? userAgentMobile;
  try {
    userAgentMobile = web.window.navigator.userAgentData?.mobile?.toDart;
  } catch (_) {
    userAgentMobile = null;
  }

  var hasCoarsePointer = false;
  try {
    hasCoarsePointer = web.window.matchMedia('(pointer: coarse)').matches;
  } catch (_) {}

  var hasFinePointer = !hasCoarsePointer;
  try {
    hasFinePointer = web.window.matchMedia('(any-pointer: fine)').matches;
  } catch (_) {}

  var maxTouchPoints = 0;
  try {
    maxTouchPoints = web.window.navigator.maxTouchPoints;
  } catch (_) {}

  return (
    userAgentMobile: userAgentMobile,
    hasCoarsePointer: hasCoarsePointer,
    hasFinePointer: hasFinePointer,
    maxTouchPoints: maxTouchPoints,
    isWeb: true,
  );
}

/// Prevents the browser from applying its own erratic page zoom on Ctrl/Meta +
/// mouse wheel so Flutter's [AppZoomWrapper] handles zoom smoothly instead.
VoidCallback? attachWebCtrlWheelGuard() {
  try {
    final listener = ((web.WheelEvent event) {
      if (event.ctrlKey || event.metaKey) {
        event.preventDefault();
      }
    }).toJS;
    web.window.addEventListener(
      'wheel',
      listener,
      web.AddEventListenerOptions(passive: false),
    );
    return () {
      try {
        web.window.removeEventListener('wheel', listener);
      } catch (_) {}
    };
  } catch (_) {
    return null;
  }
}
