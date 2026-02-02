import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app/data/models/product_model.dart';
import 'package:app/products/application/product_service.dart';
import 'package:provider/provider.dart'; // Import provider

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Product>> _productsFuture;
  // Removed direct instantiation: final ProductService _productService = ProductService(FirebaseProductRepository());

  @override
  void initState() {
    super.initState();
    // Moved _productsFuture initialization to a place where context is available
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _productsFuture = _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    final productService = context.read<ProductService>(); // Get ProductService from provider
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Future.error('User not logged in');
    }
    return productService.getProductsForCurrentUser(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No products found.'));
          } else {
            final products = snapshot.data!;
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text(product.description),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
