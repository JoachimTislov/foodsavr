import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:foodsavr/controllers/auth_controller.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/i_auth_service.dart';

FutureOr<String?> redirect(
  BuildContext context,
  GoRouterState state,
  UserController authController,
  IAuthService authService,
) {
  // TODO: Handle this in a wrapper, update a global loading state, which shows the splash screen until loading is false.
  // On web refresh, the initial state is 'not logged in' until Firebase initializes.
  // We check if we're still 'loading' the initial auth state.
  if (!authController.isInitialized) {
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
}
