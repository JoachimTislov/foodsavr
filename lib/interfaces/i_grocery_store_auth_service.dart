import '../models/grocery_store_connection.dart';
import '../models/grocery_store_provider.dart';

abstract class IGroceryStoreAuthService {
  Future<List<GroceryStoreConnection>> getConnections();
  Future<void> authorize(GroceryStoreProvider provider);
  Future<void> disconnect(GroceryStoreProvider provider);
  Future<String?> getValidAccessToken(GroceryStoreProvider provider);
  Future<Map<String, dynamic>?> fetchUserProfile(GroceryStoreProvider provider);
}
