import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:foodsavr/injection.dart';
import 'package:foodsavr/services/theme_notifier.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  @singleton
  Logger get logger => Logger(level: kReleaseMode ? Level.warning : Level.all);

  @preResolve
  Future<SharedPreferencesWithCache> get prefs =>
      SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions(
          allowList: {ThemeNotifier.kThemeModeKey},
        ),
      );

  @Named('supportsPersistence')
  bool get supportsPersistence => kIsWeb;

  ThemeNotifier get themeNotifier =>
      ThemeNotifier(getIt<SharedPreferencesWithCache>());
}
