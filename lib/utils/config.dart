import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/grocery_store_env.dart';

class Config {
  static const String environment = appFlavor ?? 'development';
  static const String oauthRedirectScheme = String.fromEnvironment(
    GroceryStoreEnv.oauthRedirectScheme,
    defaultValue: GroceryStoreDefaults.oauthRedirectScheme,
  );

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => appFlavor == 'production';
  static bool get useEmulators => isDevelopment;

  /// The IP address for local development emulators.
  ///
  /// 💡 For Android emulators, this MUST be '10.0.2.2'.
  /// 💡 For physical Android devices, use your host's local IP (e.g., '192.168.x.x').
  /// 💡 For Web, 'localhost' or '127.0.0.1' is generally used.
  /// ⚠️ IMPORTANT: If you change this, you MUST also update the domain in:
  /// `android/app/src/main/res/xml/network_security_config.xml`
  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: kIsWeb ? 'localhost' : '192.168.0.253',
  );

  static const String testUserEmail = 'bob@example.com';
  static const String testUserPassword = 'password123';

  static const String coopClientId = String.fromEnvironment(
    GroceryStoreEnv.coopClientId,
    defaultValue: GroceryStoreDefaults.coopClientId,
  );
  static const String coopDiscoveryUrl = String.fromEnvironment(
    GroceryStoreEnv.coopDiscoveryUrl,
    defaultValue: GroceryStoreDefaults.coopDiscoveryUrl,
  );
  static const String coopRedirectUri = String.fromEnvironment(
    GroceryStoreEnv.coopRedirectUri,
    defaultValue: '$oauthRedirectScheme://oauth/callback/coop',
  );
  static const String coopScopes = String.fromEnvironment(
    GroceryStoreEnv.coopScopes,
    defaultValue: GroceryStoreDefaults.coopScopes,
  );
  static const String coopUserInfoEndpoint = String.fromEnvironment(
    GroceryStoreEnv.coopUserInfoEndpoint,
    defaultValue: GroceryStoreDefaults.coopUserInfoEndpoint,
  );
  static const String coopAudience = String.fromEnvironment(
    GroceryStoreEnv.coopAudience,
  );
  static const String coopPurchaseHistoryEndpoint = String.fromEnvironment(
    GroceryStoreEnv.coopPurchaseHistoryEndpoint,
    defaultValue: GroceryStoreDefaults.coopPurchaseHistoryEndpoint,
  );

  static const String remaClientId = String.fromEnvironment(
    GroceryStoreEnv.remaClientId,
    defaultValue: GroceryStoreDefaults.remaClientId,
  );
  static const String remaAuthorizationEndpoint = String.fromEnvironment(
    GroceryStoreEnv.remaAuthorizationEndpoint,
    defaultValue: GroceryStoreDefaults.remaAuthorizationEndpoint,
  );
  static const String remaTokenEndpoint = String.fromEnvironment(
    GroceryStoreEnv.remaTokenEndpoint,
    defaultValue: GroceryStoreDefaults.remaTokenEndpoint,
  );
  static const String remaRedirectUri = String.fromEnvironment(
    GroceryStoreEnv.remaRedirectUri,
    defaultValue: '$oauthRedirectScheme://oauth/callback/rema',
  );
  static const String remaScopes = String.fromEnvironment(
    GroceryStoreEnv.remaScopes,
    defaultValue: GroceryStoreDefaults.remaScopes,
  );
  static const String remaReceiptsEndpoint = String.fromEnvironment(
    GroceryStoreEnv.remaReceiptsEndpoint,
    defaultValue: GroceryStoreDefaults.remaReceiptsEndpoint,
  );
  static const String remaSubscriptionKey = String.fromEnvironment(
    GroceryStoreEnv.remaSubscriptionKey,
  );
  static const String remaAppVersion = String.fromEnvironment(
    GroceryStoreEnv.remaAppVersion,
    defaultValue: GroceryStoreDefaults.remaAppVersion,
  );
  static const String remaAppId = String.fromEnvironment(
    GroceryStoreEnv.remaAppId,
    defaultValue: GroceryStoreDefaults.remaAppId,
  );

  static const String trumfClientId = String.fromEnvironment(
    GroceryStoreEnv.trumfClientId,
    defaultValue: GroceryStoreDefaults.trumfClientId,
  );
  static const String trumfDiscoveryUrl = String.fromEnvironment(
    GroceryStoreEnv.trumfDiscoveryUrl,
    defaultValue: GroceryStoreDefaults.trumfDiscoveryUrl,
  );
  static const String trumfRedirectUri = String.fromEnvironment(
    GroceryStoreEnv.trumfRedirectUri,
    defaultValue: '$oauthRedirectScheme://oauth/callback/trumf',
  );
  static const String trumfScopes = String.fromEnvironment(
    GroceryStoreEnv.trumfScopes,
    defaultValue: GroceryStoreDefaults.trumfScopes,
  );
}
