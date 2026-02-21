import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'interfaces/i_auth_service.dart';
import 'views/auth_view.dart';
import 'views/landing_page_view.dart';
import 'views/main_view.dart';
import 'views/product_list_view.dart';
import 'views/collection_list_view.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

GoRouter createAppRouter(IAuthService authService) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthStreamListenable(authService),
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authService.getUserId() != null;
      final isAuthRoute = state.uri.path == '/auth';
      final isLandingRoute = state.uri.path == '/';

      if (!isLoggedIn) {
        // If not logged in and not on landing or auth, redirect to landing
        if (!isLandingRoute && !isAuthRoute) {
          return '/';
        }
        return null;
      } else {
        // If logged in and on landing or auth, redirect to home (products)
        if (isLandingRoute || isAuthRoute) {
          return '/products';
        }
        return null;
      }
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const LandingPageView();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'auth',
            builder: (BuildContext context, GoRouterState state) {
              final title = state.uri.queryParameters['title'] ?? 'Auth';
              return AuthView(title: title);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/products',
        builder: (BuildContext context, GoRouterState state) {
          return const MainAppScreen();
        },
      ),
      // Define other routes here as needed to replace imperative navigation
      GoRoute(
        path: '/product-list',
        builder: (context, state) => const ProductListView(),
      ),
      GoRoute(
        path: '/collection-list',
        builder: (context, state) => const CollectionListView(),
      ),
      GoRoute(
        path: '/global-products',
        builder: (context, state) =>
            const ProductListView(showGlobalProducts: true),
      ),
    ],
  );
}

/// A [Listenable] that notifies when the auth state changes.
class _AuthStreamListenable extends ChangeNotifier {
  final IAuthService _authService;
  late final StreamSubscription<User?> _subscription;
  bool _isDisposed = false;

  _AuthStreamListenable(this._authService) {
    _subscription = _authService.authStateChanges.listen((_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
