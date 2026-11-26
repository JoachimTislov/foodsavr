import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodsavr/constants/preferences_config.dart';
import 'package:foodsavr/controllers/pwa_install_controller.dart';
import 'package:foodsavr/injection.dart';
import 'package:foodsavr/services/barcode_lookup_queue.dart';
import 'package:foodsavr/services/web_access.dart';
import 'package:foodsavr/utils/theme_notifier.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class RegisterModule {
  @lazySingleton
  FacebookAuth get facebookAuth => FacebookAuth.instance;

  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  /// Firestore with its local cache on every platform, so reads work and
  /// writes queue while offline. Android and iOS enable persistence by
  /// default; web needs it set, with multi-tab sync so several open tabs
  /// share one cache.
  @lazySingleton
  FirebaseFirestore get firebaseFirestore =>
      withOfflinePersistence(FirebaseFirestore.instance, isWeb: kIsWeb);

  @lazySingleton
  GoogleSignIn get googleSignIn => GoogleSignIn.instance;

  @lazySingleton
  FlutterSecureStorage get flutterSecureStorage => const FlutterSecureStorage();

  @lazySingleton
  http.Client get httpClient => http.Client();

  @singleton
  Logger get logger => Logger(level: kReleaseMode ? Level.warning : Level.all);

  @preResolve
  @singleton
  Future<SharedPreferencesWithCache> get prefs =>
      SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions(
          allowList: {
            ThemeNotifier.kThemeModeKey,
            PwaInstallController.kDismissedKey,
            PreferencesConfig.cacheKey,
            WebAccess.preferenceKey,
            BarcodeLookupQueue.preferenceKey,
          },
        ),
      );

  @Named('supportsPersistence')
  bool get supportsPersistence => kIsWeb;

  @Named('isWeb')
  bool get isWeb => kIsWeb;

  @singleton
  ThemeNotifier get themeNotifier =>
      ThemeNotifier(getIt<SharedPreferencesWithCache>());

  @singleton
  PwaInstallController get pwaInstallController =>
      PwaInstallController(prefs: getIt<SharedPreferencesWithCache>());
}

/// Firestore settings with offline persistence enabled.
Settings firestoreSettings({required bool isWeb}) => Settings(
  persistenceEnabled: true,
  webPersistentTabManager: isWeb
      ? const WebPersistentMultipleTabManager()
      : null,
);

/// Applies [firestoreSettings] to [firestore]. Settings can only be set before
/// first use; a web hot restart reuses the started instance, which keeps the
/// settings it was started with.
FirebaseFirestore withOfflinePersistence(
  FirebaseFirestore firestore, {
  required bool isWeb,
}) {
  try {
    firestore.settings = firestoreSettings(isWeb: isWeb);
  } catch (e) {
    getIt<Logger>().w('Firestore settings already applied: ${e.runtimeType}');
  }
  return firestore;
}
