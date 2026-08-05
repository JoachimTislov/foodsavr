import 'package:flutter/material.dart';
import 'package:foodsavr/utils/config.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/i_auth_service.dart';
import 'auth_listenable.dart';
import 'redirect.dart';
import 'routes.dart';

GoRouter createAppRouter(IAuthService authService) {
  final authListenable = AuthStreamListenable(authService);
  return GoRouter(
    debugLogDiagnostics: Config.isDevelopment,
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) =>
        redirect(context, state, authListenable, authService),
    routes: $appRoutes,
  );
}
