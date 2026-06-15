import 'package:foodsavr/models/m_grocery_store.dart';
import 'package:webview_flutter/webview_flutter.dart';

abstract class IGroceryStoreAuthService {
  Future<void> authorize(GroceryStoreProvider provider);
  Future<List<GroceryStoreConnection>> getConnections();
  Future<Map<String, dynamic>?> fetchUserProfile(GroceryStoreProvider provider);
  WebViewController get webViewController;
}
