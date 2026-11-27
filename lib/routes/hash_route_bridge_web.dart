import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../constants/public_routes.dart';

JSFunction? _activeListener;

/// Listens to browser `hashchange` events so `#`-fragment links such as
/// `/#/legal/terms`, `/#/privacy`, and `/#/account/delete` work even when the
/// app uses path URL strategy and is already loaded.
void bindHashRouteListener(void Function(String targetPath) onTarget) {
  if (_activeListener != null) {
    web.window.removeEventListener('hashchange', _activeListener);
  }
  final listener = ((web.Event _) {
    final currentUri = Uri.tryParse(web.window.location.href) ?? Uri.base;
    final target = PublicRoutes.resolveHashRoute(currentUri);
    if (target != null) {
      // Defer past the browser's synchronous popstate notification so Flutter
      // Web's BrowserPlatformLocation does not overwrite the new route.
      Timer.run(() => onTarget(target));
    }
  }).toJS;
  _activeListener = listener;
  web.window.addEventListener('hashchange', listener);
}
