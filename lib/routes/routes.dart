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
import 'package:foodsavr/views/receipt_list_view.dart';
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
import '../widgets/common/url_modal_dialog.dart';
import 'page_trail.dart';

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
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      ModalDialogPage<void>(
        key: state.pageKey,
        name: state.matchedLocation,
        child: const LegalDocumentView(document: LegalDoc.privacy),
      );
}

@TypedGoRoute<TermsRoute>(path: PublicRoutes.terms)
class TermsRoute extends GoRouteData with $TermsRoute {
  const TermsRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      ModalDialogPage<void>(
        key: state.pageKey,
        name: state.matchedLocation,
        child: const LegalDocumentView(document: LegalDoc.terms),
      );
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
    TypedStatefulShellBranch<DashboardBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<DashboardRoute>(
          path: '/dashboard',
          routes: [
            TypedGoRoute<MyProductsRoute>(path: 'my-products'),
            TypedGoRoute<RegistryRoute>(path: 'registry'),
            TypedGoRoute<ReceiptsRoute>(path: 'receipts'),
            TypedGoRoute<TransferRoute>(path: 'transfer'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<InventoryBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MyInventoryRoute>(path: '/my-inventory'),
      ],
    ),
    TypedStatefulShellBranch<ShoppingBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ShoppingListsRoute>(path: '/shopping-lists'),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ProfileRoute>(path: '/profile'),
      ],
    ),
    TypedStatefulShellBranch<SettingsBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<SettingsRoute>(
          path: '/settings',
          routes: [TypedGoRoute<WebViewRoute>(path: 'web-view')],
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

// Each branch reports its pushed pages to its [PageTrail] for the
// breadcrumbs.
class DashboardBranch extends StatefulShellBranchData {
  const DashboardBranch();
  static final List<NavigatorObserver> $observers = [PageTrail.branches[0]];
}

class InventoryBranch extends StatefulShellBranchData {
  const InventoryBranch();
  static final List<NavigatorObserver> $observers = [PageTrail.branches[1]];
}

class ShoppingBranch extends StatefulShellBranchData {
  const ShoppingBranch();
  static final List<NavigatorObserver> $observers = [PageTrail.branches[2]];
}

class ProfileBranch extends StatefulShellBranchData {
  const ProfileBranch();
  static final List<NavigatorObserver> $observers = [PageTrail.branches[3]];
}

class SettingsBranch extends StatefulShellBranchData {
  const SettingsBranch();
  static final List<NavigatorObserver> $observers = [PageTrail.branches[4]];
}

class DashboardRoute extends GoRouteData with $DashboardRoute {
  const DashboardRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DashboardView();
}

class MyProductsRoute extends GoRouteData with $MyProductsRoute {
  const MyProductsRoute();
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

class RegistryRoute extends GoRouteData with $RegistryRoute {
  const RegistryRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProductListView(showGlobalProducts: true);
}

class ReceiptsRoute extends GoRouteData with $ReceiptsRoute {
  const ReceiptsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ReceiptListView();
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
