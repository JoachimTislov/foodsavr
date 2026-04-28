// ignore_for_file: avoid_print

import 'dart:io';
import 'package:foodsavr/services/standalone_seeding_service.dart';

const String projectId = 'demo-project';
const String host = 'localhost';
const String authPort = '9099';
const String firestorePort = '8080';

const String testUserEmail = 'bob@example.com';
const String testUserPassword = 'password123';

Future<void> main() async {
  print('🚀 Starting database seeding...');

  final seedingService = StandaloneSeedingService(
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
    print('👤 Seeding database for test user: $testUserEmail...');
    final userId = await seedingService.seedAllData(
      testUserEmail,
      testUserPassword,
    );
    print('✅ Seeding completed for User ID: $userId');

    print('\n✨ Database seeding completed successfully!');
  } catch (e) {
    print('❌ Error during seeding: $e');
    exit(1);
  }
}
