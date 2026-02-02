import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:app/environment_config.dart'; // Import the new file

import 'authentication/application/auth_service.dart';
import 'authentication/presentation/my_home_page.dart';
import 'data/repositories/auth_repository.dart';
import 'data/database.dart';
import 'data/seeding.dart';
import 'main_app_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvironmentConfig.load(); // Load environment variables
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final seedingService = SeedingService(DatabaseService());
  await seedingService.seedDatabase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService(FirebaseAuthRepository());

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodSavr',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(0, 1, 27, .3),
        ),
      ),
      home: StreamBuilder(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.data == null) {
              return const MyHomePage(title: 'Welcome to FoodSavr');
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
