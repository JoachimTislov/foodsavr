import 'package:app/repositories/collection_repository.dart';
import 'package:app/repositories/product_repository.dart';
import 'package:app/repositories/user_repository.dart';
import 'package:app/utils/environment_config.dart'; // Import the new file
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'repositories/auth_repository.dart';
import 'services/auth_service.dart';
import 'utils/firebase_options.dart';
import 'utils/seeding.dart';
import 'views/home.dart';
import 'views/main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await EnvironmentConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final userRepository = UserRepository();
  final productRepository = ProductRepository();
  final collectionRepository = CollectionRepository();
  final seedingService = SeedingService(
    userRepository,
    productRepository,
    collectionRepository,
  );
  await seedingService.seedDatabase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService(
    AuthRepository(FirebaseAuth.instance),
  );

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
