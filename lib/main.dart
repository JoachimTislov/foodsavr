import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'firebase_options.dart';
import 'interfaces/i_auth_service.dart';
import 'router.dart';
import 'service_locator.dart';
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

  final serviceLocator = ServiceLocator();
  await serviceLocator.registerDependencies();

  final logger = getIt<Logger>();
  logger.i('Running in ${Config.environment} mode');

  // init Firebase app if not already initialized
  // prevent multiple initializations when restarting app in development mode
  if (Firebase.apps.isEmpty) {
    logger.i('Firebase app not initialized, initializing now...');
    await Firebase.initializeApp(
      options: Config.isDevelopment
          ? dummyOptions
          : DefaultFirebaseOptions.currentPlatform,
    );
  }
  if (Config.isDevelopment) {
    await serviceLocator.setupDevelopment();
  }

  const enLocale = Locale('en', 'US');
  await EasyLocalization.ensureInitialized();
  final router = createAppRouter(getIt<IAuthService>());
  runApp(
    EasyLocalization(
      supportedLocales: const [enLocale, Locale('nb', 'NO')],
      path: 'assets/translations',
      fallbackLocale: enLocale,
      child: MyApp(router: router),
    ),
  );
}

class MyApp extends StatelessWidget {
  final RouterConfig<Object> router;

  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FoodSavr',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
