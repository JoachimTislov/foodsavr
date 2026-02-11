class Collection {
  final String id;
  final String name;
  final List<int> productIds;

  Collection({required this.id, required this.name, required this.productIds});

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'productIds': productIds};
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      productIds: List<int>.from(json['productIds'] as List),
    );
  }
}
