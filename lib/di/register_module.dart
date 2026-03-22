import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:foodsavr/services/theme_notifier.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class RegisterModule {
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  GoogleSignIn get googleSignIn => GoogleSignIn.instance;

  @lazySingleton
  FacebookAuth get facebookAuth => FacebookAuth.instance;

  @lazySingleton
  Logger get logger => Logger(level: kReleaseMode ? Level.warning : Level.all);

  // TODO: "This is a legacy API. For new code, consider [SharedPreferencesAsync] or [SharedPreferencesWithCache]."
  @lazySingleton
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();

  @Named('supportsPersistence')
  bool get supportsPersistence => kIsWeb;

  @lazySingleton
  Future<ThemeNotifier> get themeNotifier async =>
      ThemeNotifier(await sharedPreferences);
}
