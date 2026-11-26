import 'package:flutter/material.dart';
import 'package:foodsavr/features/third_party_integration/widgets/web_view.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/views/auth_view.dart';
import 'package:foodsavr/views/barcode_scan_view.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/views/dynamic_collection_view.dart';
import 'package:foodsavr/views/landing_page_view.dart';
import 'package:foodsavr/views/main_navigation_view.dart';
import 'package:foodsavr/views/product_list_view.dart';
import 'package:foodsavr/views/profile_view.dart';
import 'package:foodsavr/views/select_products_view.dart';
import 'package:foodsavr/views/settings_view.dart';
import 'package:foodsavr/views/splash_view.dart';
import 'package:foodsavr/views/transfer_management_view.dart';
import 'package:go_router/go_router.dart';

import '../constants/legal_docs.dart';
import '../injection.dart';
import '../services/barcode_lookup_queue.dart';
import '../services/sync_status.dart';
import '../widgets/common/pending_sync_banner.dart';
import '../constants/public_routes.dart';
import '../controllers/list_query.dart';
import '../views/legal_document_view.dart';
import '../models/product_model.dart';

part 'routes.g.dart';

@TypedGoRoute<LandingPageRoute>(
  path: '/',
  routes: [TypedGoRoute<AuthRoute>(path: 'auth')],
)
class LandingPageRoute extends GoRouteData with $LandingPageRoute {
  const LandingPageRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LandingPageView();
}

class AuthRoute extends GoRouteData with $AuthRoute {
  const AuthRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final mode = state.uri.queryParameters['mode'] ?? 'login';
    final deletionOnly = PublicRoutes.isDeletionSignIn(state.uri);
    return AuthView(
      isLogin: deletionOnly || mode == 'login',
      deletionOnly: deletionOnly,
    );
  }
}

@TypedGoRoute<PrivacyRoute>(path: PublicRoutes.privacy)
class PrivacyRoute extends GoRouteData with $PrivacyRoute {
  const PrivacyRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LegalDocumentView(document: LegalDoc.privacy);
}

@TypedGoRoute<TermsRoute>(path: PublicRoutes.terms)
class TermsRoute extends GoRouteData with $TermsRoute {
  const TermsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LegalDocumentView(document: LegalDoc.terms);
}

@TypedGoRoute<SplashRoute>(path: '/splash')
class SplashRoute extends GoRouteData with $SplashRoute {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SplashView();
}

@TypedGoRoute<BarcodeScanRoute>(path: '/barcode-scan')
class BarcodeScanRoute extends GoRouteData with $BarcodeScanRoute {
  const BarcodeScanRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const BarcodeScanView();
}

@TypedGoRoute<SelectProductsRoute>(path: '/select-products')
class SelectProductsRoute extends GoRouteData with $SelectProductsRoute {
  const SelectProductsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final extra = state.extra as Map<String, String>? ?? {};
    return SelectProductsView(
      fromLocationId: extra['fromLocationId'] ?? '',
      toLocationId: extra['toLocationId'] ?? '',
      fromLocationName: extra['fromLocationName'] ?? '',
      toLocationName: extra['toLocationName'] ?? '',
    );
  }
}

@TypedStatefulShellRoute<MainNavigationRoute>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<StatefulShellBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<DashboardRoute>(
          path: '/dashboard',
          routes: [
            TypedGoRoute<ProductListRoute>(path: 'product-list'),
            TypedGoRoute<GlobalProductsRoute>(path: 'global-products'),
            TypedGoRoute<TransferRoute>(path: 'transfer'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<StatefulShellBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MyInventoryRoute>(path: '/my-inventory'),
      ],
    ),
    TypedStatefulShellBranch<StatefulShellBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ShoppingListsRoute>(path: '/shopping-lists'),
      ],
    ),
    TypedStatefulShellBranch<StatefulShellBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<SettingsRoute>(
          path: '/settings',
          routes: [
            TypedGoRoute<ProfileRoute>(path: 'profile'),
            TypedGoRoute<WebViewRoute>(path: 'web-view'),
          ],
        ),
      ],
    ),
  ],
)
class MainNavigationRoute extends StatefulShellRouteData {
  const MainNavigationRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => MainNavigationView(
    navigationShell: navigationShell,
    statusBanner: PendingSyncBanner(
      syncStatus: getIt<SyncStatus>(),
      lookupQueue: getIt<BarcodeLookupQueue>(),
    ),
  );
}

class DashboardRoute extends GoRouteData with $DashboardRoute {
  const DashboardRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DashboardView();
}

class ProductListRoute extends GoRouteData with $ProductListRoute {
  const ProductListRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => ProductListView(
    key: ValueKey(state.uri.query),
    initialSort: ListSort.values.asNameMap()[state.uri.queryParameters['sort']],
    initialStatus: switch (state.uri.queryParameters['status']) {
      'expiring' => ProductStatus.expiringSoon,
      'expired' => ProductStatus.expired,
      'fresh' => ProductStatus.fresh,
      _ => null,
    },
  );
}

class GlobalProductsRoute extends GoRouteData with $GlobalProductsRoute {
  const GlobalProductsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProductListView(showGlobalProducts: true);
}

class TransferRoute extends GoRouteData with $TransferRoute {
  const TransferRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const TransferManagementView();
}

class MyInventoryRoute extends GoRouteData with $MyInventoryRoute {
  const MyInventoryRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DynamicCollectionView(type: CollectionType.inventory);
}

class ShoppingListsRoute extends GoRouteData with $ShoppingListsRoute {
  const ShoppingListsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DynamicCollectionView(type: CollectionType.shoppingList);
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsView();
}

class ProfileRoute extends GoRouteData with $ProfileRoute {
  const ProfileRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfileView();
}

class WebViewRoute extends GoRouteData with $WebViewRoute {
  const WebViewRoute({this.provider});
  final String? provider;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return WebView(provider: provider);
  }
}
