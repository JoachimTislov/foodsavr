/// An action that enriches the dashboard insights when their data is missing.
enum DashboardAction { addProduct, addExpiry, scanReceipt, createShoppingList }

/// The counts behind the dashboard insight tiles.
class DashboardInsights {
  /// Receipts older than this many days are left out of the recent item count.
  static const int recentReceiptDays = 30;

  final int productCount;
  final int expiringSoonCount;
  final int expiredCount;

  /// Whether any product carries an expiry date.
  final bool hasExpiries;
  final int shoppingListCount;
  final int shoppingListItemCount;
  final int receiptCount;

  /// Items on the receipts of the last [recentReceiptDays] days.
  final int recentReceiptItemCount;

  const DashboardInsights({
    this.productCount = 0,
    this.expiringSoonCount = 0,
    this.expiredCount = 0,
    this.hasExpiries = false,
    this.shoppingListCount = 0,
    this.shoppingListItemCount = 0,
    this.receiptCount = 0,
    this.recentReceiptItemCount = 0,
  });

  /// The actions the insight tiles offer in place of missing data. The quick
  /// actions leave these out so no action appears twice.
  Set<DashboardAction> get emptyActions => {
    if (productCount == 0) DashboardAction.addProduct,
    if (!hasExpiries) DashboardAction.addExpiry,
    if (receiptCount == 0) DashboardAction.scanReceipt,
    if (shoppingListCount == 0) DashboardAction.createShoppingList,
  };
}
