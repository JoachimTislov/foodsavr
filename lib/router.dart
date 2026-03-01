import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'interfaces/i_auth_service.dart';
import 'models/product_model.dart';
import 'models/collection_model.dart';
import 'utils/collection_types.dart';
import 'views/auth_view.dart';
import 'views/landing_page_view.dart';
import 'views/dashboard_view.dart';
import 'views/product_list_view.dart';
import 'views/collection_list_view.dart';
import 'views/transfer_management_view.dart';
import 'views/select_products_view.dart';
import 'views/settings_view.dart';
import 'views/profile_view.dart';
import 'views/main_navigation_view.dart';
import 'views/dynamic_collection_view.dart';
import 'views/product_form_view.dart';
import 'views/collection_form_view.dart';
import 'views/add_product_to_collection_view.dart';

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
        if (!isLandingRoute && !isAuthRoute) {
          return '/';
        }
        return null;
      } else {
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationView(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const DashboardView(),
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
        ],
      ),
      GoRoute(
        path: '/product-list',
        builder: (context, state) => const ProductListView(),
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
        path: '/global-products',
        builder: (context, state) =>
            const ProductListView(showGlobalProducts: true),
      ),
      GoRoute(
        path: '/transfer',
        builder: (context, state) => const TransferManagementView(),
      ),
      GoRoute(
        path: '/select-products',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return SelectProductsView(
            fromLocationId: extra['fromLocationId'] ?? '',
            toLocationId: extra['toLocationId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileView(),
      ),
      GoRoute(
        path: '/product-form',
        builder: (context, state) {
          final product = state.extra as Product?;
          final collectionId = state.uri.queryParameters['collectionId'];
          return ProductFormView(
            product: product,
            initialCollectionId: collectionId,
          );
        },
      ),
      GoRoute(
        path: '/collection-form',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic> ||
              extra['type'] is! CollectionType) {
            return const Scaffold(
              body: Center(
                child: Text('Invalid route parameters for collection form.'),
              ),
            );
          }
          final type = extra['type'] as CollectionType;
          final collection = extra['collection'] as Collection?;
          return CollectionFormView(type: type, collection: collection);
        },
      ),
      GoRoute(
        path: '/add-product-to-collection',
        builder: (context, state) {
          final collectionId = state.uri.queryParameters['collectionId'] ?? '';
          return AddProductToCollectionView(collectionId: collectionId);
        },
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
