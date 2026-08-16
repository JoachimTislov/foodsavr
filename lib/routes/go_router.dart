import 'package:flutter/material.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/utils/config.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/i_auth_service.dart';
import 'redirect.dart';
import 'routes.dart';

GoRouter createAppRouter(IAuthService authService) {
  final authController = getIt<UserController>();
  return GoRouter(
    debugLogDiagnostics: Config.isDevelopment,
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: '/',
    refreshListenable: authController,
    redirect: (context, state) =>
        redirect(context, state, authController, authService),
    routes: $appRoutes,
  );
}
