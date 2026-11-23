import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:go_router/go_router.dart';

import '../constants/public_routes.dart';
import '../interfaces/i_auth_service.dart';
import '../services/web_access.dart';

FutureOr<String?> redirect(
  BuildContext context,
  GoRouterState state,
  UserController authController,
  IAuthService authService,
  WebAccess? webAccess,
) {
  final uri = state.uri;
  if (PublicRoutes.isPublic(uri.path)) return null;
  final isDeletionSignIn = PublicRoutes.isDeletionSignIn(uri);
  if (uri.path == PublicRoutes.webAccess) {
    if (webAccess?.isLocked ?? false) return null;
    final target = _localTarget(uri);
    return target == null || Uri.parse(target).path == PublicRoutes.webAccess
        ? '/'
        : target;
  }
  if ((webAccess?.isLocked ?? false) &&
      !isDeletionSignIn &&
      uri.path != '/splash') {
    return Uri(
      path: PublicRoutes.webAccess,
      queryParameters: {'target': uri.toString()},
    ).toString();
  }
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
    final target = _localTarget(uri);
    return target == null || Uri.parse(target).path == '/splash' ? '/' : target;
  }

  if (isOAuthCallbackRoute || (kIsWeb && uri.path == '/settings/web-view')) {
    return '/settings';
  }

  if (!isLoggedIn) {
    if (!isLandingRoute && !isAuthRoute) {
      return '/';
    }
    return null;
  } else if (isLandingRoute || (isAuthRoute && !isAnonymousUser)) {
    return isDeletionSignIn ? PublicRoutes.deleteAccount : '/dashboard';
  }
  return null;
}

String? _localTarget(Uri uri) {
  final target = uri.queryParameters['target'];
  if (target == null || !target.startsWith('/') || target.contains('\\')) {
    return null;
  }
  final parsed = Uri.tryParse(target);
  return parsed != null && !parsed.hasAuthority && !parsed.hasScheme
      ? target
      : null;
}
