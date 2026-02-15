import '../utils/collection_types.dart';

class Collection {
  final String id;
  final String name;
  final List<int> productIds;
  final String userId; // Owner of the collection
  final String? description;
  final CollectionType
  type; // Type of collection (inventory, shopping list, etc.)

  Collection({
    required this.id,
    required this.name,
    required this.productIds,
    required this.userId,
    this.description,
    this.type = CollectionType.inventory,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'productIds': productIds,
      'userId': userId,
      'description': description,
      'type': type.name,
    };
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      productIds: List<int>.from(json['productIds'] as List),
      userId: json['userId'] as String,
      description: json['description'] as String?,
      type: CollectionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CollectionType.inventory,
      ),
    );
  }
}
