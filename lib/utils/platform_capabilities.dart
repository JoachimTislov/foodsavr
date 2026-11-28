import 'package:flutter/widgets.dart';

import '../constants/adaptive_layout.dart';
import 'platform_capabilities_stub.dart'
    if (dart.library.js_interop) 'platform_capabilities_web.dart'
    as platform_impl;

/// High-level device form factor combining pointer/touch capabilities with
/// viewport width.
enum DeviceFormFactor { mobile, tablet, desktop }

/// Raw hardware and browser pointer/touch capability signals.
class PlatformCapabilitySignals {
  /// Value of `navigator.userAgentData?.mobile` on web when supported,
  /// `null` when unavailable.
  final bool? userAgentMobile;

  /// Whether the primary pointer is coarse (e.g. finger touch).
  final bool hasCoarsePointer;

  /// Whether any fine pointer (e.g. mouse or trackpad) is available.
  final bool hasFinePointer;

  /// Maximum simultaneous touch contact points (`navigator.maxTouchPoints`).
  final int maxTouchPoints;

  /// Whether the signals came from a web browser runtime.
  final bool isWeb;

  const PlatformCapabilitySignals({
    this.userAgentMobile,
    required this.hasCoarsePointer,
    required this.hasFinePointer,
    required this.maxTouchPoints,
    required this.isWeb,
  });

  factory PlatformCapabilitySignals.current() {
    final raw = platform_impl.readRawPlatformSignals();
    return PlatformCapabilitySignals(
      userAgentMobile: raw.userAgentMobile,
      hasCoarsePointer: raw.hasCoarsePointer,
      hasFinePointer: raw.hasFinePointer,
      maxTouchPoints: raw.maxTouchPoints,
      isWeb: raw.isWeb,
    );
  }
}

/// Combines browser/platform pointer signals with the current viewport width
/// to classify touch vs pointer desktop layouts accurately.
class PlatformCapabilities {
  final PlatformCapabilitySignals signals;
  final double viewportWidth;

  const PlatformCapabilities({
    required this.signals,
    required this.viewportWidth,
  });

  /// Optional test override to simulate web/mobile/desktop capability signals
  /// in widget tests.
  @visibleForTesting
  static PlatformCapabilitySignals? testSignalsOverride;

  /// Resolves capabilities for the current [BuildContext] viewport width.
  static PlatformCapabilities of(
    BuildContext context, {
    PlatformCapabilitySignals? signalsOverride,
  }) => resolve(
    viewportWidth: MediaQuery.sizeOf(context).width,
    signals: signalsOverride,
  );

  /// Pure resolver combining [viewportWidth] and [signals].
  static PlatformCapabilities resolve({
    required double viewportWidth,
    PlatformCapabilitySignals? signals,
  }) => PlatformCapabilities(
    signals:
        signals ?? testSignalsOverride ?? PlatformCapabilitySignals.current(),
    viewportWidth: viewportWidth,
  );

  /// Attaches a non-passive `wheel` guard on web to prevent browser Ctrl+wheel
  /// zoom hijacking. Returns a detach callback or `null` on non-web platforms.
  static VoidCallback? attachWebCtrlWheelGuard() =>
      platform_impl.attachWebCtrlWheelGuard();

  WindowSize get windowSize => WindowSize.fromWidth(viewportWidth);

  /// True when the primary interaction model is touch rather than mouse/trackpad.
  bool get isTouchPrimary {
    if (signals.userAgentMobile == true) return true;
    if (signals.hasCoarsePointer && !signals.hasFinePointer) return true;
    if (signals.hasCoarsePointer &&
        viewportWidth < AdaptiveLayout.expandedBreakpoint) {
      return true;
    }
    if (signals.maxTouchPoints > 0 &&
        viewportWidth < AdaptiveLayout.mediumBreakpoint) {
      return true;
    }
    return false;
  }

  /// True when running on a wide pointer-driven desktop layout.
  bool get isDesktopPointer =>
      !isTouchPrimary && viewportWidth >= AdaptiveLayout.expandedBreakpoint;

  /// Effective form factor combining signals with viewport width.
  DeviceFormFactor get formFactor {
    if (viewportWidth < AdaptiveLayout.mediumBreakpoint) {
      return DeviceFormFactor.mobile;
    }
    if (signals.userAgentMobile == true &&
        viewportWidth < AdaptiveLayout.expandedBreakpoint) {
      return DeviceFormFactor.mobile;
    }
    if (viewportWidth < AdaptiveLayout.expandedBreakpoint) {
      return DeviceFormFactor.tablet;
    }
    if (signals.hasCoarsePointer &&
        !signals.hasFinePointer &&
        signals.maxTouchPoints > 0 &&
        viewportWidth < AdaptiveLayout.extendedRailBreakpoint) {
      return DeviceFormFactor.tablet;
    }
    return DeviceFormFactor.desktop;
  }

  /// Whether desktop affordances (denser empty states) should be active.
  bool get preferDesktopAffordances =>
      formFactor == DeviceFormFactor.desktop || isDesktopPointer;
}
