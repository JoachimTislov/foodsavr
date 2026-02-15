import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/firebase_options.dart';
import 'package:foodsavr/interfaces/auth_service_interface.dart';
import 'package:logger/logger.dart';

import 'service_locator.dart';
import 'utils/environment_config.dart';
import 'views/auth_view.dart';
import 'views/main_view.dart';

const dummyOptions = FirebaseOptions(
  apiKey: 'AIzaSyDummyKeyForDemoOnly',
  appId: '1:1234567890:web:dummyid123456',
  messagingSenderId: '',
  projectId: 'demo-project',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvironmentConfig.load();

  final logger = Logger(level: kReleaseMode ? Level.warning : Level.all);
  logger.i('Running in ${EnvironmentConfig.environment} mode');

  // init Firebase app if not already initialized
  // prevent multiple initializations when restarting app in development mode
  if (Firebase.apps.isEmpty) {
    logger.i('Firebase app not initialized, initializing now...');
    await Firebase.initializeApp(
      options: EnvironmentConfig.isDevelopment
          ? dummyOptions
          : DefaultFirebaseOptions.currentPlatform,
    );
  }
  final serviceLocater = ServiceLocator(logger);
  if (EnvironmentConfig.isDevelopment) {
    await serviceLocater.setupDevelopment();
  }
  await serviceLocater.registerDependencies();

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
              return const HomePage(title: 'Welcome to FoodSavr');
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
