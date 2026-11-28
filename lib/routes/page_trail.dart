import 'dart:async';

import 'package:flutter/material.dart';

/// Tracks the pages pushed imperatively on one shell branch navigator, such as
/// a collection or product detail, so the breadcrumbs can name and pop them.
/// Only routes pushed with [PageTrail.push] (a named [PageRoute] that is not a
/// GoRouter page) are tracked.
class PageTrail extends NavigatorObserver with ChangeNotifier {
  /// One trail per shell branch, in branch order.
  static final List<PageTrail> branches = List.unmodifiable([
    for (var i = 0; i < branchCount; i++) PageTrail(),
  ]);

  static const int branchCount = 5;

  final List<Route<dynamic>> _routes = [];

  /// Tracked routes, bottom first.
  List<Route<dynamic>> get routes => List.unmodifiable(_routes);

  /// Pushes [builder]'s page on the nearest navigator, labelled [label] in the
  /// breadcrumbs.
  static Future<T?> push<T>(
    BuildContext context, {
    required String label,
    required WidgetBuilder builder,
  }) => Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      settings: RouteSettings(name: label),
      builder: builder,
    ),
  );

  /// Pops every tracked route above [route], or all of them when it is null.
  void popTo(Route<dynamic>? route) {
    final nav = navigator;
    if (nav == null || _routes.isEmpty) return;
    nav.popUntil((candidate) => candidate == route || !_isTracked(candidate));
  }

  static bool _isTracked(Route<dynamic> route) =>
      route is PageRoute &&
      route.settings is! Page &&
      route.settings.name != null;

  void _changed() {
    // Navigator callbacks can run during a build.
    scheduleMicrotask(notifyListeners);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isTracked(route)) return;
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index < 0) {
      if (newRoute != null) didPush(newRoute, null);
      return;
    }
    if (newRoute != null && _isTracked(newRoute)) {
      _routes[index] = newRoute;
    } else {
      _routes.removeAt(index);
    }
    _changed();
  }
}
