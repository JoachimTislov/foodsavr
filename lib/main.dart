import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'firebase_options.dart';
import 'interfaces/i_auth_service.dart';
import 'service_locator.dart';
import 'utils/config.dart';
import 'views/auth_view.dart';
import 'views/main_view.dart';

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

  final logger = Logger(level: kReleaseMode ? Level.warning : Level.all);
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
  final serviceLocator = ServiceLocator(logger);
  if (Config.isDevelopment) {
    await serviceLocator.setupDevelopment();
  }
  await serviceLocator.registerDependencies();

  const enLocale = Locale('en', 'US');
  await EasyLocalization.ensureInitialized();
  runApp(
    EasyLocalization(
      supportedLocales: const [enLocale, Locale('nb', 'NO')],
      path: 'assets/translations',
      fallbackLocale: enLocale,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodSavr',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(0, 1, 27, .3),
          brightness: Brightness.dark,
        ),
      ),
      home: StreamBuilder(
        stream: getIt<IAuthService>().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.data == null) {
              return const AuthView(title: 'Welcome to FoodSavr');
            } else {
              return const MainAppScreen();
            }
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
