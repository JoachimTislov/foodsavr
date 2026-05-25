import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodsavr/injection.dart';
import 'package:foodsavr/services/theme_notifier.dart';
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

  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  GoogleSignIn get googleSignIn => GoogleSignIn.instance;

  @lazySingleton
  FlutterAppAuth get flutterAppAuth => const FlutterAppAuth();

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
          allowList: {ThemeNotifier.kThemeModeKey},
        ),
      );

  @Named('supportsPersistence')
  bool get supportsPersistence => kIsWeb;

  @singleton
  ThemeNotifier get themeNotifier =>
      ThemeNotifier(getIt<SharedPreferencesWithCache>());
}
