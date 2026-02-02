import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:app/environment_config.dart';
import 'package:provider/provider.dart';

import 'authentication/application/auth_service.dart';
import 'authentication/presentation/my_home_page.dart';
import 'data/repositories/auth_repository.dart';
import 'data/database.dart';
import 'data/seeding.dart';
import 'main_app_screen.dart';
import 'firebase_options.dart';
import 'products/application/product_service.dart';
import 'products/domain/product_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvironmentConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final seedingService = SeedingService(DatabaseService());
  await seedingService.seedDatabase();

  runApp(
    MultiProvider(
      providers: [
        Provider<FirebaseAuthRepository>(
          create: (_) => FirebaseAuthRepository(),
        ),
        Provider<AuthService>(
          create: (context) =>
              AuthService(context.read<FirebaseAuthRepository>()),
        ),
        Provider<ProductRepository>(create: (_) => ProductRepository()),
        Provider<ProductService>(
          create: (context) =>
              ProductService(context.read<ProductRepository>()),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
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
        stream: authService.authStateChanges,
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
