import 'package:flutter_appauth/flutter_appauth.dart';

import 'grocery_store_provider.dart';

class GroceryStoreAuthConfig {
  const GroceryStoreAuthConfig({
    required this.provider,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    this.additionalParameters = const {},
    this.discoveryUrl,
    this.authorizationEndpoint,
    this.tokenEndpoint,
    this.userInfoEndpoint,
  });

  final GroceryStoreProvider provider;
  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final Map<String, String> additionalParameters;
  final String? discoveryUrl;
  final String? authorizationEndpoint;
  final String? tokenEndpoint;
  final String? userInfoEndpoint;

  bool get isConfigured =>
      clientId.isNotEmpty &&
      redirectUri.isNotEmpty &&
      (discoveryUrl?.isNotEmpty == true ||
          (authorizationEndpoint?.isNotEmpty == true &&
              tokenEndpoint?.isNotEmpty == true));

  AuthorizationServiceConfiguration? get serviceConfiguration {
    final authorizationEndpoint = this.authorizationEndpoint;
    final tokenEndpoint = this.tokenEndpoint;
    if (authorizationEndpoint == null || tokenEndpoint == null) {
      return null;
    }
    return AuthorizationServiceConfiguration(
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
    );
  }
}
