import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/adaptive_layout.dart';
import '../../constants/material3_config.dart';
import '../../controllers/app_zoom_controller.dart';
import '../../utils/app_theme.dart';
import '../../utils/platform_capabilities.dart';

/// Wraps the app root to provide app-wide zoom in/out and responsive desktop
/// theme adaptation.
///
/// Supports:
/// - Desktop keyboard shortcuts: `Ctrl`/`Meta` + `+`/`=` (zoom in), `-` (zoom
///   out), and `0` (reset).
/// - Desktop wheel zoom: `Ctrl`/`Meta` + mouse scroll wheel or trackpad pinch.
/// - Mobile/touch pinch zoom: two-finger pinch gesture without interfering
///   with single-finger scrolling.
class AppZoomWrapper extends StatefulWidget {
  /// How long the zoom level stays on screen after a change.
  static const indicatorDuration = Duration(seconds: 3);

  final Widget child;
  final AppZoomController? controller;

  const AppZoomWrapper({super.key, required this.child, this.controller});

  @override
  State<AppZoomWrapper> createState() => _AppZoomWrapperState();
}

class _AppZoomWrapperState extends State<AppZoomWrapper> {
  late AppZoomController _controller;
  late bool _ownsController;
  VoidCallback? _detachWebWheelGuard;

  Timer? _indicatorTimer;
  bool _showIndicator = false;

  (Brightness, WindowSize)? _themeKey;
  ThemeData? _adaptedTheme;

  final Map<int, Offset> _touches = <int, Offset>{};
  double? _pinchInitialDistance;
  double _pinchStartScale = AppZoomController.defaultScale;

  @override
  void initState() {
    super.initState();
    _initController(widget.controller);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _detachWebWheelGuard = PlatformCapabilities.attachWebCtrlWheelGuard();
  }

  @override
  void didUpdateWidget(covariant AppZoomWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _releaseController();
      _initController(widget.controller);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _themeKey = null;
  }

  void _initController(AppZoomController? external) {
    _ownsController = external == null;
    _controller = external ?? AppZoomController();
    _controller.addListener(_onScaleChanged);
    if (_ownsController) {
      unawaited(_controller.restore());
    }
  }

  void _releaseController() {
    _controller.removeListener(_onScaleChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _onScaleChanged() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(AppZoomWrapper.indicatorDuration, () {
      setState(() => _showIndicator = false);
    });
    setState(() => _showIndicator = true);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _detachWebWheelGuard?.call();
    _indicatorTimer?.cancel();
    _releaseController();
    super.dispose();
  }

  bool get _hasZoomModifier {
    final keyboard = HardwareKeyboard.instance;
    return (keyboard.isControlPressed || keyboard.isMetaPressed) &&
        !keyboard.isAltPressed;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (!_hasZoomModifier) {
      return false;
    }

    final key = event.logicalKey;
    final char = event.character;

    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd ||
        char == '+' ||
        char == '=') {
      unawaited(_controller.zoomIn());
      return true;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        char == '-') {
      unawaited(_controller.zoomOut());
      return true;
    }
    if (key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0 ||
        char == '0') {
      unawaited(_controller.reset());
      return true;
    }
    return false;
  }

  /// Claims zoom signals through the resolver. This listener sits above the
  /// app, so it wins over scrollables and Ctrl+wheel does not also scroll.
  void _handlePointerSignal(PointerSignalEvent signal) {
    if (signal is PointerScaleEvent ||
        (signal is PointerScrollEvent && _hasZoomModifier)) {
      GestureBinding.instance.pointerSignalResolver.register(
        signal,
        _applyZoomSignal,
      );
    }
  }

  void _applyZoomSignal(PointerSignalEvent signal) {
    if (signal is PointerScaleEvent) {
      // On web, Ctrl+wheel arrives as a scale event whose factor for a single
      // mouse notch spans the whole range, so one event moves one step at most.
      final delta = (_controller.scale * (signal.scale - 1))
          .clamp(-AppZoomController.step, AppZoomController.step)
          .toDouble();
      unawaited(_controller.setScale(_controller.scale + delta));
    } else if (signal is PointerScrollEvent) {
      if (signal.scrollDelta.dy < 0) {
        unawaited(_controller.zoomIn());
      } else if (signal.scrollDelta.dy > 0) {
        unawaited(_controller.zoomOut());
      }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = event.position;
    if (_touches.length == 2) {
      _pinchInitialDistance = _touchDistance();
      _pinchStartScale = _controller.scale;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.position;
    final initialDistance = _pinchInitialDistance;
    if (initialDistance == null || initialDistance <= 0) return;

    final gestureScale = _touchDistance() / initialDistance;
    if ((gestureScale - 1.0).abs() < 0.02) return;
    unawaited(
      _controller.setScale(_pinchStartScale * gestureScale, persist: false),
    );
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_touches.remove(event.pointer) == null) return;
    if (_pinchInitialDistance != null && _touches.length < 2) {
      _pinchInitialDistance = null;
      unawaited(_controller.persistCurrentScale());
    }
  }

  double _touchDistance() {
    if (_touches.length < 2) return 0;
    final points = _touches.values.take(2).toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  ThemeData _themeFor(BuildContext context, WindowSize windowSize) {
    final theme = Theme.of(context);
    if (windowSize.isCompact) return theme;
    final key = (theme.brightness, windowSize);
    if (key != _themeKey) {
      _themeKey = key;
      _adaptedTheme = AppTheme.themeFor(theme.brightness, windowSize);
    }
    return _adaptedTheme!;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    // The tree shape never changes, so the app below keeps its state.
    return Theme(
      data: _themeFor(context, WindowSize.fromWidth(mediaQuery.size.width)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaQuery(
            data: _controller.isDefault
                ? mediaQuery
                : mediaQuery.copyWith(
                    textScaler: _ZoomTextScaler(
                      mediaQuery.textScaler,
                      _controller.scale,
                    ),
                  ),
            child: widget.child,
          ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: _handlePointerSignal,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerEnd,
              onPointerCancel: _handlePointerEnd,
            ),
          ),
          if (_showIndicator && !_controller.isDefault)
            Positioned(
              right: Material3Config.spacing16,
              bottom: Material3Config.spacing16,
              child: SafeArea(
                top: false,
                left: false,
                child: _ZoomIndicatorPill(
                  zoomPercent: _controller.zoomPercent,
                  onReset: () => unawaited(_controller.reset()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Applies the app zoom on top of the platform's accessibility text scaling
/// instead of replacing or capping it.
@immutable
class _ZoomTextScaler extends TextScaler {
  final TextScaler base;
  final double zoom;

  const _ZoomTextScaler(this.base, this.zoom);

  @override
  double scale(double fontSize) => base.scale(fontSize) * zoom;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * zoom;

  @override
  bool operator ==(Object other) =>
      other is _ZoomTextScaler && other.base == base && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(base, zoom);
}

class _ZoomIndicatorPill extends StatelessWidget {
  final int zoomPercent;
  final VoidCallback onReset;

  const _ZoomIndicatorPill({required this.zoomPercent, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = '$zoomPercent%';

    return Semantics(
      container: true,
      button: true,
      liveRegion: true,
      child: Material(
        color: colorScheme.inverseSurface,
        elevation: Material3Config.elevationLevel2,
        borderRadius: BorderRadius.circular(Material3Config.radiusDesktopLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onReset,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Material3Config.spacing12,
              vertical: Material3Config.spacing8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Material3Config.spacing6),
                Icon(
                  Icons.refresh,
                  size: 14,
                  color: colorScheme.onInverseSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
