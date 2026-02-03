import 'package:app/constants/environment_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'service_locator.dart';
import 'services/auth_service.dart';
import 'services/seeding_service.dart';
import 'utils/firebase_options.dart';
import 'views/auth_view.dart';
import 'views/main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Load environment variables
  await EnvironmentConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Setup dependency injection
  await setupServiceLocator();

  // Seed database with initial data
  await getIt<SeedingService>().seedDatabase();

  const enLocale = Locale('en', 'US');
  runApp(
    EasyLocalization(
      supportedLocales: const [
        enLocale,
        Locale('no', 'NO'),
      ],
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
    final authService = getIt<AuthService>();

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
        stream: authService.authStateChanges,
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
