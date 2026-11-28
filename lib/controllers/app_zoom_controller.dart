import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app-wide text/UI zoom scaling with bounded range and local
/// persistence via [SharedPreferences].
class AppZoomController extends ChangeNotifier {
  static const String kZoomScaleKey = 'app_zoom_scale';
  static const double minScale = 0.8;
  static const double maxScale = 1.6;
  static const double defaultScale = 1.0;
  static const double step = 0.1;

  AppZoomController({
    SharedPreferences? preferences,
    double initialScale = defaultScale,
  }) : _preferences = preferences,
       _scale = normalizeScale(initialScale);

  SharedPreferences? _preferences;
  Future<void>? _restoring;
  double _scale;

  /// Current bounded zoom scale (`0.8` to `1.6`).
  double get scale => _scale;

  /// Zoom scale rounded to an integer percentage (e.g. `100`, `110`, `90`).
  int get zoomPercent => (_scale * 100).round();

  bool get isDefault => (_scale - defaultScale).abs() < 0.001;

  /// Clamps [value] to `[minScale, maxScale]` and rounds to three decimals:
  /// no floating-point drift across steps, and small trackpad deltas still
  /// accumulate.
  static double normalizeScale(double value) {
    final clamped = value.clamp(minScale, maxScale).toDouble();
    return (clamped * 1000).round() / 1000;
  }

  /// Restores any previously persisted zoom scale from [SharedPreferences].
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final saved = _preferences?.getDouble(kZoomScaleKey);
      if (saved != null) {
        final normalized = normalizeScale(saved);
        if ((normalized - _scale).abs() >= 0.001) {
          _scale = normalized;
          notifyListeners();
        }
      }
    } catch (_) {
      // Ignore storage failures (e.g. restricted web storage or headless tests).
    }
  }

  /// Increases zoom by one [step], bounded by [maxScale].
  Future<void> zoomIn() => setScale(_scale + step);

  /// Decreases zoom by one [step], bounded by [minScale].
  Future<void> zoomOut() => setScale(_scale - step);

  /// Resets zoom back to [defaultScale] (`1.0`).
  Future<void> reset() => setScale(defaultScale);

  /// Sets zoom to [value], clamping to `[minScale, maxScale]` and persisting
  /// when [persist] is true.
  Future<void> setScale(double value, {bool persist = true}) async {
    final normalized = normalizeScale(value);
    if ((normalized - _scale).abs() < 0.001) return;
    _scale = normalized;
    notifyListeners();
    if (persist) {
      await persistCurrentScale();
    }
  }

  /// Persists the current scale to [SharedPreferences] when available.
  Future<void> persistCurrentScale() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      await _preferences?.setDouble(kZoomScaleKey, _scale);
    } catch (_) {
      // Ignore storage failures so zooming remains responsive offline/in tests.
    }
  }
}
