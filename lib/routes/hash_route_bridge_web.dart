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
  final listener = ((web.HashChangeEvent event) {
    // Prefer event.newURL over window.location.href: Flutter Web's popstate
    // listener can run before hashchange and strip the # fragment via
    // history.replaceState under PathUrlStrategy.
    final rawUrl = event.newURL.isNotEmpty
        ? event.newURL
        : web.window.location.href;
    final currentUri = Uri.tryParse(rawUrl) ?? Uri.base;
    final target = PublicRoutes.resolveHashRoute(currentUri);
    if (target != null) {
      // Defer past any synchronous popstate handling so GoRouter does not
      // immediately overwrite the new modal route.
      Timer.run(() => onTarget(target));
    }
  }).toJS;
  _activeListener = listener;
  web.window.addEventListener('hashchange', listener);
}
