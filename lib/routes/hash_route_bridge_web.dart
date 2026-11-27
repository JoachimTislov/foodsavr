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
    final target = PublicRoutes.resolveHashRoute(Uri.base);
    if (target != null) {
      onTarget(target);
    }
  }).toJS;
  _activeListener = listener;
  web.window.addEventListener('hashchange', listener);
}
