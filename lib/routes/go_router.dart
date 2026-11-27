import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/utils/config.dart';
import 'package:go_router/go_router.dart';

import '../constants/public_routes.dart';
import '../interfaces/i_auth_service.dart';
import '../services/web_access.dart';
import '../views/delete_account_view.dart';
import '../views/web_access_view.dart';
import '../widgets/common/url_modal_dialog.dart';
import 'hash_route_bridge.dart';
import 'redirect.dart';
import 'routes.dart';

GoRouter createAppRouter(
  IAuthService authService,
  UserController authController, {
  WebAccess? webAccess,
  Uri? initialUri,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final effectiveInitialUri = initialUri ?? (kIsWeb ? Uri.base : null);
  final initialHashRoute = PublicRoutes.resolveHashRoute(effectiveInitialUri);

  final router = GoRouter(
    debugLogDiagnostics: Config.isDevelopment,
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: initialHashRoute ?? '/',
    overridePlatformDefaultLocation: initialHashRoute != null,
    refreshListenable: Listenable.merge([authController, webAccess]),
    redirect: (context, state) =>
        redirect(context, state, authController, authService, webAccess),
    routes: [
      ...$appRoutes,
      GoRoute(
        path: PublicRoutes.deleteAccount,
        pageBuilder: (context, state) => ModalDialogPage<void>(
          key: state.pageKey,
          name: state.matchedLocation,
          child: DeleteAccountView(controller: authController),
        ),
      ),
      // Legacy public aliases kept for external links (e.g. Facebook policy URLs).
      GoRoute(
        path: PublicRoutes.legacyPrivacy,
        redirect: (_, _) => PublicRoutes.privacy,
      ),
      GoRoute(
        path: PublicRoutes.legacyTerms,
        redirect: (_, _) => PublicRoutes.terms,
      ),
      GoRoute(
        path: PublicRoutes.legacyDeleteAccount,
        redirect: (_, _) => PublicRoutes.deleteAccount,
      ),
      if (webAccess != null)
        GoRoute(
          path: PublicRoutes.webAccess,
          builder: (_, _) => WebAccessView(access: webAccess),
        ),
    ],
  );

  if (kIsWeb) {
    bindHashRouteListener(router.go);
  }

  return router;
}
