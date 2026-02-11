import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/interfaces/auth_service.dart';
import 'package:logger/logger.dart';

// import 'firebase_options.dart';
import 'firebase_options.dart';
import 'service_locator.dart';
import 'services/seeding_service.dart';
import 'utils/environment_config.dart';
import 'views/auth_view.dart';
import 'views/main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final logger = Logger();

  // Load environment variables
  await EnvironmentConfig.load();
  logger.i('Running in ${EnvironmentConfig.environment} mode');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // Setup dependency injection
  await registerDependencies(firebaseAuth, firestore);

  if (EnvironmentConfig.isDevelopment) {
    await firebaseAuth.useAuthEmulator('localhost', 9099);
    firestore.useFirestoreEmulator('localhost', 8080);

    logger.i('Seeding database with initial data...');
    // Seed database with initial data
    await getIt<SeedingService>().seedDatabase();
  }

  const enLocale = Locale('en', 'US');
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(0, 1, 27, .3),
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
