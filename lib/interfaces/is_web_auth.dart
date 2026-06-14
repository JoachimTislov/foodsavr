import 'package:foodsavr/models/m_grocery_store.dart';

abstract class IWebAuthService {
  Future<void> authorize(String provider);
  Future<GroceryStoreConnection> get connections;
}
