import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../utils/config.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_collection_repository.dart';
import '../interfaces/i_product_repository.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import 'base_seeding_service.dart';

@injectable
class SeedingService extends BaseSeedingService {
  final IAuthService _authService;
  final IProductRepository _productRepository;
  final ICollectionRepository _collectionRepository;
  final Logger _logger;

  SeedingService(
    this._authService,
    this._productRepository,
    this._collectionRepository,
    this._logger,
  );

  /// Seeds the database using the test user credentials defined in Config.
  Future<void> seedDatabase() async {
    try {
      await super.seedAllData(Config.testUserEmail, Config.testUserPassword);
    } catch (e) {
      _logger.e('Error seeding database: $e');
    }
  }

  @override
  Future<String> createTestUser(String email, String password) async {
    User? user;
    try {
      final credential = await _authService.signUp(
        email: email,
        password: password,
      );
      user = credential.user;
    } catch (_) {
      // ignore error, user might already exist
    }
    if (user == null) {
      _logger.e('SeedingService: signUp returned a null user for $email');
      throw StateError('Failed to seed database: test user was not created.');
    }
    return user.uid;
  }

  @override
  Future<void> addProduct(Product product) async {
    await _productRepository.add(product);
  }

  @override
  Future<void> addCollection(Collection collection) async {
    await _collectionRepository.add(collection);
  }
}
