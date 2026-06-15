enum GroceryStoreProvider {
  coop('Coop'),
  rema('Rema 1000'),
  trumf('Trumf');

  const GroceryStoreProvider(this.displayName);

  final String displayName;
  String get envPrefix => toString().toUpperCase();
}

enum Status { mobileOnly, notConfigured, connected, authorizing }

class GroceryStoreConnection {
  final GroceryStoreProvider provider;
  final bool isAvailable;
  final bool isConnected;
  final String? statusKey;

  const GroceryStoreConnection({
    required this.provider,
    required this.isConnected,
    required this.isAvailable,
    this.statusKey,
  });
}

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
}
