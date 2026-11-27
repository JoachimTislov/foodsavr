import '../constants/product_categories.dart';
import '../models/product_model.dart';

enum ListSort { original, expiry, name }

class ListQuery {
  const ListQuery({
    this.search = '',
    this.category,
    this.status,
    this.collectionId,
    this.sort = ListSort.original,
  });

  final String search;
  final String? category;
  final ProductStatus? status;
  final String? collectionId;
  final ListSort sort;

  List<Product> apply(
    List<Product> products, {
    required DateTime now,
    required int expiringSoonDays,
    Map<String, Set<String>> collectionProductIds = const {},
  }) {
    final term = search.trim().toLowerCase();
    final members = collectionProductIds[collectionId];
    final today = DateTime.utc(now.year, now.month, now.day);
    final filterCategory = ProductCategory.normalize(category);
    final results = products.where((product) {
      final productCategory = ProductCategory.normalize(product.category);
      return (filterCategory == null || productCategory == filterCategory) &&
          (collectionId == null || (members?.contains(product.id) ?? false)) &&
          (status == null ||
              _status(product, today, expiringSoonDays) == status) &&
          (term.isEmpty ||
              product.name.toLowerCase().contains(term) ||
              product.description.toLowerCase().contains(term) ||
              (product.barcode?.toLowerCase().contains(term) ?? false));
    }).toList();
    if (sort == ListSort.original) return results;

    return results..sort((a, b) {
      if (sort == ListSort.expiry) {
        final aDate = a.soonestExpirationDate;
        final bDate = b.soonestExpirationDate;
        if (aDate == null && bDate != null) return 1;
        if (aDate != null && bDate == null) return -1;
        if (aDate != null && bDate != null) {
          final byDate = aDate.compareTo(bDate);
          if (byDate != 0) return byDate;
        }
      }
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName == 0 ? a.id.compareTo(b.id) : byName;
    });
  }

  static ProductStatus _status(Product product, DateTime today, int window) {
    final date = product.soonestExpirationDate;
    if (date == null) return ProductStatus.fresh;
    final days = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(today).inDays;
    if (days < 0) return ProductStatus.expired;
    return days <= window ? ProductStatus.expiringSoon : ProductStatus.fresh;
  }
}
