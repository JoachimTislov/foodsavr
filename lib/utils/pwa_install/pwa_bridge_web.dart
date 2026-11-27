import 'dart:async';
import 'dart:js_interop';

import 'pwa_bridge_types.dart';

extension type _FoodsavrPwaJs._(JSObject _) implements JSObject {
  external bool isInstalled();
  external bool canPrompt();
  external String platformHint();
  external JSPromise<JSString> promptInstall();
}

extension type _WindowJs._(JSObject _) implements JSObject {
  external _FoodsavrPwaJs? get foodsavrPwa;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

@JS('window')
external _WindowJs get _window;

/// Web implementation of [PwaBridge] backed by `window.foodsavrPwa` in `web/index.html`.
class WebPwaBridge implements PwaBridge {
  WebPwaBridge() {
    _jsListener = ((JSAny? _) {
      if (!_stateController.isClosed) {
        _stateController.add(null);
      }
    }).toJS;
    try {
      _window.addEventListener(_eventName, _jsListener);
    } catch (_) {}
  }

  static const _eventName = 'foodsavr:pwa-state';

  final StreamController<void> _stateController =
      StreamController<void>.broadcast();
  late final JSFunction _jsListener;

  @override
  bool get isSupported => true;

  @override
  bool get isInstalled {
    try {
      return _window.foodsavrPwa?.isInstalled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get canPrompt {
    try {
      return _window.foodsavrPwa?.canPrompt() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  PwaPlatformHint get platformHint {
    try {
      final raw = _window.foodsavrPwa?.platformHint() ?? 'standard';
      return parsePwaPlatformHint(raw);
    } catch (_) {
      return PwaPlatformHint.standard;
    }
  }

  @override
  Stream<void> get onStateChanged => _stateController.stream;

  @override
  Future<PwaPromptResult> promptInstall() async {
    try {
      final pwa = _window.foodsavrPwa;
      if (pwa == null) return PwaPromptResult.unavailable;
      final jsOutcome = await pwa.promptInstall().toDart;
      return switch (jsOutcome.toDart) {
        'accepted' => PwaPromptResult.accepted,
        'dismissed' => PwaPromptResult.dismissed,
        _ => PwaPromptResult.unavailable,
      };
    } catch (_) {
      return PwaPromptResult.unavailable;
    }
  }

  @override
  void dispose() {
    try {
      _window.removeEventListener(_eventName, _jsListener);
    } catch (_) {}
    _stateController.close();
  }
}

PwaBridge createPlatformPwaBridge() => WebPwaBridge();
