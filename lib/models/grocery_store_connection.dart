import 'grocery_store_provider.dart';

class GroceryStoreConnection {
  const GroceryStoreConnection({
    required this.provider,
    required this.isAvailable,
    required this.isConnected,
    this.statusKey,
  });

  final GroceryStoreProvider provider;
  final bool isAvailable;
  final bool isConnected;
  final String? statusKey;
}
