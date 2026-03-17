import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'interfaces/i_auth_service.dart';
import 'router.dart';
import 'service_locator.dart';
import 'services/barcode_scanner_service.dart';
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
///
/// - `development`: default; typically uses local emulators and
///   verbose logging.
/// - `staging`: optional; can be wired to a staging backend.
/// - `production`: connects to the production backend.
const List<String> supportedFlavors = <String>[
  'development',
  'staging',
  'production',
];

void main() async {
  if (appFlavor != null && !supportedFlavors.contains(appFlavor)) {
    throw Exception(
      'Invalid app flavor: $appFlavor. Supported flavors: ${supportedFlavors.join(', ')}',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();

  // Load preferences early to determine environment
  final prefs = await SharedPreferences.getInstance();

  // Environment Priority:
  // 1. Production build -> always remote
  // 2. Environment variable -> use if present
  // 3. User preference -> use if present
  // 4. Fallback -> default to development mode
  final bool forceEmulators = const bool.fromEnvironment(
    'USE_EMULATORS',
    defaultValue: false,
  );
  final bool userPrefersEmulators =
      prefs.getBool(Config.useEmulatorsKey) ?? Config.isDevelopment;
  final bool useEmulators =
      !Config.isProduction && (forceEmulators || userPrefersEmulators);

  OpenFoodAPIConfiguration.userAgent = UserAgent(
    name: 'FoodSavr',
    system: 'Flutter',
  );

  final serviceLocator = ServiceLocator();
  await serviceLocator.registerDependencies();

  final logger = getIt<Logger>();
  logger.i('Running in ${Config.environment} mode (Emulators: $useEmulators)');

  // init Firebase app if not already initialized
  try {
    await Firebase.initializeApp(
      options: useEmulators
          ? dummyOptions
          : DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    logger.i('Firebase app already initialized, skipping...');
  }

  if (useEmulators) {
    await serviceLocator.setupDevelopment();
  }

  const enLocale = Locale('en');
  const nbLocale = Locale('nb');
  await EasyLocalization.ensureInitialized();

  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<ThemeNotifier>(ThemeNotifier(prefs));
  if (!getIt.isRegistered<BarcodeScannerService>()) {
    getIt.registerLazySingleton<BarcodeScannerService>(
      () => BarcodeScannerService(),
      dispose: (service) => service.close(),
    );
  }
  final router = createAppRouter(getIt<IAuthService>());
  runApp(
    EasyLocalization(
      supportedLocales: const [enLocale, nbLocale],
      path: 'assets/translations',
      fallbackLocale: enLocale,
      startLocale: enLocale,
      useFallbackTranslations: true,
      child: MyApp(router: router),
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
