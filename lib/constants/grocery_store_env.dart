class GroceryStoreEnv {
  const GroceryStoreEnv._();

  static const oauthRedirectScheme = 'OAUTH_REDIRECT_SCHEME';

  static const coopClientId = 'COOP_OAUTH_CLIENT_ID';
  static const coopDiscoveryUrl = 'COOP_OAUTH_DISCOVERY_URL';
  static const coopRedirectUri = 'COOP_OAUTH_REDIRECT_URI';
  static const coopScopes = 'COOP_OAUTH_SCOPES';
  static const coopUserInfoEndpoint = 'COOP_OAUTH_USERINFO_ENDPOINT';
  static const coopAudience = 'COOP_OAUTH_AUDIENCE';
  static const coopPurchaseHistoryEndpoint =
      'COOP_OAUTH_PURCHASE_HISTORY_ENDPOINT';

  static const remaClientId = 'REMA_OAUTH_CLIENT_ID';
  static const remaAuthorizationEndpoint = 'REMA_OAUTH_AUTHORIZATION_ENDPOINT';
  static const remaTokenEndpoint = 'REMA_OAUTH_TOKEN_ENDPOINT';
  static const remaRedirectUri = 'REMA_OAUTH_REDIRECT_URI';
  static const remaScopes = 'REMA_OAUTH_SCOPES';
  static const remaReceiptsEndpoint = 'REMA_OAUTH_RECEIPTS_ENDPOINT';
  static const remaSubscriptionKey = 'REMA_OAUTH_SUBSCRIPTION_KEY';
  static const remaAppVersion = 'REMA_OAUTH_APP_VERSION';
  static const remaAppId = 'REMA_OAUTH_APP_ID';

  static const trumfClientId = 'TRUMF_OAUTH_CLIENT_ID';
  static const trumfDiscoveryUrl = 'TRUMF_OAUTH_DISCOVERY_URL';
  static const trumfRedirectUri = 'TRUMF_OAUTH_REDIRECT_URI';
  static const trumfScopes = 'TRUMF_OAUTH_SCOPES';
}

class GroceryStoreDefaults {
  const GroceryStoreDefaults._();

  static const oauthRedirectScheme = 'foodsavr';
  static const coopClientId = '7WrQEdeXwUudArpQVjmZEvrTgVs1WkRr';

  static const coopDiscoveryUrl =
      'https://login.coop.no/.well-known/openid-configuration';
  static const coopRedirectUri = 'foodsavr://oauth/callback/coop';
  static const coopScopes = 'openid profile offline_access email phone address';
  static const coopUserInfoEndpoint = 'https://login.coop.no/userinfo';
  static const coopPurchaseHistoryEndpoint =
      'https://api.coop.no/user/pay/history/list';

  static const remaClientId = 'android-251010';
  static const remaAuthorizationEndpoint = 'https://id.rema.no/authorization';
  static const remaTokenEndpoint = 'https://id.rema.no/token';
  static const remaRedirectUri = 'foodsavr://oauth/callback/rema';
  static const remaScopes = 'openid profile offline_access';
  static const remaReceiptsEndpoint =
      'https://api.rema.no/v1/bella/transaction/v2/heads';
  static const remaAppVersion = '3.0.12 #110549';
  static const remaAppId = 'bella';

  static const trumfClientId = 'trumf';
  static const trumfDiscoveryUrl =
      'https://id.trumf.no/.well-known/openid-configuration';
  static const trumfRedirectUri = 'foodsavr://oauth/callback/trumf';
  static const trumfScopes =
      'openid profile offline_access api.rest api.sylinder api.trumfid';
}
