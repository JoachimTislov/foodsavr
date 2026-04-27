import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

import 'firebase_options.dart';
import 'interfaces/i_auth_service.dart';
import 'router.dart';
import 'service_locator.dart';
import 'services/theme_notifier.dart';
import 'utils/app_theme.dart';
import 'utils/config.dart';

const dummyOptions = FirebaseOptions(
  apiKey: 'AIzaSyDummyKeyForDemoOnly',
  appId: '1:1234567890:web:dummyid123456',
  messagingSenderId: '',
  projectId: 'demo-project',
);

/// List of supported flavor names.
/// - `development`: default; typically uses local emulators and verbose logging.
/// - `production`: connects to the production backend.
const List<String> supportedFlavors = <String>['development', 'production'];

void main() async {
  if (appFlavor == null && !kIsWeb) {
    throw Exception(
      'No app flavor provided. Please run the app using `make run-dev` or specify a flavor using `--flavor development`. See archive/issues/gradle-build-failed-apk-flavor.md for more info.',
    );
  }
  if (appFlavor != null && !supportedFlavors.contains(appFlavor)) {
    throw Exception(
      'Invalid app flavor: $appFlavor. Supported flavors: ${supportedFlavors.join(', ')}',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();

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

  // We skip this check on Web because making an HTTP GET request to the emulator
  // from the browser triggers a CORS exception, which crashes the app before it
  // can even render.
  if (Config.useEmulators && !kIsWeb) {
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
          : DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    logger.i('Firebase app already initialized, skipping...');
  }

  if (Config.useEmulators) {
    try {
      await serviceLocator.setupDevelopment();
    } catch (e) {
      logger.w('Development setup failed: $e');
    }
  }

  // We wrap AppCheck activation in a try-catch block because on Web hot-restarts,
  // the JS SDK retains the initialized Firebase state, and calling `activate`
  // a second time throws an "already initialized" error, freezing the app.
  try {
    const recaptchaKey = String.fromEnvironment(
      'RECAPTCHA_V3_SITE_KEY',
      defaultValue: 'dummy-key',
    );
    if (Config.useEmulators) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(recaptchaKey),
        providerAndroid: AndroidDebugProvider(),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(recaptchaKey),
      );
    }
  } catch (e) {
    if (Config.useEmulators) {
      logger.w(
        'Firebase/AppCheck initialization failed (likely due to hot restart): $e',
      );
    } else {
      logger.e('Firebase/AppCheck initialization failed: $e');
      // TODO: Forward to crash reporting hook (e.g. Crashlytics)
    }
  }

  const enLocale = Locale('en');
  const nbLocale = Locale('nb');
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [enLocale, nbLocale],
      path: 'assets/translations',
      fallbackLocale: enLocale,
      startLocale: enLocale,
      useFallbackTranslations: true,
      child: MyApp(router: createAppRouter(getIt<IAuthService>())),
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
        title: 'FoodSavr',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: getIt<ThemeNotifier>().themeMode,
        routerConfig: router,
      ),
    );
  }
}
