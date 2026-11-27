import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

import 'firebase_options.dart';
import 'firebase_options_prod.dart';
import 'interfaces/i_auth_service.dart';
import 'interfaces/i_error_reporter.dart';
import 'routes/go_router.dart';
import 'service_locator.dart';
import 'services/offline_sync.dart';
import 'services/web_access.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/theme_notifier.dart';
import 'utils/app_scroll_behavior.dart';
import 'utils/app_theme.dart';
import 'utils/config.dart';
import 'utils/env_loader.dart';
import 'utils/app_check_storage.dart';
import 'utils/app_locales.dart';
import 'utils/startup_loader.dart';

const dummyOptions = FirebaseOptions(
  apiKey: 'AIzaSyDummyKeyForDemoOnly',
  appId: '1:1234567890:web:dummyid123456',
  messagingSenderId: '',
  projectId: 'demo-project',
);

var initializedAppCheck = false;

/// Deployment environment (deploy/instance.yaml) whose Firebase project the
/// build talks to; set by scripts/web/deploy_web.py. Local runs default to
/// the test project.
const deployEnvironment = String.fromEnvironment(
  'DEPLOY_ENVIRONMENT',
  defaultValue: 'test',
);

/// Firebase options of [environment]: the production project's for
/// `production`, the tracked test project's otherwise. Production without
/// configured options throws rather than falling back to test.
FirebaseOptions firebaseOptionsFor(String environment) =>
    environment == 'production'
    ? ProdFirebaseOptions.currentPlatform
    : DefaultFirebaseOptions.currentPlatform;

/// List of supported flavor names.
/// - `development`: default; typically uses local emulators and verbose logging.
/// - `production`: connects to the production backend.
const List<String> supportedFlavors = <String>['development', 'production'];

void main() async {
  if (appFlavor == null && !kIsWeb) {
    throw Exception(
      'No app flavor provided. Please run the app using `make run-dev` or specify a flavor using `--flavor development`. See doc/implementation/gradle-flavor-troubleshooting.md for more info.',
    );
  }
  if (!supportedFlavors.contains(Config.environment)) {
    throw Exception(
      'Invalid app flavor: ${Config.environment}. Supported flavors: ${supportedFlavors.join(', ')}',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  const recaptchaKey = String.fromEnvironment('RECAPTCHA_ENTERPRISE_SITE_KEY');
  prepareAppCheckStorage(
    enterpriseSiteKey: Config.useEmulators ? null : recaptchaKey,
  );
  await loadEnv();

  OpenFoodAPIConfiguration.userAgent = UserAgent(
    name: 'FoodSavr',
    system: 'Flutter',
  );

  final serviceLocator = ServiceLocator();
  await serviceLocator.registerDependencies();

  final logger = getIt<Logger>();
  logger.i(
    'Running in ${Config.environment} mode (Emulators: ${Config.useEmulators})',
  );

  if (Config.useEmulators) {
    try {
      // Check if Auth Emulator is reachable before continuing
      await http
          .get(Uri.parse('http://${Config.emulatorHost}:9099/'))
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // If the GET request fails or times out, the emulators are likely offline.
      throw Exception(
        'Firebase Emulators are not running! Please run "make start-firebase-emulators" (see kill-firebase-emulators in Makefile for port details).',
      );
    }
  }

  // init Firebase app if not already initialized
  try {
    await Firebase.initializeApp(
      options: Config.useEmulators
          ? dummyOptions
          : firebaseOptionsFor(deployEnvironment),
    );
  } on FirebaseException catch (e) {
    final normalizedMessage = e.message?.toLowerCase() ?? '';
    final isAlreadyInitialized =
        e.code == 'duplicate-app' ||
        e.code == 'already-initialized' ||
        normalizedMessage.contains('already initialized');

    if (!isAlreadyInitialized) rethrow;

    logger.i('Firebase App Check already initialized, skipping...');
  } catch (_) {
    rethrow;
  }

  final errorReporter = getIt<IErrorReporter>();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(errorReporter.recordFlutterError(details));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(errorReporter.recordError(error, stack, fatal: true));
    return false;
  };

  if (Config.useEmulators) {
    await serviceLocator.setupDevelopment();
  }

  if (!Config.useEmulators && !initializedAppCheck) {
    if (Config.isProduction && kIsWeb && recaptchaKey.isEmpty) {
      logger.w('RECAPTCHA_ENTERPRISE_SITE_KEY is not set.');
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(recaptchaKey),
      // Debug builds get no Play Integrity verdict; they log a debug token
      // to register under App Check > Manage debug tokens.
      providerAndroid: kDebugMode
          ? AndroidDebugProvider()
          : AndroidPlayIntegrityProvider(),
    );
    initializedAppCheck = true;
  }

  await EasyLocalization.ensureInitialized();

  // Start syncing the signed-in user's preferences from app start.
  getIt<PreferencesController>();
  // Look up barcodes that were scanned while offline once a connection returns.
  getIt<OfflineSync>().start();

  final webAccess =
      kIsWeb && !Config.useEmulators && Config.webAccessCode.isNotEmpty
      ? WebAccess(Config.webAccessCode, getIt<SharedPreferencesWithCache>())
      : null;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    dismissStartupLoader();
  });

  runApp(
    EasyLocalization(
      supportedLocales: supportedAppLocales,
      path: 'assets/translations',
      fallbackLocale: enLocale,
      // Applies only until the user picks a language; easy_localization
      // saves that choice and restores it on later launches.
      startLocale: startLocaleFor(PlatformDispatcher.instance.locale),
      useFallbackTranslations: true,
      child: MyApp(
        router: createAppRouter(
          getIt<IAuthService>(),
          getIt<UserController>(),
          webAccess: webAccess,
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final RouterConfig<Object> router;

  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: getIt<ThemeNotifier>(),
      builder: (context, _) => MaterialApp.router(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        title: 'LettMat',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: getIt<ThemeNotifier>().themeMode,
        scrollBehavior: const AppScrollBehavior(),
        routerConfig: router,
      ),
    );
  }
}
