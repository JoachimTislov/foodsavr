import 'package:flutter/material.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/utils/config.dart';
import 'package:go_router/go_router.dart';

import '../constants/public_routes.dart';
import '../interfaces/i_auth_service.dart';
import '../services/web_access.dart';
import '../views/delete_account_view.dart';
import '../views/web_access_view.dart';
import 'redirect.dart';
import 'routes.dart';

GoRouter createAppRouter(
  IAuthService authService,
  UserController authController, {
  WebAccess? webAccess,
}) {
  return GoRouter(
    debugLogDiagnostics: Config.isDevelopment,
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: '/',
    refreshListenable: Listenable.merge([authController, webAccess]),
    redirect: (context, state) =>
        redirect(context, state, authController, authService, webAccess),
    routes: [
      ...$appRoutes,
      GoRoute(
        path: PublicRoutes.deleteAccount,
        builder: (_, _) => DeleteAccountView(controller: authController),
      ),
      if (webAccess != null)
        GoRoute(
          path: PublicRoutes.webAccess,
          builder: (_, _) => WebAccessView(access: webAccess),
        ),
    ],
  );
}
