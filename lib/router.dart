import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/features/third_party_integration/widgets/web_view.dart';
import 'package:go_router/go_router.dart';

import 'interfaces/is_auth.dart';
import 'utils/u_collection_types.dart';
import 'views/v_auth.dart';
import 'views/v_barcode_scan.dart';
import 'views/v_collection_list.dart';
import 'views/v_dashboard.dart';
import 'views/v_dynamic_collection.dart';
import 'views/v_landing_page.dart';
import 'views/v_main_navigation.dart';
import 'views/v_product_list.dart';
import 'views/v_profile.dart';
import 'views/v_select_products.dart';
import 'views/v_settings.dart';
import 'views/v_splash.dart';
import 'views/v_transfer_management.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

GoRouter createAppRouter(IAuthService authService) {
  final authListenable = _AuthStreamListenable(authService);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (BuildContext context, GoRouterState state) {
      // TODO: Handle this in a wrapper, update a global loading state, which shows the splash screen until loading is false.
      // On web refresh, the initial state is 'not logged in' until Firebase initializes.
      // We check if we're still 'loading' the initial auth state.
      if (!authListenable.isInitialized) {
        if (state.uri.path != '/splash') {
          final originalUri = state.uri.toString();
          return state.uri.path == '/' && state.uri.queryParameters.isEmpty
              ? '/splash'
              : '/splash?target=${Uri.encodeComponent(originalUri)}';
        }
        return null; // Stay on splash while loading
      }

      final isLoggedIn = authService.getUserId() != null;
      final isAnonymousUser = authService.currentUser?.isAnonymous ?? false;
      final isAuthRoute = state.uri.path == '/auth';
      final isOAuthCallbackRoute = state.uri.path.startsWith('/callback/');
      final isLandingRoute = state.uri.path == '/';
      final isSplashRoute = state.uri.path == '/splash';

      if (isSplashRoute) {
        // Once initialized, proceed to the intended target.
        // GoRouter will re-evaluate redirect for that target automatically.
        // Validate target to prevent infinite loops or open redirects
        final target = state.uri.queryParameters['target'];
        if (target != null &&
            target.startsWith('/') &&
            !target.startsWith('//') &&
            target != '/splash') {
          return target;
        }
        return '/';
      }

      if (isOAuthCallbackRoute) {
        return '/settings';
      }

      if (!isLoggedIn) {
        if (!isLandingRoute && !isAuthRoute) {
          return '/';
        }
        return null;
      } else if (isLandingRoute || (isAuthRoute && !isAnonymousUser)) {
        return '/dashboard';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashView();
        },
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const LandingPageView();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'auth',
            builder: (BuildContext context, GoRouterState state) {
              final mode = state.uri.queryParameters['mode'] ?? 'login';
              return AuthView(isLogin: mode == 'login');
            },
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationView(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardView(),
                routes: [
                  GoRoute(
                    path: 'product-list',
                    builder: (context, state) => const ProductListView(),
                  ),
                  GoRoute(
                    path: 'global-products',
                    builder: (context, state) =>
                        const ProductListView(showGlobalProducts: true),
                  ),
                  GoRoute(
                    path: 'transfer',
                    builder: (context, state) => const TransferManagementView(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-inventory',
                builder: (context, state) =>
                    const DynamicCollectionView(type: CollectionType.inventory),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shopping-lists',
                builder: (context, state) => const DynamicCollectionView(
                  type: CollectionType.shoppingList,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsView(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileView(),
                  ),
                  GoRoute(
                    path: 'web-view',
                    builder: (context, state) => WebView(
                      // TODO: Handle missing provider
                      provider: state.uri.queryParameters['provider'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/collection-list',
        builder: (context, state) {
          final typeParam = state.uri.queryParameters['type'];
          CollectionType? typeFilter;
          if (typeParam == 'inventory') typeFilter = CollectionType.inventory;
          if (typeParam == 'shopping') typeFilter = CollectionType.shoppingList;
          return CollectionListView(typeFilter: typeFilter);
        },
      ),
      GoRoute(
        path: '/select-products',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return SelectProductsView(
            fromLocationId: extra['fromLocationId'] ?? '',
            toLocationId: extra['toLocationId'] ?? '',
            fromLocationName: extra['fromLocationName'] ?? '',
            toLocationName: extra['toLocationName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/barcode-scan',
        builder: (context, state) => const BarcodeScanView(),
      ),
    ],
  );
}

/// A [Listenable] that notifies when the auth state changes.
class _AuthStreamListenable extends ChangeNotifier {
  final IAuthService _authService;
  late final StreamSubscription<User?> _subscription;
  Timer? _fallbackTimer;
  bool _isDisposed = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  _AuthStreamListenable(this._authService) {
    _subscription = _authService.authStateChanges.listen((_) {
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      _isInitialized = true;
      if (!_isDisposed) {
        notifyListeners();
      }
    });

    // Safety fallback for initialization
    _fallbackTimer = Timer(const Duration(seconds: 1), () {
      if (!_isInitialized && !_isDisposed) {
        _isInitialized = true;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fallbackTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
