// ignore_for_file: avoid_print

import 'dart:io';
import 'package:foodsavr/services/seeding_service.dart';

const String projectId = 'demo-project';
const String host = 'localhost';
const String authPort = '9099';
const String firestorePort = '8080';

const String testUserEmail = 'bob@example.com';
const String testUserPassword = 'password123';

Future<void> main() async {
  print('🚀 Starting database seeding...');

  final seedingService = SeedingService(
    projectId: projectId,
    host: host,
    authPort: authPort,
    firestorePort: firestorePort,
  );

  if (!await seedingService.checkEmulators()) {
    print('❌ Error: Firebase Emulators are not running.');
    print('   Please run "make start-firebase-emulators" first.');
    exit(1);
  }

  try {
    print('👤 Creating test user: $testUserEmail...');
    final userId = await seedingService.createTestUser(
      testUserEmail,
      testUserPassword,
    );
    print('✅ User created with ID: $userId');

    print('🛡️ Seeding admin role for user...');
    await seedingService.seedUserDocument(userId);
    print('✅ Seeded user document.');

    print('🍎 Seeding inventory products...');
    final addedProducts = await seedingService.seedInventoryProducts(userId);
    print('✅ Seeded ${addedProducts.length} inventory products.');

    print('🌎 Seeding global products...');
    await seedingService.seedGlobalProducts();
    print('✅ Seeded global products.');

    print('📦 Seeding collections...');
    await seedingService.seedCollections(userId);
    print('✅ Seeded collections.');

    print('\n✨ Database seeding completed successfully!');
  } catch (e) {
    print('❌ Error during seeding: $e');
    exit(1);
  }
}
